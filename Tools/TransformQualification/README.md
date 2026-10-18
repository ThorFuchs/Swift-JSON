# Public transformation consumer

This separate SwiftPM package imports JSON and JSONTransform only. It exercises
11 witnesses: zero/null/multiple results, exact numbers/scalar keys, plan reuse,
compile/language errors, cumulative provider limits, exact bindings, cancellation
and independent concurrent invocations. These are executable assertions, not
full dialect, platform or release qualification.

Run `swift run --package-path Tools/TransformQualification TransformConsumer`.
The private return additionally copies this source into a fresh directory outside
the checkout, changing only its path dependency location.
