// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

// Public consumer of the exact scale case from the independent review. Input
// construction belongs to the caller; all owned admission and lookups share scope.
let value = JSON.array(Array(repeating: .null, count: 50_000))
let data = Data(("[" + Array(repeating: "null", count: 50_000).joined(separator: ",") + "]").utf8)
func lookups(_ scope: borrowing JSONCompositionScope, _ root: borrowing JSONCompositionRoot,
             _ pointer: JSONPointer) throws -> Int {
    for _ in 0..<1_000 {
        let selected = try scope.resolve(pointer, in: root)
        precondition(selected == .null)
    }
    return 1_000
}
for parsed in [false, true] {
    let report = try JSON.withComposition { scope in
        let pointer = try scope.pointer(tokens: ["0"])
        if parsed {
            return try scope.withParsedDocument(data) { document, root in
                precondition(document.sourceBytes == data)
                return try lookups(scope, root, pointer)
            }
        }
        return try scope.withAdmittedRoot(value) { root in try lookups(scope, root, pointer) }
    }
    precondition(report.result == 1_000)
    precondition(report.statistics[.nodes] == 51_001)
    precondition(report.statistics[.workUnits] < 1_000_000)
    precondition(report.statistics[.retainedBytes] < 6_000_000)
    print("ADMITTED_ROOT_SCALE path=\(parsed ? "parsed" : "trusted") items=50000 bytes=\(data.count) refs=1000 nodes=\(report.statistics[.nodes]) work=\(report.statistics[.workUnits]) retained=\(report.statistics[.retainedBytes]) peak=\(report.statistics.peakLogicalRetainedBytes)")
}
