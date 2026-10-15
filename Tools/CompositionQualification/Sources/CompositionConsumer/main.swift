// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema

// This target is a distinct SwiftPM package: no package/private meter access.
let data = Data(#"{"é":true,"e\u0301":false,"n":9007199254740993,"fraction":0.01}"#.utf8)
func run(_ limits: JSONLimits = .balanced, extra: UInt64 = 0) throws -> JSONOperationReport<JSONDocument> {
    try JSON.withComposition(limits: limits) { scope in
        let document = try scope.parseDocument(data)
        _ = try scope.admitTrusted(.null)
        try scope.reserveExternalLogicalBytes(64, count: 2)
        try scope.chargeExternalWork(5 + extra)
        let pointer = try scope.pointer(tokens: [])
        let count = try scope.appending(pointer, key: "n")
        let selected = try scope.resolve(count, in: document.root)
        precondition(selected.numberValue?.originalLexeme == "9007199254740993")
        let fragment = try scope.pointer(uriFragment: "#/%C3%A9")
        let flag = try scope.resolve(fragment, in: document.root)
        precondition(flag == true)
        _ = try scope.pointer(parsing: "/fraction")
        let base = try scope.uri("https://EXAMPLE.invalid/a/../api.json#part")
        let relative = try scope.uri("schemas.json#/n", relativeTo: base)
        let resource = try scope.removingFragment(relative)
        precondition(resource.string == "https://example.invalid/schemas.json")
        try scope.checkpoint()
        try scope.restrict(to: limits)
        return document
    }
}
let probe = try run()
precondition(probe.result.sourceBytes == data)
precondition(probe.statistics[.numericWorkUnits] > 0)
precondition(probe.statistics[.compiledPlanBytes] == 0)
var exact = JSONLimits.balanced
exact[.workUnits] = probe.statistics[.workUnits]
exact[.retainedBytes] = probe.statistics.peakLogicalRetainedBytes
let repeated = try run(exact)
precondition(repeated.statistics == probe.statistics)
var negativeCount = 0
for mode in 0..<3 {
    var limits = exact
    if mode == 0 { limits[.workUnits] -= 1 }
    if mode == 1 { limits[.retainedBytes] -= 1 }
    do { _ = try run(limits, extra: mode == 2 ? 1 : 0); fatalError("unbounded composition") }
    catch let failure as JSONFailure { precondition(failure.category == .resource); negativeCount += 1 }
}
var zero = JSONLimits.balanced
zero[.workUnits] = 0
 do {
    _ = try JSON.withComposition(limits: zero) { scope in
        do { try scope.chargeExternalWork(1) } catch { }
        return 1
    }
    fatalError("caught native failure finalized")
} catch let failure as JSONFailure { precondition(failure.category == .resource); negativeCount += 1 }
let rooted = try JSON.withComposition { scope in
    try scope.withParsedDocument(data) { document, root in
        let pointer = try scope.pointer(tokens: ["n"])
        for _ in 0..<100 {
            let selected = try scope.resolve(pointer, in: root)
            precondition(selected.numberValue?.originalLexeme == "9007199254740993")
        }
        return document
    }
}
precondition(rooted.result.sourceBytes == data)
let trusted = try JSON.withComposition { scope in
    try scope.withAdmittedRoot(.array([true])) { root in
        try scope.resolve(scope.pointer(tokens: ["0"]), in: root)
    }
}
precondition(trusted.result == true)
for wrongOwner in [false, true] {
    do {
        _ = try JSON.withComposition { scope in
            try scope.withAdmittedRoot(.array([true])) { root in
                let pointer = try scope.pointer(tokens: [wrongOwner ? "0" : "9"])
                if wrongOwner {
                    return try JSON.withComposition { other in
                        do { _ = try other.resolve(pointer, in: root) } catch { }
                        return 0
                    }.result
                }
                do { _ = try scope.resolve(pointer, in: root) } catch { }
                return 0
            }
        }
        fatalError("invalid admitted-root operation finalized")
    } catch is JSONFailure { negativeCount += 1 }
}
print("COMPOSITION_CONSUMER passed positive=4 negative=\(negativeCount) work=\(probe.statistics[.workUnits]) peak=\(probe.statistics.peakLogicalRetainedBytes) version=\(probe.statistics.accountingVersion)")
