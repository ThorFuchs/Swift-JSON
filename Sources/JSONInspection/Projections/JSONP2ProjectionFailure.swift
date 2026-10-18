// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Experimental refusals; no additions to the released public error surface.
package enum JSONP2ProjectionFailure: Error, Sendable, Equatable {
    case uniqueItemLimitExceeded(limit: Int)
    case rowLimitExceeded(limit: Int)
    case columnLimitExceeded(limit: Int)
    case elementLimitExceeded(limit: Int)
    case memberOutOfBounds(Int)
    case rowOutOfBounds(Int)
    case columnOutOfBounds(Int)
    case nonArrayRow(at: [JSONLocationComponent], kind: JSONTraversalKind)
    case raggedRow(at: [JSONLocationComponent], expected: Int, actual: Int)
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
