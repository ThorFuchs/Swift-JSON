// SPDX-License-Identifier: Apache-2.0
import JSON

/// Synchronous exact structural exploration of one immutable canonical document.
///
/// Each call admits the complete captured root/source once, then uses the existing
/// read scope's single core-domain meter for selection, paths, frontier and output.
/// No cursor escapes. Caller visitor computation and copies retained by the caller
/// are outside owned instruction/retention quotas; logical bytes are not RSS.
public struct JSONTraversal: Sendable {
    /// The immutable source to which every emitted absolute path belongs.
    public let document: JSONDocument
    /// Finite admission, work, path and logical-retention limits for each invocation.
    public let limits: JSONLimits
    /// Invocation-local rendezvous for qualification, absent from public consumers.
    package var checkpointObserver: (@Sendable (UInt64) -> Void)?

    /// Captures a document without admission or scanning; each operation admits it.
    /// - Parameters:
    ///   - document: An immutable canonical source, optionally with coherent mapping.
    ///   - limits: Finite cumulative limits, validated at operation entry.
    public init(document: JSONDocument, limits: JSONLimits = .balanced) {
        self.document = document; self.limits = limits
    }

    /// Visits DFS preorder with object insertion order and ascending array indices.
    /// - Parameters:
    ///   - scope: Strict absolute subtree selection, including scalar roots.
    ///   - options: Explicit depth, root-emission, kind and source-span policies.
    ///   - visitor: Synchronous caller work receiving metadata and the unchanged value.
    /// - Returns: Coverage and all successful cumulative core statistics.
    /// - Throws: Typed core access errors, invalid configuration, resource/caller errors or cancellation.
    public func visit(scope: JSONTraversalScope = .subtree(at: []),
                      options: JSONTraversalOptions = .init(),
                      _ visitor: (JSONTraversalHit, JSON) throws -> JSONTraversalAction)
        throws -> JSONOperationReport<JSONTraversalSummary> {
        let report = try execute(scope: scope, options: options, collectionLimit: nil, visitor)
        return .init(result: report.result.summary, statistics: report.statistics)
    }

    /// Collects finite metadata through the same visitor engine and the same ledger.
    /// - Parameters:
    ///   - scope: Strict absolute subtree selection.
    ///   - options: Explicit exploration and emission policies.
    ///   - maximumRecords: Nonnegative inclusive record bound; defaults to 100,000.
    /// - Returns: Records, coverage and cumulative admission/traversal/output statistics.
    /// - Throws: Collection-capacity refusal, typed access/configuration/resource errors or cancellation.
    public func collect(scope: JSONTraversalScope = .subtree(at: []),
                        options: JSONTraversalOptions = .init(), maximumRecords: Int = 100_000)
        throws -> JSONOperationReport<JSONTraversalCollection> {
        try execute(scope: scope, options: options, collectionLimit: maximumRecords) { _, _ in .continue }
    }

    private struct Frame {
        let value: JSON
        let path: JSONReadPath
        var nextChild = 0
        var entered = false
    }

    private struct Root {
        let value: JSON
        let path: JSONReadPath
    }

    private func execute(scope selection: JSONTraversalScope, options: JSONTraversalOptions,
                         collectionLimit: Int?,
                         _ visitor: (JSONTraversalHit, JSON) throws -> JSONTraversalAction)
        throws -> JSONOperationReport<JSONTraversalCollection> {
        let scope = try JSONReadScope(document, limits: limits)
        defer { scope.invalidate() }
        let state = try scope.check()
        state.meter.checkpointObserver = checkpointObserver
        guard options.depthLimit.map({ $0 >= 0 }) ?? true,
              collectionLimit.map({ $0 >= 0 }) ?? true else {
            throw JSONFailure(.configuration, code: .invalidLimits)
        }
        try state.meter.retain(128) // fixed invocation summary/staging
        let locations: [[JSONLocationComponent]], overlap: JSONScopeOverlapPolicy
        try state.meter.retain(16)
        switch selection {
        case .subtree(let path): locations = [path]; overlap = .orderedOccurrences
        case .virtual(let roots, let policy): locations = roots; overlap = policy
        }
        var roots: [Root] = []
        for location in locations {
            try state.meter.work()
            try state.meter.require(.pointerTokens, UInt64(location.count))
            var path = JSONReadPath(scope: scope, components: [], bytes: 0)
            for part in location {
                // Caller-supplied query keys have the same admission as a typed
                // read-cursor key; generated child keys were admitted with the root.
                if case .key(let key) = part {
                    try JSONAdmission.text(key.string, key: true, meter: &state.meter)
                }
                path = try scope.append(part, to: path.components, state: state)
                _ = try scope.check()
            }
            let value = try scope.run(path.components) { try scope.select(path.components, state: $0) }
            try state.meter.retain(64); roots.append(.init(value: value, path: path))
        }
        if overlap == .rejectAmbiguous {
            for second in roots.indices {
                for first in 0..<second {
                    try state.meter.work()
                    if try Self.path(roots[first].path.components, overlaps: roots[second].path.components, state: state) {
                        throw JSONTraversalFailure.ambiguousRoots(first: first, second: second)
                    }
                }
            }
        }
        var frames: [Frame] = [], seen: [JSONReadPath] = []
        var summary = JSONTraversalSummary(); summary.scopeRootCount = roots.count
        var records: [JSONTraversalHit] = []
        for rootIndex in roots.indices {
            try state.meter.retain(64)
            frames.append(.init(value: roots[rootIndex].value, path: roots[rootIndex].path))
            while !frames.isEmpty {
                _ = try scope.check()
                try state.meter.work()
                let position = frames.count - 1, depth = position
                let value = frames[position].value
                let childCount = Self.childCount(value)
                if !frames[position].entered {
                    frames[position].entered = true
                    // One charged visit precedes every increment, bounded by workUnits < UInt64.max.
                    let occurrence = summary.visitedCount
                    summary.visitedCount += 1
                    summary.maximumDepthVisited = max(summary.maximumDepthVisited, depth)
                    var action = JSONTraversalAction.continue
                    let kind = JSONTraversalKind(value)
                    var duplicate = false
                    if overlap == .uniquePhysicalNodes {
                        let path = frames[position].path
                        for prior in seen {
                            try state.meter.work()
                            if prior.components.count == path.components.count,
                               try Self.path(prior.components, overlaps: path.components, state: state) {
                                duplicate = true; break
                            }
                        }
                        if duplicate { summary.deduplicatedCount += 1 }
                        else { try state.meter.retain(16); seen.append(path) }
                    }
                    if !duplicate, (depth != 0 || options.includeScopeRoot), options.emitKinds?.contains(kind) ?? true {
                        try state.meter.retain(64)
                        let path = frames[position].path.components
                        let span = try options.includeSourceSpans
                            ? document.sourceMap?.span(at: path, kind: .value, meter: &state.meter) : nil
                        let hit = JSONTraversalHit(absoluteLocation: path, scopeRootIndex: rootIndex,
                                                   occurrenceIndex: occurrence, relativeDepth: depth,
                                                   kind: kind, sourceSpan: span)
                        if let collectionLimit {
                            guard records.count < collectionLimit else {
                                throw JSONTraversalFailure.collectionLimitExceeded(limit: collectionLimit)
                            }
                            try Self.retainRecord(hit, state: state)
                            records.append(hit)
                        }
                        action = try visitor(hit, value)
                        _ = try scope.check() // cancellation/terminal health, including after .stop
                        try state.meter.release(64)
                        summary.emittedCount += 1
                    }
                    if action == .stop { summary.completion = .visitorStopped; break }
                    if childCount > 0 {
                        if action == .skipDescendants {
                            summary.prunedSubtrees += 1; frames[position].nextChild = childCount
                            summary.completion = .restricted
                        } else if options.depthLimit.map({ depth >= $0 }) ?? false {
                            summary.depthLimitedSubtrees += 1; frames[position].nextChild = childCount
                            summary.completion = .restricted
                        }
                    }
                }
                if frames[position].nextChild < childCount {
                    let ordinal = frames[position].nextChild
                    frames[position].nextChild += 1
                    try state.meter.work()
                    let (component, child) = try Self.child(value, at: ordinal)
                    let path = try scope.append(component, to: frames[position].path.components, state: state)
                    try state.meter.retain(64)
                    frames.append(.init(value: child, path: path))
                } else {
                    frames.removeLast(); try state.meter.release(64)
                }
            }
            // Refund live frontier only; consumed admission/path/visit work never resets.
            while !frames.isEmpty { frames.removeLast(); try state.meter.release(64); try state.meter.work() }
            if summary.completion == .visitorStopped { break }
        }
        while !seen.isEmpty { seen.removeLast(); try state.meter.release(16); try state.meter.work() }
        while !roots.isEmpty { roots.removeLast(); try state.meter.release(64); try state.meter.work() }
        try state.meter.release(144)
        return try scope.complete(JSONTraversalCollection(nodes: records, summary: summary))
    }

    /// Exact metered prefix comparison; no String Set, value equality or unmetered hashing.
    private static func path(_ lhs: [JSONLocationComponent], overlaps rhs: [JSONLocationComponent],
                             state: JSONCodingState) throws -> Bool {
        for index in 0..<min(lhs.count, rhs.count) {
            try state.meter.work()
            switch (lhs[index], rhs[index]) {
            case (.index(let a), .index(let b)): if a != b { return false }
            case (.key(let a), .key(let b)):
                if try !JSONComparison.textEquals(a.string, b.string, meter: &state.meter) { return false }
            default: return false
            }
        }
        return true
    }

    private static func childCount(_ value: JSON) -> Int {
        switch value { case .object(let o): return o.count; case .array(let a): return a.count; default: return 0 }
    }

    private static func child(_ value: JSON, at index: Int) throws -> (JSONLocationComponent, JSON) {
        switch value {
        case .object(let object): return (.key(object[index].key), object[index].value)
        case .array(let array): return (.index(index), array[index])
        default: throw JSONFailure(.configuration, code: .invalidOperation)
        }
    }

    private static func retainRecord(_ hit: JSONTraversalHit, state: JSONCodingState) throws {
        try state.meter.retain(64)
        for part in hit.absoluteLocation {
            try state.meter.work(); try state.meter.retain(JSONLogicalWeights.indexSlot)
            if case .key(let key) = part {
                for _ in key.string.utf8 { try state.meter.work(); try state.meter.retain(1) }
            }
        }
    }
}
