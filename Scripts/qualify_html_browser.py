#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run pinned browser qualification; missing tools are an explicit blocked exit."""
import argparse, json, os, pathlib, shutil, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--fixtures', required=True); parser.add_argument('--output', required=True)
    args = parser.parse_args(); output = ROOT / args.output; output.mkdir(parents=True, exist_ok=True)
    node = os.environ.get('JSONHTML_NODE') or shutil.which('node')
    if not node:
        (output / 'browser.json').write_text(json.dumps({'status': 'blocked', 'reason': 'Node.js unavailable; set JSONHTML_NODE'}) + '\n')
        return 2
    result = subprocess.run([node, str(ROOT / 'Tools/JSONHTMLBrowser/browser.cjs'), str(ROOT / args.fixtures), str(output)], cwd=ROOT / 'Tools/JSONHTMLBrowser')
    if result.returncode: return result.returncode
    receipt = json.loads((output / 'browser.json').read_text())
    if receipt['status'] != 'passed' or len(receipt['engines']) != 3 or len(receipt['cases']) != 46 or any(c['status'] != 'passed' for c in receipt['cases']) or receipt['unexpectedSkips']:
        return 1
    return 0
if __name__ == '__main__': sys.exit(main())
