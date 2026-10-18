// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Checked projection refusals; positions are local to the captured source.
public enum JSONProjectionFailure: Error, Sendable, Equatable {
    /// The local position is outside the selected physical interval.
    /// - Parameter ordinal: Rejected snapshot-local position.
    case outsideSelectedSubtree(ordinal: Int)
    /// The next catalogue entry exceeds the inclusive returned-record cap.
    /// - Parameter limit: Configured nonnegative maximum.
    case recordLimitExceeded(limit: Int)
    /// The complete array exceeds the inclusive row cap.
    /// - Parameter limit: Configured nonnegative maximum.
    case rowLimitExceeded(limit: Int)
    /// The next first-seen exact key exceeds the inclusive column cap.
    /// - Parameter limit: Configured nonnegative maximum.
    case columnLimitExceeded(limit: Int)
    /// The next present object member exceeds the inclusive sparse-cell cap.
    /// - Parameter limit: Configured nonnegative maximum.
    case presentCellLimitExceeded(limit: Int)
    /// A row position is outside the complete table.
    /// - Parameter row: Rejected physical row position.
    case rowOutOfBounds(Int)
    /// A column position is outside the first-seen exact columns.
    /// - Parameter column: Rejected local column position.
    case columnOutOfBounds(Int)
    /// An actual row is not an object; a prefix observation cannot admit it.
    /// - Parameters:
    ///   - at: Absolute exact typed location of the rejected row.
    ///   - kind: Canonical kind of that row.
    case nonObjectRow(at: [JSONLocationComponent], kind: JSONTraversalKind)
}

/// Version1 logical slot policy, not allocator sizes or a process memory limit.
internal enum ProjectionAccounting {
    static func bytes(_ count: Int, unit: UInt64, limits: JSONLimits) throws -> UInt64 {
        guard count >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        let (result, overflow) = UInt64(count).multipliedReportingOverflow(by: unit)
        guard !overflow else { throw overflowFailure(limits) }
        return result
    }
    static func next(_ count: Int, limits: JSONLimits) throws -> Int {
        guard count >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        let (next, overflow) = count.addingReportingOverflow(1)
        guard !overflow else { throw overflowFailure(limits) }
        return next
    }
    private static func overflowFailure(_ limits: JSONLimits) -> JSONFailure {
        JSONFailure(.resource, code: .counterOverflow, resource: .init(
            domain: .core, metric: .retainedBytes, limit: limits[.retainedBytes],
            attemptedUsage: nil, overflow: true))
    }
}

/// A selected physical interval in one complete sealed snapshot, not another DOM.
/// No source replacement or detached handle is accepted. Metadata keeps original
/// parent/depth/path meaning, even when the selected root has a physical parent.
public struct JSONTreeProjection: Sendable {
    /// Complete immutable snapshot captured by this view.
    public let snapshot: JSONStructuralSnapshot
    /// Selected root position in the captured snapshot; depths are not rebased.
    public let rootOrdinal: Int
    /// Exclusive end of this selected physical preorder interval.
    public let endExclusive: Int
    fileprivate init(snapshot: JSONStructuralSnapshot, rootOrdinal: Int, endExclusive: Int) {
        self.snapshot = snapshot; self.rootOrdinal = rootOrdinal; self.endExclusive = endExclusive
    }

    /// One new owned operation over an already-built snapshot. Full source admission,
    /// all retained record/key aliases and selection share the original N1 ledger.
    /// Output policy:64 view +128 snapshot header +96/record +exact edge UTF8 bytes,
    /// plus the already-admitted source. The physical COW storage may be shared.
    /// - Parameters:
    ///   - snapshot: Complete attached snapshot; no replacement source is accepted.
    ///   - rootOrdinal: Local trusted position; bounds checked before admission.
    ///   - limits: Finite quotas for this independent construction operation.
    /// - Returns: Immutable source-attached view and cumulative construction statistics.
    /// - Throws: Snapshot bounds, resource/configuration failures or cancellation.
    public static func build(snapshot: JSONStructuralSnapshot, rootOrdinal: Int = 0,
                              limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSONTreeProjection> {
        guard rootOrdinal >= 0, rootOrdinal < snapshot.recordCount else {
            throw JSONStructuralSnapshotFailure.ordinalOutOfBounds(rootOrdinal)
        }
        var reducer = TreeViewReducer(snapshot: snapshot, rootOrdinal: rootOrdinal, limits: limits)
        return try JSONTraversal(document: snapshot.document, limits: limits)
            .inspectOwned(options: .init(depthLimit: 0), reducer: &reducer)
    }

    /// Ordinary fixed metadata access; there is no owned growth or new report.
    /// - Parameter ordinal: Local snapshot position within this selected interval.
    /// - Returns: Original immutable metadata, including physical parent and depth.
    /// - Throws: `JSONProjectionFailure.outsideSelectedSubtree` for an invalid position.
    public func record(at ordinal: Int) throws -> JSONStructuralRecord {
        try validate(ordinal)
        return try snapshot.record(at: ordinal)
    }
    private func validate(_ ordinal: Int) throws {
        guard ordinal >= rootOrdinal, ordinal < endExclusive else {
            throw JSONProjectionFailure.outsideSelectedSubtree(ordinal: ordinal)
        }
    }

    /// New full-source-admitted operation. Every read/jump/append is charged;
    /// returned slots cost32 fixed +8/ordinal, with96 temporary record bytes.
    /// - Parameters:
    ///   - ordinal: Local position within the selected interval.
    ///   - maximumRecords: Inclusive returned-child cap, default 100,000.
    ///   - limits: Finite quotas for this separate whole-source-admitted operation.
    /// - Returns: Immediate child positions in canonical order and actual statistics.
    /// - Throws: Invalid bounds/configuration, capacity/resource refusal or cancellation.
    public func children(of ordinal: Int, maximumRecords: Int = 100_000,
                          limits: JSONLimits = .balanced) throws -> JSONOperationReport<[Int]> {
        try catalogue(ordinal, childrenOnly: true, maximumRecords: maximumRecords, limits: limits)
    }
    /// Includes the selected node in its finalized half-open preorder interval.
    /// An insufficient inclusive cap throws rather than returning a truncated list.
    /// - Parameters:
    ///   - ordinal: Local position within the selected interval.
    ///   - maximumRecords: Inclusive returned-position cap, default 100,000.
    ///   - limits: Finite quotas for this separate whole-source-admitted operation.
    /// - Returns: Complete preorder subtree positions and actual operation statistics.
    /// - Throws: Invalid bounds/configuration, capacity/resource refusal or cancellation.
    public func subtreeOrdinals(of ordinal: Int, maximumRecords: Int = 100_000,
                                 limits: JSONLimits = .balanced) throws -> JSONOperationReport<[Int]> {
        try catalogue(ordinal, childrenOnly: false, maximumRecords: maximumRecords, limits: limits)
    }
    private func catalogue(_ ordinal: Int, childrenOnly: Bool, maximumRecords: Int,
                           limits: JSONLimits) throws -> JSONOperationReport<[Int]> {
        guard maximumRecords >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        try validate(ordinal)
        var reducer = TreeCatalogueReducer(view: self, ordinal: ordinal,
            childrenOnly: childrenOnly, maximumRecords: maximumRecords)
        return try JSONTraversal(document: snapshot.document, limits: limits)
            .inspectOwned(options: .init(depthLimit: 0), reducer: &reducer)
    }

    /// Each forwarding call delegates once to N3's independent full-source lookup.
    /// Constant local bounds checks are ordinary metadata access, not a hidden operation.
    /// - Parameters:
    ///   - ordinal: Trusted position local to the captured snapshot and selected interval.
    ///   - limits: Finite quotas for this separate full-source-admitted lookup.
    /// - Returns: Absolute exact typed location and cumulative lookup statistics.
    /// - Throws: Bounds, core resource/configuration errors or cancellation.
    public func location(for ordinal: Int, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<[JSONLocationComponent]> {
        try validate(ordinal); return try snapshot.location(for: ordinal, limits: limits)
    }
    /// Resolves the canonical value through the snapshot's one semantic delegate.
    /// - Parameters:
    ///   - ordinal: Trusted local position inside the selected interval.
    ///   - limits: Finite quotas for a new whole-source-admitted lookup.
    /// - Returns: Immutable read-value alias and actual lookup statistics.
    /// - Throws: Bounds, core access/resource/configuration errors or cancellation.
    public func value(for ordinal: Int, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSON> {
        try validate(ordinal); return try snapshot.value(for: ordinal, limits: limits)
    }
    /// Resolves a coherent original span through the captured snapshot.
    /// - Parameters:
    ///   - ordinal: Trusted local position inside the selected interval.
    ///   - limits: Finite quotas for a new whole-source-admitted lookup.
    /// - Returns: Optional original span and actual statistics; no historical map is invented.
    /// - Throws: Bounds, core resource/configuration errors or cancellation.
    public func sourceSpan(for ordinal: Int, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSONSourceSpan?> {
        try validate(ordinal); return try snapshot.sourceSpan(for: ordinal, limits: limits)
    }
}

/// Internal reducers are also exercised by post-finalization lifetime/failure proofs.
internal struct TreeViewReducer: JSONTraversalOwnedReducer {
    let snapshot: JSONStructuralSnapshot
    let rootOrdinal: Int
    let limits: JSONLimits
    var endExclusive = 0
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work()
        guard rootOrdinal >= 0, rootOrdinal < snapshot.recordCount else {
            throw JSONStructuralSnapshotFailure.ordinalOutOfBounds(rootOrdinal)
        }
        try context.retain(192)
        try context.retain(ProjectionAccounting.bytes(snapshot.recordCount, unit: 96, limits: limits))
        for ordinal in 0..<snapshot.recordCount {
            try context.work()
            let record = try snapshot.record(at: ordinal)
            if case .key(let key)? = record.componentFromParent { try context.retainKey(key) }
            if ordinal == rootOrdinal { endExclusive = record.subtreeEndExclusive }
        }
        guard endExclusive > rootOrdinal, endExclusive <= snapshot.recordCount else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        return .skipDescendants
    }
    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONTreeProjection {
        guard summary.visitedCount == 1, summary.emittedCount == 1 else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        // The executor's input is exactly snapshot.document, with no replacement
        // parameter. The view's captured snapshot owns that same original source.
        _ = try context.transferDocumentOwnership()
        return .init(snapshot: snapshot, rootOrdinal: rootOrdinal, endExclusive: endExclusive)
    }
}

internal struct TreeCatalogueReducer: JSONTraversalOwnedReducer {
    let view: JSONTreeProjection
    let ordinal: Int
    let childrenOnly: Bool
    let maximumRecords: Int
    var ordinals: [Int] = []
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work(); try context.retain(128) //32 output header +96 temporary record
        let record = try view.record(at: ordinal)
        var next = childrenOnly ? ordinal + 1 : ordinal
        while next < record.subtreeEndExclusive {
            try context.work()
            guard ordinals.count < maximumRecords else {
                throw JSONProjectionFailure.recordLimitExceeded(limit: maximumRecords)
            }
            let child = try view.record(at: next)
            if childrenOnly {
                guard child.parentOrdinal == ordinal, child.subtreeEndExclusive > next,
                      child.subtreeEndExclusive <= record.subtreeEndExclusive else {
                    throw JSONFailure(.configuration, code: .invalidOperation)
                }
            }
            try context.retain(8); ordinals.append(next)
            next = childrenOnly ? child.subtreeEndExclusive : next + 1
        }
        return .skipDescendants
    }
    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> [Int] {
        try context.work(); try context.release(96)
        let result = ordinals; ordinals = []; return result
    }
}
