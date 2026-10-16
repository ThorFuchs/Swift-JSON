// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Read-only array evidence over the canonical traversal ledger.
/// Import the opt-in JSONInspection product. Each invocation admits the entire
/// captured source once and charges selection, classification and returned storage
/// cumulatively. Logical retained bytes describe package policy, not process RSS.
public struct JSONShapeInspector: Sendable {
    /// Immutable source for every typed location and optional span.
    public let document: JSONDocument
    /// Finite core admission, work, cancellation and logical-retention policies.
    public let limits: JSONLimits
    /// Package qualification hook; no scope or meter is exposed.
    package var checkpointObserver: (@Sendable (UInt64) -> Void)?

    /// Captures trusted immutable input; admission occurs when inspection starts.
    /// - Parameters:
    ///   - document: Canonical source, optionally with coherent source mapping.
    ///   - limits: One finite profile for the whole inspection invocation.
    public init(document: JSONDocument, limits: JSONLimits = .balanced) {
        self.document = document; self.limits = limits
    }

    /// Inspects an existing array without projecting or rewriting its values.
    /// Negative sample/column configuration fails before source admission. Valid
    /// sampling always admits the full captured source, including an unseen suffix.
    /// - Parameters:
    ///   - at: Absolute exact key/index path; [] selects the root.
    ///   - sampling: Complete rows or a deterministic prefix, never inferred coverage.
    ///   - maximumColumns: Inclusive output-column bound, defaulting to 100,000.
    ///   - includeSourceSpan: Request a metered coherent selected-array value span.
    /// - Returns: Observed-only evidence and the original cumulative operation report.
    /// - Throws: Typed core selection/kind errors, invalid configuration, column
    ///   capacity, core resource exhaustion or cancellation; no partial report.
    public func inspectArray(at: [JSONLocationComponent] = [],
                             sampling: JSONShapeSampling = .complete,
                             maximumColumns: Int = 100_000,
                             includeSourceSpan: Bool = false)
        throws -> JSONOperationReport<JSONShapeArrayEvidence> {
        guard maximumColumns >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        if case .prefix(let maximumRows) = sampling, maximumRows < 0 {
            throw JSONFailure(.configuration, code: .invalidLimits)
        }
        var reducer = ArrayReducer(sampling: sampling, maximumColumns: maximumColumns,
                                   includeSourceSpan: includeSourceSpan)
        var traversal = JSONTraversal(document: document, limits: limits)
        traversal.checkpointObserver = checkpointObserver
        return try traversal.inspectOwned(scope: .subtree(at: at), options: .init(depthLimit: 1),
                                          reducer: &reducer)
    }
}

/// One fixed summary (256 logical bytes), 192 per column plus its key bytes,
/// and existing core path slots. Reserve before append; no String hash authority.
private struct ArrayReducer: JSONTraversalOwnedReducer {
    let sampling: JSONShapeSampling
    let maximumColumns: Int
    let includeSourceSpan: Bool
    var selection: [JSONLocationComponent] = []
    var span: JSONSourceSpan?
    var total = 0, wanted = 0, examined = 0
    var kinds = JSONShapeKindCounts()
    var columns: [JSONColumnObservation] = []
    var minimumArrayLength: Int?, maximumArrayLength: Int?

    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        if hit.relativeDepth == 0 {
            total = try context.arrayCount(value, at: hit.absoluteLocation)
            try context.retain(256)
            selection = try context.retainLocation(hit.absoluteLocation)
            if includeSourceSpan { span = try context.sourceSpan(at: hit.absoluteLocation) }
            switch sampling { case .complete: wanted = total; case .prefix(let maximum): wanted = min(maximum, total) }
            return wanted == 0 ? .skipDescendants : .continue
        }
        try context.work()
        let row = examined; examined += 1; kinds.record(value)
        switch value {
        case .object(let object):
            for ordinal in 0..<object.count {
                try context.work()
                let member = object[ordinal]
                var found: Int?
                for index in columns.indices {
                    try context.work()
                    if try context.equalKeys(columns[index].key, member.key) { found = index; break }
                }
                if found == nil {
                    guard columns.count < maximumColumns else {
                        throw JSONShapeInspectionFailure.columnLimitExceeded(limit: maximumColumns)
                    }
                    try context.retain(192)
                    try context.retainKey(member.key)
                    found = columns.count
                    columns.append(.init(key: member.key, firstRow: row))
                }
                // Found in the bounded scan or assigned immediately before append.
                guard let index = found else { throw JSONFailure(.configuration, code: .invalidOperation) }
                columns[index].present += 1
                if case .null = member.value { columns[index].explicitNull += 1 }
                columns[index].kinds.record(member.value)
            }
        case .array(let array):
            minimumArrayLength = min(minimumArrayLength ?? array.count, array.count)
            maximumArrayLength = max(maximumArrayLength ?? array.count, array.count)
        default: break
        }
        return examined == wanted && wanted < total ? .stop : .skipDescendants
    }

    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONShapeArrayEvidence {
        for index in columns.indices {
            try context.work()
            columns[index].missing = kinds.objects - columns[index].present
        }
        try context.work(6)
        var uniform: JSONTraversalKind?
        for kind in JSONTraversalKind.allCases where examined > 0 && kinds[kind] == UInt64(examined) {
            uniform = kind
        }
        let range: ClosedRange<Int>?
        if let minimumArrayLength, let maximumArrayLength { range = minimumArrayLength...maximumArrayLength }
        else { range = nil }
        let rectangular = examined > 0 && kinds.arrays == UInt64(examined)
            && minimumArrayLength == maximumArrayLength ? minimumArrayLength : nil
        // Transfer the charged output slots; the reducer keeps no second vector.
        let outputColumns = columns; columns = []
        let outputSelection = selection; selection = []
        return .init(sourceSelection: outputSelection, sourceSpan: span, sourceAdmissionComplete: true,
            traversal: summary, totalRows: total, examinedRows: examined,
            rowCoverage: examined == total ? .complete : .prefix(examined: examined, total: total),
            rowKinds: kinds, observedObjectRows: kinds.objects,
            observedNonObjectRows: UInt64(examined) - kinds.objects, firstSeenColumns: outputColumns,
            observedAllObjects: examined == 0 ? nil : kinds.objects == UInt64(examined),
            observedUniformRowKind: uniform, observedArrayLengthRange: range,
            observedRectangularArrayWidth: rectangular)
    }
}
