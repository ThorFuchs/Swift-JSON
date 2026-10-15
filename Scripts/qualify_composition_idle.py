#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Qualification-only pinned Release comparison for PR35; never changes other workloads.

Builds the identical public-API harness against two detached source pins before
quiet admission. No library, PR head, protection, release or dependency pin changes.
"""
import argparse,datetime,hashlib,json,math,os,pathlib,platform,re,statistics,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
# SwiftPM identities use directory basenames. Consumer and dependency must have
# distinct identities, while the two revisions retain equal-length paths.
TREES={kind:ROOT/'.build/composition-idle-inputs'/('source-'+name) for kind,name in [('baseline','before'),('candidate','after_')]}
PACKAGES={kind:ROOT/'.build/composition-idle-probes'/('probe-'+name) for kind,name in [('baseline','before'),('candidate','after_')]}
PINS={'baseline':'037e735dc6224789e4d04d2c18d15b8d27440198','candidate':'73efb65189f3f7e08e878a3b0fb6030f34524e4b'}
ORDER=[['baseline','candidate'],['candidate','baseline'],['baseline','candidate']]
EXPECTED={'parser-bytes':40,'parser-document-data':30,'pointer':200,'schema-only':3}
sha=lambda b:hashlib.sha256(b).hexdigest()
utc=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);ap.add_argument('--wait-seconds',type=int,default=120);args=ap.parse_args()
    out=ROOT/pathlib.Path(args.output);out.mkdir(parents=True,exist_ok=False)
    receipt=dict(schema_version=1,status='running',started_utc=utc(),baseline=PINS['baseline'],candidate=PINS['candidate'],qualified_measurement=False,benchmark_processes_executed=0,policy=dict(review_trigger_percent=10,minimum_idle_percent=90,consecutive_interval_samples=3,sample_interval_seconds=1,first_cumulative_top_sample_excluded=True,each_process_requires_pre_and_post_quiet=True,order=ORDER,warmup_batches_per_process=3,samples_per_workload_per_process=9,processes_per_revision=3,competing_heavy_processes=0,no_measurement_paging=True),commands=[],host_windows={},runs=[])
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def command(argv,name,cwd=ROOT,timeout=30):
        r=subprocess.run([str(v) for v in argv],cwd=cwd,capture_output=True,text=True,timeout=timeout)
        (out/name).write_text(r.stdout+r.stderr)
        receipt['commands'].append(dict(command=[str(v) for v in argv],exit_code=r.returncode,log=name,sha256=sha((out/name).read_bytes())))
        if r.returncode: raise RuntimeError('preflight/command failed: '+name)
        return r.stdout
    def parse_top(text):
        return dict(idle_percent=[float(v) for v in re.findall(r'([0-9.]+)% idle',text)],swap_totals=[[int(a),int(b)] for a,b in re.findall(r'(\d+)\(\d+\) swapins, (\d+)\(\d+\) swapouts',text)])
    def heavy(phase):
        text=command(['ps','-Ao','pid,pcpu,state,comm','-r'],phase+'-processes.log')
        rows=[]
        for line in text.splitlines()[1:]:
            fields=line.strip().split(None,3)
            if len(fields)!=4 or int(fields[0])==os.getpid() or 'T' in fields[2]:continue
            if float(fields[1])>=30 and re.search(r'swift|clang|latex|tex|pdf|python|mediaanalysis|Renderer|WindowServer',fields[3],re.I):
                rows.append(dict(pid=int(fields[0]),cpu_percent=float(fields[1]),state=fields[2],comm=fields[3]))
        return rows
    def quiet(phase):
        argv=['top','-l','0','-s','1','-n','0'];start=time.monotonic();lines=[];admitted=False;competitors=[];last_note=0
        proc=subprocess.Popen(argv,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
        try:
            for line in proc.stdout:
                lines.append(line)
                if not line.startswith('Disks:'):continue
                parsed=parse_top(''.join(lines));intervals=parsed['idle_percent'][1:]
                if len(intervals)>=3 and min(intervals[-3:])>=90:
                    competitors=heavy(phase)
                    if not competitors:admitted=True;break
                if time.monotonic()-start>=last_note+20:
                    print(phase+' waiting; recent idle='+str(intervals[-3:]),flush=True);last_note=time.monotonic()-start
                if time.monotonic()-start>=args.wait_seconds:break
        finally:
            if proc.poll() is None:proc.terminate()
            code=proc.wait(timeout=5)
        log=out/(phase+'-host.log');log.write_text(''.join(lines));parsed=parse_top(''.join(lines))
        receipt['host_windows'][phase]=dict(command=argv,monitor_exit_code=code,own_monitor_stopped=True,admitted=admitted,elapsed_seconds=time.monotonic()-start,other_heavy=competitors,log=log.name,log_sha256=sha(log.read_bytes()),**parsed)
        save()
        if not admitted:raise RuntimeError('quiet-host guard not met: '+phase)
        print(phase+' admitted; idle='+str(parsed['idle_percent'][-3:]),flush=True)
        return parsed
    exit_code=2
    try:
        assert platform.system()=='Darwin'
        env={}
        for label,argv in [('os',['sw_vers','-productVersion']),('swift',['xcrun','swift','--version']),('sdk',['xcrun','--sdk','macosx','--show-sdk-version']),('sdk_path',['xcrun','--sdk','macosx','--show-sdk-path']),('developer',['xcode-select','-p']),('hardware',['sysctl','-n','hw.model','hw.memsize','hw.ncpu']),('thermal',['pmset','-g','therm'])]:env[label]=command(argv,label+'.log').strip()
        assert tuple(map(int,env['os'].split('.')[:2]))>=(27,0) and tuple(map(int,env['sdk'].split('.')[:2]))>=(27,0)
        ver=re.search(r'Apple Swift version (\d+)\.(\d+)',env['swift']);assert ver and tuple(map(int,ver.groups()))>=(6,4)
        receipt['environment']=dict(**env,architecture=platform.machine(),language_mode='6')
        receipt['proof_commit']=command(['git','rev-parse','HEAD'],'proof-head.log').strip()
        receipt['github_run_id']=os.environ.get('GITHUB_RUN_ID')
        receipt['published_release']=False
        # Fetch-free detached inputs: checkout has full history including both pins.
        harness=command(['git','show',PINS['candidate']+':Tools/CompositionQualification/Sources/CompositionRegression/main.swift'],'harness-source.log').encode()
        assert sha(harness)=='9ba2b71bea3889deb24b8cf40301406c24ef658bd619ad2b4a41d377fa2d9b3a'
        for kind in ['baseline','candidate']:
            tree=TREES[kind];tree.parent.mkdir(parents=True,exist_ok=True)
            command(['git','worktree','add','--detach',str(tree),PINS[kind]],kind+'-checkout.log',timeout=60)
            package=PACKAGES[kind];target=package/'Sources/CompositionRegression';target.mkdir(parents=True)
            (target/'main.swift').write_bytes(harness)
            manifest='// swift-tools-version: 6.4\n// SPDX-License-Identifier: Apache-2.0\nimport PackageDescription\nlet package = Package(name: \"CompositionIdleProbe\", platforms: [.macOS(\"27.0\")], dependencies: [.package(name: \"Swift-JSON\", path: '+json.dumps(str(tree))+')], targets: [.executableTarget(name: \"CompositionRegression\", dependencies: [.product(name: \"JSON\", package: \"Swift-JSON\"), .product(name: \"JSONSchema\", package: \"Swift-JSON\")])], swiftLanguageModes: [.v6])\n'
            (package/'Package.swift').write_text(manifest)
            command(['xcrun','swift','build','-c','release','--sdk',env['sdk_path'],'--package-path',str(package),'--verbose'],kind+'-build.log',timeout=900)
            (out/(kind+'-Package.swift')).write_text(manifest)
        binaries={};identities={};source=None
        for kind in ['baseline','candidate']:
            tree=TREES[kind];pkg=PACKAGES[kind];binary=pkg/'.build/release/CompositionRegression'
            pin=command(['git','rev-parse','HEAD'],kind+'-head.log',tree).strip();assert pin==PINS[kind]
            assert not command(['git','status','--porcelain'],kind+'-status.log',tree).strip()
            harness=(pkg/'Sources/CompositionRegression/main.swift').read_bytes()
            if source is None:source=harness
            assert harness==source and sha(harness)=='9ba2b71bea3889deb24b8cf40301406c24ef658bd619ad2b4a41d377fa2d9b3a'
            (out/(kind+'-main.swift')).write_bytes(harness)
            load=command(['otool','-l',str(binary)],kind+'-load-commands.log')
            build=load.split('LC_BUILD_VERSION',1)[1].split('Load command',1)[0]
            linked_sdk=re.search(r'sdk\s+(\d+)\.(\d+)',build)
            assert re.search(r'minos\s+27\.0\b',build) and linked_sdk and tuple(map(int,linked_sdk.groups()))>=(27,0), 'unsupported Mach-O deployment/SDK: '+kind
            binaries[kind]=binary;identities[kind]=dict(source_commit=pin,harness_sha256=sha(harness),binary=str(binary),binary_sha256=sha(binary.read_bytes()),binary_bytes=binary.stat().st_size,release_build_version=build.strip(),linked_sdk=linked_sdk.group(1)+'.'+linked_sdk.group(2))
        assert identities['baseline']['linked_sdk']==identities['candidate']['linked_sdk'], 'mismatched linked SDKs'
        command(['git','diff','--quiet','084eb5af918a63e0eec113db6d347e0d06bea86d',PINS['candidate'],'--','Sources','Package.swift','Tests'],'runtime-continuity.log',TREES['candidate'])
        receipt['identities']=identities;save()
        before=None;after=None
        for trial,order in enumerate(ORDER):
            for kind in order:
                label=str(trial)+'-'+kind
                window=quiet(label+'-pre')
                if before is None:before=window['swap_totals'][-1]
                binary=binaries[kind];assert sha(binary.read_bytes())==identities[kind]['binary_sha256']
                started=time.monotonic()
                during_file=out/(label+'-during-host.log')
                with during_file.open('w') as stream:
                    monitor=subprocess.Popen(['top','-l','0','-s','1','-n','0'],stdout=stream,stderr=subprocess.STDOUT)
                    try:
                        receipt['benchmark_processes_executed']+=1;save()
                        text=command([str(binary)],label+'.stdout.json',TREES['candidate'],timeout=180)
                        during_heavy=heavy(label+'-immediate-after')
                        if during_heavy:raise RuntimeError('competing compiler/renderer at process completion: '+label)
                    finally:
                        if monitor.poll() is None:monitor.terminate()
                        monitor.wait(timeout=5)
                receipt.setdefault('during_windows',{})[label]=dict(log=during_file.name,sha256=sha(during_file.read_bytes()),other_heavy_at_completion=during_heavy,**parse_top(during_file.read_text()))
                samples=json.loads(text);assert {s['name']:s['iterations'] for s in samples}==EXPECTED
                for s in samples:assert len(s['seconds'])==9 and all(math.isfinite(v) and v>0 for v in s['seconds'])
                assert sha(binary.read_bytes())==identities[kind]['binary_sha256']
                receipt['runs'].append(dict(trial=trial,kind=kind,exit_code=0,wall_seconds=time.monotonic()-started,samples=samples))
                after=quiet(label+'-post')['swap_totals'][-1];save()
        receipt['swap_delta']=dict(swapins=after[0]-before[0],swapouts=after[1]-before[1])
        if receipt['swap_delta']!={'swapins':0,'swapouts':0}:raise RuntimeError('paging observed during matched comparison')
        summary=[]
        for name in EXPECTED:
            groups={}
            for kind in binaries:
                samples=[s for run in receipt['runs'] if run['kind']==kind for s in run['samples'] if s['name']==name]
                values=[v for s in samples for v in s['seconds']];assert len(values)==27
                measured=name in ['parser-bytes','schema-only']
                assert all(s['work']==samples[0]['work'] and s['peak']==samples[0]['peak'] for s in samples)
                groups[kind]=dict(median_seconds=statistics.median(values),relative_stddev=statistics.pstdev(values)/statistics.mean(values),sample_count=len(values),process_medians=[statistics.median(s['seconds']) for s in samples],native_counters_measured=measured,work=samples[0]['work'] if measured else None,logical_peak=samples[0]['peak'] if measured else None)
            change=100*(groups['candidate']['median_seconds']/groups['baseline']['median_seconds']-1)
            peak_change=100*(groups['candidate']['logical_peak']/groups['baseline']['logical_peak']-1) if groups['baseline']['native_counters_measured'] else None
            summary.append(dict(name=name,**groups,median_change_percent=change,logical_peak_change_percent=peak_change,review_triggered=abs(change)>=10 or (peak_change is not None and abs(peak_change)>=10)))
        receipt['summary']=summary;receipt['qualified_measurement']=True
        receipt['status']='qualified_measurement_review_required' if any(s['review_triggered'] for s in summary) else 'qualified_below_review_trigger'
        exit_code=3 if any(s['review_triggered'] for s in summary) else 0
        print(json.dumps(summary,indent=2),flush=True)
    except Exception as error:
        receipt['error']=repr(error);receipt['status']='blocked' if not receipt['qualified_measurement'] else 'failed'
        print(receipt['status']+': '+str(error),flush=True)
    finally:
        receipt['finished_utc']=utc();receipt['exit_code']=exit_code;save()
        entries=[]
        for path in sorted(out.rglob('*')):
            if path.is_file() and path.name!='MANIFEST.sha256':entries.append(sha(path.read_bytes())+'  '+path.relative_to(out).as_posix())
        (out/'MANIFEST.sha256').write_text('\n'.join(entries)+'\n')
    return exit_code
if __name__=='__main__':raise SystemExit(main())
