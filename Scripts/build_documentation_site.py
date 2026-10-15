#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Prepare and verify a static GitHub Pages site from the qualified native DocC archives."""
import hashlib
import html
from html.parser import HTMLParser
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import urllib.parse

from documentation_catalog import PRODUCTS, CATALOGS
from preflight import collect

ROOT = pathlib.Path(__file__).resolve().parents[1]
REPOSITORY = 'https://github.com/ThorFuchs/Swift-JSON'
BASE_PATH = '/Swift-JSON'
SITE_URL = 'https://thorfuchs.github.io' + BASE_PATH + '/'
GUIDES = {'JSON': ('Exact values and native coding', 'exactvaluesandcoding'),
          'JSONSchema': ('Offline schema validation', 'offlinevalidation'),
          'JSONStreaming': ('Completion and backpressure', 'completionandbackpressure'),
          'JSONPatch': ('Choosing and applying patches', 'applyingpatches'),
          'JSONHTML': ('Exact interactive HTML', 'interactiverendering'),
          'JSONBridges': ('Opt-in native conversions', 'numericfidelity'),
          'JSONValueDSL': ('Trusted exact value authoring', 'authoredvalues'),
          'JSONSchemaDSL': ('Authored schemas, engine validation', 'authoredschemas')}
DESCRIPTIONS = {
    'JSON': 'Exact values, strict UTF-8, native Codable, Pointer, presence and finite resource reports.',
    'JSONSchema': 'Draft 2020-12, explicit offline registries, immutable plans, annotations and bounded regex.',
    'JSONStreaming': 'Pull events and values, strict NDJSON, root-array completion and awaited output chunks.',
    'JSONPatch': 'Transactional RFC 6902 JSON Patch and RFC 7396 Merge Patch with exact value semantics.',
    'JSONHTML': 'Exact standalone HTML with offline disclosure/search and native-byte copy/download.',
    'JSONBridges': 'Opt-in trusted integer construction and policy-explicit Double and Foundation Decimal projection.',
    'JSONValueDSL': 'Typed authored objects and arrays with exact values, omission and finite finalization.',
    'JSONSchemaDSL': 'Typed authored Draft 2020-12 declarations, compiled and evaluated by the existing engine.'}


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ('href', 'src') and value:
                self.urls.append(value)


def source_commit():
    top = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, capture_output=True, text=True)
    if top.returncode or pathlib.Path(top.stdout.strip()).resolve() != ROOT:
        return None
    dirty = subprocess.run(['git', 'status', '--porcelain'], cwd=ROOT, capture_output=True, text=True, check=True)
    if dirty.stdout.strip():
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            raise ValueError('Publication inputs differ from the checked-out commit')
        return None
    return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()


def landing(commit):
    cards = []
    for product in PRODUCTS:
        route = BASE_PATH + '/' + product + '/documentation/' + product.lower() + '/'
        title, guide = GUIDES[product]
        guide_route = BASE_PATH + '/' + product + '/documentation/documentation/' + guide + '/'
        cards.append(f'''<article class="card">
<h2><a href="{route}">{product}</a></h2><p>{DESCRIPTIONS[product]}</p>
<a class="reference" href="{route}">API reference <span aria-hidden="true">→</span></a>
<a href="{guide_route}">{title}</a></article>''')
    source = (f'<a href="{REPOSITORY}/commit/{commit}"><code>{commit[:12]}</code></a>'
              if commit else 'Local preview')
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Swift-JSON Documentation</title>
<meta name="description" content="Exact JSON for modern Swift. Explore the JSON, JSONSchema, JSONStreaming, JSONPatch and JSONHTML API references and guides.">
<link rel="canonical" href="{SITE_URL}">
<style>
:root {{ color-scheme: light dark; --background: #f7f9fc; --surface: #fff; --text: #182335; --muted: #4e5d73; --link: #135dc7; --border: #dce3ed; }}
* {{ box-sizing: border-box; }} body {{ margin: 0; background: var(--background); color: var(--text); font: 17px/1.65 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
a {{ color: var(--link); text-underline-offset: .18em; }} a:hover {{ text-decoration-thickness: 2px; }} a:focus-visible {{ outline: 3px solid var(--link); outline-offset: 5px; border-radius: 2px; }}
.skip {{ position: absolute; top: -100px; left: 1rem; padding: .6rem 1rem; background: var(--surface); }} .skip:focus {{ top: 1rem; }}
.container {{ max-width: 1080px; margin: 0 auto; padding: 0 28px; }}
header {{ border-bottom: 1px solid var(--border); background: var(--surface); }} nav {{ display: flex; align-items: center; justify-content: space-between; gap: 24px; min-height: 76px; }}
.brand {{ font-weight: 700; color: var(--text); text-decoration: none; letter-spacing: -.025em; }} .nav-links {{ display: flex; flex-wrap: wrap; gap: 24px; font-size: 15px; }}
main {{ padding-top: 58px; }} .eyebrow {{ font-size: 13px; font-weight: 650; text-transform: uppercase; letter-spacing: .1em; color: var(--muted); }}
h1 {{ font-size: clamp(36px, 6vw, 54px); line-height: 1.12; letter-spacing: -.045em; margin: 16px 0 22px; }}
.intro {{ max-width: 790px; font-size: 21px; line-height: 1.6; color: var(--muted); }} .baseline {{ margin: 22px 0 36px; font-size: 15px; color: var(--muted); }}
.grid {{ display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px; }}
.card {{ display: flex; flex-direction: column; align-items: flex-start; padding: 28px; border: 1px solid var(--border); border-radius: 14px; background: var(--surface); }}
.card h2 {{ font-size: 25px; margin: 0; letter-spacing: -.025em; }} .card h2 a {{ color: var(--text); text-decoration: none; }} .card p {{ color: var(--muted); margin: 14px 0 22px; flex: 1; }} .card > a {{ font-size: 15px; }} .reference {{ font-weight: 650; margin-bottom: 12px; }}
.details {{ margin: 42px 0 48px; max-width: 840px; }} .details h2 {{ font-size: 22px; margin-bottom: 12px; }} .details p {{ color: var(--muted); }}
footer {{ border-top: 1px solid var(--border); padding: 24px 0 36px; color: var(--muted); font-size: 14px; }} code {{ font-size: .95em; }}
@media (prefers-color-scheme: dark) {{ :root {{ --background: #111823; --surface: #192332; --text: #e8edf5; --muted: #b2bfd1; --link: #88b9ff; --border: #33435a; }} }}
@media (max-width: 650px) {{ .container {{ padding: 0 20px; }} nav {{ align-items: flex-start; flex-direction: column; gap: 8px; padding-top: 16px; padding-bottom: 16px; }} main {{ padding-top: 38px; }} .grid {{ grid-template-columns: 1fr; }} .card {{ padding: 24px; }} .intro {{ font-size: 19px; }} }}
</style></head><body>
<a class="skip" href="#content">Skip to documentation</a>
<header><nav class="container" aria-label="Main navigation"><a class="brand" href="{BASE_PATH}/">Swift-JSON</a>
<div class="nav-links"><a href="{REPOSITORY}#installation">Get started</a><a href="{REPOSITORY}">GitHub</a><a href="{REPOSITORY}/issues">Support</a></div></nav></header>
<main id="content" class="container"><div class="eyebrow">Public Swift documentation</div>
<h1>Exact JSON. Clear contracts.</h1>
<p class="intro">Keep decimal values exact, Unicode scalar keys distinct and resource use explicit. Explore eight Swift libraries that carry those semantics from input bytes to validated, transformed and encoded output.</p>
<p class="baseline">Swift 6.4+ · Swift language mode 6 · macOS/SDK 27+ · No package dependencies</p>
<section class="grid" aria-label="Product references">{''.join(cards)}</section>
<section class="details"><h2>Start with the contract</h2>
<p>Read the <a href="{REPOSITORY}#readme">package overview and executable examples</a>, then choose a reference above. The <a href="{REPOSITORY}/blob/main/Documentation/README.md">behavior contracts</a> explain exact numbers, scalar identity, offline schema evaluation, cumulative budgets and stream completion.</p>
<p>These native DocC references track <code>main</code> and publish after native, safety and documentation CI pass. Retain your resolved package commit for reproducible dependencies. Build source: {source}. <a href="{BASE_PATH}/build-info.json">Build information</a>.</p></section></main>
<footer><div class="container">Maintained by <a href="https://github.com/ThorFuchs">Thorsten Fuchs</a> · <a href="{REPOSITORY}/blob/main/LICENSE">Apache-2.0</a> · <a href="{REPOSITORY}/blob/main/THIRD_PARTY_NOTICES.md">Upstream notices</a> · <a href="{REPOSITORY}/security/advisories/new">Private vulnerability reporting</a></div></footer>
</body></html>'''


def verify_site(site):
    paths = sorted(site.rglob('*'))
    if any(p.is_symlink() for p in paths):
        raise ValueError('Site contains a symlink')
    count = 0
    for path in paths:
        if not path.is_file():
            continue
        if path.suffix in ('.html', '.json', '.js', '.css', '.txt', '.xml'):
            text = path.read_text()
            if re.search(r'/Users/' + r'thorfuchs/|github_pat_[A-Za-z0-9_]{30,}|gh[pousr]_[A-Za-z0-9]{30,}|-----BEGIN .*PRIVATE KEY-----', text):
                raise ValueError('Private path or credential marker in site: ' + str(path.relative_to(site)))
        if path.suffix != '.html':
            continue
        links = Links()
        links.feed(path.read_text())
        for raw in links.urls:
            url = urllib.parse.urlsplit(raw)
            if url.scheme or url.netloc or not url.path:
                continue
            target = urllib.parse.unquote(url.path)
            if target.startswith('/'):
                if not target.startswith(BASE_PATH + '/'):
                    raise ValueError('Link outside project base path in ' + str(path.relative_to(site)) + ': ' + raw)
                target_path = site / target[len(BASE_PATH) + 1:]
            else:
                target_path = path.parent / target
            target_path = target_path.resolve()
            if site.resolve() not in target_path.parents and target_path != site.resolve():
                raise ValueError('Link escapes site: ' + raw)
            if not target_path.is_file() and not (target_path / 'index.html').is_file():
                raise ValueError('Missing local route or asset: ' + raw)
            count += 1
    return count


def main():
    output = ROOT / '.build/handoff/pages'
    output.mkdir(parents=True, exist_ok=True)
    site = output / 'site'
    receipt = {'schema_version': 1, 'status': 'failed', 'site_url': SITE_URL,
               'environment': collect(), 'transforms': []}
    try:
        if receipt['environment']['status'] != 'passed':
            raise ValueError('Supported native toolchain unavailable')
        catalogs = ROOT / '.build/handoff/docc'
        # Verify the exact compiler outputs already packaged by the DocC lane.
        manifest = catalogs / 'compiled-catalogs.MANIFEST.sha256'
        inputs = []
        for line in manifest.read_text().splitlines():
            expected, name = line.split('  ', 1)
            path = catalogs / name
            if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise ValueError('Qualified DocC file differs: ' + name)
            inputs.append({'path': name, 'sha256': expected})
        if not inputs:
            raise ValueError('Zero qualified DocC inputs')
        receipt['catalog_input_files'] = len(inputs)
        receipt['catalog_manifest_sha256'] = hashlib.sha256(manifest.read_bytes()).hexdigest()
        if site.exists():
            shutil.rmtree(site)
        site.mkdir()
        for product in CATALOGS:
            command = ['xcrun', 'docc', 'process-archive', 'transform-for-static-hosting',
                       str(catalogs / (product + '.doccarchive')), '--output-path', str(site / product),
                       '--hosting-base-path', BASE_PATH + '/' + product]
            log = output / (product + '.log')
            with log.open('w') as stream:
                result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
            entry = {'product': product, 'command': [arg.replace(str(ROOT), '.') for arg in command],
                     'exit_code': result.returncode, 'log': log.relative_to(ROOT).as_posix(),
                     'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
            receipt['transforms'].append(entry)
            if result.returncode:
                raise ValueError('Native static-hosting transformation failed: ' + product)
            routes = [product.lower()]
            if product in PRODUCTS:
                routes.append('documentation/' + GUIDES[product][1])
            for route in routes:
                if not (site / product / 'documentation' / route / 'index.html').is_file():
                    raise ValueError('Missing product root or guide: ' + route)
            # DocC transforms its emitted routes but retains the original archive
            # root template. Make the product entry point an explicit static redirect.
            route = BASE_PATH + '/' + product + '/documentation/' + product.lower() + '/'
            (site / product / 'index.html').write_text(f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="refresh" content="0; url={route}"><link rel="canonical" href="https://thorfuchs.github.io{route}"><title>{product} · Swift-JSON</title><p><a href="{route}">Open the {product} reference</a>.</p></html>')
        commit = source_commit()
        receipt['source_commit'] = commit
        (site / 'index.html').write_text(landing(commit))
        (site / '.nojekyll').touch()
        (site / '404.html').write_text(f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Page not found · Swift-JSON</title><h1>Page not found</h1><p><a href="{BASE_PATH}/">Open Swift-JSON documentation</a> or <a href="{REPOSITORY}">browse the source</a>.</p></html>')
        (site / 'build-info.json').write_text(json.dumps({
            'repository': REPOSITORY, 'source_commit': commit,
            'ci_run': REPOSITORY + '/actions/runs/' + os.environ['GITHUB_RUN_ID'] if os.environ.get('GITHUB_RUN_ID') else None,
            'swift': receipt['environment']['swift'], 'sdk': receipt['environment']['sdk'],
            'macos': receipt['environment']['macos'], 'swift_language_mode': '6',
            'products': list(PRODUCTS), 'channel': 'main'}, indent=2) + '\n')
        routes = sorted(p.relative_to(site).parent.as_posix() + '/' for p in site.rglob('index.html'))
        urls = [SITE_URL if route == './' else SITE_URL + urllib.parse.quote(route, safe='/') for route in routes]
        (site / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + ''.join('<url><loc>' + html.escape(url) + '</loc></url>\n' for url in urls) + '</urlset>\n')
        (site / 'robots.txt').write_text('User-agent: *\nAllow: /\nSitemap: ' + SITE_URL + 'sitemap.xml\n')
        receipt['local_links_verified'] = verify_site(site)
        receipt['static_routes'] = len(routes)
        paths = sorted(p for p in site.rglob('*') if p.is_file())
        manifest = output / 'site.MANIFEST.sha256'
        manifest.write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.relative_to(site).as_posix() + '\n' for p in paths))
        receipt['site_files'] = len(paths)
        receipt['site_manifest'] = manifest.relative_to(ROOT).as_posix()
        receipt['site_manifest_sha256'] = hashlib.sha256(manifest.read_bytes()).hexdigest()
        receipt['status'] = 'passed'
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
