// SPDX-License-Identifier: Apache-2.0
/// Counts only; no payload, clock, allocation count or process RSS.
public struct JSONOperationStatistics: Sendable, Equatable {
    public let accountingVersion: UInt32
    public let domain: JSONOperationDomain
    private let counters: [UInt64]
    public let peakLogicalRetainedBytes: UInt64
    public subscript(metric: JSONResourceMetric) -> UInt64 { counters[metric.index] }
    package init(domain: JSONOperationDomain, counters: [UInt64], peak: UInt64) {
        accountingVersion = JSONLogicalWeights.version
        self.domain = domain; self.counters = counters; peakLogicalRetainedBytes = peak
    }
}
