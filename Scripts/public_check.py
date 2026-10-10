#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check the distributed public source inventory, contracts and links."""
import hashlib, json, pathlib, re, sys
from archive_candidate import files

ROOT = pathlib.Path(__file__).resolve().parents[1]
PRIVATE = ('Documentation/Design/', 'Documentation/Execution/', 'Documentation/ReleasePreparation/', 'Documentation/Qualification/RC/', 'Reference/', 'Tools/SchemaComparison/', 'Tools/ScaffoldTests/')

def main():
    errors = []
    selected = files()
    names = {p.relative_to(ROOT).as_posix() for p in selected}
    for name in names:
        if name.startswith(PRIVATE) or name in {'CODEX_KICKOFF.md', 'START_HERE.md', 'ScaffoldInventory.json'}:
            errors.append('Private implementation input in source distribution: ' + name)
    policy = json.loads((ROOT / 'Documentation/Architecture/ResourceProfiles.json').read_text())
    metrics = [dict(m, metric=m.get('metric', m.get('id'))) for group in ['core', 'schema', 'streaming', 'patch', 'enhancement_limits'] for m in policy[group]]
    if len(metrics) != 49 or len({m['metric'] for m in metrics}) != 49:
        errors.append('Expected 49 distinct resource metrics')
    for m in metrics:
        for profile in ['conservative', 'balanced', 'offline']:
            value = m[profile]
            if type(value) is not int or not 0 <= value < 2**64 - 1:
                errors.append('Nonfinite profile: ' + m['metric'])
    matrix = json.loads((ROOT / 'Documentation/Qualification/LimitsMatrix.json').read_text())
    if {m['metric'] for m in matrix['metrics']} != {m['metric'] for m in metrics}:
        errors.append('Cap ownership table differs from finite policy')
    for m in matrix['metrics']:
        if not m['accounting_sites'] or not m['boundary_test']:
            errors.append('Missing cap owner or behavior test: ' + m['metric'])
        for site in m['accounting_sites']:
            if site['path'] not in names:
                errors.append('Missing cap accounting source: ' + site['path'])
    patterns = [r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', r'gh[pousr]_[A-Za-z0-9]{30,}', r'github_pat_[A-Za-z0-9_]{30,}', r'AKIA[A-Z0-9]{16}', r'/Users/' + r'thorfuchs/']
    for p in selected:
        name = p.relative_to(ROOT).as_posix()
        text = p.read_bytes().decode('utf-8', errors='replace')
        if any(re.search(pattern, text) for pattern in patterns):
            errors.append('Credential or personal path marker: ' + name)
        if p.suffix == '.swift' and ('SCAFFOLD_PENDING' in text or '#error(' in text):
            errors.append('Unimplemented source marker: ' + name)
        if p.suffix == '.md':
            for link in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
                link = link.split('#')[0].strip('<>')
                if not link or re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', link):
                    continue
                target = (p.parent / link).resolve()
                try:
                    rel = target.relative_to(ROOT).as_posix()
                except ValueError:
                    errors.append('Link outside public checkout: ' + name)
                    continue
                if rel not in names and not any(n.startswith(rel.rstrip('/') + '/') for n in names):
                    errors.append('Missing public link: ' + name + ' -> ' + link)
    print(json.dumps({'schema_version': 1, 'status': 'failed' if errors else 'passed', 'public_files': len(names), 'finite_metrics': len(metrics), 'profiles': 3, 'source_manifest_sha256': hashlib.sha256(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.relative_to(ROOT).as_posix() + '\n' for p in selected).encode()).hexdigest(), 'errors': errors}, indent=2))
    return 1 if errors else 0

if __name__ == '__main__':
    sys.exit(main())
