// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Inclusive finite policies for a complete reachable closure, not truncation.
public struct JSONStoreFollowLimits: Sendable {
    /// Maximum shortest link distance from the start; start has depth zero.
    public var maximumDepth: Int = 64
    /// Maximum pending BFS positions, excluding already consumed queue entries.
    public var maximumFrontier: Int = 10_000
    /// Maximum distinct visited records, including the start.
    public var maximumVisited: Int = 10_000
    /// Maximum returned positions, including the start.
    public var maximumResults: Int = 10_000
    /// Uses finite defaults; zero is valid, negative values and Int.max are invalid.
    public init() {}
    internal func validate() throws {
        for value in [maximumDepth, maximumFrontier, maximumVisited, maximumResults] {
            guard value >= 0, value < Int.max else { throw JSONFailure(.configuration, code: .invalidLimits) }
        }
    }
}

extension JSONConfiguredStore {
    /// Looks up an exact collection/string ID in one independent admitted operation.
    /// No canonical normalization or id/_id fallback. Missing IDs return nil;
    /// an unknown collection is a distinct typed refusal. Metadata scans and text
    /// comparisons use the same source-admission ledger; no index speed is promised.
    /// - Parameters:
    ///   - collection: Exact decoded-scalar configured collection name.
    ///   - id: Exact decoded-scalar string record identifier.
    ///   - limits: Finite cumulative native quotas for this lookup.
    /// - Returns: Owner-bound position or nil, plus cumulative statistics.
    /// - Throws: Unknown collection, native configuration/resource failure or cancellation.
    public func lookup(collection: JSONKey, id: String, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSONStorePosition?> {
        let report = try query(.lookup(collection, id), limits: limits)
        guard case .position(let result) = report.result else { throw JSONFailure(.configuration, code: .invalidOperation) }
        return .init(result: result, statistics: report.statistics)
    }

    /// Reads exact values in request order, preserving repeated positions.
    /// One source admission, metadata reservation and ledger cover the entire batch.
    /// Empty requests still admit the whole source; foreign tokens never become null.
    /// Result aliases follow ordinary native read semantics and caller-copy boundaries.
    /// - Parameters:
    ///   - positions: Unforgeable same-store record positions.
    ///   - maximumRequests: Inclusive finite request/result cap, default1024.
    ///   - limits: Finite native quotas for the whole independent batch.
    /// - Returns: All canonical record objects and cumulative statistics.
    /// - Throws: Position/batch/core resource/configuration failure or cancellation.
    public func values(at positions: [JSONStorePosition], maximumRequests: Int = 1_024,
                       limits: JSONLimits = .balanced) throws -> JSONOperationReport<[JSON]> {
        try checkInspectionBatch(positions.count, maximum: maximumRequests)
        let report = try query(.values(positions), limits: limits)
        guard case .values(let result) = report.result else { throw JSONFailure(.configuration, code: .invalidOperation) }
        return .init(result: result, statistics: report.statistics)
    }

    /// Resolves one same-store position through the one-request batch delegate.
    /// - Parameters:
    ///   - position: Unforgeable same-store physical record position.
    ///   - limits: Finite native quotas for this independent admitted read.
    /// - Returns: The original canonical record and actual operation statistics.
    /// - Throws: Invalid position, core resource/configuration failure or cancellation.
    public func value(at position: JSONStorePosition, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSON> {
        let report = try values(at: [position], maximumRequests: 1, limits: limits)
        return .init(result: report.result[0], statistics: report.statistics)
    }

    /// Returns the complete BFS reachable closure, including start exactly once.
    /// Only declared validated link slots are edges. Absent/null slots add no edge;
    /// cycles are deduplicated by physical positions. Any exceeded depth/frontier/
    /// visited/result cap throws instead of publishing a truncated closure. No I/O.
    /// - Parameters:
    ///   - start: Owner-bound starting record in this immutable store.
    ///   - bounds: Inclusive finite BFS policies, including a finite depth ceiling.
    ///   - limits: Finite native quotas shared by admission, aliases, scans and output.
    /// - Returns: Deterministic positions in configured-field BFS order and statistics.
    /// - Throws: Invalid position, typed capacity/native resource failure or cancellation.
    public func follow(from start: JSONStorePosition, bounds: JSONStoreFollowLimits = .init(),
                       limits: JSONLimits = .balanced) throws -> JSONOperationReport<[JSONStorePosition]> {
        try Task.checkCancellation(); try bounds.validate()
        let report = try query(.follow(start, bounds), limits: limits)
        guard case .positions(let result) = report.result else { throw JSONFailure(.configuration, code: .invalidOperation) }
        return .init(result: result, statistics: report.statistics)
    }

    package func followForQualification(from start: JSONStorePosition, bounds: JSONStoreFollowLimits,
        limits: JSONLimits, checkpointObserver: @Sendable @escaping (UInt64) -> Void,
        lifetimeObserver: @Sendable @escaping (Bool, Bool) -> Void,
        edgeObserver: (@Sendable (Int) -> Void)? = nil) throws -> JSONOperationReport<[JSONStorePosition]> {
        try bounds.validate()
        let report = try query(.follow(start, bounds), limits: limits,
            checkpointObserver: checkpointObserver, lifetimeObserver: lifetimeObserver, edgeObserver: edgeObserver)
        guard case .positions(let result) = report.result else { throw JSONFailure(.configuration, code: .invalidOperation) }
        return .init(result: result, statistics: report.statistics)
    }

    private func query(_ operation: StoreReadOperation, limits: JSONLimits,
                       checkpointObserver: (@Sendable (UInt64) -> Void)? = nil,
                       lifetimeObserver: (@Sendable (Bool, Bool) -> Void)? = nil,
                       edgeObserver: (@Sendable (Int) -> Void)? = nil)
        throws -> JSONOperationReport<StoreReadResult> {
        var reducer = StoreReadReducer(store: self, operation: operation, edgeObserver: edgeObserver)
        var traversal = JSONTraversal(document: document, limits: limits)
        traversal.checkpointObserver = checkpointObserver
        traversal.lifetimeObserver = lifetimeObserver
        return try traversal.inspectPreparedOwned(options: .init(depthLimit: 0), reducer: &reducer)
    }
}

private enum StoreReadOperation {
    case lookup(JSONKey, String)
    case values([JSONStorePosition])
    case follow(JSONStorePosition, JSONStoreFollowLimits)
}
private enum StoreReadResult {
    case position(JSONStorePosition?)
    case values([JSON])
    case positions([JSONStorePosition])
}

private struct StoreReadReducer: JSONReadPreparation, JSONTraversalOwnedReducer {
    let store: JSONConfiguredStore
    let operation: StoreReadOperation
    let edgeObserver: (@Sendable (Int) -> Void)?
    private var inputAliases: UInt64 = 0
    init(store: JSONConfiguredStore, operation: StoreReadOperation, edgeObserver: (@Sendable (Int) -> Void)?) {
        self.store = store; self.operation = operation; self.edgeObserver = edgeObserver
    }
    mutating func prepare(context: inout JSONReadPreparationContext) throws {
        inputAliases = try JSONStoreAccounting.sum(store.overlayLogicalBytes, 128)
        try context.retain(inputAliases)
        switch operation {
        case .lookup(let collection, let id):
            try context.admitText(collection.string, key: true); try context.admitText(id)
            for text in [collection.string, id] {
                for _ in text.utf8 { try context.work(); inputAliases = try JSONStoreAccounting.sum(inputAliases, 1) }
            }
        case .values(let positions):
            for position in positions {
                try context.work(); _ = try store.record(at: position)
                try context.retain(8); inputAliases = try JSONStoreAccounting.sum(inputAliases, 8)
            }
        case .follow(let start, _):
            try context.work(); _ = try store.record(at: start)
        }
    }
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work(); return .skipDescendants
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> StoreReadResult {
        let result: StoreReadResult
        switch operation {
        case .lookup(let collection, let id): result = .position(try lookup(collection, id: id, context: &context))
        case .values(let positions):
            var values: [JSON] = []; try context.retain(32)
            for position in positions {
                try context.work()
                let record = try store.record(at: position)
                let value = try context.selectedValue(at: record.path)
                try context.retain(32); values.append(value)
            }
            result = .values(values)
        case .follow(let start, let bounds): result = .positions(try follow(start, bounds: bounds, context: &context))
        }
        try context.checkpoint(); try context.release(inputAliases)
        return result
    }
    private func lookup(_ name: JSONKey, id: String, context: inout JSONTraversalContext) throws -> JSONStorePosition? {
        try context.retain(32)
        for collection in 0..<store.collectionCount {
            try context.work()
            if try context.equalKeys(store.collectionName(at: collection), name) {
                for row in 0..<(try store.recordCount(in: collection)) {
                    try context.work(); let record = try store.record(collection: collection, row: row)
                    if try context.equalStrings(record.id, id) { return record.position }
                }
                return nil
            }
        }
        throw JSONStoreFailure(.unknownCollection, phase: 9, domain: .operation)
    }
    private func flatIndex(_ position: JSONStorePosition, context: inout JSONTraversalContext) throws -> Int {
        try context.work(); _ = try store.record(at: position)
        var offset: UInt64 = 0
        for collection in 0..<position.collection {
            try context.work(); offset = try JSONStoreAccounting.sum(offset, UInt64(store.recordCount(in: collection)))
        }
        return try JSONStoreAccounting.checkedCount(JSONStoreAccounting.sum(offset, UInt64(position.row)), phase: 9)
    }
    private func follow(_ start: JSONStorePosition, bounds: JSONStoreFollowLimits,
                        context: inout JSONTraversalContext) throws -> [JSONStorePosition] {
        var visited: [Bool] = [], result: [JSONStorePosition] = [], depths: [Int] = []
        try context.retain(32)
        for _ in 0..<store.recordCount { try context.work(); try context.retain(1); visited.append(false) }
        var head = 0, edges = 0
        func refuse(_ name: String, _ limit: Int) -> JSONStoreFailure {
            .init(.capacityExceeded, phase: 9, domain: .operation, capacity: name, limit: limit)
        }
        func enqueue(_ position: JSONStorePosition, depth: Int, context: inout JSONTraversalContext) throws {
            try context.work()
            guard depth <= bounds.maximumDepth else { throw refuse("maximumDepth", bounds.maximumDepth) }
            guard result.count - head < bounds.maximumFrontier else { throw refuse("maximumFrontier", bounds.maximumFrontier) }
            guard result.count < bounds.maximumVisited else { throw refuse("maximumVisited", bounds.maximumVisited) }
            guard result.count < bounds.maximumResults else { throw refuse("maximumResults", bounds.maximumResults) }
            let index = try flatIndex(position, context: &context)
            try context.retain(40); visited[index] = true; result.append(position); depths.append(depth)
        }
        try enqueue(start, depth: 0, context: &context)
        while head < result.count {
            try context.work()
            let record = try store.record(at: result[head]), depth = depths[head]; head += 1
            for slot in record.referenceRange {
                try context.work()
                if case .link(let target) = store.references[slot].state {
                    let index = try flatIndex(target, context: &context)
                    if !visited[index] {
                        guard depth < bounds.maximumDepth else { throw refuse("maximumDepth", bounds.maximumDepth) }
                        try enqueue(target, depth: depth + 1, context: &context)
                    }
                }
                edges += 1; edgeObserver?(edges)
                try context.checkpoint()
            }
        }
        let scratch = try JSONStoreAccounting.sum(UInt64(visited.count), JSONStoreAccounting.product(UInt64(depths.count), 8))
        visited = []; depths = []; try context.release(scratch)
        return result
    }
}
