#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Qualify the full-language wasm32 WASI command target with materialized outcomes."""
import argparse, hashlib, json, os, pathlib, re, shutil, signal, subprocess, time
from archive_candidate import files

ROOT = pathlib.Path(__file__).resolve().parents[1]
SDK = 'swift-6.4.0-RELEASE_wasm'
from test_discovery import DISCOVERY
COUNTS = DISCOVERY['wasi_root_functions']
GROUPS = {'core': 6, 'resources': 1, 'schema': 2, 'streaming': 3, 'html': 6}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--scope', choices=['full', 'root-qa'], default='full')
    args = parser.parse_args()
    output = ROOT / args.output; output.mkdir(parents=True, exist_ok=True)
    result = {'schema_version': 1, 'status': 'running', 'target': 'wasm32-unknown-wasip1',
              'sdk': SDK, 'commands': [], 'modules': [], 'root_counts': COUNTS,
              'wasmkit_scope': '14 public consumer functions, 49 caps, 20 rooted vectors, debug/release command parity',
              'node_scope': 'complete core/HTML debug/release root suites, caps, public consumers and independent qualification; CLI runtime disposition is separate'}
    result['scope'] = args.scope
    result['streaming_timeout_policy'] = 'Identical assertions; native/Linux one-minute traits, pinned WASI SDK cooperative-timer limitation uses an interruptible 120-second host watchdog.'
    if args.scope == 'root-qa':
        result.update(qa_counts=DISCOVERY['qa_functions'], wasmkit_scope='Exact affected QA only; no full root/corpus refresh claim', node_scope='Complete core/HTML roots and affected QA; no separate corpus refresh')
    def save():
        (output / 'wasi.json').write_text(json.dumps(result, indent=2) + '\n')
    def run(name, command, check=lambda c, t: c == 0, timeout=1800):
        print('WASI ' + name, flush=True)
        path = output / (name + '.log'); started = time.monotonic()
        with path.open('w') as stream:
            process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            try: code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL); process.wait(); code = None
        text = path.read_text(errors='replace')
        passed = check(code, text)
        path.write_text(text.replace(str(ROOT), '.'))
        result['commands'].append({'name': name, 'command': [x.replace(str(ROOT), '.') for x in command],
            'exit_code': code, 'status': 'passed' if passed else 'failed', 'seconds': time.monotonic() - started,
            'log': path.relative_to(ROOT).as_posix(), 'log_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        save()
        if not passed: raise ValueError('Failed actual outcome: ' + name)
        return text
    def tests(expected):
        return lambda c, t: c == 0 and [int(n) for n in re.findall(r'Test run with (\d+) tests? in[^\n]*passed', t)] == [expected]
    def binary(scratch, config, name):
        found = [p for p in (ROOT / scratch).rglob(name + '.wasm') if p.parent.name == config.title() + '-webassembly-wasm32']
        if len(found) != 1: raise ValueError('Ambiguous/missing module: ' + name)
        path = found[0]
        result['modules'].append({'name': name, 'configuration': config, 'path': path.relative_to(ROOT).as_posix(),
            'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        return path
    try:
        swift, wasmkit, node = [shutil.which(x) for x in ['swift', 'wasmkit', 'node']]
        if not all([swift, wasmkit, node]): raise ValueError('Matching swift, wasmkit and node required on PATH')
        run('compiler', [swift, '--version'], lambda c, t: c == 0 and 'swift-6.4-RELEASE' in t)
        run('sdk', [swift, 'sdk', 'list'], lambda c, t: c == 0 and SDK in t.splitlines())
        run('wasmkit-version', [wasmkit, '--version']); run('node-version', [node, '--version'])
        manifest_text = run('root-manifest', [swift, 'package', 'dump-package'])
        # SwiftPM can write its lock-wait diagnostic before JSON on the merged log.
        # Accept only that precise preamble; the decoded manifest and trailing bytes
        # remain exact. The full diagnostic is retained in the command receipt.
        start = manifest_text.find('{')
        if start < 0: raise ValueError('Missing dump-package JSON')
        preamble = manifest_text[:start].strip()
        if preamble and not re.fullmatch(r"Another instance of SwiftPM .*waiting until that process has finished execution\.\.\.", preamble):
            raise ValueError('Unexpected manifest preamble: ' + preamble)
        manifest = json.loads(manifest_text[start:])
        if manifest['dependencies'] or sorted(p['name'] for p in manifest['products']) != ['JSON', 'JSONBridges', 'JSONHTML', 'JSONPatch', 'JSONSchema', 'JSONSchemaExamples', 'JSONStreaming', 'swift-json']:
            raise ValueError('Changed public products/dependencies')
        def invoke(engine, path, mode='command', arguments=(), repo=True, resources=True):
            if engine == 'node':
                return [node, 'Tools/WasmAudit/run-node.mjs', str(path), mode] + (['--resources'] if resources else []) + (['--repo'] if repo else []) + (['--', *arguments] if arguments else [])
            return [wasmkit, 'run'] + (['--dir', str(path.parent)] if resources else []) + (['--dir', str(ROOT)] if repo else []) + [str(path)] + (['--testing-library', 'swift-testing', *arguments] if mode == 'tests' else list(arguments) if mode == 'command' else [mode])
        modules = {}
        for config in ['debug', 'release']:
            build = [swift, 'build', '-c', config, '--swift-sdk', SDK]
            scratch = '.build/wasm-audit-root'
            run('root-build-' + config, build + ['--scratch-path', scratch, '--build-tests'] +
                (['-Xswiftc', '-enable-testing'] if config == 'release' else []))
            roots = {name: binary(scratch, config, name + '-test-runner') for name in COUNTS}
            invocations = 0
            for name, count in COUNTS.items():
                text = run('node-' + config + '-' + name, invoke('node', roots[name], 'tests'), tests(count), timeout=120 if name in ('JSONStreamingTests', 'JSONIntegrationTests') else 1800)
                invocations += sum(int(n) for n in re.findall(r'with (\d+) test cases passed', text))
            if invocations != DISCOVERY['wasi_parameterized_invocations']: raise ValueError('Changed root parameterized discovery: ' + str(invocations))
            if args.scope == 'root-qa':
                for name, count in DISCOVERY['qa_functions'].items():
                    for engine in ['node', 'wasmkit']:
                        run(engine + '-' + config + '-qa-' + name, invoke(engine, roots[name], 'tests', arguments=['--filter', 'qa']), tests(count), timeout=120 if name in ('JSONStreamingTests', 'JSONIntegrationTests') else 1800)
                continue
            for package, name, scratch in [('Tools/WasmAudit', 'WasmAudit', '.build/wasm-audit-consumer'),
                                            ('Tools/Qualification', 'Qualification', '.build/wasm-qualification'),
                                            ('Tools/MCPReadiness', 'MCPReadiness', '.build/wasm-readiness')]:
                run(name + '-build-' + config, build + ['--package-path', package, '--scratch-path', scratch, '--build-tests'])
                modules[config, name] = binary(scratch, config, name)
                runner = binary(scratch, config, {'WasmAudit': 'WasmAuditTests', 'Qualification': 'LimitQualificationTests', 'MCPReadiness': 'MCPReadinessTests'}[name] + '-test-runner')
                for engine in ['node', 'wasmkit']:
                    text = run(engine + '-' + config + '-' + name + '-tests', invoke(engine, runner, 'tests'), tests({'WasmAudit':14, 'Qualification':1, 'MCPReadiness':3}[name]))
                    if name == 'Qualification':
                        matrix = json.loads((ROOT / 'Documentation/Qualification/LimitsMatrix.json').read_text())
                        expected = {m['metric']: m['public_probe_outcome'] for m in matrix['metrics']}
                        probes = re.findall(r'^CAP_PROBE (\w+) (\S+)$', text, re.MULTILINE)
                        if len(probes) != 49 or dict(probes) != expected: raise ValueError('Missing or changed 49 cap outcomes')
            for engine in ['node', 'wasmkit']:
                for mode in ['profiles', *GROUPS]:
                    def check(c, t, mode=mode):
                        if c != 0 or 'AUDIT_COMPLETED mode=' + mode not in t: return False
                        if mode == 'profiles': return all(x in t for x in ['TARGET int_bits=32','PROFILE conservative passed','PROFILE balanced passed','PROFILE offline passed','DEFAULT_PARSER passed','PERSISTENCE passed'])
                        return len(re.findall(r'^CASE \S+ passed$', t, re.MULTILINE)) == GROUPS[mode]
                    run(engine + '-' + config + '-' + mode, invoke(engine, modules[config, 'WasmAudit'], mode, repo=False), check)
            # The full independent suite is evaluated in the Node host, with the
            # same explicit policy table as Apple/Linux; WasmKit's scope is above.
            if config == 'release':
                for engine in ['node', 'wasmkit']:
                    destination = output / (engine + '-consumer.json')
                    run(engine + '-rooted-consumer', invoke(engine, modules[config, 'MCPReadiness'], arguments=[str(destination)]))
                    consumer = json.loads(destination.read_text())
                    if consumer['status'] != 'passed' or (consumer['positiveCases'],consumer['negativeCases'],consumer['operationalErrors']) != (8,12,2) or len(consumer['outcomes']) != 20:
                        raise ValueError('Missing rooted public consumer cases')
                destination = output / 'qualification.json'
                run('node-independent-qualification', invoke('node', modules[config, 'Qualification'], arguments=['--all','--root',str(ROOT),'--registry','Documentation/Qualification/FixtureRegistry.json','--output',destination.relative_to(ROOT).as_posix()]))
                qualification = json.loads(destination.read_text())
                expected = {'nst/JSONTestSuite':(318,287,31), 'json-schema-org/JSON-Schema-Test-Suite':(2337,2300,37)}
                if qualification['status'] != 'passed' or qualification['errors'] or len(qualification['suites']) != 2: raise ValueError('Independent qualification failed')
                for suite in qualification['suites']:
                    if (suite['observed_cases'],suite['passed_cases'],suite['policy_cases']) != expected[suite['repository']] or suite['failed_cases'] or suite['unexpected_skips'] or len(suite['cases']) != suite['observed_cases']: raise ValueError('Changed suite policy/cardinality')
                authored = {a['name']:a for a in qualification['authored']}
                for name,count in [('authored_public_semantics',82),('public_budget_and_counter_boundaries',9),('deterministic_malformed_utf8_replay',4396)]:
                    if authored[name]['observed'] != count or authored[name]['failed']: raise ValueError('Changed authored outcomes')
        run('strict-memory', [swift,'build','--swift-sdk',SDK,'--scratch-path','.build/wasm-strict','-Xswiftc','-strict-memory-safety','-Xswiftc','-warnings-as-errors'])
        if args.scope == 'root-qa':
            result['status'] = 'passed'; save(); return 0
        path = modules['release','WasmAudit']
        for engine in ['node','wasmkit']:
            run(engine + '-missing-resources', invoke(engine,path,'missing-resources',repo=False,resources=False), lambda c,t:c == 0 and 'MISSING_RESOURCES structured_metaSchema' in t)
        run('abi', invoke('node',path,'imports',repo=False))
        measurements = []
        for iteration in range(3):
            text = run('node-runtime-sample-' + str(iteration), invoke('node',path,'benchmark',repo=False))
            measurements.append(json.loads(re.search(r'^WASI_HOST_MEASURE (.+)$',text,re.MULTILINE).group(1)))
        result['measurements'] = measurements
        result['measurement_policy'] = 'Module-run time and allocated linear-memory pages; host process RSS is separate, not owned logical retention, workload allocation count or a hard bound.'
        result['materialized_outcomes'] = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.json') if p.name != 'wasi.json'}
        result['status'] = 'passed'; save(); return 0
    except (OSError,ValueError,KeyError,AttributeError) as error:
        result['status'] = 'failed'; result['error'] = str(error); save(); print(str(error),flush=True); return 1

if __name__ == '__main__': raise SystemExit(main())
