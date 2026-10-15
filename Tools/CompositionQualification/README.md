# Independent public composition consumer

Swift 6.4 / language 6; imports only normal public JSON and JSONSchema products.
The root package dependency graph stays empty. Tests do not use @testable, SPI,
private meter shims or package-name impersonation. The dependency's explicit
SwiftPM display name is unrelated to package-access identity.

Run from the repository root:

```sh
python3 Scripts/ci.py --lane composition
```

This executes 26 Swift Testing functions in Debug and Release, checks exact raw
Swift Testing events and the golden owned-event TSV, runs the same positive test
with two missing-charge mutations expecting real assertion failures, then builds
14 unrelated negative consumer packages. A wrong import/dependency or compiler
crash is not an accepted negative outcome. Logs preserve diagnostics and hashes.

`CompositionProbe` is a compile-only ordinary public consumer suitable for Apple
SDK and Linux cross-build probes. `Negative/*.swift.txt` are fixtures compiled as
separate ordinary SwiftPM executable packages, not included in passing targets.

Apple Swift 6.4.0.34.1 and Swift.org 6.4 have a SIL-generation crash for a nested
local function capturing an inferred borrowed scope parameter. Explicitly annotate
`(scope: borrowing JSONCompositionScope)` to compile the nested synchronous helper.
The public tests qualify this form; explicit borrowed helper parameters also compile. No unsafe annotations or compiler flags are
needed. Platform receipts and the captured crash are reported with the handoff.

The direct escaping-closure capture shape also crashes the observed 6.4 compiler
during SIL ownership verification (`Have operand with incompatible ownership?!`,
`copy_addr`). It is preserved under `CompilerBugs` and in failed exploratory
receipts; it is not counted as an intended compiler-negative pass. The negative
escape probe instead attempts to return an escaping closure from an explicit
borrowed-parameter helper and requires a normal ownership diagnostic. These
compiler defects remain usability/qualification limitations, not runtime passes.

Forming a bound method reference also triggers the same observed SIL verifier
crash, both directly and through a borrowed helper. Those two reproducers are
retained separately as compiler limitations. Call an explicit borrowed helper
instead of forming a method value. The return probe uses explicit `return`; an
unused noncopyable expression can infer Void and does not attempt escape.
The storage probe explicitly consumes to test the borrowed-value restriction.

Run the same proof on the supported Ubuntu/glibc runtime with
`python3 Scripts/ci.py --lane linux-composition`. The matching Swift.org 6.4.0
static Linux SDK can compile `CompositionProbe` and link `CompositionBenchmark`
for ARM64 and x86_64. That SDK lacks the Testing module; these cross-builds do not
replace actual Linux behavior/sanitizer execution. See CompilerBugs/README.md for
standalone reductions and the replay command returning 2 on observed crashes.
