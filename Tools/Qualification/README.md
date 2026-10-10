# Public independent qualification

Run from the repository root on the supported native baseline:

```sh
swift run -c release --package-path Tools/Qualification Qualification --all --registry Documentation/Qualification/FixtureRegistry.json --output .build/handoff/qualification.json
```

The runner imports only the four public products. It verifies suite identities,
file SHA-256/size, original license presence and populated discovery counts.
Every syntax/schema case has a recorded outcome. Schema resources come from
an explicit per-group local registry; there is no runtime network fetch.

Syntax policies cover implementation-defined inputs, exact duplicate keys and
the two named excessive-depth fixtures. Resource exhaustion remains an
operational policy outcome rather than ordinary syntax invalidity. The schema
ledger identifies 37 historic/legacy optional extension cases individually;
all 2337 cases are discovered and all supported 2300 cases are evaluated.
Optional format assertions use a separate explicit mode.

The same run executes authored exact-value/Pointer/Patch/Merge Patch/writer/
completion vectors, public budget/report checks and fixed-seed malformed UTF-8
stream/native replay. Unexpected operational errors, absent fixtures, zero
cases, orphan resource/policy entries and hash mismatches fail the tool.

`Scripts/qualification_watchdog.py` runs this or another native command under
an external deadline, kills the process group on non-progress and records
compiler/SDK/environment, command, exit status and output hash. A successful
runner is one gate; safety lanes, full native tests and release review remain
separate requirements.
