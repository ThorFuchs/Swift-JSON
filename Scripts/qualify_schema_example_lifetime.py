#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""ASan public-consumer process lifetime: no suppressions or ignored leak exits."""
import argparse, hashlib, json, os, pathlib, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = r'''import JSON
import JSONSchemaExamples

@inline(never) func checkCorpus() throws {
    let corpus = JSONSchemaExampleCorpus.synthetic
    let text = try JSONWriter().writeString(.array(corpus.values))
    precondition(text == #"[null,false,0,"example",[],{}]"#)
    var changed = corpus.values
    changed.append(.string("local"))
    precondition(changed.count == 7 && corpus.values.count == 6)
    precondition(JSONSchemaExampleOptions().corpus.values.count == 6)
}

@main struct CorpusLifetime {
    static func main() throws {
        for _ in 0..<128 { try checkCorpus() }
        print("SCHEMA_EXAMPLES_CORPUS passed mode=owned scopes=128 values=6 exact=1")
    }
}
'''
MARKER = 'SCHEMA_EXAMPLES_CORPUS passed mode=owned scopes=128 values=6 exact=1'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    out = ROOT / args.output; out.mkdir(parents=True, exist_ok=True)
    package = out / 'consumer'; sources = package / 'Sources/CorpusLifetime'; sources.mkdir(parents=True, exist_ok=True)
    (package / 'Package.swift').write_text('''// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "CorpusLifetime", platforms: [.macOS("27.0"), .iOS("27.0")],
    dependencies: [.package(name: "Swift-JSON", path: ''' + json.dumps(str(ROOT)) + ''')],
    targets: [.executableTarget(name: "CorpusLifetime", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchemaExamples", package: "Swift-JSON")])], swiftLanguageModes: [.v6])
''')
    (sources / 'CorpusLifetime.swift').write_text(SOURCE)
    report = dict(status='failed', commands=[], scopes=128, values=6, sanitizer_suppressions=False,
                  scope='Real public products, repeated exact synthetic corpus/options reads and caller copy mutation; process exit must be ASan/LSan clean.')
    def run(name, command, timeout, environment=None):
        log = out / (name + '.log')
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout, env=environment)
        log.write_text(result.stdout + result.stderr)
        report['commands'].append(dict(command=command, exit_code=result.returncode, log=str(log.relative_to(ROOT)), log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        if result.returncode: raise ValueError(name + ' exited ' + str(result.returncode))
        return log.read_text()
    try:
        build = ['swift', 'build', '-c', 'release', '--sanitize', 'address', '--jobs', '2', '--package-path', str(package), '--scratch-path', '.build/schema-example-lifetime']
        run('build', build, 1200)
        path = run('bin-path', build + ['--show-bin-path'], 120)
        binary = pathlib.Path(path.strip()) / 'CorpusLifetime'
        environment = None
        if sys.platform.startswith('linux'):
            environment = dict(os.environ, ASAN_OPTIONS='detect_leaks=1', LSAN_OPTIONS='')
            report['process_environment_overrides'] = {'ASAN_OPTIONS': 'detect_leaks=1', 'LSAN_OPTIONS': ''}
        text = run('process', [str(binary)], 120, environment)
        if text.splitlines() != [MARKER]: raise ValueError('Missing or additional process outcome')
        report.update(status='passed', binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        report['error'] = str(error)
    (out / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n')
    print(MARKER if report['status'] == 'passed' else 'SCHEMA_EXAMPLES_CORPUS failed')
    return 0 if report['status'] == 'passed' else 1

if __name__ == '__main__': raise SystemExit(main())
