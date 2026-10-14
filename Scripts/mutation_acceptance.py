#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Single-site native mutants in an explicitly supplied disposable Git worktree."""
import argparse, collections, hashlib, json, os, pathlib, re, signal, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[1]

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--worktree', required=True); parser.add_argument('--output', required=True)
    parser.add_argument('--only', nargs='*'); args = parser.parse_args()
    worker = pathlib.Path(args.worktree).resolve(); output = (ROOT/args.output).resolve()
    # Never patch the control checkout or an unrelated checkout. The caller creates
    # this detached disposable worktree; no reset/clean affects another session.
    assert worker != ROOT and worker.is_relative_to(ROOT/'Artifacts'), 'Worktree must be task-owned and disposable'
    def git(*parts): return subprocess.check_output(['git','-C',str(worker),*parts], text=True).strip()
    assert git('rev-parse','--show-toplevel') == str(worker)
    assert git('rev-parse','--abbrev-ref','HEAD') == 'HEAD'
    assert not git('status','--porcelain'), 'Worker must initially be clean'
    pin = git('rev-parse','HEAD'); output.mkdir(parents=True,exist_ok=True)
    spec = ROOT/'Documentation/Qualification/Release1.2.1/MutationPilot.json'
    selected = [m for m in json.loads(spec.read_text())['mutants'] if not args.only or m['id'] in args.only]
    assert selected and len({m['id'] for m in selected}) == len(selected)
    receipt = dict(schema_version=1, status='running', source=pin, specification_sha256=sha(spec), selected=len(selected), baselines=[], mutants=[])
    def save():
        receipt['counts'] = dict(collections.Counter(m['outcome'] for m in receipt['mutants']))
        (output/'mutation.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def run(name, test_filter):
        command = ['swift','test','--disable-xctest','--filter',test_filter]
        log = output/(name+'.log'); start = time.monotonic(); timed_out=False
        with log.open('w') as stream:
            process = subprocess.Popen(command,cwd=worker,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
            try: code=process.wait(timeout=1800)
            except subprocess.TimeoutExpired:
                timed_out=True; os.killpg(process.pid,signal.SIGTERM)
                try: process.wait(timeout=10)
                except subprocess.TimeoutExpired: os.killpg(process.pid,signal.SIGKILL);process.wait()
                code=process.returncode
        text=log.read_text()
        return dict(command=command, exit_code=code, seconds=time.monotonic()-start, timed_out=timed_out,
            log=log.name, sha256=sha(log), function_counts=[int(n) for n in re.findall(r'Test run with (\d+) tests? in[^\n]*passed',text)]),text
    # Every selected filter must first demonstrate its exact nonzero baseline.
    for test_filter in sorted({m['filter'] for m in selected}):
        record,text=run('baseline-'+test_filter,test_filter)
        expected=[20] if test_filter == 'qaE2E' else [1]
        assert record['exit_code']==0 and record['function_counts']==expected, 'Baseline failed: '+test_filter
        receipt['baselines'].append(record); save()
    for mutant in selected:
        relative=pathlib.PurePosixPath(mutant['path'])
        assert not relative.is_absolute() and '..' not in relative.parts and relative.parts[0]=='Sources'
        source=worker/relative; original=source.read_bytes(); text=original.decode()
        assert text.count(mutant['before']) == 1, 'Mutant site changed: '+mutant['id']
        modified=text.replace(mutant['before'],mutant['after'],1).encode()
        source.write_bytes(modified)
        try:
            record,text=run(mutant['id'],mutant['filter'])
            if record['timed_out']: outcome='timed_out'
            elif 'error: Build failed' in text or 'error: fatalError' in text: outcome='unbuildable'
            elif record['exit_code'] != 0 and ('recorded an issue' in text or re.search(r'Test run with \d+ tests? in[^\n]*failed',text)): outcome='killed'
            elif record['exit_code']==0 and record['function_counts']==([20] if mutant['filter']=='qaE2E' else [1]): outcome='survived'
            else: outcome='execution_error'
            record.update(id=mutant['id'],path=mutant['path'],family=mutant['family'],outcome=outcome,
                original_sha256=hashlib.sha256(original).hexdigest(),mutated_sha256=hashlib.sha256(modified).hexdigest())
            receipt['mutants'].append(record)
            print(mutant['id']+' '+outcome,flush=True)
        finally: source.write_bytes(original)
        assert not git('status','--porcelain'), 'Restoration failed'
        save()
    receipt.update(status='completed', restored=True);save()

if __name__=='__main__': main()
