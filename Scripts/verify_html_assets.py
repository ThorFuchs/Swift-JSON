#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify or regenerate the fixed original asset mirror and exact CSP hashes."""
import base64, hashlib, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
def expected(root):
    base = (root / 'Sources/JSONHTML/JSONHTMLAssets.swift').read_text().split('package static let css = """\n')[1].split('\n"""')[0]
    css = (root / 'Sources/JSONHTML/Assets/Interactive.css').read_text().rstrip('\n')
    js = (root / 'Sources/JSONHTML/Assets/Interactive.js').read_text().rstrip('\n')
    def digest(t): return base64.b64encode(hashlib.sha256(t.encode()).digest()).decode()
    return '// SPDX-License-Identifier: Apache-2.0\n// Generated from Assets; verify with Scripts/verify_html_assets.py.\npackage enum JSONHTMLInteractiveAssets {\n    package static let base64Alphabet: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)\n    package static let css = #"""\n' + css + '\n"""#\n    package static let script = #"""\n' + js + '\n"""#\n    package static let styleHash = "' + digest(base + '\n' + css) + '"\n    package static let scriptHash = "' + digest(js) + '"\n}\n'
if __name__ == '__main__':
    target = ROOT / 'Sources/JSONHTML/JSONHTMLInteractiveAssets.swift'
    text = expected(ROOT)
    if sys.argv[1:] == ['--write']: target.write_text(text)
    if target.read_text() != text: raise SystemExit('Interactive asset mirror or CSP hash mismatch')
    print('JSONHTML_ASSETS passed count=2')
