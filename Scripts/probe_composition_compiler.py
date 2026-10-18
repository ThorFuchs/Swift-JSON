#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Record standalone compiler outcomes; observed compiler crashes return exit 2."""
import argparse, hashlib, json, os, pathlib, subprocess, time

ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', default='swiftc')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = pathlib.Path(args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    version = subprocess.run([args.compiler, '--version'], capture_output=True, text=True, check=True).stdout
    receipt = {'compiler': args.compiler, 'version': version, 'sdkroot': os.environ.get('SDKROOT'),
               'status': 'running', 'commands': []}
    for fixture in sorted((ROOT/'Tools/CompositionQualification/CompilerBugs/Reduced').glob('*.swift.txt')):
        name = fixture.name.removesuffix('.swift.txt')
        source = output/(name+'.swift'); source.write_bytes(fixture.read_bytes())
        command = [args.compiler, '-swift-version', '6', '-module-cache-path', str(output/'cache'),
                   '-c', str(source), '-o', str(output/(name+'.o'))]
        started = time.monotonic()
        try:
            run = subprocess.run(command, capture_output=True, text=True, timeout=120)
            code, text = run.returncode, run.stdout+run.stderr
        except subprocess.TimeoutExpired as error:
            code, text = None, str(error)
        log = output/(name+'.log'); log.write_text(text)
        crash = code is not None and (code < 0 or any(s in text for s in ['Stack dump', 'Please submit a bug report', 'SIL verification failed']))
        outcome = 'compiler_crash' if crash else 'compiled' if code == 0 else 'timeout' if code is None else 'diagnostic'
        receipt['commands'].append({'fixture': fixture.relative_to(ROOT).as_posix(),
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'command': command,
            'exit_code': code, 'outcome': outcome, 'seconds': time.monotonic()-started,
            'log': log.name, 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
        (output/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
        print(name, outcome, 'exit='+str(code), flush=True)
    receipt['counts'] = {key:sum(r['outcome']==key for r in receipt['commands'])
                         for key in ['compiled', 'diagnostic', 'compiler_crash', 'timeout']}
    receipt['status'] = 'compiler_defects_observed' if receipt['counts']['compiler_crash'] else 'recorded'
    (output/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    return 2 if receipt['counts']['compiler_crash'] else 1 if receipt['counts']['timeout'] else 0

if __name__ == '__main__': raise SystemExit(main())
