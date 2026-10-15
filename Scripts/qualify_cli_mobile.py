#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compile only the five-library public consumer for the supported mobile SDKs."""
import argparse, hashlib, json, pathlib, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();output=ROOT/a.output;output.mkdir(parents=True,exist_ok=True);rows=[]
    for sdk,triple in [('iphoneos','arm64-apple-ios27.0'),('iphonesimulator','arm64-apple-ios27.0-simulator')]:
        version=subprocess.run(['xcrun','--sdk',sdk,'--show-sdk-version'],capture_output=True,text=True)
        path=subprocess.run(['xcrun','--sdk',sdk,'--show-sdk-path'],capture_output=True,text=True)
        if version.returncode or path.returncode or int(version.stdout.strip().split('.')[0])<27:raise RuntimeError('Supported SDK unavailable: '+sdk)
        cmd=['swift','build','-c','release','--package-path','Tools/CLIQualification','--target','CLIMobileConsumer','--scratch-path','.build/cli-mobile-'+sdk,'--triple',triple,'--sdk',path.stdout.strip()]
        run=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=900);log=output/(sdk+'.log');log.write_text((run.stdout+run.stderr).replace(str(ROOT),'.'))
        contamination=any(('] '+name) in log.read_text() for name in ['JSONCLIEngine','JSONFilterRuntime','JSONCLI '])
        rows.append({'command':cmd,'sdk_version':version.stdout.strip(),'exit_code':run.returncode,'status':'passed' if run.returncode==0 and not contamination else 'failed','cli_target_contamination':contamination,'log':log.name,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()})
        print(sdk,rows[-1]['status'],flush=True)
    d={'schema_version':1,'status':'passed' if len(rows)==2 and all(r['status']=='passed' for r in rows) else 'failed','scope':'five selected library SDK builds; no CLI or device/runtime claim','commands':rows}
    (output/'receipt.json').write_text(json.dumps(d,indent=2)+'\n');return 0 if d['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
