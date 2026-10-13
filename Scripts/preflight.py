#!/usr/bin/env python3
"""Record actual native baseline; never downgrade macOS/Swift/SDK requirements."""
import argparse, datetime, json, pathlib, platform, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
def version(text):
    match = re.search(r'(\d+)\.(\d+)(?:\.(\d+))?',text)
    if not match:
        raise ValueError('Unrecognized version: '+text[:120])
    return tuple(int(v or 0) for v in match.groups())

def check_baseline(os_name, os_version, swift_text, sdk_version):
    errors = []
    if os_name!='Darwin': errors.append('Native macOS host required')
    if version(os_version)<(27,0,0): errors.append('macOS 27+ required')
    if version(swift_text)<(6,4,0): errors.append('Swift 6.4+ required')
    if version(sdk_version)<(27,0,0): errors.append('macOS SDK 27+ required')
    return errors

def run(command):
    try:
        r = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=30)
        return {'command':command,'exit_code':r.returncode,'stdout':r.stdout.strip(),'stderr':r.stderr.strip()}
    except (OSError,subprocess.TimeoutExpired) as error:
        return {'command':command,'exit_code':None,'error':str(error)}

def collect():
    result = {'schema_version':1,'time_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'os':platform.system(),'architecture':platform.machine(),'status':'blocked',
              'commands':[],'errors':[],'swift_language_mode_required':'6','manifest_compiled':False}
    if platform.system()!='Darwin':
        result['errors']=['Native macOS 27+ host required; this host cannot qualify the package']
        return result
    commands = [['sw_vers','-productVersion'],['xcrun','swift','--version'],
                ['xcrun','--sdk','macosx','--show-sdk-version'],['xcode-select','-p'],['xcodebuild','-version']]
    result['commands']=[run(c) for c in commands]
    required = result['commands'][:4]
    if any(r['exit_code']!=0 for r in required):
        result['errors']=['Required native tool/SDK command failed; inspect recorded command results']
        return result
    try:
        swift = required[1]['stdout'].splitlines()[0]
        errors = check_baseline('Darwin',required[0]['stdout'],swift,required[2]['stdout'])
        result.update(macos=required[0]['stdout'],swift=swift,sdk=required[2]['stdout'])
        result['errors']=errors
        result['status']='passed' if not errors else 'blocked'
    except (ValueError,IndexError) as error:
        result['errors']=[str(error)]
    # A preflight pass identifies tools; actual manifest/build/test gates still require execution.
    return result

def collect_linux():
    """Separate Linux receipts; Apple native qualification is never substituted."""
    result = {'schema_version': 1, 'time_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'os': platform.system(), 'architecture': platform.machine(), 'status': 'blocked',
              'commands': [], 'errors': [], 'swift_language_mode_required': '6', 'manifest_compiled': False}
    if platform.system() != 'Linux':
        result['errors'] = ['Actual Linux execution required; a cross-build is not runtime qualification']
        return result
    result['commands'] = [run(['swift', '--version']), run(['uname', '-a']), run(['ldd', '--version'])]
    try:
        result['distribution'] = dict(line.split('=', 1) for line in pathlib.Path('/etc/os-release').read_text().splitlines() if '=' in line)
    except OSError as error:
        result['distribution'] = {}
        result['errors'].append(str(error))
    result['libc'] = platform.libc_ver()
    result['python'] = sys.version
    try:
        compiler_ok = result['commands'][0]['exit_code'] == 0 and version(result['commands'][0].get('stdout', '')) >= (6,4,0)
    except ValueError:
        compiler_ok = False
    if not compiler_ok:
        result['errors'].append('Swift 6.4+ required')
    if result['distribution'].get('ID', '').strip('"') != 'ubuntu' or result['distribution'].get('VERSION_ID', '').strip('"') != '24.04':
        result['errors'].append('Initial native Linux qualification requires Ubuntu 24.04')
    if result['architecture'] not in ('aarch64', 'x86_64') or result['libc'][0] != 'glibc':
        result['errors'].append('Initial native Linux qualification requires 64-bit ARM64/x86_64 glibc')
    result['swift'] = result['commands'][0].get('stdout', '')
    result['status'] = 'blocked' if result['errors'] else 'passed'
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',default=str(ROOT/'.build/handoff/preflight.json'))
    args=parser.parse_args()
    result=collect()
    output=pathlib.Path(args.output)
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return 0 if result['status']=='passed' else 2
if __name__=='__main__':sys.exit(main())
