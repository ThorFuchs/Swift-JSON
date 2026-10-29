#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Public-only selection consumer and ownership/completion compiler boundaries."""
import argparse, hashlib, json, pathlib, platform, re, shutil, subprocess, sys, tempfile, textwrap
from qualify_transform_ownership import ordinary_rejection
ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--output', required=True)
    args = parser.parse_args(); output = (ROOT/args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    guide=(ROOT/'Sources/JSONTransform/Documentation.docc/IndexedSelection.md').read_text()
    fences=re.findall(r'```swift\n(.*?)\n```',guide,re.S)
    consumer_text=(ROOT/'Tools/TransformSelectionQualification/Sources/TransformSelectionConsumer/Main.swift').read_text()
    body=re.search(r'func selectionGuideExample\(\) throws \{\n(.*?)\n\}\nprivate',consumer_text,re.S).group(1)
    assert len(fences)==1 and textwrap.dedent(body).strip()=='\n'.join(line for line in fences[0].splitlines() if not line.startswith('import ')).strip()
    commands = []
    def run(command, name):
        result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
        data=result.stdout+result.stderr; path=output/(name+'.log');path.write_text(data)
        row=dict(command=command,exit_code=result.returncode,log=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        commands.append(row); return result,row
    with tempfile.TemporaryDirectory(prefix='swift-json-selection-consumer-') as temporary:
        consumer=pathlib.Path(temporary)
        for p in (ROOT/'Tools/TransformSelectionQualification').rglob('*'):
            if p.is_file() and not any(x in p.parts for x in ('.build','.swiftpm')):
                target=consumer/p.relative_to(ROOT/'Tools/TransformSelectionQualification');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(p.read_bytes())
        manifest=consumer/'Package.swift';manifest.write_text(manifest.read_text().replace('path: "../.."','path: '+json.dumps(str(ROOT))))
        inputs=[dict(path=p.relative_to(consumer).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(consumer.rglob('*')) if p.is_file()]
        for config in ['debug','release']:
            result,row=run(['swift','run','--package-path',str(consumer),'-c',config,'--jobs','2','TransformSelectionConsumer'],config+'-consumer')
            row['passed']=result.returncode==0 and result.stdout.splitlines()==['TRANSFORM_SELECTION passed witnesses=10']
            if not row['passed']:break
            result,row=run(['swift','build','--package-path',str(consumer),'-c',config,'--show-bin-path'],config+'-binpath')
            row['passed']=result.returncode==0
            if not row['passed']:break
            modules=pathlib.Path(result.stdout.strip()); binary=modules/'TransformSelectionConsumer'
            target=output/(config+'-TransformSelectionConsumer');shutil.copyfile(binary,target)
            row['binary_sha256']=hashlib.sha256(target.read_bytes()).hexdigest()
            base=['swiftc','-swift-version','6','-I',str(modules),'-module-cache-path',str(output/'ModuleCache'),'-c']
            if sys.platform=='darwin':
                sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
                base+=['-sdk',sdk,'-target',platform.machine()+'-apple-macos27.0','-F',str(modules/'PackageFrameworks')]
            fixtures = [
                ('position','import JSONTransform\nlet x = JSONTransformSelectionPosition()\n',False,'inaccessible'),
                ('completion','import JSONTransform\nlet x = JSONTransformSelectionCompletion()\n',False,'inaccessible'),
                ('report','import JSONTransform\nfunc forge(_ c: JSONTransformSelectionCompletion) { _ = JSONTransformSelectionReport(result: (), completion: c) }\n',False,'inaccessible'),
                ('scope','import JSONTransform\nlet x = JSONTransformSelectionScope()\n',False,'inaccessible'),
                ('send-scope','import JSONTransform\nfunc send<T: Sendable>(_: T) {}\nfunc check(_ s: JSONTransformSelectionScope) { send(s) }\n',False,'does not conform to'),
                ('send-position','import JSONTransform\nfunc send<T: Sendable>(_: T) {}\nfunc check(_ p: JSONTransformSelectionPosition) { send(p) }\n',False,'does not conform to'),
                ('send-completion','import JSONTransform\nfunc send<T: Sendable>(_: T) {}\nfunc check(_ c: JSONTransformSelectionCompletion) { send(c) }\n',False,'does not conform to'),
                ('guarded-alias','import JSONTransform\nfunc check(_ p: JSONTransformProgram) throws -> (() throws -> JSONTransformSelectionPosition?)? { var escaped: (() throws -> JSONTransformSelectionPosition?)?; _ = try p.withSelection(population: []) { s in escaped = { try s.next() }; let eof = try s.next(); precondition(eof == nil) }; return escaped }\n',True,None),
            ]
            for name,source,positive,diagnostic in fixtures:
                path=output/(config+'-'+name+'.swift');path.write_text(source)
                result,row=run(base+[str(path),'-o',str(output/(config+'-'+name+'.o'))],config+'-'+name)
                row['positive']=positive;row['expected_diagnostic']=diagnostic;row['passed']=result.returncode==0 if positive else ordinary_rejection(result.returncode,result.stderr,diagnostic)
    passed=len(commands)==20 and all(x['passed'] for x in commands)
    receipt=dict(status='passed' if passed else 'failed',commands=commands,source_inputs=inputs,compiled_guide_fences=1,
                 configurations=2,witnesses_per_configuration=10,negative_fixture_invocations=14,
                 scope='Outside-Git public-only path consumer; no private imports or released-version resolution.')
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt));return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
