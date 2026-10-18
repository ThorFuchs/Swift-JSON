#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Qualify public exact set/matrix APIs, external package and three executed DocC examples."""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
from archive_candidate import files

ROOT = pathlib.Path(__file__).resolve().parents[1]
CHECKS = {'inclusive-ledgers', 'shape-refusals', 'captured-source', 'numeric-matrix', 'typed-root-paths', 'exact-scalars', 'large-integers', 'cumulative-reports', 'inclusive-capacity', 'source-positions', 'zero-shapes', 'first-lexeme', 'ordered-and-unordered', 'concurrent-reads', 'bounds-precedence', 'null-and-missing', 'public-import', 'separate-read-cost', 'orientation', 'cancellation-health'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    output = ROOT / parser.parse_args().output
    output.mkdir(parents=True, exist_ok=True)
    inputs = [{'path': p.relative_to(ROOT).as_posix(),
               'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]
    receipt = dict(status='running', source_inputs=inputs, commands=[], consumer_results={})

    def save():
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')

    def run(name, command, expected=None):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=900)
        text = result.stdout + result.stderr
        crash = result.returncode < 0 or any(x in text for x in
                    ['Stack dump:', 'Assertion failed', 'fatal error encountered during compilation'])
        diagnostics = re.findall(r': error: ([^\n]+)', result.stderr)
        passed = not crash and (result.returncode == 0 if expected is None else
                    result.returncode > 0 and any(expected in d for d in diagnostics))
        log = output / (name + '.log')
        log.write_text(text.replace(str(ROOT), '.'))
        receipt['commands'].append(dict(name=name, command=[x.replace(str(ROOT), '.') for x in command],
            exit_code=result.returncode, status='passed' if passed else 'failed', compiler_crash=crash,
            expected_diagnostic=expected, primary_diagnostics=diagnostics,
            log=log.relative_to(ROOT).as_posix(), log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        save()
        if not passed:
            raise ValueError('Unexpected compiler/consumer outcome: ' + name)
        return result.stdout

    def consumer(name, command):
        text = run(name, command)
        checks = re.findall(r'^EXACT_PROJECTION_CHECK (\S+) passed$', text, re.M)
        if len(checks) != 20 or set(checks) != CHECKS or 'EXACT_PROJECTION_CONSUMER passed cases=20' not in text:
            raise ValueError('Missing/duplicate inspection consumer checks: ' + name)
        resource = re.search(r'^EXACT_PROJECTION_RESOURCE work=(\d+) retained=(\d+) peak=(\d+) nodes=(\d+)$', text, re.M)
        if resource is None or not all(int(x) > 0 for x in resource.groups()):
            raise ValueError('Missing finite cumulative report: ' + name)
        costs = re.findall(r'^EXACT_ACCESS_COST sibling_items=(\d+) nodes=(\d+) member_work=(\d+) cell_work=(\d+) read_retained=(\d+) read_peak=(\d+)$', text, re.M)
        if len(costs) != 3 or [int(c[0]) for c in costs] != [0,16,128]:
            raise ValueError('Missing access-cost witnesses')
        receipt['consumer_results'][name] = dict(cases=checks, access_costs=costs, work_units=int(resource[1]),
            logical_retained_bytes=int(resource[2]), peak_logical_retained_bytes=int(resource[3]),
            admitted_nodes=int(resource[4]))
        save()

    try:
        for config in ['debug', 'release']:
            run(config + '-build', ['swift', 'build', '-c', config, '--target', 'JSONInspection'])
            binpath = pathlib.Path(run(config + '-binpath', ['swift', 'build', '-c', config, '--show-bin-path']).strip())
            modules = binpath / 'Modules' if (binpath / 'Modules').is_dir() else binpath
            objects = []
            for module in ['JSON', 'JSONNavigation', 'JSONInspection']:
                aggregate = binpath / (module + '.o')
                selected = [aggregate] if aggregate.is_file() else sorted((binpath / (module + '.build')).glob('*.o'))
                if not selected:
                    raise ValueError('Missing built objects: ' + module)
                objects.extend(str(p) for p in selected)
            common = ['swiftc', '-swift-version', '6', '-warnings-as-errors', '-package-name',
                      'exact_projection_external_consumer', '-I', str(modules),
                      '-O' if config == 'release' else '-Onone']
            consumer(config, ['swift', 'run', '-c', config, '--package-path',
                              'Tools/ExactProjectionQualification', 'ExactProjectionConsumer'])
            guide = ROOT / 'Sources/JSONInspection/Documentation.docc/ExactProjections.md'
            fences = re.findall(r'```swift\n(.*?)\n```', guide.read_text(), re.S)
            if len(fences) != 3:
                raise ValueError('Changed three-fence guide inventory')
            for index, fence in enumerate(fences):
                file = output / ('guide-' + str(index) + '.swift')
                file.write_text('import Foundation\nimport JSON\nimport JSONInspection\n'
                    '@main struct Guide { static func main() throws {\n' + fence + '\n} }\n')
                binary = output / ('guide-' + config + '-' + str(index))
                run(config + '-guide-' + str(index), common + ['-parse-as-library', str(file), *objects, '-o', str(binary)])
                run(config + '-guide-' + str(index) + '-run', [str(binary)])
            probes = [('core-import-isolation', 'import JSON\nlet x = JSONStructuralSetProjection.self\n', 'cannot find'), ('forged-set', 'import JSONInspection\nlet x = JSONStructuralSetProjection()\n', 'initializer is inaccessible'), ('forged-matrix', 'import JSONInspection\nlet x = JSONNumericMatrixProjection()\n', 'initializer is inaccessible'), ('representatives-readonly', 'import JSONInspection\nfunc f(_ x: inout JSONStructuralSetProjection) { x.representativeIndices.removeAll() }\n', "'let' constant"), ('dimensions-readonly', 'import JSONInspection\nfunc f(_ x: inout JSONNumericMatrixProjection) { x.rowCount = 99 }\n', 'get-only property'), ('source-readonly', 'import JSON\nimport JSONInspection\nfunc f(_ x: inout JSONNumericMatrixProjection) { x.document = .init(root: .null) }\n', "'let' constant"), ('context-isolation', 'import JSONNavigation\nlet x = JSONTraversalContext.self\n', 'cannot find'), ('meter-isolation', 'import JSON\nlet x = JSONWorkMeter.self\n', 'cannot find'), ('reducer-isolation', 'import JSONInspection\nlet x = StructuralSetReducer.self\n', 'cannot find'), ('accounting-isolation', 'import JSONInspection\nlet x = P2Accounting.self\n', 'cannot find'), ('wrong-view-operation', 'import JSONInspection\nfunc f(_ x: JSONStructuralSetProjection) throws { _ = try x.element(row: 0, column: 0) }\n', 'has no member'), ('no-source-rebinding', 'import JSON\nimport JSONInspection\nfunc f(_ x: JSONNumericMatrixProjection) throws { _ = try x.element(row: 0, column: 0, document: .init(root: .null)) }\n', "extra argument 'document'")]
            for name, source, expected in probes:
                file = output / (name + '.swift'); file.write_text(source)
                run(config + '-' + name, common + ['-parse-as-library', '-c', str(file),
                    '-o', str(output / (config + '-' + name + '.o'))], expected)
        consumer('address', ['swift', 'run', '-c', 'release', '--sanitize', 'address',
            '--scratch-path', '.build/exact-projection-consumer-address', '--package-path',
            'Tools/ExactProjectionQualification', 'ExactProjectionConsumer'])
        receipt['status'] = 'passed'
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        receipt.update(status='failed', error=str(error))
    save()
    print('PUBLIC_EXACT_PROJECTIONS_COMPILER ' + receipt['status'] +
          ' configurations=2 consumer_cases=20 address_cases=20 guide_fences=3 negative_probes=24')
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
