#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Export every instrumented root bundle; reject partial or stale Swift coverage."""
import argparse
import datetime
import hashlib
import json
import pathlib
import platform
import shutil
import subprocess
import sys
import time
from archive_candidate import files
from test_discovery import DISCOVERY, ROOT, ROOT_COUNTS, PARAMETER_INVOCATIONS, check_root

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def executable_objects(bin_directory):
    result = {}
    for name in ROOT_COUNTS:
        candidates = [bin_directory / (name + '.xctest') / 'Contents/MacOS' / name,
                      bin_directory / (name + '.xctest'),
                      bin_directory / (name + '-test-runner')]
        found = [p for p in candidates if p.is_file()]
        if len(found) != 1:
            raise ValueError('Missing or ambiguous instrumented executable: ' + name)
        result[name] = found[0]
    return result

def validate_export(export, root=ROOT, policy=DISCOVERY):
    """Validate the executable source denominator before calculating percentages."""
    expected = {p.relative_to(root).as_posix() for p in (root / 'Sources').rglob('*.swift')}
    unmapped = set(policy['coverage_unmapped'])
    generated = set(policy['coverage_generated'])
    if not unmapped <= expected or not generated <= expected:
        raise ValueError('Coverage classification references absent source')
    mapped = {}
    for data in export['data']:
        for record in data['files']:
            file = pathlib.Path(record['filename']).resolve()
            try:
                name = file.relative_to(root.resolve()).as_posix()
            except ValueError:
                continue  # SDK/macro code is outside the library denominator.
            if not name.startswith('Sources/'):
                continue
            if name not in expected or name in mapped:
                raise ValueError('Unexpected or duplicate library mapping: ' + name)
            # LLVM saturates negative derived counts at Int64.max. Such a
            # segment is not evidence of trillions of executions or coverage.
            # Concurrent Swift invocations need atomic instrumentation counters.
            if any(segment[3] and segment[2] >= 2**63 - 1 for segment in record.get('segments', [])):
                raise ValueError('Saturated LLVM coverage counter: ' + name)
            for kind in ['lines', 'regions', 'functions', 'branches', 'mcdc']:
                count = record['summary'][kind]['count']
                covered = record['summary'][kind]['covered']
                if type(count) is not int or type(covered) is not int or not 0 <= covered <= count:
                    raise ValueError('Invalid coverage counter: ' + name + '/' + kind)
            mapped[name] = record['summary']
    missing = expected - unmapped - set(mapped)
    if missing:
        raise ValueError('Incomplete library export: ' + ', '.join(sorted(missing)))
    if unmapped & set(mapped):
        raise ValueError('Unmapped classification changed; review compiler/source mapping')

    def totals(names):
        result = {}
        for kind in ['lines', 'regions', 'functions', 'branches', 'mcdc']:
            count = sum(mapped[name][kind]['count'] for name in names)
            covered = sum(mapped[name][kind]['covered'] for name in names)
            result[kind] = dict(count=count, covered=covered,
                                percent=100*covered/count if count else None)
        return result

    modules = {}
    for test_target in policy['root_functions']:
        module = test_target.removesuffix('Tests')
        names = {name for name in mapped if name.startswith('Sources/' + module + '/')}
        if not names or not totals(names)['regions']['count']:
            raise ValueError('Missing executable module coverage: ' + module)
        modules[module] = dict(mapped_files=len(names), authored=totals(names - generated),
                               generated=totals(names & generated))
    return dict(modules=modules, authored=totals(set(mapped)-generated),
                generated=totals(set(mapped)&generated),
                files={name:mapped[name] for name in sorted(mapped)},
                unmapped=policy['coverage_unmapped'],
                branch_counters_available=bool(totals(mapped)['branches']['count']),
                mcdc_counters_available=bool(totals(mapped)['mcdc']['count']))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--verify-export', help='Check an existing export without compiling/running tests')
    args = parser.parse_args()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    receipt = dict(schema_version=1, status='running', commands=[], started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    def save():
        (output / 'coverage.json').write_text(json.dumps(receipt, indent=2)+'\n')
    def run(command, name, binary=False):
        start = time.monotonic()
        log = output / name
        with log.open('wb') as stream:
            process = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
        receipt['commands'].append(dict(command=[str(c).replace(str(ROOT), '.') for c in command],
            exit_code=process.returncode, seconds=time.monotonic()-start, log=name, sha256=digest(log)))
        save()
        if process.returncode:
            raise ValueError('Command failed: ' + ' '.join(map(str, command)))
        return log.read_bytes() if binary else log.read_text()
    try:
        if args.verify_export:
            export = json.loads((ROOT / args.verify_export).read_text())
            receipt.update(validate_export(export), scope='existing export verification only', status='passed')
        else:
            inputs = [{'path':p.relative_to(ROOT).as_posix(), 'sha256':digest(p)} for p in files()]
            receipt['source_inputs'] = inputs
            receipt['source_manifest_sha256'] = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
            receipt['toolchain'] = run(['swift', '--version'], 'compiler.log').strip()
            if platform.system() == 'Darwin':
                llvm = ['xcrun', 'llvm-cov']
            else:
                tool = pathlib.Path(shutil.which('swift')).resolve().parent / 'llvm-cov'
                if not tool.is_file():
                    raise ValueError('Swift toolchain llvm-cov required')
                llvm = [str(tool)]
            receipt['llvm'] = run(llvm + ['--version'], 'llvm.log').strip()
            profile_flags = ['-Xswiftc', '-Xllvm', '-Xswiftc', '-instrprof-atomic-counter-update-all']
            receipt['counter_policy'] = 'Atomic profiling increments for concurrent tests. Reject saturated LLVM segment counts rather than count them as executed paths. Profiling flags do not alter package manifests or ordinary product builds.'
            tests = run(['swift', 'test', '--enable-code-coverage', '--disable-xctest', *profile_flags], 'tests.log')
            if not check_root(tests):
                raise ValueError('Exact root discovery/parameterized cardinality changed')
            receipt.update(root_counts=ROOT_COUNTS, parameterized_invocations=PARAMETER_INVOCATIONS)
            bin_directory = pathlib.Path(run(['swift', 'build', '--show-bin-path'], 'bin-path.log').strip())
            objects = executable_objects(bin_directory)
            coverage_path = pathlib.Path(run(['swift', 'test', '--show-codecov-path'], 'profile-path.log').strip())
            profile = coverage_path.parent / 'default.profdata'
            if not profile.is_file():
                raise ValueError('Merged coverage profile missing')
            shutil.copy2(profile, output / 'default.profdata')
            receipt['profile_sha256'] = digest(profile)
            receipt['binaries'] = {name:dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for name,p in objects.items()}
            first, *others = objects.values()
            command = llvm + ['export', str(first), '-instr-profile=' + str(profile)]
            for other in others:
                command.extend(['-object', str(other)])
            raw = run(command, 'all-modules.raw.json', binary=True)
            export = json.loads(raw)
            receipt.update(validate_export(export))
            try:
                validate_export(json.loads(coverage_path.read_text()))
                receipt['default_export'] = dict(status='complete')
            except ValueError as error:
                receipt['default_export'] = dict(status='incomplete', error=str(error))
            # This actual exporter probe must omit the schema-only executable;
            # regex code alone is also linked in schema tests and is not a useful omission.
            omitted = [p for name,p in objects.items() if name != 'JSONSchemaTests']
            negative_command = llvm + ['export', str(omitted[0]), '-instr-profile=' + str(profile)]
            for other in omitted[1:]:
                negative_command.extend(['-object', str(other)])
            negative = run(negative_command, 'omitted-schema.raw.json', binary=True)
            try:
                validate_export(json.loads(negative))
            except ValueError as error:
                if 'Incomplete library export:' not in str(error):
                    raise
                receipt['omitted_binary_probe'] = dict(status='rejected', omitted='JSONSchemaTests', reason=str(error))
            else:
                raise ValueError('Harness accepted export missing the schema executable')
            # Public summaries and normalized export contain no local source path.
            for data in export['data']:
                for record in data['files']:
                    record['filename'] = record['filename'].replace(str(ROOT), '.')
                for function in data.get('functions', []):
                    function['filenames'] = [p.replace(str(ROOT), '.') for p in function['filenames']]
            (output / 'all-modules.json').write_text(json.dumps(export)+'\n')
            receipt['raw_export_sha256'] = hashlib.sha256(raw).hexdigest()
            receipt['normalized_export_sha256'] = digest(output / 'all-modules.json')
            if inputs != [{'path':p.relative_to(ROOT).as_posix(), 'sha256':digest(p)} for p in files()]:
                raise ValueError('Source changed during instrumented run')
            receipt.update(status='passed', source_inputs_unchanged=True,
                interpretation='Execution lines/regions, not assertion completeness; unavailable branch counters are null, generated tables are separate.')
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
        receipt.update(status='failed', error=str(error).replace(str(ROOT), '.'))
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
    print(json.dumps({k:receipt[k] for k in ['status', 'error', 'root_counts', 'parameterized_invocations', 'authored'] if k in receipt}, indent=2))
    return 0 if receipt['status'] == 'passed' else 1

if __name__ == '__main__':
    sys.exit(main())
