// SPDX-License-Identifier: Apache-2.0
// Generated from Assets; verify with Scripts/verify_html_assets.py.
package enum JSONHTMLInteractiveAssets {
    package static let base64Alphabet: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
    package static let css = #"""
/* SPDX-License-Identifier: Apache-2.0; Swift-JSON interactive asset v1 */
.interactive .toolbar{display:flex;gap:.5rem;align-items:center;flex-wrap:wrap;margin-bottom:1rem}.interactive button,.interactive input{font:inherit;padding:.35rem .55rem;border:1px solid currentColor;border-radius:.3rem;background:var(--bg);color:var(--fg)}.interactive :focus-visible{outline:3px solid var(--num);outline-offset:3px}.interactive .layout{display:grid;grid-template-columns:minmax(0,1fr) 18rem;gap:1.5rem}.interactive .layout:not(:has(.outline)){grid-template-columns:minmax(0,1fr)}.interactive .outline{max-height:70vh;overflow:auto;position:sticky;top:1rem;align-self:start}.interactive a{color:var(--num);overflow-wrap:anywhere}.interactive ul{padding-left:1.1rem}.interactive .node{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;line-height:1.7;overflow-wrap:anywhere}.interactive .children{padding-left:1.25rem;border-left:1px solid var(--fg);margin-left:.35rem}.interactive summary{cursor:pointer}.interactive .pointer-label{font-size:.8em;opacity:.85;margin-inline:.5rem}.interactive:not(.enhanced) .pointer-actions{display:none}.interactive .pointer-actions{display:inline-flex;gap:.3rem;flex-wrap:wrap}.interactive .pointer-actions button{font-size:.75rem;padding:.1rem .3rem}.interactive .search-hit{outline:2px solid var(--num);outline-offset:2px}.interactive #jh-status{min-height:1.7rem}.interactive .manual-copy textarea{display:block;width:100%;min-height:8rem;font-family:monospace}.interactive .print-json{display:none}.interactive [hidden]{display:none!important}.interactive code{white-space:pre-wrap}.interactive .search-results{max-height:16rem;overflow:auto}.interactive .kind{font-weight:600}@media(max-width:700px){body.interactive{padding:1rem}.interactive .layout{grid-template-columns:1fr}.interactive .outline{position:static;max-height:15rem}.interactive .pointer-actions{display:flex}.interactive .children{padding-left:.75rem}}@media print{.interactive .toolbar,.interactive .layout,.interactive .manual-copy,.interactive #jh-status,.interactive .search-results,.interactive noscript{display:none!important}.interactive .print-json{display:block!important}.interactive .print-json pre{white-space:pre-wrap;overflow:visible}}
/* Structured forms/cards and native previews. Fixed original asset v2. */
.rich{font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;line-height:1.5;max-width:88rem;margin:auto;padding:2rem;--card:#fff;--line:#d3dce8;--muted:#46566b;--chip:#edf4ff;--string:#174075;--number:#134c27;--bool:#683817;--null:#4b466e}
.rich.dark{--card:#182438;--line:#43526a;--muted:#bbc9dc;--chip:#233753;--string:#c2deff;--number:#b8e4c4;--bool:#ffd8b8;--null:#d9ceff}
.rich .document-header{border-bottom:1px solid var(--line);margin-bottom:1rem}.rich .document-header h1{font-size:1.6rem;margin:.2rem 0}.rich .document-header p{color:var(--muted);font-size:.9rem}.rich .view-tabs{display:flex;gap:.6rem;margin:1rem 0}.rich .view-tabs a{border:1px solid var(--line);border-radius:.45rem;padding:.45rem .8rem;text-decoration:none}.rich [aria-selected=true]{background:var(--chip);font-weight:650}
.rich .layout{grid-template-columns:minmax(0,1fr) 16rem}.rich .node{font-family:inherit;min-width:0;overflow-wrap:anywhere}.rich .container{background:var(--card);border:1px solid var(--line);border-radius:.65rem;padding:.7rem;margin:.2rem 0 .6rem}.rich summary{cursor:pointer;line-height:1.6}.rich summary .kind{color:var(--muted);font-size:.83rem}.rich .container.depth-0{padding:1rem}.rich .container.depth-1{border-inline-start:3px solid #789ac3}.rich .container.depth-2{border-inline-start:3px solid #809d8b}.rich .container.depth-3{border-inline-start:3px solid #9b8ead}
.rich .object-form{margin:.6rem 0 0}.rich .field-row{display:grid;grid-template-columns:minmax(7rem,23%) minmax(0,1fr);gap:.6rem;border-top:1px solid var(--line);padding:.6rem 0}.rich dt,.rich dd{margin:0;min-width:0}.rich dt{color:var(--muted)}.rich .key{white-space:pre-wrap;overflow-wrap:anywhere;font-size:.85rem}.rich .scalar{padding:.2rem .45rem;border-radius:.35rem;background:var(--chip);white-space:normal}.rich .scalar.string{color:var(--string)}.rich .scalar.number{color:var(--number)}.rich .scalar.bool{color:var(--bool)}.rich .scalar.null{color:var(--null)}.rich .display-value{white-space:pre-wrap;overflow-wrap:anywhere}.rich code{font-size:.9em}.rich .pointer-actions{margin-inline:.4rem}.rich .pointer-actions button{font-size:.72rem}
.rich .indexed-list{list-style:none;padding:0;margin:.6rem 0 0;display:grid;gap:.65rem}.rich .record-card{border:1px solid var(--line);border-radius:.55rem;padding:.65rem;min-width:0}.rich .index-label{display:block;font-size:.8rem;color:var(--muted);font-weight:650;margin-bottom:.35rem}.rich .scalar-flow{display:flex;flex-wrap:wrap;list-style:none;padding:0;gap:.4rem}.rich .flow-item{min-width:0;max-width:100%}.rich .visually-hidden{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%)}.rich .original-value{margin:.4rem 0;color:var(--fg);border-top:1px dashed var(--line);padding-top:.4rem}.rich .original-value code{display:block;white-space:pre-wrap;overflow-wrap:anywhere}.rich .preview-label,.rich .preview-kind{display:block;font-size:.78rem;color:var(--muted);margin:.25rem 0}.rich .color-swatch{display:block;width:7.5rem;height:3rem;border:1px solid var(--line);border-radius:.4rem;margin:.3rem 0}.rich .image-preview{margin:.5rem 0}.rich .image-preview img{display:block;max-width:100%;height:auto;object-fit:contain}.rich figcaption{font-size:.78rem;color:var(--muted)}.rich math{font-size:1.12em;max-width:100%;overflow-x:auto;vertical-align:middle}.rich .inert-link,.rich .inert-image{overflow-wrap:anywhere}.rich .exact-source{margin:1rem 0}.rich .print-json{display:none}.rich dialog{width:min(90vw,44rem);background:var(--bg);color:var(--fg);border:1px solid var(--line);border-radius:.5rem}.rich dialog::backdrop{background:#0008}.rich .manual-copy textarea{box-sizing:border-box}.rich .search-hit{outline:2px solid var(--num);outline-offset:2px}.rich pre{white-space:pre-wrap;overflow-wrap:anywhere;overflow:visible}.rich a:focus-visible,.rich button:focus-visible,.rich input:focus-visible,.rich select:focus-visible{outline:3px solid var(--num);outline-offset:3px}
@media(prefers-color-scheme:dark){.rich.automatic{--card:#182438;--line:#43526a;--muted:#bbc9dc;--chip:#233753;--string:#c2deff;--number:#b8e4c4;--bool:#ffd8b8;--null:#d9ceff}}
@media(max-width:700px){.rich,.rich.interactive{padding:.8rem}.rich .layout{grid-template-columns:minmax(0,1fr)}.rich .field-row{grid-template-columns:minmax(0,1fr);gap:.3rem}.rich .container.depth-0{padding:.55rem}.rich .container,.rich .record-card{padding:.45rem}.rich .outline{position:static}}
@media(prefers-reduced-motion:reduce){.rich *{scroll-behavior:auto!important;animation:none!important;transition:none!important}}
@media(forced-colors:active){.rich .scalar,.rich .container,.rich .record-card{background:Canvas;color:CanvasText;border-color:CanvasText}.rich .color-swatch{forced-color-adjust:none}.rich .kind,.rich .preview-kind,.rich .preview-label,.rich .index-label{color:CanvasText}}
@media print{.rich .screen-view,.rich .document-header,.rich .exact-source,.rich .view-tabs,.rich .preview-issues,.rich .toolbar,.rich #jh-status,.rich .search-results,.rich dialog,.rich noscript{display:none!important}.rich .print-json{display:block!important}.rich .print-json .container{border:1px solid #aaa;break-inside:auto}.rich .print-json .record-card{break-inside:avoid}.rich{padding:0;max-width:none;color:#111;background:#fff;--card:#fff;--line:#bbb;--muted:#333;--chip:#f6f6f6;--string:#173353;--number:#154524;--bool:#4b2611;--null:#494158}.rich .original-value{display:block}.rich .image-preview img{max-height:22cm;width:auto;max-width:100%}.rich .print-json .object-form{display:block}.rich .print-json summary{list-style:none}}
.rich pre code{unicode-bidi:plaintext;direction:ltr}.rich .container.depth-3{padding:0;border:0;margin:.2rem 0;border-radius:0}.rich dialog[open]{display:block!important}
.rich .scalar-kind{font-size:.72rem;color:var(--muted);margin-inline-end:.4rem;font-weight:600}.rich .display-value,.rich .key,.rich .original-value code,.rich .inert-link,.rich .inert-image{unicode-bidi:isolate;direction:ltr}.rich .depth-3 .field-row{grid-template-columns:minmax(0,1fr)}
.rich .color-swatch{max-width:100%;height:auto;aspect-ratio:5/2}.rich .view-tabs{flex-wrap:wrap}.rich .pointer-actions{max-width:100%;min-width:0}.rich button,.rich input,.rich select{max-width:100%;min-width:0;box-sizing:border-box}.rich button{white-space:normal;overflow-wrap:anywhere}

@media print{.rich .source-download{display:none!important}}
"""#
    package static let script = #"""
// SPDX-License-Identifier: Apache-2.0
// Swift-JSON interactive asset v1. UI text only; never a browser JSON model.
(() => {
  'use strict';
  const tree = document.getElementById('jh-tree');
  const status = document.getElementById('jh-status');
  const query = document.getElementById('jh-query');
  const results = document.getElementById('jh-results');
  const manual = document.getElementById('jh-manual');
  const manualText = document.getElementById('jh-manual-text');
  const CHUNK = 128;
  const MAX_RESULTS = 100;
  let searchEpoch = 0;
  let bulkEpoch = 0;
  let activeView = 'structured';
  let hitIDs = [], hitIndex = -1, copyFocus;
  const tabs = document.getElementById('jh-tabs');
  const views = ['structured', 'syntax'];
  const activate = (view, focus = false) => {
    const changed = activeView !== view;
    activeView = view;
    if (!tabs) return;
    for (const name of views) {
      const tab = document.getElementById('jh-tab-' + name);
      const pane = document.getElementById('jh-' + name);
      const selected = name === view;
      tab.setAttribute('aria-selected', String(selected)); tab.tabIndex = selected ? 0 : -1;
      pane.hidden = !selected;
      if (focus && selected) tab.focus();
    }
    const label = document.querySelector('label[for="jh-query"]');
    label.textContent = view === 'syntax' ? 'Search exact JSON source' : 'Search previews';
    if (changed) search();
  };
  const moveHit = delta => {
    if (!hitIDs.length) return;
    hitIndex = hitIndex < 0 ? (delta < 0 ? hitIDs.length - 1 : 0) : (hitIndex + delta + hitIDs.length) % hitIDs.length;
    reveal(hitIDs[hitIndex]);
    say('Result ' + (hitIndex + 1) + ' of ' + hitIDs.length + ' listed matches (maximum 100).');
  };
  const bytes = encoded => {
    const text = atob(encoded);
    const result = new Uint8Array(text.length);
    for (let i = 0; i < text.length; i++) result[i] = text.charCodeAt(i);
    return result;
  };
  const text = encoded => new TextDecoder('utf-8', {fatal: true}).decode(bytes(encoded));
  const say = message => { status.textContent = message; };
  const reveal = (id, focus = true) => {
    const node = document.getElementById(id);
    if (!node || !(tree.contains(node) || node.id === 'jh-syntax')) return;
    if (tabs) activate(node.id === 'jh-syntax' ? 'syntax' : 'structured');
    for (let parent = node.parentElement; parent; parent = parent.parentElement) {
      if (parent.tagName === 'DETAILS') parent.open = true;
    }
    if (node.tagName === 'DETAILS') node.open = true;
    if (focus) {
      node.focus({preventScroll: true});
      node.scrollIntoView({block: 'nearest'});
    }
  };
  const download = (encoded, filename) => {
    const url = URL.createObjectURL(new Blob([bytes(encoded)], {type: filename.endsWith('.txt') ? 'text/plain;charset=utf-8' : 'application/json;charset=utf-8'}));
    const link = document.createElement('a');
    link.href = url; link.download = filename;
    document.body.append(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    say('Download requested: ' + filename + '.');
  };
  const copy = async (encoded, label, opener) => {
    const value = text(encoded);
    copyFocus = opener || document.activeElement;
    if (manual.open) manual.close();
    else manual.hidden = true;
    try {
      if (!navigator.clipboard || !navigator.clipboard.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(value);
      say('Browser accepted ' + label + ' copy. Platform clipboard transformations may differ.');
    } catch (_) {
      manual.hidden = false; manualText.value = value;
      if (manual.showModal) manual.showModal();
      manualText.focus(); manualText.select();
      say(value.length === 0 ? 'Root Pointer is empty. Clipboard unavailable or rejected; download exact UTF-8 bytes.' : 'Clipboard unavailable or rejected. Select the text and copy manually, or download exact UTF-8 bytes.');
    }
  };
  const bulk = open => {
    const epoch = ++bulkEpoch;
    if (tabs && activeView === 'syntax') { say('The exact JSON source view has no container disclosures.'); return; }
    const nodes = tree.querySelectorAll('details.node');
    let i = 0;
    const step = () => {
      if (epoch !== bulkEpoch) return;
      const end = Math.min(i + CHUNK, nodes.length);
      for (; i < end; i++) nodes[i].open = open;
      if (i < nodes.length) setTimeout(step, 0);
      else say((open ? 'Expanded ' : 'Collapsed ') + nodes.length + ' containers.');
    };
    step();
  };
  // Full DOM remains present. Scanning is chunked, not a browser CPU/heap quota.
  const search = () => {
    const epoch = ++searchEpoch;
    results.replaceChildren(); hitIDs = []; hitIndex = -1;
    const needle = query.value;
    const byteLimit = Number(query.dataset.byteLimit);
    let issue = '';
    if (needle.length > byteLimit) issue = 'Search query exceeds the UTF-8 byte limit.';
    else {
      for (const scalar of needle) {
        const cp = scalar.codePointAt(0);
        if (cp >= 0xd800 && cp <= 0xdfff) issue = 'Search requires Unicode scalar text.';
      }
      if (new TextEncoder().encode(needle).length > byteLimit) issue = 'Search query exceeds the UTF-8 byte limit.';
    }
    const accepted = issue ? '' : needle;
    const candidates = activeView === 'syntax' && tabs ? [document.getElementById('jh-syntax')] : tree.querySelectorAll('.node');
    let i = 0, matches = 0, listed = 0;
    const step = () => {
      if (epoch !== searchEpoch) return;
      const end = Math.min(i + CHUNK, candidates.length);
      for (; i < end; i++) {
        const node = candidates[i];
        const fields = node.id === 'jh-syntax' ? node.querySelectorAll('[data-source-search]') : node.tagName === 'DETAILS' ? node.querySelector('summary').querySelectorAll('[data-search]') : node.querySelectorAll(':scope > [data-search]');
        const key = node.parentElement.tagName === 'DD' ? node.parentElement.previousElementSibling : null;
        let matched = false;
        for (const field of fields) { if (accepted.length > 0 && field.textContent.includes(accepted)) matched = true; }
        if (key && accepted.length && key.textContent.includes(accepted)) matched = true;
        node.classList.toggle('search-hit', matched && listed < MAX_RESULTS);
        if (!matched) continue;
        matches++;
        if (listed < MAX_RESULTS) {
          const item = document.createElement('li');
          const link = document.createElement('a');
          link.href = '#' + node.id;
          link.dataset.target = node.id;
          link.textContent = 'Match ' + matches + ': ' + (node.dataset.pointerEscaped ? text(node.dataset.pointerEscaped) : 'Exact JSON source');
          hitIDs.push(node.id);
          item.append(link); results.append(item); listed++;
        }
      }
      if (i < candidates.length) setTimeout(step, 0);
      else {
        say(issue || matches + ' matching nodes in ' + (activeView === 'syntax' ? 'exact JSON source' : 'displayed key/value previews') + '. ' + listed + ' results listed (maximum ' + MAX_RESULTS + ').');
        const first = results.querySelector('a');
        if (first) reveal(first.dataset.target, false);
      }
    };
    step();
  };
  query.addEventListener('input', search);
  query.addEventListener('keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); query.value = ''; search(); }
    if (event.key === 'Enter') { event.preventDefault(); moveHit(event.shiftKey ? -1 : 1); }
  });
  if (tabs) {
    tabs.setAttribute('role', 'tablist'); tabs.setAttribute('aria-label', 'JSON view');
    for (const view of views) {
      const tab = document.getElementById('jh-tab-' + view), pane = document.getElementById('jh-' + view);
      tab.setAttribute('role', 'tab'); tab.setAttribute('aria-controls', pane.id);
      pane.setAttribute('role', 'tabpanel'); pane.setAttribute('aria-labelledby', tab.id);
      tab.addEventListener('click', event => { event.preventDefault(); activate(view); search(); });
      tab.addEventListener('keydown', event => {
        if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
        event.preventDefault();
        activate(event.key === 'Home' ? 'structured' : event.key === 'End' ? 'syntax' : view === 'syntax' ? 'structured' : 'syntax', true); search();
      });
    }
    activate(document.getElementById('jh-structured').dataset.initialView);
  }
  const theme = document.getElementById('jh-theme');
  if (theme) {
    theme.value = document.body.classList.contains('dark') ? 'dark' : document.body.classList.contains('light') ? 'light' : 'automatic';
    theme.addEventListener('change', () => { for (const value of ['automatic', 'light', 'dark']) document.body.classList.toggle(value, value === theme.value); });
  }
  if (manual.tagName === 'DIALOG') manual.addEventListener('close', () => { if (copyFocus && copyFocus.isConnected) copyFocus.focus(); });
  document.addEventListener('click', event => {
    const link = event.target.closest('a[data-target]');
    if (link) { event.preventDefault(); reveal(link.dataset.target); return; }
    const button = event.target.closest('button[data-action]');
    if (!button) return;
    event.preventDefault(); event.stopPropagation();
    const action = button.dataset.action;
    if (action === 'next') { moveHit(1); return; }
    if (action === 'previous') { moveHit(-1); return; }
    if (action === 'close-copy') { manual.close(); return; }
    if (action === 'expand') { bulk(true); return; }
    if (action === 'collapse') { bulk(false); return; }
    if (action === 'clear') { query.value = ''; search(); return; }
    if (action === 'select') { manualText.focus(); manualText.select(); return; }
    if (action === 'copy-json' || action === 'download-json') {
      const encoded = document.getElementById('jh-copy-json').dataset.bytes;
      if (action === 'copy-json') void copy(encoded, 'JSON', button);
      else download(encoded, 'document.json');
      return;
    }
    const node = document.getElementById(button.dataset.node);
    if (!node) return;
    if (action === 'copy-pointer') void copy(node.dataset.pointer, 'raw RFC 6901 Pointer', button);
    else if (action === 'copy-pointer-escaped') void copy(node.dataset.pointerEscaped, 'Pointer JSON string', button);
    else if (action === 'download-pointer') download(node.dataset.pointer, 'pointer.txt');
  });
  document.body.classList.add('enhanced');
  document.getElementById('jh-toolbar').hidden = false;
  say('Interactive controls ready. Search scope: selected displayed previews or exact JSON source.');
})();
"""#
    package static let styleHash = "f+TaCOj0W3wyCPnJkJlaJPTkXaxYdsglIBjynmeClbg="
    package static let scriptHash = "0E/zm4efMpR/ae2G76+pX+c/zABUnOf3Bmlbu8CFcDc="
}
