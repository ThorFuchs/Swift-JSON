# External inspection consumer

Run `python3 -B Scripts/qualify_inspection.py --output .build/ci/inspection-consumer`.
The separate SwiftPM package imports public products without @testable. Twelve
named outcomes run in Debug/Release; the same source runs under ASan. Three DocC
examples compile and run in each configuration, and ordinary compiler errors prove
core-only import and package-capability isolation. I01-I17 remain the root tests.
