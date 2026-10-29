// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// A finite batch request policy refusal; ordinary selection errors retain core paths.
public enum JSONInspectionBatchFailure: Error, Sendable, Equatable {
    /// The requested result count exceeds the inclusive batch bound.
    /// - Parameters:
    ///   - limit: Configured finite maximum.
    ///   - actual: Number of caller requests, including repeated requests.
    case requestLimitExceeded(limit: Int, actual: Int)
}

internal func checkInspectionBatch(_ count: Int, maximum: Int) throws {
    try Task.checkCancellation()
    guard maximum >= 0, maximum < Int.max else { throw JSONFailure(.configuration, code: .invalidLimits) }
    guard count <= maximum else { throw JSONInspectionBatchFailure.requestLimitExceeded(limit: maximum, actual: count) }
}

/// Ordered exact value reads with one complete source admission and cumulative ledger.
/// Caller-authored paths and later caller copies retain their ordinary value semantics.
public struct JSONInspectionBatch: Sendable {
    /// Canonical immutable source used by every request.
    public let document: JSONDocument
    /// Finite original native quotas for each batch, not per selection.
    public let limits: JSONLimits
    package var checkpointObserver: (@Sendable (UInt64) -> Void)?
    package var outputObserver: (@Sendable (Int) -> Void)?
    package var lifetimeObserver: (@Sendable (Bool, Bool) -> Void)?

    /// Captures immutable input without opening an operation or scanning it.
    /// - Parameters:
    ///   - document: Canonical source, optionally with coherent source mapping.
    ///   - limits: Finite cumulative admission, work, path and retention quotas.
    public init(document: JSONDocument, limits: JSONLimits = .balanced) {
        self.document = document; self.limits = limits
    }

    /// Reads all requested values or throws, preserving caller order and repeats.
    /// Even an empty batch admits the entire source. JSON null is a value; missing
    /// paths throw. The result owns32 logical header bytes and32 per alias slot;
    /// JSON aliases follow existing read semantics, not an RSS guarantee.
    /// - Parameters:
    ///   - paths: Absolute typed selections; an empty path selects the root.
    ///   - maximumRequests: Inclusive request cap, default1024; zero admits only [].
    /// - Returns: All exact values and one cumulative operation report.
    /// - Throws: Batch capacity, core access/resource/configuration errors or cancellation.
    public func values(at paths: [[JSONLocationComponent]], maximumRequests: Int = 1_024)
        throws -> JSONOperationReport<[JSON]> {
        try checkInspectionBatch(paths.count, maximum: maximumRequests)
        var reducer = PathBatchReducer(outputObserver: outputObserver)
        var traversal = JSONTraversal(document: document, limits: limits)
        traversal.checkpointObserver = checkpointObserver
        traversal.lifetimeObserver = lifetimeObserver
        return try traversal.inspectPreparedOwned(scope: .virtual(roots: paths, overlap: .orderedOccurrences),
            options: .init(depthLimit: 0), reducer: &reducer)
    }
}

private struct PathBatchReducer: JSONReadPreparation, JSONTraversalOwnedReducer {
    var values: [JSON] = []
    let outputObserver: (@Sendable (Int) -> Void)?
    mutating func prepare(context: inout JSONReadPreparationContext) throws { try context.retain(32) }
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work(); try context.retain(32); values.append(value)
        outputObserver?(values.count)
        return .skipDescendants
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> [JSON] {
        try context.checkpoint()
        let result = values; values = []; return result
    }
}

extension JSONStructuralSnapshot {
    /// Resolves ordered snapshot positions with one source admission and ledger.
    /// This does not invoke singular public reads. Invalid positions throw before
    /// admission; repeats are preserved, billed and never silently deduplicated.
    /// - Parameters:
    ///   - ordinals: Positions local to this complete immutable snapshot.
    ///   - maximumRequests: Inclusive finite request/output count, default1024.
    ///   - limits: Cumulative native quotas for this entire independent batch.
    /// - Returns: Exact values in request order and cumulative statistics.
    /// - Throws: Position/capacity, core resource/access/configuration errors or cancellation.
    public func values(for ordinals: [Int], maximumRequests: Int = 1_024,
                       limits: JSONLimits = .balanced) throws -> JSONOperationReport<[JSON]> {
        try checkInspectionBatch(ordinals.count, maximum: maximumRequests)
        return try readValues(for: ordinals, limits: limits)
    }
    package func valuesForQualification(for ordinals: [Int], limits: JSONLimits,
        outputObserver: @Sendable @escaping (Int) -> Void,
        lifetimeObserver: @Sendable @escaping (Bool, Bool) -> Void) throws -> JSONOperationReport<[JSON]> {
        try checkInspectionBatch(ordinals.count, maximum: 1_024)
        return try readValues(for: ordinals, limits: limits, outputObserver: outputObserver, lifetimeObserver: lifetimeObserver)
    }
    private func readValues(for ordinals: [Int], limits: JSONLimits,
        outputObserver: (@Sendable (Int) -> Void)? = nil,
        lifetimeObserver: (@Sendable (Bool, Bool) -> Void)? = nil) throws -> JSONOperationReport<[JSON]> {
        var reducer = SnapshotBatchReducer(snapshot: self, ordinals: ordinals, outputObserver: outputObserver)
        var traversal = JSONTraversal(document: document, limits: limits)
        traversal.lifetimeObserver = lifetimeObserver
        return try traversal.inspectPreparedOwned(options: .init(depthLimit: 0), reducer: &reducer)
    }
}

private struct SnapshotBatchReducer: JSONReadPreparation, JSONTraversalOwnedReducer {
    let snapshot: JSONStructuralSnapshot
    let ordinals: [Int]
    let outputObserver: (@Sendable (Int) -> Void)?
    private var requestAliases: UInt64 = 0
    init(snapshot: JSONStructuralSnapshot, ordinals: [Int], outputObserver: (@Sendable (Int) -> Void)?) {
        self.snapshot = snapshot; self.ordinals = ordinals; self.outputObserver = outputObserver
    }
    mutating func prepare(context: inout JSONReadPreparationContext) throws {
        try context.retain(32)
        for ordinal in ordinals {
            try context.work(); _ = try snapshot.record(at: ordinal)
            try context.retain(8); requestAliases += 8 // count was capped before preparation
        }
    }
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work(); return .skipDescendants
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> [JSON] {
        var result: [JSON] = []
        for ordinal in ordinals {
            try context.work()
            var reversed: [JSONLocationComponent] = [], current = ordinal, scratch: UInt64 = 0
            while let parent = try snapshot.record(at: current).parentOrdinal {
                try context.work()
                guard parent >= 0, parent < current,
                      let component = try snapshot.record(at: current).componentFromParent else {
                    throw JSONFailure(.configuration, code: .invalidOperation)
                }
                try context.retain(32); scratch += 32
                if case .key(let key) = component {
                    for _ in key.string.utf8 { try context.work(); try context.retain(1); scratch += 1 }
                }
                reversed.append(component); current = parent
            }
            // Reuse the reserved reverse buffer; do not accumulate owned prefix copies.
            for index in 0..<(reversed.count / 2) {
                try context.work(); reversed.swapAt(index, reversed.count - index - 1)
            }
            let value = try context.selectedValue(at: reversed)
            reversed = []; try context.release(scratch)
            try context.retain(32); result.append(value); outputObserver?(result.count)
        }
        try context.checkpoint(); try context.release(requestAliases); return result
    }
}
