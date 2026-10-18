// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Experimental complete rectangular view of original exact numeric cells.
/// No dense grid, binary conversion, arithmetic, padding or JSON materializer.
package struct JSONNumericMatrixProjection: Sendable {
    package let document: JSONDocument
    package let selectedArrayPath: [JSONLocationComponent]
    package let originalRowCount: Int
    package let originalColumnCount: Int
    package let isTransposed: Bool
    package var rowCount: Int { isTransposed ? originalColumnCount : originalRowCount }
    package var columnCount: Int { isTransposed ? originalRowCount : originalColumnCount }
    package let elementCount: Int
    package let traversal: JSONTraversalSummary

    fileprivate init(document: JSONDocument, selectedArrayPath: [JSONLocationComponent],
                     rows: Int, columns: Int, elementCount: Int, isTransposed: Bool = false,
                     traversal: JSONTraversalSummary) {
        self.document = document; self.selectedArrayPath = selectedArrayPath
        self.originalRowCount = rows; self.originalColumnCount = columns
        self.elementCount = elementCount; self.isTransposed = isTransposed; self.traversal = traversal
    }

    /// One original N1 ledger covers complete source admission, every row/cell,
    /// shape checks and output. Defaults are inclusive finite counts100000/100000/1000000.
    /// Logical output128 +typed selection +captured source; no per-cell JSON alias.
    /// [] is0x0; [[],[]] is2x0. Only complete evidence can build this view.
    package static func build(document: JSONDocument, at path: [JSONLocationComponent] = [],
                              limits: JSONLimits = .balanced, maximumRows: Int = 100_000,
                              maximumColumns: Int = 100_000, maximumElements: Int = 1_000_000)
        throws -> JSONOperationReport<Self> {
        guard maximumRows >= 0, maximumColumns >= 0, maximumElements >= 0 else {
            throw JSONFailure(.configuration, code: .invalidLimits)
        }
        var reducer = NumericMatrixReducer(maximumRows: maximumRows, maximumColumns: maximumColumns,
                                           maximumElements: maximumElements, limits: limits)
        return try JSONTraversal(document: document, limits: limits).inspectOwned(
            scope: .subtree(at: path), options: .init(depthLimit: 2), reducer: &reducer)
    }

    /// Fixed-size immutable orientation copy, like ordinary caller-owned value copying.
    /// 2x0 becomes0x2 without pretending [] can losslessly represent that shape.
    package func transposed() -> Self {
        .init(document: document, selectedArrayPath: selectedArrayPath, rows: originalRowCount,
              columns: originalColumnCount, elementCount: elementCount, isTransposed: !isTransposed,
              traversal: traversal)
    }

    /// New explicit full-source-admitted operation and report, never a constructor
    /// budget remainder. Typed logical bounds map to exact original physical indices.
    package func element(row: Int, column: Int, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSONNumber> {
        guard row >= 0, row < rowCount else { throw JSONP2ProjectionFailure.rowOutOfBounds(row) }
        guard column >= 0, column < columnCount else { throw JSONP2ProjectionFailure.columnOutOfBounds(column) }
        return try P2Accounting.read(document, selection: selectedArrayPath,
            indices: isTransposed ? [column,row] : [row,column], limits: limits) { value in
            guard case .number(let number) = value else { throw JSONFailure(.typeMismatch, code: .wrongKind) }
            return number
        }
    }
}

internal struct NumericMatrixReducer: JSONTraversalOwnedReducer {
    let maximumRows: Int
    let maximumColumns: Int
    let maximumElements: Int
    let limits: JSONLimits
    var selection: [JSONLocationComponent] = []
    var totalRows = 0, rows = 0, columns = 0, cells = 0, cellsInRow = 0
    var expectedElements = 0

    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work()
        if hit.relativeDepth == 0 {
            totalRows = try context.arrayCount(value, at: hit.absoluteLocation)
            guard totalRows <= maximumRows else { throw JSONP2ProjectionFailure.rowLimitExceeded(limit: maximumRows) }
            _ = try ProjectionAccounting.next(totalRows, limits: limits)
            try context.retain(128)
            selection = try context.retainLocation(hit.absoluteLocation)
            return .continue
        }
        if hit.relativeDepth == 1 {
            guard rows < totalRows, hit.absoluteLocation.last == .index(rows),
                  rows == 0 || cellsInRow == columns else {
                throw JSONFailure(.configuration, code: .invalidOperation)
            }
            guard case .array(let row) = value else {
                throw JSONP2ProjectionFailure.nonArrayRow(at: try context.retainLocation(hit.absoluteLocation), kind: hit.kind)
            }
            if rows == 0 {
                columns = row.count
                guard columns <= maximumColumns else { throw JSONP2ProjectionFailure.columnLimitExceeded(limit: maximumColumns) }
                expectedElements = try P2Accounting.product(totalRows, columns, limits: limits)
                guard expectedElements <= maximumElements else { throw JSONP2ProjectionFailure.elementLimitExceeded(limit: maximumElements) }
            } else if row.count != columns {
                throw JSONP2ProjectionFailure.raggedRow(at: try context.retainLocation(hit.absoluteLocation), expected: columns, actual: row.count)
            }
            cellsInRow = 0
            rows = try ProjectionAccounting.next(rows, limits: limits)
            return .continue
        }
        guard hit.relativeDepth == 2, cellsInRow < columns,
              hit.absoluteLocation.last == .index(cellsInRow) else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        guard case .number = value else {
            throw JSONP2ProjectionFailure.nonNumericCell(at: try context.retainLocation(hit.absoluteLocation), kind: hit.kind)
        }
        // No conversion: JSONNumber has already passed the core admission authority.
        cells = try ProjectionAccounting.next(cells, limits: limits)
        cellsInRow = try ProjectionAccounting.next(cellsInRow, limits: limits)
        return .skipDescendants
    }

    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONNumericMatrixProjection {
        try context.work()
        // Both nonnegative Int counts fit in UInt64; their sum plus one fits
        // even at Int.max on a 64-bit platform (2*Int.max+1 == UInt64.max).
        let visited = UInt64(totalRows) + UInt64(expectedElements) + 1
        guard rows == totalRows, cells == expectedElements,
              totalRows == 0 || cellsInRow == columns,
              summary.visitedCount == visited, summary.emittedCount == visited else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        let document = try context.transferDocumentOwnership()
        let result = JSONNumericMatrixProjection(document: document, selectedArrayPath: selection,
            rows: totalRows, columns: columns, elementCount: expectedElements, traversal: summary)
        selection = []
        return result
    }
}
