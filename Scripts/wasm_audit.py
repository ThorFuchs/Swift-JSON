#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Audit the unchanged package on WASI; a completed audit is not platform qualification."""
import argparse, hashlib, json, os, pathlib, re, shutil, subprocess, time

ROOT = pathlib.Path(__file__).resolve().parents[1]
SDK = 'swift-6.4.0-RELEASE_wasm'
CASE_COUNTS = {'core': 6, 'resources': 1, 'schema': 2, 'streaming': 3}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = ROOT / args.output; output.mkdir(parents=True, exist_ok=True)
    commands = []
    result = {'audit_status': 'running', 'support_qualification': 'blocked', 'sdk': SDK,
              'commands': commands, 'findings': [], 'runtime_feature_groups': {}}
    def save():
        (output / 'audit.json').write_text(json.dumps(result, indent=2) + '\n')
    def run(name, command, check, outcome='passed'):
        path = output / (name + '.log'); start = time.monotonic()
        with path.open('w') as stream:
            code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=600).returncode
        text = path.read_text(errors='replace').replace(str(ROOT), '.')
        path.write_text(text)
        matched = check(code, text)
        commands.append({'name': name, 'command': [arg.replace(str(ROOT), '.') for arg in command],
                         'exit_code': code, 'status': outcome if matched else 'unexpected_failure',
                         'seconds': time.monotonic() - start, 'log': path.relative_to(ROOT).as_posix(),
                         'log_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        save()
        if not matched: raise ValueError('Unexpected outcome: ' + name)
        return text
    try:
        swift = shutil.which('swift'); wasmkit = shutil.which('wasmkit'); node = shutil.which('node')
        if not all([swift, wasmkit, node]): raise ValueError('swift, wasmkit and node are required on PATH')
        run('compiler', [swift, '--version'], lambda c, t: c == 0 and 'swift-6.4-RELEASE' in t)
        run('sdk', [swift, 'sdk', 'list'], lambda c, t: c == 0 and SDK in t.splitlines())
        run('wasmkit-version', [wasmkit, '--version'], lambda c, t: c == 0 and bool(t.strip()))
        run('node-version', [node, '--version'], lambda c, t: c == 0 and bool(t.strip()))
        manifest = json.loads(run('root-manifest', [swift, 'package', 'dump-package'], lambda c, t: c == 0))
        assert not manifest['dependencies'] and sorted(p['name'] for p in manifest['products']) == ['JSON', 'JSONPatch', 'JSONSchema', 'JSONStreaming']
        root_build = '.build/wasm-audit-root'
        run('root-build', [swift, 'build', '--swift-sdk', SDK, '--scratch-path', root_build], lambda c, t: c == 0)
        scratch = '.build/wasm-audit-consumer'
        base = [swift, 'build', '--package-path', 'Tools/WasmAudit', '--swift-sdk', SDK, '--scratch-path', scratch, '--build-tests']
        run('consumer-and-tests-build', base, lambda c, t: c == 0)
        binaries = list((ROOT / scratch).rglob('WasmAudit.wasm')); assert len(binaries) == 1
        wasm = binaries[0]; tests = wasm.parent / 'WasmAuditTests-test-runner.wasm'; assert tests.is_file()
        result['modules'] = [{'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size,
                              'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in [wasm, tests]]
        for runtime in ['wasmkit', 'node']:
            for mode in ['profiles', *CASE_COUNTS]:
                command = [wasmkit, 'run', '--dir', str(wasm.parent), str(wasm), mode] if runtime == 'wasmkit' else [node, 'Tools/WasmAudit/run-node.mjs', str(wasm), mode, '--resources']
                def correct(code, text, mode=mode):
                    if code != 0 or 'AUDIT_COMPLETED mode=' + mode not in text: return False
                    if mode == 'profiles':
                        return all(line in text for line in ['TARGET int_bits=32', 'profile=balanced blocked code=invalidLimits', 'profile=offline blocked code=invalidLimits', 'default_parser blocked code=invalidLimits', 'payload_explicit_conservative blocked balanced_intersection_invalidLimits'])
                    return len(re.findall(r'^CASE \S+ passed$', text, re.MULTILINE)) == CASE_COUNTS[mode]
                run(runtime + '-' + mode, command, correct, 'observed_support_blocker' if mode == 'profiles' else 'passed')
            command = [wasmkit, 'run', '--dir', str(tests.parent), str(tests), '--testing-library', 'swift-testing'] if runtime == 'wasmkit' else [node, 'Tools/WasmAudit/run-node.mjs', str(tests), 'tests', '--resources']
            run(runtime + '-swift-testing', command, lambda c, t: c == 0 and re.findall(r'Test run with (\d+) tests? in[^\n]*passed', t) == ['13'])
            result['runtime_feature_groups'][runtime] = sum(CASE_COUNTS.values())
        imports = run('imports', [node, 'Tools/WasmAudit/run-node.mjs', str(wasm), 'imports'], lambda c, t: c == 0)
        abi = json.loads(imports[imports.index('{'):]); assert abi['imports'] and all(i['module'] == 'wasi_snapshot_preview1' for i in abi['imports'])
        result['abi'] = abi
        run('bare-host', [node, 'Tools/WasmAudit/run-node.mjs', str(wasm), 'bare-host'], lambda c, t: c == 0 and 'OBSERVATION bare_host blocked missing_WASI_imports' in t, 'observed_host_requirement')
        run('unmounted-resources', [wasmkit, 'run', str(wasm), 'resources'], lambda c, t: c != 0 and 'BundleC' in t and 'Trap: unreachable' in t, 'observed_deployment_failure')
        run('unchanged-root-suite', [swift, 'test', '--swift-sdk', SDK, '--scratch-path', '.build/wasm-audit-root-tests', '--disable-xctest'], lambda c, t: c != 0 and "no such module 'Dispatch'" in t, 'blocked_before_evaluation')
        run('embedded-json', [swift, 'build', '--swift-sdk', SDK + '-embedded', '--target', 'JSON', '--scratch-path', '.build/wasm-audit-embedded'], lambda c, t: c != 0 and "no such module 'Foundation'" in t, 'unsupported_sdk_surface')
        result['findings'] = [
            'Balanced/offline profiles and default operations reject wasm32 because cumulative UInt64 quotas are subjected to Int capacity validation.',
            'Persistence validates balanced before intersecting explicit limits, so explicit conservative persistence is blocked too.',
            'The unchanged root suite imports unavailable Dispatch; zero root cases were evaluated.',
            'Schema execution requires its actual resource bundle directory; unmounted SDK bundle discovery traps.',
            'The module is a WASI Preview 1 command requiring system imports; bare-host instantiation and Embedded Swift are not supported by these bytes.',
            'Task concurrency probes use the cooperative WASI executor, not physical parallelism. Browser hosting, all independent suites, all 49 WASI cap probes and memory/performance calibration remain unqualified.']
        result['audit_status'] = 'completed'
        save(); print(json.dumps({k: v for k, v in result.items() if k not in ('commands', 'abi')}, indent=2))
        return 0
    except (OSError, ValueError, AssertionError, subprocess.TimeoutExpired) as error:
        result['audit_status'] = 'incomplete'; result['error'] = str(error); save(); print(str(error)); return 1

if __name__ == '__main__':
    raise SystemExit(main())
