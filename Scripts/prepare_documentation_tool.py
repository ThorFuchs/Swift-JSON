#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Fetch and verify the pinned development-only Doxygen binary; never use PATH fallback."""
import argparse
import hashlib
import json
import pathlib
import platform
import shutil
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PIN = ROOT / 'Documentation/Doxygen/Toolchain.json'
DIRECTORY = ROOT / '.build/documentation-tools'
BINARY = DIRECTORY / 'doxygen-1.17.0/doxygen'


def digest(path):
    with path.open('rb') as stream:
        value = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def verified_tool():
    """Return tool provenance only after byte identity and version checks."""
    pin = json.loads(PIN.read_text())
    if not BINARY.is_file() or digest(BINARY) != pin['binary_sha256']:
        raise ValueError('Pinned Doxygen unavailable or changed; run Scripts/prepare_documentation_tool.py')
    version = subprocess.check_output([str(BINARY), '--version'], text=True, timeout=60).strip()
    if version != pin['version']:
        raise ValueError('Unexpected pinned Doxygen version: ' + version)
    return BINARY, {'version': version, 'binary_sha256': pin['binary_sha256'],
                    'archive_sha256': pin['archive_sha256'], 'release': pin['release'],
                    'pin_sha256': digest(PIN)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=pathlib.Path, help='Use an already downloaded pinned archive without network access')
    args = parser.parse_args()
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise ValueError('The pinned documentation tool requires native macOS ARM64')
    pin = json.loads(PIN.read_text())
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    if not BINARY.exists():
        archive = args.archive or DIRECTORY / 'doxygen-1.17.0-mac-arm.zip'
        if not archive.exists():
            if args.archive:
                raise ValueError('Supplied archive does not exist')
            temporary = archive.with_suffix('.download')
            try:
                subprocess.run(['curl', '--fail', '--location', '--proto', '=https',
                                '--tlsv1.2', '--output', str(temporary), pin['url']], check=True, timeout=600)
                temporary.replace(archive)
            finally:
                temporary.unlink(missing_ok=True)
        if archive.stat().st_size != pin['archive_bytes'] or digest(archive) != pin['archive_sha256']:
            raise ValueError('Doxygen archive differs from the published pin')
        BINARY.parent.mkdir(parents=True, exist_ok=True)
        temporary = BINARY.with_suffix('.extract')
        try:
            with zipfile.ZipFile(archive) as source:
                info = source.getinfo(pin['binary_member'])
                if info.file_size != pin['binary_bytes']:
                    raise ValueError('Unexpected Doxygen member size')
                with source.open(info) as incoming, temporary.open('wb') as outgoing:
                    shutil.copyfileobj(incoming, outgoing)
            if digest(temporary) != pin['binary_sha256']:
                raise ValueError('Doxygen binary differs from the verified archive')
            temporary.chmod(0o755)
            temporary.replace(BINARY)
        finally:
            temporary.unlink(missing_ok=True)
    binary, receipt = verified_tool()
    receipt.update(status='passed', binary=str(binary.relative_to(ROOT)))
    (DIRECTORY / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
