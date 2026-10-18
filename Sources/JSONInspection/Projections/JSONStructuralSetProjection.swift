// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Experimental complete structural set over one immutable physical array.
/// Representatives are original source indices, never IDs, hashes or JSON copies.
/// Equality delegates to core under the constructor's one cumulative ledger.
package struct JSONStructuralSetProjection: Sendable {
    package let document: JSONDocument
    package let selectedArrayPath: [JSONLocationComponent]
    package let inputCount: Int
    package let representativeIndices: [Int]
    package var uniqueCount: Int { representativeIndices.count }
    package let traversal: JSONTraversalSummary

    fileprivate init(document: JSONDocument, selectedArrayPath: [JSONLocationComponent],
                     inputCount: Int, representativeIndices: [Int], traversal: JSONTraversalSummary) {
        self.document = document; self.selectedArrayPath = selectedArrayPath
        self.inputCount = inputCount; self.representativeIndices = representativeIndices
        self.traversal = traversal
    }

    /// Full source admission, exact selection, all comparisons and output accounting
    /// share the existing N1 scope. No prefix/partial successful artifact exists.
    /// Inclusive unique cap100000; logical output128 +8/representative +typed path
    /// +original captured source. Comparison scratch uses core's existing weights.
    /// Worst case quadratic comparisons plus exact value/path costs; no speed claim.
    package static func build(document: JSONDocument, at path: [JSONLocationComponent] = [],
                              limits: JSONLimits = .balanced, maximumUniqueItems: Int = 100_000)
        throws -> JSONOperationReport<Self> {
        guard maximumUniqueItems >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        var reducer = StructuralSetReducer(maximumUniqueItems: maximumUniqueItems, limits: limits)
        return try JSONTraversal(document: document, limits: limits).inspectOwned(
            scope: .subtree(at: path), options: .init(depthLimit: 1), reducer: &reducer)
    }

    /// New explicit finite operation over the captured whole source. Returns the
    /// first original occurrence, preserving number lexemes and object source order.
    package func member(at position: Int, limits: JSONLimits = .balanced) throws -> JSONOperationReport<JSON> {
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
