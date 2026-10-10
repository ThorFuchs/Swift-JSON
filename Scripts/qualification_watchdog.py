#!/usr/bin/env python3
"""Bounded external watchdog for a public-engine qualification command; no in-process timeout race."""
import argparse,datetime,hashlib,json,pathlib,subprocess,sys,time
from preflight import collect
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--timeout',type=int,default=900);p.add_argument('--output',default='.build/handoff/watchdog.json');p.add_argument('command',nargs=argparse.REMAINDER);a=p.parse_args()
 command=a.command[1:] if a.command[:1]==['--'] else a.command
 if not command or not 1<=a.timeout<=1800:p.error('Provide a command and 1...1800 second timeout')
 destination=ROOT/a.output;destination.parent.mkdir(parents=True,exist_ok=True);log=destination.with_suffix('.log')
 receipt={'schema_version':1,'environment':collect(),'command':command,'timeout_seconds':a.timeout,'time_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'failed'}
 started=time.monotonic()
 with log.open('w') as stream:
  try:
   process=subprocess.Popen(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
   try:code=process.wait(timeout=a.timeout)
   except subprocess.TimeoutExpired:
    import os,signal
    os.killpg(process.pid,signal.SIGKILL);process.wait();receipt['failure']='external_watchdog_timeout';code=None
   receipt['exit_code']=code
   if code==0 and receipt['environment']['status']=='passed':receipt['status']='passed'
  except OSError as error:receipt['failure']=type(error).__name__
 receipt['elapsed_seconds']=time.monotonic()-started;receipt['log']=str(log.relative_to(ROOT));receipt['log_sha256']=hashlib.sha256(log.read_bytes()).hexdigest()
 destination.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2));return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':sys.exit(main())
