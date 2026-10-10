// SPDX-License-Identifier: Apache-2.0
import JSON

/// Consumer-owned account, deliberately outside the JSON package. All public
/// owned-work buckets remain cumulative. Shape/live-capacity limits are per stage.
public struct RemainingWork {
    public enum Failure: Error { case terminated, accountingVersion, exceeded }
    public static let buckets: [JSONResourceMetric] = [.workUnits, .numericWorkUnits,
        .compileWorkUnits, .evaluationWorkUnits, .regexCompileWorkUnits,
        .aggregateRegexWorkUnits, .patchWorkUnits, .totalWorkUnits]
    private var available: JSONLimits
    public private(set) var terminated = false
    public private(set) var stages: [Stage] = []
    public struct Stage: Codable, Sendable {
        public let name: String
        public let work: UInt64
        public let remaining: UInt64
        public let accountingVersion: UInt32
    }
    public init(limits: JSONLimits) throws { try limits.validate(); available = limits }
    public var remaining: UInt64 { available[.workUnits] }
    public mutating func perform<T>(_ name: String, _ operation: (JSONLimits) throws -> JSONOperationReport<T>) throws -> T {
        guard !terminated else { throw Failure.terminated }
        do {
            let report = try operation(available)
            guard report.statistics.accountingVersion == 1 else { throw Failure.accountingVersion }
            var next = available
            for metric in Self.buckets {
                let (value, underflow) = next[metric].subtractingReportingOverflow(report.statistics[metric])
                guard !underflow else { throw Failure.exceeded }
                next[metric] = value
            }
            available = next
            stages.append(.init(name: name, work: report.statistics[.workUnits],
                remaining: remaining, accountingVersion: report.statistics.accountingVersion))
            return report.result
        } catch { terminated = true; throw error }
    }
}
