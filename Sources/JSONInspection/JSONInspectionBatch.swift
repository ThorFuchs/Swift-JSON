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

    /// Reads every requested value in caller order, returning nil where the path is missing.
    ///
    /// Missing means an absent object member or an array index past the end. Explicit
    /// JSON null is a value, `.some(.null)`, never nil. Because `JSON` itself accepts
    /// the `nil` literal as JSON null, test for missing with `if let`, `switch` or
    /// `== .none` rather than relying on a bare `nil` in a JSON-typed context. Every other problem still throws,
    /// exactly as in ``values(at:maximumRequests:)``: stepping into the wrong kind of
    /// container, a negative index, more path components than the pointer-token limit,
    /// resource exhaustion and cancellation. One complete source admission and one
    /// cumulative ledger cover the whole batch, and no partial array is published.
    /// - Parameters:
    ///   - paths: Absolute typed selections; an empty path selects the root.
    ///   - maximumRequests: Inclusive request cap, default 1024; zero admits only [].
    /// - Returns: One optional value per request, in order, and one cumulative report.
    /// - Throws: Batch capacity, wrong-kind/negative-index, resource/configuration errors or cancellation.
    public func optionalValues(at paths: [[JSONLocationComponent]], maximumRequests: Int = 1_024)
        throws -> JSONOperationReport<[JSON?]> {
        try checkInspectionBatch(paths.count, maximum: maximumRequests)
        try limits.validate()
        for path in paths where UInt64(path.count) > limits[.pointerTokens] {
            throw JSONFailure(.resource, code: .limitExceeded, resource: .init(domain: .core,
                metric: .pointerTokens, limit: limits[.pointerTokens], attemptedUsage: UInt64(path.count), overflow: false))
        }
        var reducer = OptionalPathBatchReducer(paths: paths, outputObserver: outputObserver)
        var traversal = JSONTraversal(document: document, limits: limits)
        traversal.checkpointObserver = checkpointObserver
        traversal.lifetimeObserver = lifetimeObserver
        return try traversal.inspectPreparedOwned(options: .init(depthLimit: 0), reducer: &reducer)
    }
}

private struct OptionalPathBatchReducer: JSONReadPreparation, JSONTraversalOwnedReducer {
    let paths: [[JSONLocationComponent]]
    let outputObserver: (@Sendable (Int) -> Void)?
    private var root: JSON?
    private var requestBytes: UInt64 = 0
    init(paths: [[JSONLocationComponent]], outputObserver: (@Sendable (Int) -> Void)?) {
        self.paths = paths; self.outputObserver = outputObserver
    }
    mutating func prepare(context: inout JSONReadPreparationContext) throws {
        try context.retain(32)
        // Each caller path component is an owned request slot; keys are admitted as text.
        for path in paths {
            for component in path {
                try context.work(); try context.retain(JSONLogicalWeights.indexSlot)
                requestBytes = try JSONStoreAccounting.sum(requestBytes, JSONLogicalWeights.indexSlot)
                if case .key(let key) = component { try context.admitText(key.string, key: true) }
            }
        }
    }
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work()
        guard root == nil, hit.relativeDepth == 0 else { throw JSONFailure(.configuration, code: .invalidOperation) }
        root = value
        return .skipDescendants
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> [JSON?] {
        guard let root else { throw JSONFailure(.configuration, code: .invalidOperation) }
        var result: [JSON?] = []
        for path in paths {
            try context.work()
            // JSON is ExpressibleByNilLiteral (JSON null): spell missing as Optional.none.
            var current: JSON? = .some(root)
            for (hop, component) in path.enumerated() {
                guard let value = current else { break }
                try context.work()
                // Errors name the attempted path up to and including the failing hop,
                // exactly like values(at:).
                let attempted = Array(path.prefix(hop + 1))
                switch component {
                case .key(let key):
                    // Absent members are nil; a non-object container throws through the ledger.
                    current = try context.member(value, key: key, at: attempted)
                case .index(let index):
                    guard case .array(let array) = value else {
                        let failure = JSONAccessFailure(cause: JSONFailure(.typeMismatch, code: .wrongKind), path: attempted)
                        try context.recordFailure(failure); throw failure
                    }
                    guard index >= 0 else {
                        let failure = JSONAccessFailure(cause: JSONFailure(.configuration, code: .invalidIndex), path: attempted)
                        try context.recordFailure(failure); throw failure
                    }
                    current = index < array.count ? .some(array[index]) : .none
                }
            }
            try context.retain(32); result.append(current); outputObserver?(result.count)
        }
        try context.checkpoint(); try context.release(requestBytes)
        self.root = nil
        return result
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
