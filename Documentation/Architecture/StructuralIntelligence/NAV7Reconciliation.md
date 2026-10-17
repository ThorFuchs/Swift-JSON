# NAV7 current-main integration proposal

This isolated N2 proposal replays the reviewed NAV6 N2 delta (37d84e8 relative to
c79d48c) onto main f975ac1, preserving #39 schema examples, #44 DocC navigation
indexes and #45 version 1.6.0 release metadata. Original #41/#42/#43 branches and
NAV6 candidates remain unchanged. No N3 snapshot or P1 projection source enters
this N2 branch; all merge, ready, tag and release decisions remain owner gates.

JSONInspection retains44 authored declarations and JSONNavigation56. Native,
Linux and WASI test identities and the original exclusive-inout reducer are
unchanged. All49 capacity probes and126 maintenance identities remain enforced.
Current main has eight public libraries plus CLI; this proposal adds Inspection
as the ninth library. Root dependencies remain empty.

DocC integration retains all four #44 files and twelve guide-index regression
cases. The existing source-to-HTML guide routes, per-product byte-identical
navigator aliases and verification functions remain. Only Inspection's catalogue,
guide entry and descriptions are added. Archive catalogue count is derived from
the actual product list. The independent site regression and complete native docs
lane must pass on this source; historical status is comparison evidence only.

README preserves main's release notes while explicitly labeling Inspection an
unreleased candidate. CLI release version remains1.6.0; its generated source hash
is refreshed from this exact manifest and source. Native, Linux, safety, external
consumer, compiler-negative, WASI/WasmKit, mobile SDK and Git-free receipts are
bound to the final candidate in the private NAV7 return. This document does not
claim results before execution or change any historical receipt.
