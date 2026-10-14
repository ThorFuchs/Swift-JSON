# Third-party provenance

The root LICENSE covers original Swift-JSON code and contributions. It does not
replace applicable licenses on adapted source, data or qualification fixtures.

| Material | Distribution and license |
| --- | --- |
| RhoePlatform/RhoeJSON, commit 51d37acc137422065b07ebeb7e4ecdb2d02b99ee | Selected API/concept adaptations; Apache-2.0. Original LICENSE and NOTICE retained under Licenses/RhoeJSON. The reference clone is not distributed. |
| ridiculousfish/regress, pinned in UpstreamPins.json | Selectively adapted private native regex VM; Apache-2.0 alternative selected, both upstream licenses retained under Licenses. |
| JSONTestSuite and JSON-Schema-Test-Suite | Pinned fixtures and complete upstream licenses under Tests/Fixtures/External. |
| Official Draft 2020-12 meta-schemas | Nine byte-identical resources; BSD-3-Clause alternative selected, complete upstream BSD/AFL license retained. |
| Frozen MCP schema and vectors | Qualification-only consumer, commit c518f7a927cff918bce35d3522fcdb046d264d7c. Full transition license, NOTICE and provenance in Tools/MCPReadiness resources; Apache-2.0/CC-BY-4.0/historical MIT terms are not uniformly relicensed. |
| Unicode 13 data | Regex, NFC/IDNA/UTS46 tables and normalization corpus; Unicode-3.0 notice retained. Input/generator/output hashes in UnicodeProvenance.json and IDNAProvenance.json. |

Actual adaptations are recorded in Documentation/Architecture/ExtractionManifest.json.
Original copyrights and applicable notices remain in the source and license files.
The root package has no third-party runtime dependencies or foreign binary backend.
Research and discarded comparison experiments are not distributed dependencies.

Playwright 1.62.1 is an optional qualification-only development tool (Apache-2.0),
with its full license, NOTICE and third-party notices retained under
Licenses/PlaywrightQualification. No Playwright source or browser binary is adapted
or shipped as a library runtime dependency. The browser tool has its own manifest;
root package dependencies remain empty.


The CLI qualification corpus includes 119 golden and 49 subset cases from
RhoePlatform/RhoeJSON at 51d37acc137422065b07ebeb7e4ecdb2d02b99ee, retained unchanged
in Tests/Fixtures/CLI/Inherited. RhoeJSON contributors retain attribution;
Apache-2.0 text is in Licenses/RhoeJSON-CLI-Fixtures-Apache-2.0.txt. Historical and
planning compatibility labels do not constitute current evaluated successes.
