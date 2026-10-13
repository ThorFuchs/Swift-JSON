// SPDX-License-Identifier: Apache-2.0
import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const path = resolve(process.argv[2]);
const mode = process.argv[3] ?? 'core';
const grant = process.argv.includes('--resources');
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const separator = process.argv.indexOf('--');
const extra = separator < 0 ? [] : process.argv.slice(separator + 1);
const preopens = grant ? {[dirname(path)]: dirname(path)} : {};
if (process.argv.includes('--repo')) preopens[root] = root;
const wasi = new WASI({version: 'preview1',
  args: mode === 'tests' ? [path, '--testing-library', 'swift-testing', ...extra]
    : mode === 'command' ? [path, ...extra] : [path, mode],
  env: {}, preopens, returnOnExit: true});
const module = await WebAssembly.compile(await readFile(path));
if (mode === 'imports') {
  console.log(JSON.stringify({imports: WebAssembly.Module.imports(module),
    exports: WebAssembly.Module.exports(module)}, null, 2));
} else if (mode === 'bare-host') {
  // A browser-like raw WebAssembly host supplies no WASI system imports.
  try {
    await WebAssembly.instantiate(module, {});
    throw new Error('Unexpectedly instantiated without required imports');
  } catch (error) {
    if (!(error instanceof TypeError || error instanceof WebAssembly.LinkError)) throw error;
    console.log('OBSERVATION bare_host blocked missing_WASI_imports');
  }
} else {
  const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
  const start = performance.now();
  process.exitCode = wasi.start(instance);
  console.error('WASI_HOST_MEASURE ' + JSON.stringify({
    milliseconds: performance.now() - start,
    allocatedLinearMemoryBytes: instance.exports.memory.buffer.byteLength,
    hostProcessMaxRSSKiB: process.resourceUsage().maxRSS}));
}
