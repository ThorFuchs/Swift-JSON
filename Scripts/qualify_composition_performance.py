#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Matched native Release ABBA comparison with mandatory quiet-host admission."""
import argparse, datetime, hashlib, json, os, pathlib, re, shutil, statistics, subprocess, tarfile, time
from preflight import collect
from archive_candidate import files

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = '30631e8fe60201518c00544c172340ec6576e0d5'
FIXTURE_SHA = 'ef70b61f99b6d2e5e3b46863822eab08dff6a45bedc7a08914e0e5b133f40203'
NAMES = {'parser-bytes-wide512': 8, 'parser-document-data-wide512': 6,
         'pointer-wide512': 30, 'schema-only': 3, 'composition-document': 4}

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def inventory(directory):
    return {p.relative_to(directory).as_posix(): digest(p) for p in directory.rglob('*') if p.is_file()}
def source_identity():
    return [{'path':p.relative_to(ROOT).as_posix(), 'sha256':digest(p)} for p in files()]

class Blocked(Exception): pass

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args(); output = pathlib.Path(args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    inputs = source_identity()
    receipt = {'status':'running', 'baseline':BASE, 'candidate':None, 'environment':collect(),
        'source_inputs':inputs, 'source_manifest_sha256':hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(),
        'configuration':'release', 'build_system':'native', 'review_trigger_percent':10,
        'minimum_pre_and_post_idle_percent':90, 'commands':[], 'host_checks':[], 'runs':[],
        'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
    def save(): (output/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    def run(name, command, env=None):
        log = output/(name+'.log'); start = time.monotonic()
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=1200)
        receipt['commands'].append({'name':name, 'command':command, 'exit_code':result.returncode,
            'seconds':time.monotonic()-start, 'log':log.name, 'log_sha256':digest(log)})
        save()
        if result.returncode: raise ValueError('Command failed: '+name)
        return log.read_text()
    def host(name):
        result = subprocess.run(['top','-l','4','-n','0','-s','1'], capture_output=True, text=True, timeout=15)
        log = output/(name+'.log'); log.write_text(result.stdout+result.stderr)
        matches = re.findall(r'([0-9.]+)% idle', result.stdout)
        intervals = [float(v) for v in matches[-3:]] if result.returncode == 0 and len(matches) == 4 else []
        idle = min(intervals) if intervals else None
        receipt['host_checks'].append({'name':name, 'command':['top','-l','4','-n','0','-s','1'], 'interval_idle_percent':intervals,
            'exit_code':result.returncode, 'idle_percent':idle, 'log':log.name, 'log_sha256':digest(log)})
        save(); print(name, 'idle='+str(idle), flush=True)
        return idle is not None and idle >= 90
    try:
        save()
        if receipt['environment']['status'] != 'passed': raise Blocked('Supported native Mac/toolchain/SDK required')
        run('cpu', ['sysctl','-n','machdep.cpu.brand_string'])
        run('memory', ['sysctl','-n','hw.memsize'])
        run('os-build', ['sw_vers','-buildVersion'])
        run('compiler', ['swift','--version'])
        receipt['candidate'] = run('candidate', ['git','rev-parse','HEAD']).strip()
        if run('baseline', ['git','rev-parse',BASE]).strip() != BASE: raise ValueError('Unexpected baseline')
        baseline = output/'baseline-source'; baseline.mkdir(exist_ok=True)
        archive = output/'baseline.tar'
        with archive.open('wb') as stream: subprocess.run(['git','archive',BASE], cwd=ROOT, stdout=stream, check=True)
        with tarfile.open(archive) as tar:
            if any(m.issym() or m.islnk() or pathlib.PurePosixPath(m.name).is_absolute() or '..' in pathlib.PurePosixPath(m.name).parts for m in tar):
                raise ValueError('Unsafe baseline archive')
            tar.extractall(baseline)
        source = ROOT/'Tools/CompositionQualification/Sources/CompositionBenchmark/main.swift'
        receipt['benchmark_source_sha256'] = digest(source)
        fixture = ROOT/'Tools/MCPReadiness/Sources/MCPReadinessKit/Resources/schema-2026-07-28.json'
        if digest(fixture) != FIXTURE_SHA: raise ValueError('Changed frozen fixture')
        receipt['fixture'] = {'path':fixture.relative_to(ROOT).as_posix(), 'bytes':fixture.stat().st_size, 'sha256':FIXTURE_SHA,
            'scope':'JSON bytes/Pointer only; schema-only always compiles the fixed small schema, not this definitions-only resource'}
        binaries = {}
        for name, dependency in [('baseline',baseline), ('candidate',ROOT)]:
            package = output/(name+'-package'); target = package/'Sources/CompositionBenchmark'; target.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source,target/'main.swift')
            (package/'Package.swift').write_text('// swift-tools-version: 6.4\nimport PackageDescription\nlet package = Package(name: "MatchedBenchmark", platforms: [.macOS("27.0")], dependencies: [.package(name: "Swift-JSON", path: '+json.dumps(str(dependency))+')], targets: [.executableTarget(name: "CompositionBenchmark", dependencies: [.product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONSchema", package: "Swift-JSON")])], swiftLanguageModes: [.v6])\n')
            command = ['swift','build','--build-system','native','--package-path',str(package),'-c','release','--jobs','2']
            run(name+'-build',command+['--product','CompositionBenchmark'])
            location = run(name+'-bin-path',command+['--show-bin-path'])
            paths = [pathlib.Path(line) for line in location.splitlines()
                     if line.startswith('/') and (pathlib.Path(line)/'CompositionBenchmark').is_file()]
            if len(paths)!=1: raise ValueError('Ambiguous/missing native binary directory')
            binaries[name] = paths[0]/'CompositionBenchmark'
        bundle = 'Swift-JSON_JSONSchema.bundle'
        resources = inventory(binaries['baseline'].parent/bundle)
        if not resources or resources != inventory(binaries['candidate'].parent/bundle): raise ValueError('Resource bundles differ')
        runtime = output/'Runtime'; runtime.mkdir(exist_ok=True)
        if (runtime/bundle).exists(): shutil.rmtree(runtime/bundle)
        shutil.copytree(binaries['baseline'].parent/bundle, runtime/bundle)
        receipt['resource_files'] = resources
        receipt['binaries'] = {name:{'sha256':digest(path), 'bytes':path.stat().st_size} for name,path in binaries.items()}
        save()
        for workload in ['wide512','frozen-schema']:
            env = os.environ.copy(); env.pop('JCOMP_BENCHMARK_INPUT',None)
            if workload == 'frozen-schema': env['JCOMP_BENCHMARK_INPUT'] = str(fixture)
            for index, name in enumerate(['baseline','candidate','candidate','baseline']):
                label = workload+'-'+str(index)+'-'+name
                # A bounded settling period is allowed before a measurement.
                # Post-run eligibility is checked immediately, with no waiting to hide noise.
                for attempt in range(12):
                    if host(label+'-before-'+str(attempt)): break
                    time.sleep(3)
                else: raise Blocked('No 90% pre-run idle window: '+label)
                shutil.copy2(binaries[name],runtime/'CompositionBenchmark')
                text = run(label,[str(runtime/'CompositionBenchmark')],env)
                rows = json.loads(text)
                if len(rows)!=5 or {row['name']:row['iterations'] for row in rows} != NAMES:
                    raise ValueError('Changed benchmark discovery/iterations')
                if any(len(row['seconds'])!=9 or any(v<=0 for v in row['seconds']) for row in rows):
                    raise ValueError('Missing/nonpositive timing samples')
                receipt['runs'].append({'workload':workload, 'name':name, 'log':label+'.log', 'samples':rows})
                save()
                if not host(label+'-after'): raise Blocked('Post-run idle below 90%: '+label)
        comparison = []
        for workload in ['wide512','frozen-schema']:
            for operation in NAMES:
                rows = {name:[] for name in binaries}; counters = {name:set() for name in binaries}
                for sample in receipt['runs']:
                    if sample['workload'] != workload: continue
                    row = next(r for r in sample['samples'] if r['name']==operation)
                    rows[sample['name']].extend(row['seconds'])
                    counters[sample['name']].add((row.get('work'),row.get('peak'),row.get('retained'),row['inputBytes']))
                if len(counters['baseline'])!=1 or len(counters['candidate'])!=1:
                    raise ValueError('Nondeterministic accounting: '+operation)
                base_count = next(iter(counters['baseline'])); candidate_count = next(iter(counters['candidate']))
                if operation == 'composition-document':
                    if candidate_count != (base_count[0]+50, max(base_count[1], base_count[2]+424), base_count[2]+424, base_count[3]):
                        raise ValueError('Unexpected composition receipt delta')
                elif counters['baseline'] != counters['candidate']:
                    raise ValueError('Changed old-API work/retention/input identity: '+operation)
                before, after = [statistics.median(rows[name]) for name in ['baseline','candidate']]
                if any(len(v)!=18 for v in rows.values()): raise ValueError('Missing ABBA samples')
                comparison.append({'workload':workload,'operation':operation,'baseline_median_seconds':before,
                    'candidate_median_seconds':after,'change_percent':100*(after/before-1),
                    'samples_per_build':18,'baseline_work_peak_input':list(base_count), 'candidate_work_peak_input':list(candidate_count),
                    'accounting_disposition':'completion +50 work/+424 logical bytes' if operation=='composition-document' else 'unchanged'})
        receipt['comparison'] = comparison
        receipt['status'] = 'review_required' if any(row['change_percent']>10 for row in comparison) else 'passed'
        receipt['disposition'] = '10% review trigger unchanged; no automatic exception, speedup or RSS claim.'
    except Blocked as error:
        receipt.update(status='blocked', error=str(error))
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        receipt.update(status='failed', error=str(error))
    receipt['source_inputs_unchanged'] = source_identity() == inputs
    if not receipt['source_inputs_unchanged']: receipt.update(status='failed',error='Source changed during measurement')
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat(); save()
    return {'passed':0,'blocked':2,'review_required':3}.get(receipt['status'],1)

if __name__ == '__main__': raise SystemExit(main())
