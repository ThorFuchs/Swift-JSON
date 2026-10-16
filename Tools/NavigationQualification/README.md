# External Navigation consumer

This separate SwiftPM package resolves JSONNavigation through its real library product,
using the exact source checkout as a path dependency. Run `swift run --package-path
Tools/NavigationQualification NavigationConsumer` and repeat with `-c release`.
The executable checks 18 named exact path/value/coverage/resource outcomes. The
repository compiler lane also checks import/package/cursor isolation and executes
the three public DocC guide examples. No package-scoped meter is imported here.
