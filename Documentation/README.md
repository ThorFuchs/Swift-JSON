# Documentation

Four public products require Swift 6.4+, Swift language mode 6 and macOS/SDK 27+.

- [API and value coding](Architecture/API.md)
- [Exact numbers and scalar identity](Architecture/NumbersAndUnicode.md)
- [Finite resource limits](Architecture/ResourceLimits.md) and [profile values](Architecture/ResourceProfiles.json)
- [Schema dialect and private regex](Architecture/SchemaAndRegex.md)
- [Streaming and completion](Architecture/Streaming.md)
- [Patch and Merge Patch](Architecture/Patch.md)
- [Concurrency and ownership](Architecture/Concurrency.md)
- [Public consumer interface](ConsumerInterface.md)
- [Qualification and suite policy](Qualification/README.md)
- [Native CI](CI/README.md)
- [Performance and selected optimizations](Performance/README.md)
- [Adaptation provenance](Architecture/ExtractionManifest.json) and [upstream pins](Architecture/UpstreamPins.json)

Each public product also has a DocC catalog under Sources. Compile them with
`python3 Scripts/ci.py --lane docs`; warnings are errors.
