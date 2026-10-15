// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema

/// Synthetic, bounded input; never an application or protocol conformance claim.
public struct ReferenceFixture: Sendable {
    public let definitions: Int
    public let references: Int
    public let data: Data

    public init(definitions: Int, references: Int, missingLast: Bool = false) {
        precondition((1...1024).contains(definitions) && (1...1024).contains(references))
        self.definitions = definitions
        self.references = references
        let entries = (0..<definitions).map {
            "\"schema\($0)\":{\"n\":9007199254740993,\"decimal\":0.0100,\"é\":true,\"e\\u0301\":false}"
        }.joined(separator: ",")
        let keys = ["n", "decimal", "%C3%A9", "e%CC%81"]
        let refs = (0..<references).map { index in
            let key = missingLast && index == references - 1 ? "missing" : "schema\(index % definitions)"
            return "{\"$ref\":\"#/$defs/\(key)/\(keys[index % 4])\"}"
        }.joined(separator: ",")
        data = Data("{\"$defs\":{\(entries)},\"refs\":[\(refs)]}".utf8)
    }

    /// Caller-owned independent exact oracle, outside the composition's ledger.
    public func expectedSelections() throws -> [JSON] {
        let values: [JSON] = [
            .number(try JSONNumber(parsing: "9007199254740993")),
            .number(try JSONNumber(parsing: "0.0100")), .boolean(true), .boolean(false)
        ]
        return (0..<references).map { values[$0 % 4] }
    }
}

/// Caller progress is not a partial native statistics report.
public struct ImportProgress: Sendable {
    public var completedReferences = 0
    public init() {}
}

public enum ReferenceStrategy: String, Sendable {
    case perReferenceRoot, stagedReferenceArray
}

/// A public-API-only adapter with explicit monotone logical storage declarations.
public func importReferences(_ fixture: ReferenceFixture, scope: borrowing JSONCompositionScope,
                             progress: inout ImportProgress, cancelAt: Int? = nil,
                             strategy: ReferenceStrategy = .perReferenceRoot) throws -> [JSON] {
    // Adapter frame and output slots are declared logical weights, not heap/RSS.
    try scope.reserveExternalLogicalBytes(64)
    try scope.reserveExternalLogicalBytes(16, count: UInt64(fixture.references))
    let document = try scope.parseDocument(fixture.data)
    let base = try scope.uri("https://example.invalid/resources/document.json")
    let descriptorRoot: JSON
    if strategy == .stagedReferenceArray {
        try scope.reserveExternalLogicalBytes(16) // One input token slot, before construction.
        try scope.chargeExternalWork(1)
        descriptorRoot = try scope.resolve(scope.pointer(tokens: ["refs"]), in: document.root)
    } else {
        descriptorRoot = document.root
    }
    var selections: [JSON] = []
    selections.reserveCapacity(fixture.references)
    for index in 0..<fixture.references {
        if index == cancelAt { withUnsafeCurrentTask { $0?.cancel() } }
        try scope.checkpoint()
        // At most 20 index-text bytes + three 16-byte input token slots.
        // Both strategies use this conservative descriptor bound.
        try scope.chargeExternalWork(20)
        try scope.reserveExternalLogicalBytes(68)
        let location = try scope.pointer(tokens: strategy == .stagedReferenceArray
            ? [String(index), "$ref"] : ["refs", String(index), "$ref"])
        let raw = try scope.resolve(location, in: descriptorRoot)
        guard let fragment = raw.stringValue else { throw FixtureFailure.wrongReferenceKind }
        let uri = try scope.uri(fragment, relativeTo: base)
        _ = try scope.removingFragment(uri)
        let pointer = try scope.pointer(uriFragment: fragment)
        let selected = try scope.resolve(pointer, in: document.root)
        try scope.chargeExternalWork(1)
        selections.append(selected)
        progress.completedReferences += 1
    }
    return selections
}

public enum FixtureFailure: Error { case wrongReferenceKind }
