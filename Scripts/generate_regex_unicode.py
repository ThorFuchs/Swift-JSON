#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Generate immutable ECMA-262 2020 property tables from pinned Unicode 13 UCD.

No runtime networking, host Unicode database, or normalization is used. Input
hashes, generator hash and output hashes are emitted alongside the generated
code. Regeneration must compare byte-for-byte before accepting a data change.
"""
import argparse
import hashlib
import json
from pathlib import Path

BINARY = set('''ASCII ASCII_Hex_Digit Alphabetic Any Assigned Bidi_Control Bidi_Mirrored Case_Ignorable Cased
Changes_When_Casefolded Changes_When_Casemapped Changes_When_Lowercased Changes_When_NFKC_Casefolded
Changes_When_Titlecased Changes_When_Uppercased Dash Default_Ignorable_Code_Point Deprecated Diacritic
Emoji Emoji_Component Emoji_Modifier Emoji_Modifier_Base Emoji_Presentation Extended_Pictographic Extender
Grapheme_Base Grapheme_Extend Hex_Digit ID_Continue ID_Start Ideographic IDS_Binary_Operator IDS_Trinary_Operator
Join_Control Logical_Order_Exception Lowercase Math Noncharacter_Code_Point Pattern_Syntax Pattern_White_Space
Quotation_Mark Radical Regional_Indicator Sentence_Terminal Soft_Dotted Terminal_Punctuation Unified_Ideograph
Uppercase Variation_Selector White_Space XID_Continue XID_Start'''.split())
FILES = ['ReadMe.txt', 'PropertyAliases.txt', 'PropertyValueAliases.txt', 'extracted/DerivedGeneralCategory.txt',
         'DerivedCoreProperties.txt', 'PropList.txt', 'emoji/emoji-data.txt', 'extracted/DerivedBinaryProperties.txt',
         'DerivedNormalizationProps.txt', 'Scripts.txt', 'ScriptExtensions.txt']

def rows(path):
    for line in path.read_text().splitlines():
        line = line.split('#')[0].strip()
        if line:
            yield [part.strip() for part in line.split(';')]

def merge(ranges):
    result = []
    for a, b in sorted(ranges):
        if result and a <= result[-1][1] + 1:
            result[-1] = (result[-1][0], max(b, result[-1][1]))
        else:
            result.append((a, b))
    return result

def complement(ranges):
    result, cursor = [], 0
    for a, b in merge(ranges):
        if a > cursor:
            result.append((cursor, a-1))
        cursor = b+1
    if cursor <= 0x10ffff:
        result.append((cursor, 0x10ffff))
    return result

def subtract(ranges, removed):
    # Development-only interval operations, independent of the runtime matcher.
    result, removed = [], merge(removed)
    for a, b in merge(ranges):
        cursor = a
        for c, d in removed:
            if d < cursor:
                continue
            if c > b:
                break
            if c > cursor:
                result.append((cursor, c-1))
            cursor = max(cursor, d+1)
        if cursor <= b:
            result.append((cursor, b))
    return result

def ranges(path):
    result = {}
    for row in rows(path):
        points = row[0].split('..')
        a, b = int(points[0], 16), int(points[-1], 16)
        result.setdefault(row[1], []).append((a,b))
    return {key: merge(value) for key, value in result.items()}

def generate(root):
    if 'Version 13.0.0' not in (root/'ReadMe.txt').read_text():
        raise ValueError('Expected the fixed Unicode 13.0.0 input')
    tables, aliases = [], {}
    def add(keys, values):
        index = len(tables)
        tables.append(merge(values))
        for key in dict.fromkeys(keys):
            if key in aliases:
                raise ValueError(f'duplicate property alias {key}')
            aliases[key] = index
    categories = ranges(root/'extracted/DerivedGeneralCategory.txt')
    for row in rows(root/'PropertyValueAliases.txt'):
        if row[0] != 'gc':
            continue
        short = row[1]
        if short in categories:
            values = categories[short]
        elif short == 'LC':
            values = sum((categories[key] for key in ['Lu', 'Ll', 'Lt']), [])
        else:
            values = sum((v for key, v in categories.items() if key.startswith(short)), [])
        assert values, short
        names = row[1:]
        add(names + [f'{prefix}={name}' for prefix in ['gc', 'General_Category'] for name in names], values)
    binary = {'ASCII': [(0,127)], 'Any': [(0,0x10ffff)], 'Assigned': complement(categories['Cn'])}
    for file in FILES[4:9]:
        for key, values in ranges(root/file).items():
            if key in BINARY:
                if key in binary:
                    raise ValueError(f'multiple input definitions for {key}')
                binary[key] = values
    assert set(binary) == BINARY, BINARY-set(binary)
    property_aliases = {}
    for row in rows(root/'PropertyAliases.txt'):
        if row[1] in BINARY:
            property_aliases[row[1]] = row
    for key in sorted(BINARY):
        add(property_aliases.get(key, [key]), binary[key])
    scripts = ranges(root/'Scripts.txt')
    scripts['Unknown'] = complement(sum(scripts.values(), []))
    extended, replaced = {}, []
    for key, values in ranges(root/'ScriptExtensions.txt').items():
        replaced.extend(values)
        for alias in key.split():
            extended.setdefault(alias, []).extend(values)
    for row in rows(root/'PropertyValueAliases.txt'):
        if row[0] != 'sc':
            continue
        short, long = row[1:3]
        values = scripts.get(long, [])
        add([f'{prefix}={name}' for prefix in ['sc', 'Script'] for name in row[1:]], values)
        values = subtract(values, replaced) + extended.get(short, [])
        add([f'{prefix}={name}' for prefix in ['scx', 'Script_Extensions'] for name in row[1:]], values)
    code = ['// SPDX-License-Identifier: Apache-2.0 AND Unicode-3.0',
            '// Generated by Scripts/generate_regex_unicode.py; do not edit.',
            '// Unicode data copyright © 2020 Unicode, Inc. License: Licenses/Unicode-3.0.txt.',
            'import JSON', 'package enum RegexUnicodeTables {', '    package static let version = "13.0.0"',
            '    private static let aliases: [(String, Int)] = [']
    for name, index in sorted(aliases.items()):
        code.append(f'        ("{name}", {index}),')
    code += ['    ]', '    private static let tables: [[UInt32]] = [']
    for values in tables:
        flat = [v for item in values for v in item]
        code.append('        [' + ','.join(hex(value) for value in flat) + '],')
    code += ['    ]', '''    package static func resolve(_ name: String, meter: inout JSONWorkMeter) throws -> Int? {
        var lo = 0, hi = aliases.count
        while lo < hi {
            try RegexBudget.compileStep(meter: &meter)
            let mid = lo + (hi-lo)/2
            var a = name.utf8.makeIterator(), b = aliases[mid].0.utf8.makeIterator(), order = 0
            while true {
                try RegexBudget.compileStep(meter: &meter)
                let x = a.next(), y = b.next()
                if x == nil || y == nil { order = x == y ? 0 : (x == nil ? -1 : 1); break }
                if x != y { order = x! < y! ? -1 : 1; break }
            }
            if order == 0 { return aliases[mid].1 }
            if order < 0 { hi = mid } else { lo = mid+1 }
        }
        return nil
    }
    package static func contains(_ id: Int, _ scalar: UInt32, compiling: Bool = false, meter: inout JSONWorkMeter) throws -> Bool {
        let ranges = tables[id]
        var lo = 0, hi = ranges.count/2
        while lo < hi {
            if compiling { try RegexBudget.compileStep(meter: &meter) } else { try RegexBudget.searchStep(meter: &meter) }
            let mid = lo + (hi-lo)/2
            if scalar < ranges[mid*2] { hi = mid }
            else if scalar > ranges[mid*2+1] { lo = mid+1 }
            else { return true }
        }
        return false
    }
}''']
    return ('\n'.join(code)+'\n').encode(), tables, aliases

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input', type=Path)
    parser.add_argument('--output', type=Path, default=Path('Sources/JSONRegexRuntime/RegexUnicodeTables.swift'))
    parser.add_argument('--receipt', type=Path, default=Path('Documentation/Qualification/UnicodeProvenance.json'))
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    code, tables, aliases = generate(args.input)
    if args.check:
        if args.output.read_bytes() != code:
            raise SystemExit('Generated tables differ from checked-in output')
    else:
        args.output.write_bytes(code)
    digest = lambda data: hashlib.sha256(data).hexdigest()
    inputs = [{'path': file, 'bytes': (args.input/file).stat().st_size, 'sha256': digest((args.input/file).read_bytes())} for file in FILES]
    receipt = {'version': 1, 'unicode_version': '13.0.0', 'ecmascript_edition': 11,
               'source_url': 'https://www.unicode.org/Public/zipped/13.0.0/UCD.zip',
               'archive_sha256': digest((args.input/'UCD.zip').read_bytes()), 'inputs': inputs,
               'generator': str(Path(__file__).relative_to(Path.cwd())), 'generator_sha256': digest(Path(__file__).read_bytes()),
               'license': 'Unicode-3.0', 'license_path': 'Licenses/Unicode-3.0.txt',
               'license_sha256': digest(Path('Licenses/Unicode-3.0.txt').read_bytes()),
               'output': str(args.output), 'output_sha256': digest(code), 'output_bytes': len(code),
               'tables': len(tables), 'aliases': len(aliases), 'ranges': sum(map(len,tables)),
               'policy': 'Exact case-sensitive ECMA property aliases. Script_Extensions overrides Script defaults; host Unicode APIs unused.'}
    if args.check:
        recorded = json.loads(args.receipt.read_text())
        if recorded != receipt:
            raise SystemExit("Unicode provenance differs from the pinned receipt")
    if not args.check:
        args.receipt.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'tables': len(tables), 'aliases': len(aliases), 'ranges': sum(map(len,tables)), 'sha256': digest(code), 'regeneration_equal': args.check}))
if __name__ == '__main__':
    main()
