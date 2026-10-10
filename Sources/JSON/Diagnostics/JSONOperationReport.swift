// SPDX-License-Identifier: Apache-2.0
public struct JSONOperationReport<Result> {
    public let result: Result
    public let statistics: JSONOperationStatistics
    public init(result: Result, statistics: JSONOperationStatistics) {
        self.result = result; self.statistics = statistics
    }
}
extension JSONOperationReport: Sendable where Result: Sendable {}
