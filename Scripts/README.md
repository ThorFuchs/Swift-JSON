# Development tools

Python 3 standard-library tools, run from the repository root. Tool packages are
separate from the dependency-free library. Native lanes fail on unsupported hosts.

| Command | Purpose |
| --- | --- |
| `python3 Scripts/public_check.py` | Public inventory, links, baseline and finite profiles |
| `python3 Scripts/preflight.py` | Actual native OS/compiler/SDK receipt |
| `python3 Scripts/ci.py --lane native` | Manifests, builds, Swift Testing, consumers and suites |
| `python3 Scripts/ci.py --lane safety` | Address/Thread Sanitizer and strict memory safety |
| `python3 Scripts/ci.py --lane linux` | Actual Linux preflight, all four products, exact root/cap/corpus/consumer counts |
| `python3 Scripts/ci.py --lane linux-safety` | Linux Address/Thread Sanitizer and strict memory safety |
| `python3 Scripts/qualify_linux_reproduction.py --output PATH` | Actual source archive, byte-equal rebuild, clean extraction, build/tests and public consumer |
| `python3 Scripts/ci.py --lane docs` | Four DocC catalogs, authored API/parameter coverage, executed README examples and verified static Pages site |
| `python3 Scripts/build_documentation_site.py` | Transform already-qualified DocC archives and verify static routes/assets |
| `python3 Scripts/qualification_watchdog.py --timeout 900 --output PATH -- COMMAND` | Process-group timeout and native receipt |
| `python3 Scripts/archive_candidate.py --output PATH` | Public source archive with exact hashes and byte-equal rebuild |

Fixture import and Unicode/schema generators retain pinned input hashes and
licenses. They neither publish nor introduce runtime network resolution.
Receipts go to `.build/ci/` and GitHub Actions artifacts. Private local records
and original frozen archives stay in ignored `Artifacts/`.
