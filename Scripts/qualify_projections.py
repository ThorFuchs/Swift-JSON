#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Full-codegen proof of projection invariants and package-only storage/reducers."""
import argparse, hashlib, json, pathlib, re, subprocess
from archive_candidate import files
ROOT = pathlib.Path(__file__).resolve().parents[1]
POSITIVE = r'''import Foundation
import JSON
import JSONNavigation
import JSONInspection
@main struct PrivateProjectionConsumer {
 static func check(_ value: Bool) { precondition(value) }
 static func main() throws {
  let document = try JSONParser().parseDocument(Data(#"{"x":[{"0":9007199254740993},null]}"#.utf8))
  let snapshot = try JSONStructuralSnapshotBuilder(document: document).build().result
  let view = try JSONTreeProjection.build(snapshot: snapshot, rootOrdinal: 1).result
  check(try view.children(of: 1).result == [2,4])
  print("PRIVATE_PROJECTION tree passed")
  check(try view.value(for: 3).result.numberValue?.integer(as: UInt64.self) == 9007199254740993)
  print("PRIVATE_PROJECTION exact passed")
  let source = try JSONParser().parseDocument(Data(#"[{"é":null},{"e\u0301":9007199254740993},{}]"#.utf8))
  let built = try JSONSparseTableProjection.build(document: source), table = built.result
  check(table.columns == [JSONKey("é"), JSONKey("e\u{301}")])
  check(table.rowOffsets == [0,1,2,2])
  check(try table.cell(row: 0, column: 0).result == .null)
  check(try table.cell(row: 2, column: 0).result == .absent)
  print("PRIVATE_PROJECTION sparse-presence passed")
  let lookup = try table.cell(row: 1, column: 1)
  check(built.statistics[.nodes] == 6 && lookup.statistics[.nodes] == 6)
  check(built.statistics[.retainedBytes] > 0 && lookup.statistics[.workUnits] > 0)
  print("PRIVATE_PROJECTION admission passed")
  let late = try JSONParser().parseDocument(Data("[{},{},false]".utf8))
  let evidence = try JSONShapeInspector(document: late).inspectArray(sampling: .prefix(maximumRows: 2)).result
  check(evidence.observedAllObjects == true)
  do { _ = try JSONSparseTableProjection.build(document: late); preconditionFailure("Late nonobject must fail") }
  catch JSONProjectionFailure.nonObjectRow(let path, let kind) { check(path == [.index(2)] && kind == .boolean) }
  print("PRIVATE_PROJECTION late-refusal passed")
 }
}
'''
PROBES = [
    ('positive', POSITIVE, None, False),
    ('external-member', 'import JSONInspection\nlet x = JSONSparseTableMember.self\n', 'cannot find', True),
    ('external-accounting', 'import JSONInspection\nlet x = ProjectionAccounting.self\n', 'cannot find', True),
    ('external-reducer', 'import JSONInspection\nlet x = SparseTableReducer.self\n', 'cannot find', True),
    ('core-isolation', 'import JSON\nlet x = JSONTreeProjection.self\n', 'cannot find', True),
    ('forged-tree', 'import JSONInspection\nfunc f(_ s: JSONStructuralSnapshot) { _ = JSONTreeProjection(snapshot: s, rootOrdinal: 0, endExclusive: 1) }\n', 'initializer is inaccessible', False),
    ('immutable-source', 'import JSON\nimport JSONInspection\nfunc f(_ x: inout JSONSparseTableProjection) { x.document = JSONDocument(root: .null) }\n', "'document' is a 'let' constant", False),
    ('immutable-columns', 'import JSONInspection\nfunc f(_ x: inout JSONSparseTableProjection) { x.columns.removeAll() }\n', "'columns' is a 'let' constant", False),
]
CHECKS = {'tree', 'exact', 'sparse-presence', 'admission', 'late-refusal'}

def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--output', required=True)
    out = ROOT / parser.parse_args().output; out.mkdir(parents=True, exist_ok=True)
    receipt = dict(status='running', scope='same-package sparse-storage proof + external invariant rejection; public views stay in JSONInspection',
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
        if not passed: raise ValueError('Unexpected projection compiler outcome: ' + name)
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
                run(config + '-' + name, common + ['-package-name','projection_external' if external else identity,
                    '-module-name','ProjectionCompilerProbe','-c',str(source),'-o',str(out / (config + '-' + name + '.o'))], diagnostic)
            objects = []
            for module in ['JSON','JSONNavigation','JSONInspection']:
                aggregate = binpath / (module + '.o')
                selected = [aggregate] if aggregate.is_file() else sorted((binpath / (module + '.build')).glob('*.o'))
                if not selected: raise ValueError('Missing objects: ' + module)
                objects.extend(str(p) for p in selected)
            binary = out / ('private-' + config)
            run(config + '-link', common + ['-package-name',identity,str(out/'positive.swift'),*objects,'-o',str(binary)])
            output = run(config + '-run', [str(binary)])
            checks = re.findall(r'^PRIVATE_PROJECTION (\S+) passed$', output, re.M)
            if len(checks) != 5 or set(checks) != CHECKS: raise ValueError('Private projection consumer identity/count drift')
        receipt['status'] = 'passed'
    except (ValueError, OSError, subprocess.TimeoutExpired) as error: receipt.update(status='failed', error=str(error))
    save(); print('PROJECTIONS_COMPILER ' + receipt['status'] + ' commands=24 positive_codegen=2 negative_codegen=14 private_cases=5/config')
    return 0 if receipt['status'] == 'passed' else 1
if __name__ == '__main__': raise SystemExit(main())
