// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Exact set and numeric matrix shape, capacity and coordinate refusals.
///
/// Core selection, resource and cancellation errors retain their original types.
public enum JSONP2ProjectionFailure: Error, Sendable, Equatable {
    /// Adding a new structural representative would exceed the inclusive unique capacity.
    case uniqueItemLimitExceeded(limit: Int)
    /// The complete original row count exceeds the inclusive row capacity.
    case rowLimitExceeded(limit: Int)
    /// The original first-row width exceeds the inclusive column capacity.
    case columnLimitExceeded(limit: Int)
    /// The checked original dimension product exceeds the inclusive cell capacity.
    case elementLimitExceeded(limit: Int)
    /// The requested representative position is negative or outside the unique member count.
    case memberOutOfBounds(Int)
    /// The logical row is negative or outside the current orientation.
    case rowOutOfBounds(Int)
    /// The logical column is negative or outside the current orientation.
    case columnOutOfBounds(Int)
    /// The original row at the exact physical path has the reported non-array kind.
    case nonArrayRow(at: [JSONLocationComponent], kind: JSONTraversalKind)
    /// The original row width differs from the first row; no padding is performed.
    case raggedRow(at: [JSONLocationComponent], expected: Int, actual: Int)
    /// The original cell at the exact physical path is not a JSON number.
    case nonNumericCell(at: [JSONLocationComponent], kind: JSONTraversalKind)
}

internal enum P2Accounting {
    /// No multiplication traps or huge allocation are needed to test the boundary.
    static func product(_ rows: Int, _ columns: Int, limits: JSONLimits) throws -> Int {
        guard rows >= 0, columns >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        let (result, overflow) = rows.multipliedReportingOverflow(by: columns)
        guard !overflow else {
            throw JSONFailure(.resource, code: .counterOverflow, resource: .init(
                domain: .core, metric: .nodes, limit: limits[.nodes],
                attemptedUsage: nil, overflow: true))
        }
        return result
    }

    /// A NEW independent, full-source-admitted read. No constructor budget reset.
    static func read<T>(_ document: JSONDocument, selection: [JSONLocationComponent],
                        indices: [Int], limits: JSONLimits,
                        convert: (JSON) throws -> T) throws -> JSONOperationReport<T> {
        let scope = try JSONReadScope(document, limits: limits)
        defer { scope.invalidate() }
        let state = try scope.check()
        var path = JSONReadPath(scope: scope, components: [], bytes: 0)
        for component in selection {
            try state.meter.work()
            path = try scope.append(component, to: path.components, state: state)
            _ = try scope.check()
        }
        // At most two indices, owned by a constant-size accessor call.
        for index in indices {
            try state.meter.work()
            path = try scope.append(.index(index), to: path.components, state: state)
            _ = try scope.check()
        }
        let result = try scope.run(path.components) { state in
            try state.meter.work()
            return try convert(scope.select(path.components, state: state))
        }
        return try scope.complete(result)
    }
}
