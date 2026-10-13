// SPDX-License-Identifier: Apache-2.0
// Qualification-only. No Playwright or Node dependency enters the root package.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {pathToFileURL} = require('node:url');
const playwright = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const version = require(path.join(path.dirname(require.resolve(process.env.PLAYWRIGHT_MODULE || 'playwright')), 'package.json')).version;
assert.equal(version, '1.62.1', 'Qualification requires the pinned Playwright version');
const fixtures = path.resolve(process.argv[2]), out = path.resolve(process.argv[3]);
fs.mkdirSync(out, {recursive: true});
const records = JSON.parse(fs.readFileSync(path.join(fixtures, 'fixtures.json')));
assert.equal(records.length, 8);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const receipt = {status: 'running', playwright: version, fixtures: [], engines: [], cases: [], limitations: ['Playwright WebKit is not native Safari qualification.', 'Viewport tests do not qualify physical mobile browsers or VoiceOver.', 'Clipboard API acceptance is separate from platform clipboard transformations; exact downloads are independently compared.', 'Search chunking is not an instruction, CPU, heap or process RSS guarantee.']};
for (const name of fs.readdirSync(fixtures).sort()) {
  const bytes = fs.readFileSync(path.join(fixtures, name));
  receipt.fixtures.push({path: name, bytes: bytes.length, sha256: sha(bytes)});
}
const server = http.createServer((req, res) => {
  const name = path.basename(new URL(req.url, 'http://localhost').pathname);
  if (!/^[a-z-]+\.(html|json)$/.test(name) || !fs.existsSync(path.join(fixtures, name))) {res.writeHead(404); res.end(); return;}
  res.writeHead(200, {'Content-Type': name.endsWith('.html') ? 'text/html; charset=utf-8' : 'application/json'});
  res.end(fs.readFileSync(path.join(fixtures, name)));
});
const activeBrowsers = [];
const save = () => fs.writeFileSync(path.join(out, 'browser.json'), JSON.stringify(receipt, null, 2) + '\n');
async function main() {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = 'http://127.0.0.1:' + server.address().port;
  for (const engine of ['chromium', 'webkit', 'firefox']) {
    let browser;
    try { browser = await playwright[engine].launch({headless: true, timeout: 30_000}); }
    catch (error) {
      receipt.engines.push({name: engine, status: 'blocked', error: error.message, executedCases: 0, unexecutedCases: engine === 'chromium' ? 13 : 12});
      save(); continue;
    }
    activeBrowsers.push(browser);
    receipt.engines.push({name: engine, status: 'started', version: browser.version(), executable: path.basename(playwright[engine].executablePath())});
    async function run(name, fixture, protocol, javaScriptEnabled, action, extra = {}) {
      const errors = [], requests = [], violations = [];
      const context = await browser.newContext({javaScriptEnabled, acceptDownloads: true, viewport: {width: 1440, height: 1000}, ...extra});
      await context.route('**/*', async route => {
        const url = route.request().url();
        if (url.startsWith(origin + '/') || url.startsWith('file:') || url.startsWith('blob:')) return route.continue();
        requests.push(url); await route.abort();
      });
      const page = await context.newPage();
      page.on('pageerror', error => errors.push(error.message));
      page.on('console', message => {if (message.type() === 'error') errors.push(message.text());});
      await context.addInitScript(() => {
        window.__violations = [];
        document.addEventListener('securitypolicyviolation', e => window.__violations.push(e.violatedDirective));
      });
      const entry = {engine, name, fixture, protocol, javaScriptEnabled, status: 'running'};
      receipt.cases.push(entry); save();
      try {
        const url = protocol === 'file' ? pathToFileURL(path.join(fixtures, fixture + '.html')).href : origin + '/' + fixture + '.html';
        await page.goto(url);
        assert.ok((await page.title()).length > 0);
        assert.equal(await page.locator('h1').count(), 1);
        const record = records.find(r => r.name === fixture);
        const dom = await page.evaluate(() => {
          let count = 0; const iterator = document.createTreeWalker(document, NodeFilter.SHOW_ALL);
          while (iterator.nextNode()) count++; return count;
        });
        assert.ok(dom <= record.domUpperBound, 'DOM bound undercounts actual nodes');
        entry.actualDOMNodes = dom; entry.domUpperBound = record.domUpperBound;
        if (fixture !== 'formatted') {
          assert.equal(await page.locator('#jh-tree .node').count(), record.nodes);
          assert.equal(await page.locator('#jh-toolbar').isVisible(), javaScriptEnabled);
        }
        await action(page, context, record);
        if (javaScriptEnabled) violations.push(...await page.evaluate(() => window.__violations));
        const enhancedDOM = await page.evaluate(() => {let count = 0; const it = document.createTreeWalker(document, NodeFilter.SHOW_ALL); while (it.nextNode()) count++; return count;});
        assert.ok(enhancedDOM <= record.domUpperBound, 'Enhanced DOM bound undercounts');
        entry.enhancedDOMNodes = enhancedDOM;
        assert.deepEqual(errors, [], 'Unexpected browser console/page errors');
        assert.deepEqual(requests, [], 'Unexpected external resource request');
        assert.deepEqual(violations, [], 'CSP violation');
        entry.status = 'passed'; entry.consoleErrors = errors; entry.externalRequests = requests; entry.cspViolations = violations;
      } catch (e) {
        entry.status = 'failed'; entry.error = e.stack; entry.consoleErrors = errors; entry.externalRequests = requests; entry.cspViolations = violations;
        await page.screenshot({path: path.join(out, engine + '-' + name + '-failure.png'), fullPage: true}).catch(() => {});
        throw e;
      } finally { await context.close(); save(); }
    }
    async function status(page, text) { await page.waitForFunction(text => document.getElementById('jh-status').textContent.includes(text), text); }
    async function downloaded(page, selector) {
      const event = page.waitForEvent('download'); await page.locator(selector).first().click();
      const download = await event; const file = await download.path(); assert.ok(file);
      return {bytes: fs.readFileSync(file), filename: download.suggestedFilename()};
    }
    for (const protocol of ['file', 'http']) for (const enabled of [false, true]) {
      await run(protocol + '-disclosure-' + enabled, 'exact', protocol, enabled, async page => {
        const root = page.locator('#jh-n-0');
        assert.equal(await root.evaluate(n => n.open), true);
        await root.locator(':scope > summary').click({position: {x: 5, y: 8}});
        assert.equal(await root.evaluate(n => n.open), false);
        await root.locator(':scope > summary').focus(); await page.keyboard.press('Enter');
        assert.equal(await root.evaluate(n => n.open), true);
        assert.equal(await page.locator('details[name]').count(), 0);
      });
    }
    await run('keyboard-outline', 'deep', 'http', true, async page => {
      await page.locator('.outline a').last().click();
      assert.equal(await page.locator('details[open]').count(), 4);
      assert.equal(await page.evaluate(() => document.activeElement.id), 'jh-n-3');
      await page.getByRole('button', {name: 'Expand all', exact: true}).click(); await status(page, 'Expanded 40');
      assert.equal(await page.locator('details[open]').count(), 40);
      await page.getByRole('button', {name: 'Collapse all', exact: true}).click(); await status(page, 'Collapsed 40');
      assert.equal(await page.locator('details[open]').count(), 0);
    });
    await run('literal-search', 'wide', 'http', true, async page => {
      await page.locator('#jh-query').fill('[needle]'); await status(page, '150 matching nodes');
      assert.equal(await page.locator('#jh-results a').count(), 100);
      assert.equal(await page.locator('.search-hit').count(), 150);
      const peakDOM = await page.evaluate(() => {let n = 0; const it = document.createTreeWalker(document, NodeFilter.SHOW_ALL); while (it.nextNode()) n++; return n;});
      assert.ok(peakDOM <= records.find(r => r.name === 'wide').domUpperBound);
      await page.locator('#jh-query').fill('Needle'); await status(page, '0 matching nodes');
      await page.locator('#jh-query').fill('');
      await page.locator('#jh-query').pressSequentially('literal [needle] 149'); await status(page, '1 matching nodes');
      assert.equal(await page.evaluate(() => document.activeElement.id), 'jh-query');
      await page.locator('#jh-results a').click();
      assert.equal(await page.evaluate(() => document.activeElement.id), 'jh-n-150');
      await page.getByRole('button', {name: 'Clear search', exact: true}).click(); await status(page, '0 matching nodes');
      assert.equal(await page.locator('.search-hit').count(), 0);
    });
    await run('exact-copy-download', 'exact', 'http', true, async page => {
      await page.evaluate(() => Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {writeText: value => new Promise(resolve => {window.__copied = value; window.__resolveCopy = resolve;})}}));
      await page.getByRole('button', {name: 'Copy JSON', exact: true}).click();
      assert.equal((await page.locator('#jh-status').textContent()).includes('Browser accepted JSON'), false);
      await page.evaluate(() => window.__resolveCopy()); await status(page, 'Browser accepted JSON');
      const expected = fs.readFileSync(path.join(fixtures, 'exact.json'));
      assert.deepEqual(Buffer.from(await page.evaluate(() => window.__copied), 'utf8'), expected);
      const download = await downloaded(page, '[data-action="download-json"]');
      assert.equal(download.filename, 'document.json'); assert.deepEqual(download.bytes, expected);
    });
    await run('pointer-manual-fallback', 'exact', 'file', true, async page => {
      await page.evaluate(() => Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {writeText: async () => {throw new Error('Rejected for qualification');}}}));
      const raw = '/~01~1a\0\r\n';
      const download = await downloaded(page, '#jh-n-1 > summary [data-action="download-pointer"]');
      assert.equal(download.filename, 'pointer.txt'); assert.deepEqual(download.bytes, Buffer.from(raw, 'utf8'));
      await page.locator('#jh-n-1 > summary [data-action="copy-pointer"]').click(); await status(page, 'Clipboard unavailable or rejected');
      // Textareas normalize CRLF; fallback is visibly manual and does not promise byte fidelity.
      assert.equal(await page.locator('#jh-manual-text').inputValue(), raw.replace(/\r\n/g, '\n'));
      await page.locator('#jh-n-1 > summary [data-action="copy-pointer-escaped"]').click();
      await page.waitForFunction(() => document.getElementById('jh-manual-text').value.startsWith('"'));
      assert.equal(await page.locator('#jh-manual-text').inputValue(), '"/~01~1a\\u0000\\u000d\\u000a"');
      assert.equal(await page.locator('#jh-n-1').evaluate(n => n.open), true);
      await page.evaluate(() => Object.defineProperty(navigator, 'clipboard', {configurable: true, value: undefined}));
      await page.getByRole('button', {name: 'Copy JSON', exact: true}).click(); await status(page, 'Clipboard unavailable or rejected');
      assert.equal(await page.locator('#jh-manual-text').inputValue(), fs.readFileSync(path.join(fixtures, 'exact.json'), 'utf8'));
    });
    await run('hostile-csp', 'hostile', 'http', true, async page => {
      assert.equal(await page.locator('img').count(), 0);
      assert.equal(await page.locator('script').count(), 1);
      assert.equal(await page.evaluate(() => typeof window.pwned), 'undefined');
      const download = await downloaded(page, '[data-action="download-json"]');
      assert.deepEqual(download.bytes, fs.readFileSync(path.join(fixtures, 'hostile.json')));
      assert.equal(await page.locator('code[data-search]').textContent(), fs.readFileSync(path.join(fixtures, 'hostile.json'), 'utf8'));
    });
    await run('mobile-layout', 'exact', 'http', true, async page => {
      assert.ok(await page.getByRole('button', {name: 'Download JSON (UTF-8)', exact: true}).isVisible());
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
      assert.equal(overflow, false, 'Mobile horizontal overflow');
      await page.screenshot({path: path.join(out, engine + '-mobile.png'), fullPage: true});
      await page.setViewportSize({width: 1440, height: 1000});
      await page.screenshot({path: path.join(out, engine + '-desktop.png'), fullPage: true});
    }, {viewport: {width: 390, height: 844}});
    await run('complete-print', 'deep', 'http', true, async page => {
      assert.equal(await page.locator('details[open]').count(), 0);
      await page.emulateMedia({media: 'print'});
      assert.equal(await page.locator('#jh-tree').isVisible(), false);
      assert.equal(await page.locator('.print-json').isVisible(), true);
      assert.equal(await page.locator('.print-json code').textContent(), fs.readFileSync(path.join(fixtures, 'deep.json'), 'utf8'));
      if (engine === 'chromium') await page.pdf({path: path.join(out, 'chromium-complete.pdf'), format: 'A4'});
      assert.equal(await page.locator('details[open]').count(), 0);
    });
    await run('query-limit-no-outline', 'zero-query', 'http', true, async page => {
      await page.locator('#jh-query').fill('é'); await status(page, 'exceeds the UTF-8 byte limit');
      assert.equal(await page.locator('#jh-results a').count(), 0);
      await page.goto(origin + '/no-outline.html');
      assert.equal(await page.locator('.outline').count(), 0);
      await page.locator('#jh-query').fill('é'); await status(page, '1 matching nodes');
      await page.locator('#jh-query').fill('é'); await status(page, '1 matching nodes');
      await page.locator('#jh-query').fill('é'.repeat(513)); await status(page, 'exceeds the UTF-8 byte limit');
      assert.equal(await page.locator('.search-hit').count(), 0);
      await page.evaluate(() => {const q = document.getElementById('jh-query'); q.value = '\ud800'; q.dispatchEvent(new Event('input'));});
      await status(page, 'Unicode scalar text');
    });
    if (engine === 'chromium') await run('native-browser-clipboard', 'exact', 'http', true, async (page, context) => {
      await context.grantPermissions(['clipboard-read', 'clipboard-write']);
      await page.getByRole('button', {name: 'Copy JSON', exact: true}).click(); await status(page, 'Browser accepted JSON');
      assert.deepEqual(Buffer.from(await page.evaluate(() => navigator.clipboard.readText()), 'utf8'), fs.readFileSync(path.join(fixtures, 'exact.json')));
    });
    await browser.close();
  }
  receipt.expectedCases = 37; receipt.passedCases = receipt.cases.filter(c => c.status === 'passed').length;
  receipt.unexecutedCases = receipt.engines.reduce((sum, e) => sum + (e.unexecutedCases || 0), 0);
  if (receipt.unexecutedCases) {receipt.status = 'blocked'; save(); console.error('Browser startup blocked; unexecuted cases=' + receipt.unexecutedCases); process.exitCode = 2; return;}
  assert.equal(receipt.cases.length, 37);
  assert.equal(receipt.cases.filter(c => c.status === 'passed').length, 37);
  receipt.status = 'passed'; receipt.expectedCases = 37; receipt.passedCases = 37; receipt.unexpectedSkips = 0;
  save(); console.log('JSONHTML_BROWSER passed engines=3 cases=37 skips=0');
}
main().catch(error => {receipt.status = 'failed'; receipt.error = error.stack; save(); console.error(error); process.exitCode = 1;}).finally(async () => {await Promise.all(activeBrowsers.map(b => b.close().catch(() => {}))); server.close();});
