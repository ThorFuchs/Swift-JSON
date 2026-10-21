// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// A complete first-occurrence structural set over one immutable original array.
///
/// Exact decimal and scalar identity, order-independent object equality and ordered
/// array equality delegate to core under one cumulative construction ledger.
/// Representatives retain source positions, rather than copied values or persistent
/// identities. Worst-case construction uses quadratic comparisons, each with exact
/// value and selection costs. Later member reads independently admit the full source.
public struct JSONStructuralSetProjection: Sendable {
    /// The immutable original document, including its coherent source map when available.
    public let document: JSONDocument
    /// The exact typed physical path to the selected original array.
    public let selectedArrayPath: [JSONLocationComponent]
    /// The complete selected array length, including duplicate occurrences.
    public let inputCount: Int
    /// First-occurrence offsets in the original array, in increasing source order. These are source-local positions, not persistent IDs.
    public let representativeIndices: [Int]
    /// The number of distinct structural equality classes in the selected array.
    public var uniqueCount: Int { representativeIndices.count }
    /// The completed constructor traversal; descendants may be pruned after complete source admission.
    public let traversal: JSONTraversalSummary

    fileprivate init(document: JSONDocument, selectedArrayPath: [JSONLocationComponent],
                     inputCount: Int, representativeIndices: [Int], traversal: JSONTraversalSummary) {
        self.document = document; self.selectedArrayPath = selectedArrayPath
        self.inputCount = inputCount; self.representativeIndices = representativeIndices
        self.traversal = traversal
    }

    /// Builds complete first-occurrence representatives under one cumulative ledger.
    ///
    /// Full source admission, exact selection, comparisons and output accounting
    /// share the original traversal scope. Logical output reserves 128 fixed bytes,
    /// 8 per representative, the typed path and the original source. Comparison
    /// scratch uses core weights. These are logical policy units, not RSS bounds.
    /// - Parameters:
    ///   - document: The canonical source to admit completely, including unselected siblings.
    ///   - path: Exact typed selection of an existing array; the empty path selects the root.
    ///   - limits: Finite cumulative core limits for this construction.
    ///   - maximumUniqueItems: Inclusive representative capacity, defaulting to 100,000.
    /// - Returns: A complete immutable view and its construction statistics.
    /// - Throws: Configuration, selection, capacity, resource or cancellation errors;
    ///   no successful partial view is returned.
    public static func build(document: JSONDocument, at path: [JSONLocationComponent] = [],
                              limits: JSONLimits = .balanced, maximumUniqueItems: Int = 100_000)
        throws -> JSONOperationReport<Self> {
        guard maximumUniqueItems >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        var reducer = StructuralSetReducer(maximumUniqueItems: maximumUniqueItems, limits: limits)
        return try JSONTraversal(document: document, limits: limits).inspectOwned(
            scope: .subtree(at: path), options: .init(depthLimit: 1), reducer: &reducer)
    }

    /// New explicit finite operation over the captured whole source. Returns the
    /// first original occurrence, preserving number lexemes and object source order.
    /// Bounds are checked before source admission. This is a separately owned read,
    /// not a continuation of construction; repeated calls repeat full-source admission.
    /// - Parameters:
    ///   - position: A position in `representativeIndices`, not an original array offset.
    ///   - limits: Finite limits for this independent read.
    /// - Returns: The original first occurrence and independent read statistics.
    /// - Throws: A member-bounds refusal, core resource error or cancellation.
    public func member(at position: Int, limits: JSONLimits = .balanced) throws -> JSONOperationReport<JSON> {
        guard position >= 0, position < representativeIndices.count else {
            throw JSONP2ProjectionFailure.memberOutOfBounds(position)
        }
        return try P2Accounting.read(document, selection: selectedArrayPath,
            indices: [representativeIndices[position]], limits: limits) { $0 }
    }
}

internal struct StructuralSetReducer: JSONTraversalOwnedReducer {
    let maximumUniqueItems: Int
    let limits: JSONLimits
    var selection: [JSONLocationComponent] = []
    var totalItems = 0, seen = 0
    var representatives: [Int] = []

    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work()
        if hit.relativeDepth == 0 {
            totalItems = try context.arrayCount(value, at: hit.absoluteLocation)
            _ = try ProjectionAccounting.next(totalItems, limits: limits)
            try context.retain(128)
            selection = try context.retainLocation(hit.absoluteLocation)
            return .continue
        }
        guard hit.relativeDepth == 1, hit.absoluteLocation.last == .index(seen), seen < totalItems else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        var duplicate = false
        for representative in representatives {
            try context.work()
            if try context.equalArrayElements(at: selection, lhs: representative, rhs: seen) {
                duplicate = true; break
            }
        }
        if !duplicate {
            guard representatives.count < maximumUniqueItems else {
                throw JSONP2ProjectionFailure.uniqueItemLimitExceeded(limit: maximumUniqueItems)
            }
            _ = try ProjectionAccounting.next(representatives.count, limits: limits)
            try context.retain(8); representatives.append(seen)
        }
        seen = try ProjectionAccounting.next(seen, limits: limits)
        return .skipDescendants
    }

    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONStructuralSetProjection {
        let visited = try ProjectionAccounting.next(totalItems, limits: limits)
        guard seen == totalItems, summary.visitedCount == UInt64(visited),
              summary.emittedCount == UInt64(visited) else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        var previous = -1
        for index in representatives {
            try context.work()
            guard index > previous, index < totalItems else {
                throw JSONFailure(.configuration, code: .invalidOperation)
            }
            previous = index
        }
        let document = try context.transferDocumentOwnership()
        let result = JSONStructuralSetProjection(document: document, selectedArrayPath: selection,
            inputCount: totalItems, representativeIndices: representatives, traversal: summary)
        selection = []; representatives = []
        return result
    }
}
