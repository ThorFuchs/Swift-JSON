// SPDX-License-Identifier: Apache-2.0
// Development differential oracle only. Never used by the production library.
import fs from 'node:fs';
import crypto from 'node:crypto';
const atoms = ['a','b','.','a?','a*','a+','a??','a*?','a+?','a{0,2}','a{1,3}?','(a)','(a*)','(a|b)','(a|aa)','(a?)','(?:)','(a|)'];
const patterns = new Set();
for (const a of atoms) for (const b of atoms) patterns.add(`^${a}${b}$`);
for (const a of atoms) {
  patterns.add(`^(?:${a})+$`);
  patterns.add(`^(?:${a})*b$`);
  patterns.add(`(?<=${a})b`);
  patterns.add(`(?<!${a})b`);
  patterns.add(`^(?=${a})a*b$`);
  patterns.add(`^(?!${a})a*b$`);
}
for (const pattern of [String.raw`^(a|b)+\1$`, String.raw`^(a|(b))+\1\2$`, String.raw`^(a*?)(b*)\1\2$`,
  String.raw`^(?=(a+))a*b\1$`, String.raw`(?<=([ab]+)([bc]+))\1\2$`, String.raw`(?<=\1(a))b`,
  String.raw`(?<=(a)\1)b`, String.raw`(?<!(a))b\1`, String.raw`^((a)?)*\2$`, String.raw`^((a)?)+\2$`]) patterns.add(pattern);
const subjects = ['', 'é', 'é', '𝄞', 'a𝄞b', '\n', '\r', '\u2028', 'ab\n', 'aba\u2028'];
for (let size=1; size<=5; size++) for (let bits=0; bits < 2**size; bits++) {
  let value=''; for (let j=0;j<size;j++) value += bits & (1<<j) ? 'a' : 'b'; subjects.push(value);
}
const vectors = [...patterns].sort().map(pattern => {
  const engine = new RegExp(pattern,'u');
  return {pattern, cases: subjects.map(subject => ({subject, expected: engine.test(subject)}))};
});
const output = JSON.stringify(vectors)+'\n';
fs.writeFileSync('Tests/Fixtures/Regex/differential.json', output);
const receipt = {version:1, engine:'Node.js RegExp', node:process.version, v8:process.versions.v8, unicode:process.versions.unicode,
  flags:'u', policy:'Deterministic scalar grammar combinations; property-version differences excluded from this differential oracle.',
  pattern_count:vectors.length, case_count:vectors.reduce((n,v)=>n+v.cases.length,0),
  generator_sha256:crypto.createHash('sha256').update(fs.readFileSync('Tools/RegexQualification/generate.mjs')).digest('hex'),
  fixture:'Tests/Fixtures/Regex/differential.json', fixture_sha256:crypto.createHash('sha256').update(output).digest('hex')};
fs.writeFileSync('Tests/Fixtures/Regex/DifferentialProvenance.json', JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify(receipt));
