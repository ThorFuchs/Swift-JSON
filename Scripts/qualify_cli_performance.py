#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Release-native pull/slow-sink observations; logical bytes and RSS stay separate."""
import argparse,hashlib,json,pathlib,platform,statistics,subprocess,threading,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--output',required=True);a=p.parse_args();binary=(ROOT/a.binary).resolve();rows=[]
    for records in [2000,20000]:
        for iteration in range(3):
            argv=[str(binary),'query','--compact','--report=json','--diagnostics=json','--limits=offline','.n']
            # macOS time -l reports bytes; these are process RSS, never logical quotas.
            command=['/usr/bin/time','-l',*argv] if platform.system()=='Darwin' else argv
            start=time.monotonic();proc=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE);digest=hashlib.sha256();size=[0]
            def read():
                while True:
                    chunk=proc.stdout.read(4096)
                    if not chunk:break
                    digest.update(chunk);size[0]+=len(chunk);time.sleep(.0001)
            reader=threading.Thread(target=read);reader.start()
            try:
                for _ in range(records):proc.stdin.write(b'{"n":9007199254740993}\n')
                proc.stdin.close()
            except BrokenPipeError:pass
            stderr=proc.stderr.read();code=proc.wait(timeout=60);reader.join(timeout=10)
            lines=stderr.decode().splitlines();report=next((json.loads(line) for line in lines if line.startswith('{') and json.loads(line).get('kind')=='report'),None)
            rss=next((int(line.strip().split()[0]) for line in lines if 'maximum resident set size' in line),None)
            good=code==0 and not reader.is_alive() and report is not None and report['completed'] and report['inputRecords']==records and report['committedOutputResults']==records and size[0]==records*17
            rows.append({'command':command,'records':records,'iteration':iteration,'seconds':time.monotonic()-start,'exit':code,'status':'passed' if good else 'failed','outputBytes':size[0],'output_sha256':digest.hexdigest(),'processMaxRSSBytes':rss,'report':report,'stderr':lines})
    d={'schema_version':1,'status':'passed' if len(rows)==6 and all(r['status']=='passed' for r in rows) else 'failed','platform':platform.platform(),'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'scope':'one small generated input record at a time; bounded slow sink without retaining all outputs; finite offline profile','host_load':subprocess.run(['uptime'],capture_output=True,text=True).stdout.strip(),'limitation':'No quiet-host/baseline comparison or throughput/RSS guarantee; RSS includes runtime/allocator and differs from logical retention','rows':rows,'medians':{str(n):statistics.median(r['seconds'] for r in rows if r['records']==n) for n in [2000,20000]}}
    path=ROOT/a.output;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(d,indent=2)+'\n');print(json.dumps({k:v for k,v in d.items() if k!='rows'}));return 0 if d['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
