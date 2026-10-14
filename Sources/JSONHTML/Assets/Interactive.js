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
