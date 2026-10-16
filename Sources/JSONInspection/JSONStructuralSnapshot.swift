// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Experimental metadata only; ordinal identity is local to one snapshot.
package struct JSONStructuralRecord: Sendable {
    package let ordinal: Int
    package let parentOrdinal: Int?
    package let componentFromParent: JSONLocationComponent?
    package let kind: JSONTraversalKind
    package let depth: Int
    package let childCount: Int
    package internal(set) var subtreeEndExclusive: Int
}

package enum JSONStructuralSnapshotFailure: Error, Sendable, Equatable {
    case recordLimitExceeded(limit: Int)
    case ordinalOutOfBounds(Int)
}

/// One complete physical source and compact immutable parent-linked metadata.
/// No detached handle or caller-supplied document can rebind its ordinals.
package struct JSONStructuralSnapshot: Sendable {
    package let document: JSONDocument
    private let records: [JSONStructuralRecord]
    package var recordCount: Int { records.count }
    fileprivate init(document: JSONDocument, records: [JSONStructuralRecord]) {
        self.document = document; self.records = records
    }

    /// Constant bounded metadata access. No path/value scan or allocation.
    package func record(at ordinal: Int) throws -> JSONStructuralRecord {
        guard ordinal >= 0, ordinal < records.count else {
            throw JSONStructuralSnapshotFailure.ordinalOutOfBounds(ordinal)
        }
        return records[ordinal]
    }

    /// Separate owned lookup; all parent-chain and path work uses its own scope.
    package func location(for ordinal: Int, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<[JSONLocationComponent]> {
        try lookup(ordinal, limits: limits) { path, state, _ in
            // Output path ownership survives scope completion's temporary refund.
            for part in path {
                try state.meter.work(); try state.meter.retain(JSONLogicalWeights.indexSlot)
                if case .key(let key) = part {
                    for _ in key.string.utf8 { try state.meter.work(); try state.meter.retain(1) }
                }
            }
            return path
        }
    }

    /// Resolve only against this captured source, using the core strict selector.
    /// Returned JSON follows existing read-value alias semantics, not a copied DOM.
    package func value(for ordinal: Int, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSON> {
        try lookup(ordinal, limits: limits) { path, state, scope in
            try state.meter.work()
            return try scope.select(path, state: state)
        }
    }

    package func sourceSpan(for ordinal: Int, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSONSourceSpan?> {
        try lookup(ordinal, limits: limits) { path, state, _ in
            try document.sourceMap?.span(at: path, kind: .value, meter: &state.meter)
        }
    }

    private func lookup<Result>(_ ordinal: Int, limits: JSONLimits,
                                _ body: ([JSONLocationComponent], JSONCodingState, JSONReadScope) throws -> Result)
        throws -> JSONOperationReport<Result> {
        // Invalid ordinals precede admission; never a null/missing default.
        _ = try record(at: ordinal)
        let scope = try JSONReadScope(document, limits: limits)
        defer { scope.invalidate() }
        let state = try scope.check()
        var reversed: [JSONLocationComponent] = [], temporary: UInt64 = 0
        var current = ordinal
        while let parent = records[current].parentOrdinal {
            try state.meter.work()
            guard parent >= 0, parent < current, let component = records[current].componentFromParent else {
                throw JSONFailure(.configuration, code: .invalidOperation)
            }
            try state.meter.retain(JSONLogicalWeights.indexSlot)
            temporary = try state.meter.adding(.retainedBytes, temporary, JSONLogicalWeights.indexSlot)
            if case .key(let key) = component {
                for _ in key.string.utf8 {
                    try state.meter.work(); try state.meter.retain(1)
                    temporary = try state.meter.adding(.retainedBytes, temporary, 1)
                }
            }
            reversed.append(component); current = parent
        }
        var path = JSONReadPath(scope: scope, components: [], bytes: 0)
        for component in reversed.reversed() {
            try state.meter.work()
            path = try scope.append(component, to: path.components, state: state)
            _ = try scope.check()
        }
        reversed = []; try state.meter.release(temporary)
        return try scope.complete(scope.run(path.components) { try body(path.components, $0, scope) })
    }
}

/// Complete physical-root only; no filter, prune, prefix or custom callback.
package struct JSONStructuralSnapshotBuilder: Sendable {
    package let document: JSONDocument
    package let limits: JSONLimits
    package var checkpointObserver: (@Sendable (UInt64) -> Void)?
    package var lifetimeObserver: (@Sendable (Bool, Bool) -> Void)?
    package init(document: JSONDocument, limits: JSONLimits = .balanced) {
        self.document = document; self.limits = limits
    }
    package func build(maximumRecords: Int = 100_000)
        throws -> JSONOperationReport<JSONStructuralSnapshot> {
        guard maximumRecords >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        var reducer = SnapshotReducer(maximumRecords: maximumRecords)
        var traversal = JSONTraversal(document: document, limits: limits)
        traversal.checkpointObserver = checkpointObserver
        traversal.lifetimeObserver = lifetimeObserver
        return try traversal.inspectOwned(reducer: &reducer)
    }
}

/// Logical overlay v1: 128 fixed, 96/record + exact key bytes, 16/open frame.
private struct SnapshotReducer: JSONTraversalOwnedReducer {
    let maximumRecords: Int
    var records: [JSONStructuralRecord] = []
    var open: [Int] = []

    mutating func close(_ end: Int, context: inout JSONTraversalContext) throws {
        try context.work()
        guard let ordinal = open.last, ordinal < end else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        records[ordinal].subtreeEndExclusive = end
        open.removeLast(); try context.release(16)
    }

    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work()
        let ordinal = records.count, depth = hit.relativeDepth
        while open.count > depth { try close(ordinal, context: &context) }
        guard open.count == depth, ordinal < maximumRecords else {
            if ordinal >= maximumRecords { throw JSONStructuralSnapshotFailure.recordLimitExceeded(limit: maximumRecords) }
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        if ordinal == 0 { try context.retain(128) }
        let component = depth == 0 ? nil : hit.absoluteLocation.last
        guard (depth == 0) == (component == nil) else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        try context.retain(96)
        if case .key(let key) = component { try context.retainKey(key) }
        let childCount: Int
        switch value { case .object(let o): childCount = o.count; case .array(let a): childCount = a.count; default: childCount = 0 }
        records.append(.init(ordinal: ordinal, parentOrdinal: open.last, componentFromParent: component,
            kind: hit.kind, depth: depth, childCount: childCount, subtreeEndExclusive: 0))
        try context.retain(16); open.append(ordinal)
        return .continue
    }

    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONStructuralSnapshot {
        guard summary.completion == .complete,
              summary.visitedCount == UInt64(records.count),
              summary.emittedCount == UInt64(records.count), !records.isEmpty else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        while !open.isEmpty { try close(records.count, context: &context) }
        let document = try context.transferDocumentOwnership()
        let result = JSONStructuralSnapshot(document: document, records: records)
        records = []
        return result
    }
}
