#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run the full native lane from exact archive bytes outside every Git checkout."""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from archive_candidate import archive, files, verify

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    receipt = dict(status='running', commands=[], scope='Full native lane from a Git-free extraction')
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

    def save():
        (output / 'reproduction.json').write_text(json.dumps(receipt, indent=2) + '\n')

    try:
        candidate = output / 'candidate.tar.gz'
        repeat = output / 'candidate.rebuild.tar.gz'
        archive(candidate, files())
        archive(repeat, files())
        receipt.update(archive_sha256=sha(candidate), archive_bytes=candidate.stat().st_size,
                       archive_entries=verify(candidate), byte_equal_rebuild=sha(candidate) == sha(repeat))
        if not receipt['byte_equal_rebuild']:
            raise ValueError('Source archive changed between constructions')
        repeat.unlink()
        with tempfile.TemporaryDirectory(prefix='swift-json-native-reproduction-') as temporary:
            temporary = pathlib.Path(temporary)
            with tarfile.open(candidate) as tar:
                for member in tar.getmembers():
                    # verify() already rejects links, traversal and duplicates.
                    path = temporary / member.name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(tar.extractfile(member).read())
                    path.chmod(member.mode)
            extracted = temporary / 'Swift-JSON'
            git = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=extracted,
                                 capture_output=True, text=True)
            receipt['outside_git_verified'] = git.returncode != 0
            if not receipt['outside_git_verified']:
                raise ValueError('Extraction inherited a Git checkout')
            command = [sys.executable, '-B', 'Scripts/ci.py', '--lane', 'native']
            log = output / 'native.log'
            start = time.monotonic()
            with log.open('w') as stream:
                result = subprocess.run(command, cwd=extracted, stdout=stream,
                                        stderr=subprocess.STDOUT, timeout=3300)
            receipt['commands'].append(dict(command=command, exit_code=result.returncode,
                seconds=time.monotonic() - start, log=log.name, log_sha256=sha(log)))
            child = extracted / '.build/ci/native'
            if child.is_dir():
                shutil.copytree(child, output / 'native', dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('ModuleCache', '*.dylib', '*.o', '*.swiftmodule'))
            if result.returncode:
                raise ValueError('Git-free native lane failed')
            native = json.loads((output / 'native/receipt.json').read_text())
            if native['status'] != 'passed' or native['git_commit'] is not None or not native['source_inputs_unchanged']:
                raise ValueError('Git-free native provenance or execution failed')
            for name in ['ownership.json', 'reader.json']:
                probe = json.loads((output / 'native' / name).read_text())
                if probe['status'] != 'passed' or probe['git_head'] is not None:
                    raise ValueError('Probe borrowed Git identity: ' + name)
            rebuilt = output / 'candidate.extracted-rebuild.tar.gz'
            archive(rebuilt, files(extracted), root=extracted)
            receipt['byte_equal_extracted_rebuild'] = sha(rebuilt) == receipt['archive_sha256']
            if not receipt['byte_equal_extracted_rebuild']:
                raise ValueError('Native execution changed extracted source')
            rebuilt.unlink()
            receipt['native_commands'] = len(native['commands'])
            receipt['native_receipt_sha256'] = sha(output / 'native/receipt.json')
        receipt['status'] = 'passed'
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        receipt.update(status='failed', error=str(error))
    save()
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
