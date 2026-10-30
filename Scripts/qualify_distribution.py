#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Public consumer plus installed-resource failures; touch only owned build output."""
import argparse, hashlib, json, os, pathlib, re, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser(); p.add_argument('--output', required=True); a = p.parse_args()
    output = ROOT / a.output; output.mkdir(parents=True, exist_ok=True)
    receipt = dict(status='failed', commands=[], resource_probes=3)
    environment = os.environ.copy()
    for key in ('PACKAGE_RESOURCE_BUNDLE_PATH', 'PACKAGE_RESOURCE_BUNDLE_URL'):
        environment.pop(key, None)
    def save(): (output/'distribution.json').write_text(json.dumps(receipt,indent=2)+'\n')
    save()
    def run(name, command, expected=None):
        start = time.monotonic(); log = output / (name+'.log')
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=ROOT, env=environment, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
        text = log.read_text()
        receipt['commands'].append(dict(command=command, exit_code=result.returncode, seconds=time.monotonic()-start,
            log=log.name, sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        save()
        assert result.returncode == 0 and (expected is None or expected in text), name
        return text.strip()
    package = 'Tools/DistributionAcceptance'
    # The native backend loads tests from a nested .xctest image under a helper.
    # A standalone executable does not exercise its sibling-bundle discovery.
    for configuration in ('debug', 'release'):
        text = run('native-test-host-' + configuration,
            ['swift', 'test', '-c', configuration, '--build-system', 'native',
             '--package-path', package, '--scratch-path', str(output / 'native-test-host')],
            'DISTRIBUTION native_test_host nine_offline_resources exact_verdicts')
        assert re.findall(r'Test run with (\d+) tests? in[^\n]*passed', text) == ['1'], 'Native host discovery changed'
    receipt['native_test_host'] = dict(configurations=['debug', 'release'], functions=1,
        backend='native', resource_overrides_used=False)
    save()
    run('build', ['swift','build','-c','release','--package-path',package])
    directory = pathlib.Path(run('bin-path', ['swift','build','-c','release','--package-path',package,'--show-bin-path']))
    executable = directory / 'DistributionAcceptance'
    candidates = list(directory.glob('Swift-JSON_JSONSchema.*'))
    bundles = [q for q in candidates if q.is_dir() and q.suffix in ('.bundle','.resources')]
    assert len(bundles) == 1, 'Missing/ambiguous installed schema bundle'
    bundle = bundles[0]; files = sorted(q for q in bundle.rglob('*') if q.is_file())
    base = bundle / 'Contents/Resources' if (bundle/'Contents').is_dir() else bundle
    expected = {'schema.json','Provenance.json'} | {'meta/'+name+'.json' for name in
        ['applicator','content','core','format-annotation','format-assertion','meta-data','unevaluated','validation']}
    prefix = base.relative_to(bundle).as_posix()
    installed = {(base/'Draft2020-12'/name).relative_to(bundle).as_posix() for name in expected}
    metadata = 'Contents/Info.plist' if prefix != '.' else 'Info.plist'
    if (bundle/metadata).is_file(): installed.add(metadata)
    receipt['observed_layout'] = dict(resource_prefix=prefix, metadata_present=(bundle/metadata).is_file(),
        files=[q.relative_to(bundle).as_posix() for q in files])
    save()
    assert {q.relative_to(bundle).as_posix() for q in files} == installed, 'Unexpected installed bundle contents'
    resource = base / 'Draft2020-12/schema.json'; original = resource.read_bytes()
    receipt['bundle'] = dict(layout=bundle.name, files=[dict(path=q.relative_to(bundle).as_posix(),sha256=hashlib.sha256(q.read_bytes()).hexdigest()) for q in files])
    receipt['executable_sha256'] = hashlib.sha256(executable.read_bytes()).hexdigest()
    run('intact', [str(executable),'intact'], 'DISTRIBUTION intact nine_offline_resources')
    hidden = bundle.with_name(bundle.name+'.held-by-acceptance')
    assert not hidden.exists()
    bundle.rename(hidden)
    try: run('missing', [str(executable),'unavailable'], 'DISTRIBUTION unavailable structured_metaSchema')
    finally: hidden.rename(bundle)
    # Still valid JSON and the same byte count: catches missing integrity checks.
    assert original.count(b'"title"') == 1
    resource.write_bytes(original.replace(b'"title"',b'"titlf"',1))
    try: run('corrupt', [str(executable),'unavailable'], 'DISTRIBUTION unavailable structured_metaSchema')
    finally: resource.write_bytes(original)
    assert resource.read_bytes() == original
    receipt.update(status='passed', restored=True)
    (output/'distribution.json').write_text(json.dumps(receipt,indent=2)+'\n')

if __name__ == '__main__': main()
