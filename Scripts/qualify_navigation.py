#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compile/run the unpublished N1 module as an external consumer, including negative compiler probes."""
import argparse
import gzip
import hashlib
import io
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tarfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
CHECKS = {'root-empty-key', 'typed-key-index', 'presence', 'scalar-keys', 'native-exact',
          'pointer-parity', 'metadata-collection', 'ordered-occurrences', 'unique-paths',
          'default-overlap-rejection', 'typed-missing', 'complete-empty-filter',
          'collection-limit', 'cumulative-report', 'coherent-spans',
          'replacement-invalidates-spans', 'intentional-stop', 'cumulative-quota'}


def pack_catalog(catalog, output):
    """Preserve native DocC names inside a verified portable transport envelope."""
    if catalog.is_symlink() or catalog.parent.resolve() != output.resolve():
        raise ValueError('Unexpected generated catalogue location')
    records = []
    for path in sorted(catalog.rglob('*')):
        if path.is_symlink():
            raise ValueError('Unexpected generated catalogue symlink')
        if path.is_file():
            records.append((path.relative_to(output).as_posix(), path.read_bytes()))
    if not records:
        raise ValueError('Empty experimental DocC catalogue')
    archive = output / 'JSONNavigation-DocC.tar.gz'
    manifest = output / 'JSONNavigation-DocC.MANIFEST.sha256'
    manifest.write_text(''.join(hashlib.sha256(data).hexdigest() + '  ' + name + '\n' for name, data in records))
    with archive.open('wb') as stream:
        with gzip.GzipFile(fileobj=stream, mode='wb', filename='', mtime=0) as zipped:
            with tarfile.open(fileobj=zipped, mode='w', format=tarfile.GNU_FORMAT) as tar:
                for name, data in records:
                    entry = tarfile.TarInfo(name); entry.size = len(data); entry.mode = 0o644
                    tar.addfile(entry, io.BytesIO(data))
    with tarfile.open(archive) as tar:
        members = tar.getmembers()
        if len(members) != len(records) or len({m.name for m in members}) != len(records):
            raise ValueError('DocC transport inventory differs')
        for member, (name, data) in zip(members, records):
            if not member.isfile() or member.name != name or tar.extractfile(member).read() != data:
                raise ValueError('DocC transport bytes differ')
    # Only this helper's verified generated tree is removed. Native ':' filenames
    # remain intact inside the tar; GitHub artifact transport never sees raw paths.
    shutil.rmtree(catalog)
    return {'archive': archive.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
            'bytes': archive.stat().st_size, 'files': len(records), 'manifest': manifest.relative_to(ROOT).as_posix(),
            'manifest_sha256': hashlib.sha256(manifest.read_bytes()).hexdigest(), 'all_bytes_verified': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    receipt = {'schema_version': 1, 'status': 'running', 'commands': [],
               'scope': 'External Swift module API proof; JSONNavigation is not a released SwiftPM product',
               'consumer_sha256': hashlib.sha256((ROOT / 'Tools/NavigationQualification/Consumer.swift').read_bytes()).hexdigest()}

    def run(name, command, expected=None):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=900)
        log = output / (name + '.log')
        log.write_text((result.stdout + result.stderr).replace(str(ROOT), '.'))
        passed = result.returncode == 0 if expected is None else result.returncode != 0 and expected in result.stderr
        receipt['commands'].append({'name': name, 'command': [x.replace(str(ROOT), '.') for x in command],
                                    'exit_code': result.returncode, 'status': 'passed' if passed else 'failed',
                                    'expected_diagnostic': expected, 'log': log.relative_to(ROOT).as_posix(),
                                    'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not passed:
            raise ValueError('Compiler/consumer outcome failed: ' + name)
        return result.stdout

    try:
        for config in ['debug', 'release']:
            run(config + '-build', ['swift', 'build', '-c', config, '--target', 'JSONNavigation'])
            # Build settings are interrogated, never inferred from a user's checkout name.
            binpath = pathlib.Path(run(config + '-binpath', ['swift', 'build', '-c', config, '--show-bin-path']).strip())
            modules = binpath / 'Modules' if (binpath / 'Modules').is_dir() else binpath
            objects = []
            for module in ['JSON', 'JSONNavigation']:
                aggregate = binpath / (module + '.o')
                selected = [aggregate] if aggregate.is_file() else sorted((binpath / (module + '.build')).glob('*.o'))
                if not selected:
                    raise ValueError('Missing built module objects: ' + module)
                objects.extend(str(p) for p in selected)
            common = ['swiftc', '-swift-version', '6', '-warnings-as-errors', '-I', str(modules), '-package-name', 'navigation_external_consumer']
            executable = output / ('consumer-' + config)
            run(config + '-consumer-compile', common + ['-parse-as-library', str(ROOT / 'Tools/NavigationQualification/Consumer.swift'), *objects, '-o', str(executable)])
            text = run(config + '-consumer-run', [str(executable)])
            observed = re.findall(r'^NAVIGATION_CHECK (\S+) passed$', text, re.M)
            if len(observed) != 18 or set(observed) != CHECKS or 'NAVIGATION_CONSUMER passed cases=18' not in text:
                raise ValueError('Missing/duplicate public consumer outcomes')
            resource = re.search(r'^NAVIGATION_RESOURCE work=(\d+) retained=(\d+) peak=(\d+) nodes=(\d+)$', text, re.M)
            if resource is None or int(resource[4]) != 10 or not all(int(n) > 0 for n in resource.groups()):
                raise ValueError('Missing cumulative resource observations')
            receipt.setdefault('consumer_results', {})[config] = {'cases': observed, 'work_units': int(resource[1]),
                'logical_retained_bytes': int(resource[2]), 'peak_logical_retained_bytes': int(resource[3]), 'admitted_nodes': int(resource[4])}
            guide = ROOT / 'Sources/JSONNavigation/Documentation.docc/Traversal.md'
            fences = re.findall(r'```swift\n(.*?)\n```', guide.read_text(), re.S)
            if len(fences) != 3:
                raise ValueError('Changed three-fence compiled guide inventory')
            for index, fence in enumerate(fences):
                file = output / ('guide-' + str(index) + '.swift')
                file.write_text('import JSON\nimport JSONNavigation\n@main struct Guide { static func main() throws {\n' + fence + '\n} }\n')
                binary = output / ('guide-' + config + '-' + str(index))
                run(config + '-guide-' + str(index) + '-compile', common + ['-parse-as-library', str(file), *objects, '-o', str(binary)])
                run(config + '-guide-' + str(index) + '-run', [str(binary)])
            probes = [
                ('core-import-isolation', 'import JSON\nlet x = JSONTraversal.self\n', 'cannot find'),
                ('private-meter-isolation', 'import JSON\nlet x = JSONWorkMeter.self\n', 'cannot find'),
                ('cursor-cross-task-rejection', 'import JSON\nfunc cross(_ cursor: JSONReadCursor) { let f: @Sendable () throws -> JSON = { try cursor.requiredValue() }; _ = f }\n', 'non-Sendable'),
                ('no-missing-kind', 'import JSONNavigation\nlet x = JSONTraversalKind.missing\n', 'has no member'),
            ]
            for name, source, expected in probes:
                file = output / (name + '.swift')
                file.write_text(source)
                run(config + '-' + name, common + ['-typecheck', str(file)], expected)
        if sys.platform == 'darwin':
            graphs = output / 'symbols'; graphs.mkdir(exist_ok=True)
            # Standalone extraction from an optimized serialized module omits source
            # locations. SwiftPM emits source-aware graphs during real compilation.
            run('symbol-graph', ['swift', 'package', 'dump-symbol-graph', '--minimum-access-level', 'public'])
            for path in (ROOT / '.build/out/symbolgraph').glob('JSONNavigation*.symbols.json'):
                shutil.copyfile(path, graphs / path.name)
            import documentation_catalog
            # This local audit does not promote an experimental module to the public site.
            documentation_catalog.PRODUCTS = ('JSONNavigation',)
            coverage = documentation_catalog.verify_comments(documentation_catalog.public_symbols(graphs))
            receipt['experimental_api_coverage'] = coverage
            if coverage['errors']:
                raise ValueError('Undocumented experimental API: ' + str(coverage['errors']))
            run('docc', ['xcrun', 'docc', 'convert', str(ROOT / 'Sources/JSONNavigation/Documentation.docc'),
                '--additional-symbol-graph-dir', str(graphs), '--output-dir', str(output / 'JSONNavigation.doccarchive'),
                '--fallback-bundle-identifier', 'org.swift-json.experimental.JSONNavigation', '--warnings-as-errors'])
            receipt['compiled_docc'] = pack_catalog(output / 'JSONNavigation.doccarchive', output)
        receipt['status'] = 'passed'
    except (OSError, ValueError, tarfile.TarError, subprocess.TimeoutExpired) as error:
        receipt['status'] = 'failed'; receipt['error'] = str(error)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('NAVIGATION_COMPILER ' + receipt['status'] + ' configurations=2 consumer_cases=18 negative_probes=8')
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
