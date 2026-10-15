#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compile positive ownership and exact negative diagnostic probes with the live toolchain."""
import argparse, hashlib, json, pathlib, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();output=ROOT/a.output;output.mkdir(parents=True,exist_ok=True)
    sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
    modules=ROOT/'.build/debug'; rows=[]
    cases=[('borrowed-job','import JSONFilterRuntime\npackage func use(_ job: inout CLIJobContext) throws { try job.work() }\n',True,None),
           ('double-consume','import JSONFilterRuntime\npackage func twice(_ job: consuming CLIJobContext) { let first = consume job; let second = consume job; _ = consume first; _ = consume second }\n',False,'consumed more than once'),
           ('outside-private-package','import JSONFilterRuntime\nfunc make() throws { let job = try CLIJobContext(); _ = consume job }\n',False,'cannot find')]
    for name,source,positive,diagnostic in cases:
        file=output/(name+'.swift');file.write_text(source)
        command=['xcrun','swiftc','-swift-version','6','-sdk',sdk,'-target','arm64-apple-macos27.0','-module-cache-path',str(output/'ModuleCache'),'-I',str(modules),'-package-name','swift_json' if name!='outside-private-package' else 'external_consumer','-c',str(file),'-o',str(output/(name+'.o'))]
        r=subprocess.run(command,capture_output=True,text=True);log=output/(name+'.log');log.write_text((r.stdout+r.stderr).replace(str(ROOT),'.'))
        passed=r.returncode==0 if positive else r.returncode!=0 and diagnostic in r.stderr
        rows.append({'id':name,'command':[x.replace(str(ROOT),'.') for x in command],'exit_code':r.returncode,'expected_diagnostic':diagnostic,'status':'passed' if passed else 'failed','source_sha256':hashlib.sha256(source.encode()).hexdigest(),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()})
    receipt={'schema_version':1,'status':'passed' if all(r['status']=='passed' for r in rows) else 'failed','observed':3,'cases':rows};(output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt));return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
