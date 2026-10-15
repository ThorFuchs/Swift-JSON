#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise the real CLI subprocess, exact bytes, exits, stderr and atomic files."""
import argparse, hashlib, json, os, pathlib, signal, subprocess, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--binary', required=True); parser.add_argument('--output', required=True)
    args = parser.parse_args(); binary = (ROOT / args.binary).resolve(); rows = []
    def run(name, argv, data=b'', exit=0, expected=None, check=None):
        command = [str(binary), *argv]; process = subprocess.run(command, input=data, capture_output=True, timeout=30)
        ok = process.returncode == exit and (expected is None or process.stdout == expected)
        if check: ok = ok and check(process)
        rows.append({'id': name, 'command': ['swift-json', *[a if isinstance(a,str) else {'bytes_hex':a.hex()} for a in argv]], 'exit_code': process.returncode, 'expected_exit': exit,
                     'stdout_sha256': hashlib.sha256(process.stdout).hexdigest(), 'stdout_bytes': len(process.stdout),
                     'stderr_sha256': hashlib.sha256(process.stderr).hexdigest(), 'stderr_bytes': len(process.stderr), 'status': 'passed' if ok else 'failed'})
        if not ok: print(name, process.returncode, repr(process.stdout[:250]), repr(process.stderr[:500]), flush=True)
        return process
    with tempfile.TemporaryDirectory(prefix='swift-json-cli-') as temp:
        temp = pathlib.Path(temp)
        def file(name, data):
            path = temp / name; path.write_bytes(data); return str(path)
        def limit(**caps): return file('limits.json', json.dumps({'version':1,'cli':caps}).encode())
        run('help', ['--help'], check=lambda p: b'format' in p.stdout and not p.stderr)
        run('invalid-argv-utf8', ['format', b'\xff'], exit=2, expected=b'', check=lambda p: b'invalidArgvUTF8' in p.stderr)
        run('version', ['--version'], expected=b'swift-json 1.4.0-dev\n')
        run('version-json', ['--version','--json'], check=lambda p: json.loads(p.stdout)['revision'] == 'unknown')
        run('missing-command', [], exit=2, expected=b'')
        run('unknown-option', ['format','--unknown'], exit=2, expected=b'')
        run('usage-json-diagnostic', ['format','--diagnostics=json','--unknown'], exit=2, expected=b'', check=lambda p: json.loads(p.stderr)['kind'] == 'diagnostic' and json.loads(p.stderr)['category'] == 'usage')
        run('duplicate-option', ['format','--compact','--compact'], exit=2, expected=b'')
        run('indent-conflict', ['format','--compact','--tab'], exit=2, expected=b'')
        run('preserved-numbers', ['format','--compact'], b'[9007199254740993,0.10,-0,1e1000]', expected=b'[9007199254740993,0.10,-0,1e1000]\n')
        run('normalized-numbers', ['format','--compact','--number-style=normalized'], b'[0.10,-0]', expected=b'[1e-1,0]\n')
        run('tab-indentation', ['format','--tab'], b'{"a":[1]}', expected=b'{\n\t"a": [\n\t\t1\n\t]\n}\n')
        scalar = '{"é":1,"é":2}'.encode()
        run('scalar-distinct-keys', ['format','-cS'], scalar, expected='{"é":2,"é":1}\n'.encode())
        run('duplicate-decoded-key', ['format','--compact'], b'{"a":1,"\\u0061":2}', exit=5, expected=b'')
        run('malformed-utf8', ['format'], b'"\xff"', exit=5, expected=b'')
        run('trailing-root', ['format'], b'{} []', exit=5, expected=b'')
        run('validation-syntax', ['validate'], b'{}', check=lambda p: json.loads(p.stdout) == {'valid':True,'issues':[],'truncated':False})
        run('validation-malformed', ['validate'], b'{', exit=5, expected=b'')
        schema = file('schema.json', b'{"type":"integer","minimum":3}')
        run('schema-valid', ['validate','--schema',schema], b'4', check=lambda p: json.loads(p.stdout)['valid'] is True)
        run('schema-invalid', ['validate','--schema',schema], b'2', exit=1, check=lambda p: json.loads(p.stdout)['valid'] is False and len(json.loads(p.stdout)['issues']) > 0)
        run('schema-bounded-issues', ['validate','--schema',schema,'--max-issues','0'], b'2', exit=1, check=lambda p: json.loads(p.stdout) == {'valid':False,'issues':[],'truncated':True})
        run('pointer-null', ['pointer','/a'], b'{"a":null}', expected=b'null\n')
        run('pointer-missing', ['pointer','/a'], b'{}', exit=5, expected=b'')
        run('pointer-allow-missing', ['pointer','/a','--allow-missing'], b'{}', exit=4, expected=b'')
        run('pointer-array-absence', ['pointer','/0','--allow-missing'], b'[]', exit=4, expected=b'')
        run('pointer-malformed-index-stays-error', ['pointer','/01','--allow-missing'], b'[]', exit=5, expected=b'')
        run('pointer-wrong-type', ['pointer','/a','--allow-missing'], b'[]', exit=5, expected=b'')
        run('pointer-escaped-key', ['pointer','/a~1b~0c'], b'{"a/b~c":1}', expected=b'1\n')
        patch = file('patch.json', b'[{"op":"remove","path":""}]')
        run('patch-root-absence', ['patch','--patch',patch], b'null', expected=b'')
        patch = file('patch.json', b'[{"op":"add","path":"/b","value":9007199254740993}]')
        run('patch-exact-value', ['patch','--patch',patch], b'{"a":1}', check=lambda p: b'9007199254740993' in p.stdout)
        patch = file('patch.json', b'[{"op":"add","path":"/b","value":2},{"op":"test","path":"/a","value":0}]')
        run('patch-failure-no-candidate', ['patch','--patch',patch], b'{"a":1}', exit=5, expected=b'')
        run('html-invalid-title-is-usage', ['render','--title','\x01'], b'{}', exit=2, expected=b'')
        run('static-html', ['render'], b'{"x":"<script>"}', check=lambda p: b'<!doctype html>' in p.stdout and b'<script>' not in p.stdout and b'script-src \'none\'' in p.stdout)
        run('interactive-explicit', ['render','--presentation','interactive'], b'[1]', check=lambda p: b'<script' in p.stdout and b'<details' in p.stdout)
        run('markdown-tabs', ['render','--format','markdown'], b'{"a":1}', expected=b'```json\n{\n\t"a": 1\n}\n```\n')
        run('render-text-tabs', ['render','--format','text'], b'{"a":1}', expected=b'{\n\t"a": 1\n}\n')
        run('unqualified-format-not-advertised', ['render','--format','pdf'], b'{}', exit=2, expected=b'')
        report = run('stderr-report', ['format','--compact','--diagnostics=json','--report=json'], b'null', expected=b'null\n', check=lambda p: json.loads(p.stderr)['completed'] is True and len(json.loads(p.stderr)['resolvedLimits']['cli']) == 16 and len(json.loads(p.stderr)['resolvedLimits']['json']) == 49)
        run('terminal-report', ['format','--diagnostics=json','--report=json'], b'{', exit=5, expected=b'', check=lambda p: len(p.stderr.splitlines()) == 2 and json.loads(p.stderr.splitlines()[1])['completed'] is False)
        run('zero-diagnostic-quota', ['format','--diagnostics=json','--report=json','--limits-file',limit(diagnosticBytes=0)], b'{', exit=5, expected=b'', check=lambda p: p.stderr == b'')
        run('small-diagnostic-quota', ['format','--diagnostics=json','--report=json','--limits-file',limit(diagnosticBytes=128)], b'{', exit=5, expected=b'', check=lambda p: len(p.stderr) <= 128 and all(json.loads(line)['kind'] == 'diagnostic' for line in p.stderr.splitlines()))
        source = file('source.json', b'{"a":1}'); target = temp/'output.json'
        run('atomic-install', ['format','--compact',source,'--output',str(target)], expected=b'', check=lambda p: target.read_bytes() == b'{"a":1}\n')
        run('existing-output-rejected', ['format',source,'--output',str(target)], exit=7, expected=b'', check=lambda p: target.read_bytes() == b'{"a":1}\n')
        run('input-output-collision', ['format',source,'--output',source,'--overwrite'], exit=7, expected=b'', check=lambda p: pathlib.Path(source).read_bytes() == b'{"a":1}')
        symlink = temp/'link.json'; symlink.symlink_to(target)
        run('output-symlink-rejected', ['format',source,'--output',str(symlink),'--overwrite'], exit=7, expected=b'', check=lambda p: symlink.is_symlink())
        malformed = file('broken.json', b'{} x')
        run('atomic-malformed-keeps-destination', ['format',malformed,'--output',str(target),'--overwrite'], exit=5, expected=b'', check=lambda p: target.read_bytes() == b'{"a":1}\n' and not list(temp.glob('.swift-json-*.tmp')))
        run('output-budget', ['format','--compact','--limits-file',limit(totalOutputBytes=3)], b'null', exit=6, expected=b'')
        run('staging-budget', ['format',source,'--output',str(target),'--overwrite','--limits-file',limit(diskStagingBytes=1)], exit=6, expected=b'', check=lambda p: target.read_bytes() == b'{"a":1}\n')
        overflow = file('overflow.json', b'{"version":1,"cli":{"totalResults":100000000000000000000}}')
        run('overflow-limit-usage', ['format','--limits-file',overflow], b'null', exit=2, expected=b'')
        malformed_config = file('invalid-limits.json', b'{')
        run('malformed-limit-usage', ['format','--limits-file',malformed_config], b'null', exit=2, expected=b'')
        run('unknown-limit', ['format','--limits-file',limit(unknownQuota=1)], b'null', exit=2, expected=b'')
        process = subprocess.Popen([str(binary),'format','--diagnostics=json','--output',str(temp/'cancelled.json')], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        # The exclusive staging file proves execute() began after the signal source
        # was installed. Keep stdin open until the command exits: communicate()
        # would otherwise introduce a competing EOF and make the test nondeterministic.
        deadline = time.monotonic()+5
        while not list(temp.glob('.swift-json-*.tmp')) and process.poll() is None and time.monotonic()<deadline: time.sleep(.01)
        ready = bool(list(temp.glob('.swift-json-*.tmp')))
        process.send_signal(signal.SIGINT); process.wait(timeout=5)
        stdout, stderr = process.communicate(timeout=5)
        rows.append({'id':'sigint-blocked-stdin','exit_code':process.returncode,'expected_exit':130,'stdout_bytes':len(stdout),'stderr_bytes':len(stderr),'status':'passed' if ready and process.returncode == 130 and not stdout and not list(temp.glob('.swift-json-*.tmp')) else 'failed'})
        fifo = temp/'input.fifo'; os.mkfifo(fifo)
        process = subprocess.Popen([str(binary),'format',str(fifo),'--output',str(temp/'fifo-output.json')], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        deadline = time.monotonic()+5
        while not list(temp.glob('.swift-json-*.tmp')) and process.poll() is None and time.monotonic()<deadline: time.sleep(.01)
        ready = bool(list(temp.glob('.swift-json-*.tmp')))
        process.send_signal(signal.SIGINT); process.wait(timeout=5)
        stdout, stderr = process.communicate(timeout=5)
        rows.append({'id':'sigint-named-fifo-open','exit_code':process.returncode,'expected_exit':130,'stdout_bytes':len(stdout),'stderr_bytes':len(stderr),'status':'passed' if ready and process.returncode == 130 and not stdout and not list(temp.glob('.swift-json-*.tmp')) else 'failed'})

    report = {'schema_version':1,'scope':'C1 foundation subprocess acceptance', 'status':'passed' if all(x['status']=='passed' for x in rows) else 'failed', 'observed':len(rows),'passed':sum(x['status']=='passed' for x in rows),'failed':sum(x['status']=='failed' for x in rows), 'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(), 'cases':rows}
    output = ROOT/args.output; output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps({k:v for k,v in report.items() if k!='cases'}))
    return 0 if report['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
