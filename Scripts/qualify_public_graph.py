#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Qualify public graph imports, semantics and three executable DocC examples."""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
from archive_candidate import files

ROOT = pathlib.Path(__file__).resolve().parents[1]
CHECKS = {'GP%02d' % i for i in range(1,17)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    output = ROOT / parser.parse_args().output
    output.mkdir(parents=True, exist_ok=True)
    shared = (ROOT / 'Tests/JSONInspectionTests/GraphPublicAcceptanceTests.swift').read_text().split('\n@Test')[0].replace('import Testing\n', '')
    actual = (ROOT / 'Tools/GraphPublicQualification/Sources/GraphPublicConsumer/Main.swift').read_text()
    if actual.split('\n@main struct')[0] != shared:
        raise ValueError('Public consumer scenario bytes differ from the sixteen pinned root cases')
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
        checks = re.findall(r'^GRAPH_PUBLIC_CHECK (\S+) passed$', text, re.M)
        if len(checks) != 16 or set(checks) != CHECKS or 'GRAPH_PUBLIC_CONSUMER passed cases=16' not in text:
            raise ValueError('Missing/duplicate graph consumer checks: ' + name)
        resource = re.search(r'^GRAPH_PUBLIC_RESOURCE work=(\d+) retained=(\d+) peak=(\d+) nodes=(\d+)$', text, re.M)
        if resource is None or not all(int(x) > 0 for x in resource.groups()):
            raise ValueError('Missing finite cumulative report: ' + name)
        receipt['consumer_results'][name] = dict(cases=checks, work_units=int(resource[1]),
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
                      'graph_external_consumer', '-I', str(modules),
                      '-O' if config == 'release' else '-Onone']
            consumer(config, ['swift', 'run', '-c', config, '--package-path',
                              'Tools/GraphPublicQualification', 'GraphPublicConsumer'])
            guide = ROOT / 'Sources/JSONInspection/Documentation.docc/SourceBoundGraphs.md'
            fences = re.findall(r'```swift\n(.*?)\n```', guide.read_text(), re.S)
            if len(fences) != 3:
                raise ValueError('Changed three-fence guide inventory')
            for index, fence in enumerate(fences):
                file = output / ('guide-' + str(index) + '.swift')
                file.write_text('import Foundation\nimport JSON\nimport JSONNavigation\nimport JSONInspection\n'
                    '@main struct Guide { static func main() throws {\n' + fence + '\n} }\n')
                binary = output / ('guide-' + config + '-' + str(index))
                run(config + '-guide-' + str(index), common + ['-parse-as-library', str(file), *objects, '-o', str(binary)])
                run(config + '-guide-' + str(index) + '-run', [str(binary)])
            probes = [('core-import-isolation', 'import JSON\nlet x = JSONGraphProjection.self\n', 'cannot find'), ('scope-isolation', 'import JSON\nlet x = JSONReadScope.self\n', 'cannot find'), ('capability-isolation', 'import JSONNavigation\nlet x = JSONTraversalContext.self\n', 'cannot find'), ('forged-graph', 'import JSON\nimport JSONNavigation\nimport JSONInspection\nfunc f(_ d: JSONDocument, _ p: JSONGraphProfile, _ s: JSONTraversalSummary) { _ = JSONGraphProjection(document: d, profile: p, nodeIDs: [], edges: [], offsets: [], adjacency: [], traversal: s) }\n', 'initializer is inaccessible'), ('immutable-profile', 'import JSONInspection\nfunc f(_ p: inout JSONGraphProfile) { p.nodesAt.removeAll() }\n', "'let' constant"), ('immutable-count', 'import JSONInspection\nfunc f(_ p: inout JSONGraphProjection) { p.nodeCount = 0 }\n', 'get-only property'), ('private-ids', 'import JSONInspection\nfunc f(_ p: JSONGraphProjection) { _ = p.nodeIDs }\n', 'is inaccessible'), ('private-edges', 'import JSONInspection\nfunc f(_ p: JSONGraphProjection) { _ = p.edges }\n', 'is inaccessible'), ('private-offsets', 'import JSONInspection\nfunc f(_ p: JSONGraphProjection) { _ = p.offsets }\n', 'is inaccessible'), ('private-adjacency', 'import JSONInspection\nfunc f(_ p: JSONGraphProjection) { _ = p.adjacency }\n', 'is inaccessible'), ('private-builder', 'import JSONInspection\nlet x = GraphBuilder.self\n', 'cannot find'), ('private-query', 'import JSONInspection\nlet x = GraphQuery.self\n', 'cannot find'), ('private-record', 'import JSONInspection\nlet x = JSONGraphEdgeRecord.self\n', 'cannot find')]
            for name, source, expected in probes:
                file = output / (name + '.swift'); file.write_text(source)
                run(config + '-' + name, common + ['-parse-as-library', '-c', str(file),
                    '-o', str(output / (config + '-' + name + '.o'))], expected)
        consumer('address', ['swift', 'run', '-c', 'release', '--sanitize', 'address',
            '--scratch-path', '.build/graph-public-consumer-address', '--package-path',
            'Tools/GraphPublicQualification', 'GraphPublicConsumer'])
        receipt['status'] = 'passed'
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        receipt.update(status='failed', error=str(error))
    save()
    print('PUBLIC_GRAPH_COMPILER ' + receipt['status'] +
          ' configurations=2 consumer_cases=16 address_cases=16 guide_fences=3 negative_probes=26')
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
