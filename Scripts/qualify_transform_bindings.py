#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Public-only definition consumer and ordinary full-codegen constructor refusals."""
import argparse, hashlib, json, pathlib, platform, re, shutil, subprocess, sys, tempfile, textwrap
from qualify_transform_ownership import ordinary_rejection
ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--output', required=True)
    args = parser.parse_args(); output = (ROOT/args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    guide=(ROOT/'Sources/JSONTransform/Documentation.docc/SourceDefinitions.md').read_text()
    fences=re.findall(r'```swift\n(.*?)\n```',guide,re.S)
    consumer_text=(ROOT/'Tools/TransformBindingQualification/Sources/TransformBindingConsumer/Main.swift').read_text()
    body=re.search(r'func guideExample\(\) throws \{\n(.*?)\n\}\n@main',consumer_text,re.S).group(1)
    assert len(fences)==1 and textwrap.dedent(body).strip()=='\n'.join(line for line in fences[0].splitlines() if not line.startswith('import ')).strip()
    commands = []
    def run(command, name):
        result = subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
        data=result.stdout+result.stderr; path=output/(name+'.log');path.write_text(data)
        row=dict(command=command,exit_code=result.returncode,log=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        commands.append(row); return result,row
    with tempfile.TemporaryDirectory(prefix='swift-json-binding-consumer-') as temporary:
        consumer=pathlib.Path(temporary)
        for p in (ROOT/'Tools/TransformBindingQualification').rglob('*'):
            if p.is_file() and not any(x in p.parts for x in ('.build','.swiftpm')):
                target=consumer/p.relative_to(ROOT/'Tools/TransformBindingQualification');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(p.read_bytes())
        manifest=consumer/'Package.swift';manifest.write_text(manifest.read_text().replace('path: "../.."','path: '+json.dumps(str(ROOT))))
        inputs=[dict(path=p.relative_to(consumer).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(consumer.rglob('*')) if p.is_file()]
        for config in ['debug','release']:
            result,row=run(['swift','run','--package-path',str(consumer),'-c',config,'--jobs','2','TransformBindingConsumer'],config+'-consumer')
            row['passed']=result.returncode==0 and result.stdout.splitlines()==['TRANSFORM_BINDINGS passed witnesses=6']
            if not row['passed']:break
            result,row=run(['swift','build','--package-path',str(consumer),'-c',config,'--show-bin-path'],config+'-binpath')
            row['passed']=result.returncode==0
            if not row['passed']:break
            modules=pathlib.Path(result.stdout.strip()); binary=modules/'TransformBindingConsumer'
            target=output/(config+'-TransformBindingConsumer');shutil.copyfile(binary,target)
            row['binary_sha256']=hashlib.sha256(target.read_bytes()).hexdigest()
            base=['swiftc','-swift-version','6','-I',str(modules),'-module-cache-path',str(output/'ModuleCache'),'-c']
            if sys.platform=='darwin':
                sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
                base+=['-sdk',sdk,'-target',platform.machine()+'-apple-macos27.0','-F',str(modules/'PackageFrameworks')]
            for name,source,diagnostic in [
                ('immutable','import JSONTransform\nfunc check(_ d: JSONTransformProgramDefinition) { d.source = "changed" }\n','cannot assign to property'),
                ('constructor','import JSONTransform\nlet d = JSONTransformProgramDefinition(validatedSource: ".", canonicalNames: [])\n',"inaccessible due to 'private'")]:
                path=output/(config+'-'+name+'.swift');path.write_text(source)
                result,row=run(base+[str(path),'-o',str(output/(config+'-'+name+'.o'))],config+'-'+name)
                row['expected_diagnostic']=diagnostic;row['passed']=ordinary_rejection(result.returncode,result.stderr,diagnostic)
    passed=len(commands)==8 and all(x['passed'] for x in commands)
    receipt=dict(status='passed' if passed else 'failed',commands=commands,source_inputs=inputs,compiled_guide_fences=1,
                 configurations=2,witnesses_per_configuration=6,negative_fixture_invocations=4,
                 scope='Outside-Git public-only path consumer; no private imports or released-version resolution.')
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt));return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
