// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Original object-member and first-seen column positions; row is the offset slice.
package struct JSONSparseTableMember: Sendable, Equatable {
    package let memberOrdinal: Int
    package let columnOrdinal: Int
}

/// Complete all-object array metadata, never a schema or numeric matrix verdict.
/// Stores no cell JSON/path copy, dense grid, guessed row id or normalized key.
public struct JSONSparseTableProjection: Sendable {
    /// Captured immutable source; cell lookups cannot rebind it.
    public let document: JSONDocument
    /// Exact absolute path of the completely checked array; [] denotes the root.
    public let selectedArrayPath: [JSONLocationComponent]
    /// Complete number of original array rows, including empty object rows.
    public let rowCount: Int
    /// Distinct decoded-scalar keys in deterministic first-seen source order.
    public let columns: [JSONKey]
    /// Nondecreasing prefix offsets; an empty object row has an empty slice.
    package let rowOffsets: [Int]
    package let presentMembers: [JSONSparseTableMember]
    /// Descendant traversal may be restricted although every physical row was admitted.
    public let traversal: JSONTraversalSummary
    fileprivate init(document: JSONDocument, selectedArrayPath: [JSONLocationComponent],
                     rowCount: Int, columns: [JSONKey], rowOffsets: [Int],
                     presentMembers: [JSONSparseTableMember], traversal: JSONTraversalSummary) {
        self.document = document; self.selectedArrayPath = selectedArrayPath
        self.rowCount = rowCount; self.columns = columns; self.rowOffsets = rowOffsets
        self.presentMembers = presentMembers; self.traversal = traversal
    }

    /// One original N1 invocation, complete source admission and strict object rows.
    /// Inclusive defaults:100000 rows,10000 columns,1000000 present members.
    /// Negative configuration precedes admission; source/root and row failures throw.
    /// Logical policy v1:256 fixed +8/offset +64/column +exact key bytes +16/member,
    /// retained selection and captured source. No partial or prefix output exists.
    /// Every selected row is checked, even when prior N2 prefix evidence was positive.
    /// An empty array is 0-by-0; two empty objects are 2-by-0. Linear exact column
    /// scans may be quadratic. Logical bytes are policy, not process RSS.
    /// - Parameters:
    ///   - document: Canonical immutable source, admitted once in this invocation.
    ///   - path: Existing exact typed array location; keys and indices are distinct.
    ///   - limits: One finite profile shared by selection, classification and output.
    ///   - maximumRows: Inclusive complete-row bound, default 100,000.
    ///   - maximumColumns: Inclusive first-seen exact-key bound, default 10,000.
    ///   - maximumPresentCells: Inclusive present-member bound, default 1,000,000.
    /// - Returns: Complete source-attached sparse table and cumulative statistics.
    /// - Throws: Negative configuration, wrong-kind/missing source, nonobject row,
    ///   capacity/resource failure or cancellation; never a partial successful table.
    public static func build(document: JSONDocument, at path: [JSONLocationComponent] = [],
                              limits: JSONLimits = .balanced, maximumRows: Int = 100_000,
                              maximumColumns: Int = 10_000, maximumPresentCells: Int = 1_000_000)
        throws -> JSONOperationReport<JSONSparseTableProjection> {
        guard maximumRows >= 0, maximumColumns >= 0, maximumPresentCells >= 0 else {
            throw JSONFailure(.configuration, code: .invalidLimits)
        }
        var reducer = SparseTableReducer(maximumRows: maximumRows, maximumColumns: maximumColumns,
                                         maximumPresentCells: maximumPresentCells, limits: limits)
        return try JSONTraversal(document: document, limits: limits).inspectOwned(
            scope: .subtree(at: path), options: .init(depthLimit: 1), reducer: &reducer)
    }

    /// A NEW owned whole-source-admitted lookup, not the construction meter's remainder.
    /// Row slices are scanned with charged work. Core JSONObject lookup and scalar
    /// comparison own presence/key identity. Wrong bounds never become absence/null.
    /// - Parameters:
    ///   - row: Original zero-based physical array position.
    ///   - column: Position in this table's first-seen exact columns.
    ///   - limits: Finite quotas for this new operation, independent of construction.
    /// - Returns: Distinct absent, explicit null or canonical value and actual statistics.
    /// - Throws: Typed bounds, core access/resource/configuration errors or cancellation.
    public func cell(row: Int, column: Int, limits: JSONLimits = .balanced)
        throws -> JSONOperationReport<JSONPresence<JSON>> {
        guard row >= 0, row < rowCount else { throw JSONProjectionFailure.rowOutOfBounds(row) }
        guard column >= 0, column < columns.count else { throw JSONProjectionFailure.columnOutOfBounds(column) }
        let scope = try JSONReadScope(document, limits: limits)
        defer { scope.invalidate() }
        let state = try scope.check()
        var path = JSONReadPath(scope: scope, components: [], bytes: 0)
        for component in selectedArrayPath {
            try state.meter.work(); path = try scope.append(component, to: path.components, state: state)
            _ = try scope.check()
        }
        path = try scope.append(.index(row), to: path.components, state: state)
        let result: JSONPresence<JSON> = try scope.run(path.components) { state in
            guard case .object(let object) = try scope.select(path.components, state: state) else {
                throw JSONFailure(.typeMismatch, code: .wrongKind)
            }
            var member: Int?
            // row+1 is safe: construction checked rowCount+1 and row<rowCount.
            for position in rowOffsets[row]..<rowOffsets[row + 1] {
                try state.meter.work()
                if presentMembers[position].columnOrdinal == column {
                    member = presentMembers[position].memberOrdinal; break
                }
            }
            let value = try object.lookup(columns[column].string, meter: &state.meter)
            switch (member, value) {
            case (nil, nil): return .absent
            case (.some(let ordinal), .some(let value)):
                try state.meter.work()
                guard ordinal >= 0, ordinal < object.count,
                      try JSONComparison.textEquals(object[ordinal].key.string, columns[column].string,
                                                    meter: &state.meter) else {
                    throw JSONFailure(.configuration, code: .invalidOperation)
                }
                if case .null = value { return .null }
                return .value(value)
            default: throw JSONFailure(.configuration, code: .invalidOperation)
            }
        }
        return try scope.complete(result)
    }
}

internal struct SparseTableReducer: JSONTraversalOwnedReducer {
    let maximumRows: Int
    let maximumColumns: Int
    let maximumPresentCells: Int
    let limits: JSONLimits
    var selection: [JSONLocationComponent] = []
    var totalRows = 0, rows = 0
    var columns: [JSONKey] = []
    var offsets: [Int] = []
    var members: [JSONSparseTableMember] = []
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work()
        if hit.relativeDepth == 0 {
            totalRows = try context.arrayCount(value, at: hit.absoluteLocation)
            guard totalRows <= maximumRows else { throw JSONProjectionFailure.rowLimitExceeded(limit: maximumRows) }
            _ = try ProjectionAccounting.next(totalRows, limits: limits)
            try context.retain(256)
            selection = try context.retainLocation(hit.absoluteLocation)
            try context.retain(8); offsets.append(0)
            return .continue
        }
        guard case .object(let object) = value else {
            let path = try context.retainLocation(hit.absoluteLocation)
            throw JSONProjectionFailure.nonObjectRow(at: path, kind: hit.kind)
        }
        for ordinal in 0..<object.count {
            try context.work()
            guard members.count < maximumPresentCells else {
                throw JSONProjectionFailure.presentCellLimitExceeded(limit: maximumPresentCells)
            }
            let key = object[ordinal].key
            var column: Int?
            for index in columns.indices {
                try context.work()
                if try context.equalKeys(columns[index], key) { column = index; break }
            }
            if column == nil {
                guard columns.count < maximumColumns else {
                    throw JSONProjectionFailure.columnLimitExceeded(limit: maximumColumns)
                }
                _ = try ProjectionAccounting.next(columns.count, limits: limits)
                try context.retain(64); try context.retainKey(key)
                column = columns.count; columns.append(key)
            }
            guard let column else { throw JSONFailure(.configuration, code: .invalidOperation) }
            _ = try ProjectionAccounting.next(members.count, limits: limits)
            try context.retain(16); members.append(.init(memberOrdinal: ordinal, columnOrdinal: column))
        }
        _ = try ProjectionAccounting.next(offsets.count, limits: limits)
        try context.retain(8); offsets.append(members.count)
        rows = try ProjectionAccounting.next(rows, limits: limits)
        return .skipDescendants
    }
    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONSparseTableProjection {
        let offsetCount = try ProjectionAccounting.next(totalRows, limits: limits)
        guard rows == totalRows, offsets.count == offsetCount, offsets.first == 0,
              offsets.last == members.count, summary.visitedCount == UInt64(offsetCount),
              summary.emittedCount == UInt64(offsetCount) else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        for position in offsets.indices {
            try context.work()
            guard offsets[position] >= 0, offsets[position] <= members.count,
                  position == 0 || offsets[position - 1] <= offsets[position] else {
                throw JSONFailure(.configuration, code: .invalidOperation)
            }
        }
        for member in members {
            try context.work()
            guard member.memberOrdinal >= 0, member.columnOrdinal >= 0,
                  member.columnOrdinal < columns.count else {
                throw JSONFailure(.configuration, code: .invalidOperation)
            }
        }
        let document = try context.transferDocumentOwnership()
        let result = JSONSparseTableProjection(document: document, selectedArrayPath: selection,
            rowCount: totalRows, columns: columns, rowOffsets: offsets, presentMembers: members,
            traversal: summary)
        selection = []; columns = []; offsets = []; members = []
        return result
    }
}
