# Exact projection public consumer

Independent SwiftPM package depending only on the JSON and JSONInspection products.
It imports no package-private scope, meter or SPI. Run on the supported Swift 6.4
native toolchain:

```sh
swift run --package-path Tools/ExactProjectionQualification ExactProjectionConsumer
python3 -B Scripts/qualify_exact_projections.py --output .build/ci/exact-projections
```

The qualifier requires 20 named outcomes in Debug/Release/ASan, three executed DocC
fences per configuration, 24 ordinary external compiler refusals and three deterministic
whole-source access-cost witnesses. These are logical work/retention counters, not
performance measurements. SDK compilation and portable runtime have separate receipts.
The source graph remains opt-in and this candidate does not publish a release.
