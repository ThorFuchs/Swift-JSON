# Enrichment fixtures and gold cases

The root enrichment-registry.json pins nine initial input/case-set/raster files. These are handoff fixtures, not execution reports. All inline/math cases and 88 combined scenarios remain not_run.

- colors.json: strict valid/invalid color strings and ambiguous/explicit channel examples.
- strings.json: 511/512/513 source boundaries, astral/combining/control expansion, cutoff spans and TAIL_SENTINEL for full-source access.
- inline-cases.json: 32 supported/protected/unsupported/unsafe inline examples; source is never code.
- math-cases.json: 18 hand-authored successful MathML trees and 27 literal-fallback interiors. A test harness wraps interiors in accepted inline delimiters and checks complete original-span fallback. Tree wrappers may only be canonicalized by an explicitly recorded equivalent policy.
- base64-cases.json: 16 canonical/negative encoding vectors. Empty base64 is valid binary encoding but not an eligible image.
- media.json: declared/unhinted/dataURI/MIME mismatch/unsafe/inline sources and a typed declaration example.
- sample.png and sample.jpg: original deterministic 4×4 raster fixtures, generated with Pillow 12.3.0.
- oversized-header.png: intentionally unusable PNG header with 100000×100000 dimensions, for native eligibility rejection before any raster decode. Do not hand it to an image decoder as a valid sample.

Fixtures are original supplements to the repo's pinned independent tests. They do not replace conformance fixtures or baseline counts. The integrity script checks byte identities, XML structure, canonical vector consistency and the two small image headers; it does not execute a native formatter/parser/decoder or browser.

Delimiter edge cases are in inline-cases; math-cases contains interiors. For negative math, preserving exact source means preserving the original delimiters as well when rendered through the public pipeline. Include actual native tests for work/cancellation/quotas, no-source mutation, script-free full-source access and complete versus inspection print policies.
