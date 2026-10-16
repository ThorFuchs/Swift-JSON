// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Read-only DFS preorder metadata for one physical node in a complete snapshot.
/// Ordinals are local positions in the containing snapshot, not transferable node
/// identities. A record cannot resolve a value or attach to a replacement source.
public struct JSONStructuralRecord: Sendable {
    /// Zero-based preorder position within the containing snapshot.
    public let ordinal: Int
    /// Parent position, strictly lower than this ordinal; nil only for the root.
    public let parentOrdinal: Int?
    /// Exact key or array index from the parent; nil only for the physical root.
    public let componentFromParent: JSONLocationComponent?
    /// Canonical JSON kind; no inferred schema, missing or table kind.
    public let kind: JSONTraversalKind
    /// Number of physical edges from the root, whose depth is zero.
    public let depth: Int
    /// Number of immediate children; a scalar or empty container has zero.
    public let childCount: Int
    /// Finalized exclusive preorder end; this node’s subtree is [ordinal, end).
    public internal(set) var subtreeEndExclusive: Int
}

/// A capacity or local-position refusal; no partial snapshot or null substitute.
public enum JSONStructuralSnapshotFailure: Error, Sendable, Equatable {
    /// The next physical node exceeds the inclusive record bound.
    /// - Parameter limit: Nonnegative maximum configured for this build.
    case recordLimitExceeded(limit: Int)
    /// The supplied local position is outside 0..<recordCount.
    /// - Parameter ordinal: Rejected position, including negative values.
    case ordinalOutOfBounds(Int)
}

/// One complete physical source and compact immutable parent-linked metadata.
/// No detached handle or caller-supplied document can rebind its ordinals.
public struct JSONStructuralSnapshot: Sendable {
    /// Immutable captured source; no operation accepts a replacement document.
    public let document: JSONDocument
    private let records: [JSONStructuralRecord]
    /// Complete number of physical nodes, including the one real root.
    public var recordCount: Int { records.count }
    fileprivate init(document: JSONDocument, records: [JSONStructuralRecord]) {
        self.document = document; self.records = records
    }

    /// Reads one metadata record in O(1), without opening a new resource ledger.
    /// This trusted-memory access performs no path/value scan or owned growth.
    /// - Parameter ordinal: Position local to this snapshot, not a detached node ID.
    /// - Returns: Read-only metadata with a finalized half-open subtree range.
    /// - Throws: `JSONStructuralSnapshotFailure.ordinalOutOfBounds` for an invalid position.
    public func record(at ordinal: Int) throws -> JSONStructuralRecord {
        guard ordinal >= 0, ordinal < records.count else {
            throw JSONStructuralSnapshotFailure.ordinalOutOfBounds(ordinal)
        }
        return records[ordinal]
    }

    /// Reconstructs an exact typed location in a separate bounded operation.
    /// Re-admits the entire captured root/source/map before parent-chain/path work.
    /// Core prefix copying can be quadratic in depth; this is not O(1) lookup.
    /// - Parameters:
    ///   - ordinal: Position local to this snapshot; bounds checked before admission.
    ///   - limits: Finite quotas for this new lookup, independent of construction.
    /// - Returns: Exact key/index path and cumulative lookup statistics; [] is root.
    /// - Throws: Typed bounds, core resource/configuration failures or cancellation.
    public func location(for ordinal: Int, limits: JSONLimits = .balanced)
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

    /// Resolves a value only against the captured source in a new bounded operation.
    /// Each call re-admits the full source and reconstructs its typed path before
    /// core selection. The result uses existing immutable read-value alias semantics;
    /// no JSON subtree is cached in a record or converted through binary floating point.
    /// - Parameters:
    ///   - ordinal: Position local to this snapshot; invalid positions never become null.
    ///   - limits: Finite quotas for this separate lookup, not the builder’s remainder.
    /// - Returns: The canonical value, including explicit null, and lookup statistics.
    /// - Throws: Typed bounds, core access/resource/configuration errors or cancellation.
    public func value(for ordinal: Int, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSON> {
        try lookup(ordinal, limits: limits) { path, state, scope in
            try state.meter.work()
            return try scope.select(path, state: state)
        }
    }

    /// Looks up a coherent original value span in a new bounded operation.
    /// Full captured-source admission and path reconstruction occur even without a
    /// source map. A replacement/unmapped document has no invented historical span.
    /// - Parameters:
    ///   - ordinal: Position local to this snapshot; bounds checked before admission.
    ///   - limits: Finite quotas for this separate source-map lookup.
    /// - Returns: Original mapped span or nil when unavailable, plus lookup statistics.
    /// - Throws: Typed bounds, core resource/configuration failures or cancellation.
    public func sourceSpan(for ordinal: Int, limits: JSONLimits = .balanced)
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

/// Builds complete source-attached metadata with one original cumulative ledger.
/// No filtering, pruning, prefix, callback, per-node JSON copy or second admission.
/// Records retain parent/edge metadata and one immutable document. Existing walker
/// hit paths mean total construction is depth-sensitive, not guaranteed O(nodes).
/// Logical overlay v1 is 128 fixed bytes, 96/record, exact UTF-8 edge-key bytes and
/// 16/live open frame, plus source/path admission. These weights are not heap/RSS.
public struct JSONStructuralSnapshotBuilder: Sendable {
    /// Canonical immutable source; admitted once when build begins.
    public let document: JSONDocument
    /// Finite construction quotas shared by admission, traversal and finalization.
    public let limits: JSONLimits
    package var checkpointObserver: (@Sendable (UInt64) -> Void)?
    package var lifetimeObserver: (@Sendable (Bool, Bool) -> Void)?
    /// Captures trusted source and policy; this initializer performs no admission.
    /// - Parameters:
    ///   - document: Physical canonical root, optionally with coherent source mapping.
    ///   - limits: One finite profile for the complete construction invocation.
    public init(document: JSONDocument, limits: JSONLimits = .balanced) {
        self.document = document; self.limits = limits
    }
    /// Returns every physical node with finalized ranges, or throws without an artifact.
    /// Negative capacity fails before admission; zero refuses the real root. Even
    /// null and empty containers have one record. Source ownership transfers once
    /// only after complete traversal; temporary scope references are invalidated.
    /// - Parameter maximumRecords: Inclusive nonnegative bound, default 100,000.
    /// - Returns: Immutable complete snapshot and cumulative construction statistics.
    /// - Throws: Typed capacity refusal, invalid configuration, resource exhaustion
    ///   or cancellation. No successful partial snapshot or terminal-error override.
    public func build(maximumRecords: Int = 100_000)
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
