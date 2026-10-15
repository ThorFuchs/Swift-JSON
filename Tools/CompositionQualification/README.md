# Independent public composition consumer

Swift 6.4 / language 6; imports only normal public JSON and JSONSchema products.
The root package dependency graph stays empty. Tests do not use @testable, SPI,
private meter shims or package-name impersonation. The dependency's explicit
SwiftPM display name is unrelated to package-access identity.

Run from the repository root:

```sh
python3 Scripts/ci.py --lane composition
```

This executes 24 Swift Testing functions in Debug and Release, checks exact raw
Swift Testing events and the golden owned-event TSV, runs the same positive test
with two missing-charge mutations expecting real assertion failures, then builds
13 unrelated negative consumer packages. A wrong import/dependency or compiler
crash is not an accepted negative outcome. Logs preserve diagnostics and hashes.

`CompositionProbe` is a compile-only ordinary public consumer suitable for Apple
SDK and Linux cross-build probes. `Negative/*.swift.txt` are fixtures compiled as
separate ordinary SwiftPM executable packages, not included in passing targets.

Apple Swift 6.4.0.34.1 has a SIL-generation crash for a nested local function
capturing the borrowed scope. Explicit borrowed helper parameters compile; the
positive consumer uses that shape. No unsafe annotations or compiler flags are
needed. Platform receipts and the captured crash are reported with the handoff.
