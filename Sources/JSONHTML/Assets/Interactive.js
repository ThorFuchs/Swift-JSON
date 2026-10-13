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
    if (!node || !tree.contains(node)) return;
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
  const copy = async (encoded, label) => {
    const value = text(encoded);
    manual.hidden = true;
    try {
      if (!navigator.clipboard || !navigator.clipboard.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(value);
      say('Browser accepted ' + label + ' copy. Platform clipboard transformations may differ.');
    } catch (_) {
      manual.hidden = false; manualText.value = value;
      manualText.focus(); manualText.select();
      say('Clipboard unavailable or rejected. Select the text and copy manually, or download exact UTF-8 bytes.');
    }
  };
  const bulk = open => {
    const epoch = ++bulkEpoch;
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
    results.replaceChildren();
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
    const candidates = tree.querySelectorAll('.node');
    let i = 0, matches = 0, listed = 0;
    const step = () => {
      if (epoch !== searchEpoch) return;
      const end = Math.min(i + CHUNK, candidates.length);
      for (; i < end; i++) {
        const node = candidates[i];
        const fields = node.tagName === 'DETAILS' ? node.querySelector('summary').querySelectorAll('[data-search]') : node.querySelectorAll(':scope > [data-search]');
        let matched = false;
        for (const field of fields) { if (accepted.length > 0 && field.textContent.includes(accepted)) matched = true; }
        node.classList.toggle('search-hit', matched);
        if (!matched) continue;
        matches++;
        if (listed < MAX_RESULTS) {
          const item = document.createElement('li');
          const link = document.createElement('a');
          link.href = '#' + node.id;
          link.dataset.target = node.id;
          link.textContent = 'Match ' + matches + ': ' + text(node.dataset.pointerEscaped);
          item.append(link); results.append(item); listed++;
        }
      }
      if (i < candidates.length) setTimeout(step, 0);
      else {
        say(issue || matches + ' matching nodes in rendered JSON key/value text. ' + listed + ' results listed (maximum ' + MAX_RESULTS + ').');
        const first = results.querySelector('a');
        if (first) reveal(first.dataset.target, false);
      }
    };
    step();
  };
  document.getElementById('jh-toolbar').hidden = false;
  query.addEventListener('input', search);
  document.addEventListener('click', event => {
    const link = event.target.closest('a[data-target]');
    if (link) { event.preventDefault(); reveal(link.dataset.target); return; }
    const button = event.target.closest('button[data-action]');
    if (!button) return;
    event.preventDefault(); event.stopPropagation();
    const action = button.dataset.action;
    if (action === 'expand') { bulk(true); return; }
    if (action === 'collapse') { bulk(false); return; }
    if (action === 'clear') { query.value = ''; search(); return; }
    if (action === 'select') { manualText.focus(); manualText.select(); return; }
    if (action === 'copy-json' || action === 'download-json') {
      const encoded = document.getElementById('jh-copy-json').dataset.bytes;
      if (action === 'copy-json') void copy(encoded, 'JSON');
      else download(encoded, 'document.json');
      return;
    }
    const node = document.getElementById(button.dataset.node);
    if (!node) return;
    if (action === 'copy-pointer') void copy(node.dataset.pointer, 'raw RFC 6901 Pointer');
    else if (action === 'copy-pointer-escaped') void copy(node.dataset.pointerEscaped, 'Pointer JSON string');
    else if (action === 'download-pointer') download(node.dataset.pointer, 'pointer.txt');
  });
  say('Interactive controls ready. Search scope: rendered JSON key/value text.');
})();
