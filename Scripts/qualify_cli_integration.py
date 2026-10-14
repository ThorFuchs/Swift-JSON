#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""C5 portable command, installation, late-failure and actual pipe consumers."""
import argparse, hashlib, json, os, pathlib, shutil, signal, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--binary', required=True); parser.add_argument('--output', required=True)
    args = parser.parse_args(); binary = (ROOT / args.binary).resolve(); rows = []
    def run(name, argv, data=b'', exit=0, expected=None, check=lambda p: True, executable=binary, cwd=ROOT):
        p = subprocess.run([str(executable), *argv], input=data, capture_output=True, timeout=30, cwd=cwd)
        passed = p.returncode == exit and (expected is None or p.stdout == expected) and check(p)
        rows.append({'id':name,'command':['swift-json',*argv],'exit_code':p.returncode,'expected_exit':exit,'status':'passed' if passed else 'failed',
                     'stdout_sha256':hashlib.sha256(p.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(p.stderr).hexdigest(),'stdout_bytes':len(p.stdout)})
        if not passed: print(name,p.returncode,p.stdout[:300],p.stderr[:500],flush=True)
    with tempfile.TemporaryDirectory(prefix='swift-json-integration-') as directory:
        directory = pathlib.Path(directory)
        def file(name, text):
            p=directory/name;p.write_bytes(text if isinstance(text,bytes) else text.encode());return str(p)
        for command in ['format','validate','pointer','patch','query','stream','schema','render']:
            run('help-'+command,['help',command],check=lambda p, command=command:b'Usage: swift-json '+command.encode() in p.stdout and not p.stderr)
        run('unknown-help',['help','server'],exit=2,expected=b'')
        run('render-usage-before-input',['render','--presentation','bogus'],b'{',exit=2,expected=b'')
        run('query-usage-before-compile',['query','--input-framing','bogus','('],b'null',exit=2,expected=b'')
        run('stream-cat',['stream','cat'],b'1 {"n":9007199254740993} null',expected=b'1\n{"n":9007199254740993}\nnull\n')
        run('stream-check',['stream','check','--framing','ndjson'],b'1\r\n{}\n',check=lambda p:json.loads(p.stdout)=={'completed':True,'inputRecords':2})
        run('stream-blank-line',['stream','check','--framing','ndjson'],b'1\n\n2\n',exit=5,expected=b'')
        run('stream-document-two-roots',['stream','check','--framing','document'],b'{} []',exit=5,expected=b'')
        run('stream-empty-values',['stream','check'],b'',check=lambda p:json.loads(p.stdout)['inputRecords']==0)
        run('stream-empty-array',['stream','array'],b'[]',expected=b'')
        run('stream-array-late-tail',['stream','array','--report=json'],b'[1,2] junk',exit=5,expected=b'1\n2\n',check=lambda p:json.loads(p.stderr.splitlines()[-1])['completed'] is False)
        run('stream-array-missing-close',['stream','array'],b'[1,2',exit=5)
        run('stream-array-wrong-root',['stream','array'],b'{}',exit=5,expected=b'')
        schema=file('schema.json','{"$ref":"https://example.test/integer"}');resource=file('integer.json','{"type":"integer"}')
        run('schema-offline',['schema','check',schema,'--resource','https://example.test/integer='+resource],check=lambda p:json.loads(p.stdout)['completed'] and 'valid' not in json.loads(p.stdout))
        run('schema-missing-resource',['schema','check',schema],exit=5,expected=b'')
        run('schema-boolean',['schema','check',file('false.json','false')],check=lambda p:json.loads(p.stdout)['schemaKind']=='boolean')
        run('schema-invalid-declaration',['schema','check',file('invalid-schema.json','{"type":123}')],exit=5,expected=b'')
        for capability in ['openai-format','openai-tool','apple-check']:
            run('unavailable-'+capability,['schema','--diagnostics=json','provider',capability,'not-opened.json','--name','sample'],exit=2,expected=b'',check=lambda p:json.loads(p.stderr)['code']=='capabilityUnavailable')
        run('filter-utf8-is-compile',['query','-f',file('filter.bin',b'\xff')],b'null',exit=3,expected=b'',check=lambda p:b'invalidQueryUTF8' in p.stderr)
        run('missing-filter-file-is-io',['query','-f',str(directory/'missing')],exit=7,expected=b'')
        run('raw-binding-utf8-is-input',['query','-n','--rawfile','x',file('binding.bin',b'\xff'),'$x'],exit=5,expected=b'')
        target=directory/'protected.json';target.write_bytes(b'old')
        source=file('late-tail.jsons',b'{"x":"exact"}\n'*3000+b'{')
        run('long-prefix-atomic-failure',['query','--compact','.x',source,'--output',str(target),'--overwrite'],exit=5,expected=b'',check=lambda p:target.read_bytes()==b'old' and not list(directory.glob('.swift-json-*.tmp')))
        installed=directory/'installed with spaces';installed.mkdir();executable=installed/'swift-json';shutil.copy2(binary,executable)
        bundle=next((p for p in binary.parent.iterdir() if p.name=='Swift-JSON_JSONSchema.bundle'),None)
        if bundle is None:raise ValueError('Missing actual sibling schema bundle')
        installed_bundle=installed/bundle.name;shutil.copytree(bundle,installed_bundle)
        run('installed-resource-schema',['validate','--schema',resource],b'9007199254740993',check=lambda p:json.loads(p.stdout)['valid'],executable=executable,cwd=directory)
        file('--source.json','{"n":9007199254740993}')
        run('installed-leading-dash-file',['format','--compact','--','--source.json'],expected=b'{"n":9007199254740993}\n',executable=executable,cwd=directory)
        # Tampering the sibling proves this installed command uses that bundle,
        # even on hosts with SwiftPM's build-time fallback directory still present.
        pin=next(installed_bundle.rglob('schema.json'));pin.write_bytes(b'{}')
        run('installed-tampered-resource',['validate','--schema',resource],b'1',exit=5,expected=b'',executable=executable,cwd=directory)
        p=subprocess.Popen([str(binary),'query','-n','--diagnostics=json','range(10000)'],stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        p.stdout.close();stderr=p.stderr.read();code=p.wait(timeout=10)
        good=code==7 and json.loads(stderr)['category']=='io'
        rows.append({'id':'actual-broken-pipe','exit_code':code,'expected_exit':7,'status':'passed' if good else 'failed','stderr_sha256':hashlib.sha256(stderr).hexdigest()})
        p=subprocess.Popen([str(binary),'query','-n','--diagnostics=json','range(10000000)'],stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        prefix=os.read(p.stdout.fileno(),1024)
        p.send_signal(signal.SIGINT);out,err=p.communicate(timeout=10)
        good=bool(prefix) and p.returncode==130 and json.loads(err)['category']=='cancelled'
        rows.append({'id':'cancel-after-real-pipe-progress','exit_code':p.returncode,'expected_exit':130,'accepted_prefix_bytes':len(prefix)+len(out),'status':'passed' if good else 'failed'})
    receipt={'schema_version':1,'status':'passed' if rows and all(r['status']=='passed' for r in rows) else 'failed','observed':len(rows),'passed':sum(r['status']=='passed' for r in rows),'failed':sum(r['status']=='failed' for r in rows),'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'cases':rows,
             'scope':'Qualified portable C5 adapters and unavailable-capability rejection; provider successes remain blocked in authored C5 vector receipt'}
    output=ROOT/args.output;output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:v for k,v in receipt.items() if k!='cases'}));return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
