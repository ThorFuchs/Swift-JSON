#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Full-codegen proof of graph invariants and non-public storage/reducer boundaries."""
import argparse, hashlib, json, pathlib, re, subprocess
from archive_candidate import files
ROOT = pathlib.Path(__file__).resolve().parents[1]
POSITIVE = r'''import JSON
import JSONNavigation
import JSONInspection
@main struct GraphConsumer {
 static func check(_ value: Bool) { precondition(value) }
 static func main() throws {
  let profile = JSONGraphProfile(nodesAt: [.key("nodes")], edgesAt: [.key("edges")], nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
  let document = JSONDocument(root: try JSON.parse(#"{"nodes":[{"id":"é","n":9007199254740993},{"id":"e\u0301"}],"edges":[{"from":"é","to":"e\u0301"}]}"#))
  let built = try JSONGraphProjection.build(document: document, profile: profile)
  check(built.result.nodeCount == 2 && built.result.edgeCount == 1)
  print("PRIVATE_GRAPH exact passed")
  check(try built.result.breadthFirst(fromNode: 0).result == [0,1])
  print("PRIVATE_GRAPH bfs passed")
  check(try built.result.outgoingEdges(of: 0).result == [0])
  print("PRIVATE_GRAPH adjacency passed")
  check(try built.result.nodeValue(at: 0).result.objectValue?["n"]?.numberValue?.integer(as: UInt64.self) == 9007199254740993)
  print("PRIVATE_GRAPH values passed")
  let baseline = try JSONTraversal(document: document).visit { _,_ in .continue }
  check(built.statistics[.nodes] == baseline.statistics[.nodes] && built.statistics[.retainedBytes] > 0)
  print("PRIVATE_GRAPH admission passed")
 }
}
'''
PROBES = [
 ('positive', POSITIVE, None, False),
 ('external-builder', 'import JSONInspection\nlet x = GraphBuilder.self\n', 'cannot find', True),
 ('external-query', 'import JSONInspection\nlet x = GraphQuery.self\n', 'cannot find', True),
 ('external-stage', 'import JSONInspection\nlet x = GraphWorkStage.self\n', 'cannot find', True),
 ('external-record', 'import JSONInspection\nlet x = JSONGraphEdgeRecord.self\n', 'cannot find', True),
 ('external-context', 'import JSONNavigation\nlet x = JSONTraversalContext.self\n', 'cannot find', True),
 ('core-isolation', 'import JSON\nlet x = JSONGraphProjection.self\n', 'cannot find', True),
 ('immutable-ids', 'import JSONInspection\nfunc f(_ x: inout JSONGraphProjection) { x.nodeIDs.removeAll() }\n', "'nodeIDs' is a 'let' constant", False),
 ('forged-graph', 'import JSON\nimport JSONNavigation\nimport JSONInspection\nfunc f(_ d: JSONDocument, _ p: JSONGraphProfile, _ s: JSONTraversalSummary) { _ = JSONGraphProjection(document: d, profile: p, nodeIDs: [], edges: [], offsets: [], adjacency: [], traversal: s) }\n', 'initializer is inaccessible', False),
 ('private-reducer', 'import JSONInspection\nlet x = GraphBuilder.self\n', 'cannot find', False),
]
CHECKS = {'exact', 'bfs', 'adjacency', 'values', 'admission'}

def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--output', required=True)
    out = ROOT / parser.parse_args().output; out.mkdir(parents=True, exist_ok=True)
    receipt = dict(status='running', scope='same-package graph proof; graph public surface plus private storage/reducers; same-package invariant proof',
        source_inputs=[dict(path=p.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files()], commands=[])
    def save(): (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    def run(name, command, expected=None):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=900)
        text = result.stdout + result.stderr; diagnostics = re.findall(r': error: ([^\n]+)', result.stderr)
        crash = result.returncode < 0 or any(s in text for s in ['Stack dump:', 'Assertion failed', 'fatal error encountered during compilation', 'Found ownership error'])
        passed = not crash and (result.returncode == 0 if expected is None else result.returncode > 0 and any(expected.lower() in d.lower() for d in diagnostics))
        log = out / (name + '.log'); log.write_text(text.replace(str(ROOT), '.'))
        receipt['commands'].append(dict(name=name, command=[x.replace(str(ROOT), '.') for x in command], exit_code=result.returncode,
            status='passed' if passed else 'failed', compiler_crash=crash, expected_diagnostic=expected,
            primary_diagnostics=diagnostics, log=log.relative_to(ROOT).as_posix(), log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        save()
        if not passed: raise ValueError('Unexpected graph compiler outcome: ' + name)
        return result.stdout
    try:
        identity = re.sub(r'[^a-zA-Z0-9_]', '_', ROOT.name.lower())
        if not identity or identity[0].isdigit(): identity = '_' + identity
        for config in ['debug', 'release']:
            run(config + '-build', ['swift','build','-c',config,'--target','JSONInspection'])
            binpath = pathlib.Path(run(config + '-binpath', ['swift','build','-c',config,'--show-bin-path']).strip())
            modules = binpath / 'Modules' if (binpath / 'Modules').is_dir() else binpath
            common = ['swiftc','-swift-version','6','-warnings-as-errors','-I',str(modules),'-Onone' if config == 'debug' else '-O','-parse-as-library']
            for name, text, diagnostic, external in PROBES:
                source = out / (name + '.swift'); source.write_text(text)
                run(config + '-' + name, common + ['-package-name','graph_external' if external else identity,
                    '-module-name','GraphCompilerProbe','-c',str(source),'-o',str(out / (config + '-' + name + '.o'))], diagnostic)
            objects = []
            for module in ['JSON','JSONNavigation','JSONInspection']:
                aggregate = binpath / (module + '.o')
                selected = [aggregate] if aggregate.is_file() else sorted((binpath / (module + '.build')).glob('*.o'))
                if not selected: raise ValueError('Missing objects: ' + module)
                objects.extend(str(p) for p in selected)
            binary = out / ('private-' + config)
            run(config + '-link', common + ['-package-name',identity,str(out/'positive.swift'),*objects,'-o',str(binary)])
            output = run(config + '-run', [str(binary)])
            checks = re.findall(r'^PRIVATE_GRAPH (\S+) passed$', output, re.M)
            if len(checks) != 5 or set(checks) != CHECKS: raise ValueError('Private projection consumer identity/count drift')
        receipt['status'] = 'passed'
    except (ValueError, OSError, subprocess.TimeoutExpired) as error: receipt.update(status='failed', error=str(error))
    save(); print('GRAPH_COMPILER ' + receipt['status'] + ' commands=28 positive_codegen=2 negative_codegen=18 private_cases=5/config')
    return 0 if receipt['status'] == 'passed' else 1
if __name__ == '__main__': raise SystemExit(main())
