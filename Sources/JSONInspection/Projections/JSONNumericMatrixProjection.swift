// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// A complete rectangular view of original exact JSON numeric cells.
///
/// Every row and cell is checked under one construction ledger. The view stores
/// dimensions and orientation, without a dense numeric buffer or binary conversion.
/// Later element reads independently admit the captured full source. Empty `[]` is
/// zero by zero; `[[],[]]` transposes from two by zero to zero by two. No JSON
/// materializer can preserve that independent empty dimension.
public struct JSONNumericMatrixProjection: Sendable {
    /// The immutable original document, including its coherent source map when available.
    public let document: JSONDocument
    /// The exact typed physical path to the selected original array.
    public let selectedArrayPath: [JSONLocationComponent]
    /// The row count in the original physical source, independent of orientation.
    public let originalRowCount: Int
    /// The original rectangular width; an empty source array has width zero.
    public let originalColumnCount: Int
    /// Whether logical coordinates exchange the original row and column positions.
    public let isTransposed: Bool
    /// The logical row count in the current orientation.
    public var rowCount: Int { isTransposed ? originalColumnCount : originalRowCount }
    /// The logical column count, retained even when the logical row count is zero.
    public var columnCount: Int { isTransposed ? originalRowCount : originalColumnCount }
    /// The checked product of the original dimensions; unchanged by transposition.
    public let elementCount: Int
    /// The completed constructor traversal, after every row and numeric cell was checked.
    public let traversal: JSONTraversalSummary

    fileprivate init(document: JSONDocument, selectedArrayPath: [JSONLocationComponent],
                     rows: Int, columns: Int, elementCount: Int, isTransposed: Bool = false,
                     traversal: JSONTraversalSummary) {
        self.document = document; self.selectedArrayPath = selectedArrayPath
        self.originalRowCount = rows; self.originalColumnCount = columns
        self.elementCount = elementCount; self.isTransposed = isTransposed; self.traversal = traversal
    }

    /// Admits a complete rectangular numeric array under one cumulative ledger.
    ///
    /// Source admission, every row and cell, shape checks and output share the
    /// original traversal scope. Logical output reserves 128 fixed bytes, the
    /// typed selection and captured source, with no per-cell JSON storage.
    /// - Parameters:
    ///   - document: The original source to admit completely, including unselected siblings.
    ///   - path: Exact typed selection of an existing array; the empty path selects the root.
    ///   - limits: Finite cumulative limits for this construction.
    ///   - maximumRows: Inclusive original row capacity, defaulting to 100,000.
    ///   - maximumColumns: Inclusive original column capacity, defaulting to 100,000.
    ///   - maximumElements: Inclusive cell capacity, defaulting to 1,000,000.
    /// - Returns: A completely admitted exact numeric view and construction statistics.
    /// - Throws: Configuration, selection, shape, capacity, resource or cancellation errors.
    public static func build(document: JSONDocument, at path: [JSONLocationComponent] = [],
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

    /// Returns an immutable orientation copy without traversing or copying cells.
    ///
    /// Two by zero becomes zero by two without a lossy empty-array materialization.
    /// - Returns: A source-sharing copy with exchanged logical dimensions.
    public func transposed() -> Self {
        .init(document: document, selectedArrayPath: selectedArrayPath, rows: originalRowCount,
              columns: originalColumnCount, elementCount: elementCount, isTransposed: !isTransposed,
              traversal: traversal)
    }

    /// New explicit full-source-admitted operation and report, never a constructor
    /// budget remainder. Typed logical bounds map to exact original physical indices.
    /// Row bounds precede column bounds, then valid reads admit the entire source.
    /// Repeated calls repeat admission; no constructor remainder or cache is shared.
    /// - Parameters:
    ///   - row: A zero-based logical row in the current orientation.
    ///   - column: A zero-based logical column in the current orientation.
    ///   - limits: Finite limits for this independent read.
    /// - Returns: The original exact number, including its admitted numeric lexeme,
    ///   and independent read statistics.
    /// - Throws: Row or column bounds, core resource errors or cancellation.
    public func element(row: Int, column: Int, limits: JSONLimits = .balanced)
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
