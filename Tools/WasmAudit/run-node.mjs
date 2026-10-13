// SPDX-License-Identifier: Apache-2.0
import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';
import { resolve, dirname } from 'node:path';

const path = resolve(process.argv[2]);
const mode = process.argv[3] ?? 'core';
const grant = process.argv.includes('--resources');
const overrides = process.argv.includes('--resource-override');
const wasi = new WASI({version: 'preview1', args: mode === 'tests' ? [path, '--testing-library', 'swift-testing'] : [path, mode],
  env: overrides ? {PACKAGE_RESOURCE_BUNDLE_PATH: dirname(path)} : {},
  preopens: grant ? {[dirname(path)]: dirname(path)} : {}, returnOnExit: true});
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
  process.exitCode = wasi.start(instance);
}
