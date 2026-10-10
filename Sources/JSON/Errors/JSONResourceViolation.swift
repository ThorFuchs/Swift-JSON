// SPDX-License-Identifier: Apache-2.0
public enum JSONOperationDomain: String, Sendable, Codable {
    case core, parsing, writing, coding, pointer, schemaCompilation, schemaEvaluation, regex, patch, streaming
}

/// On counter overflow attemptedUsage is nil and overflow is true.
public struct JSONResourceViolation: Sendable, Equatable, Codable {
    public let domain: JSONOperationDomain
    public let metric: JSONResourceMetric
    public let limit: UInt64
    public let attemptedUsage: UInt64?
    public let overflow: Bool
    package init(domain: JSONOperationDomain, metric: JSONResourceMetric, limit: UInt64,
                 attemptedUsage: UInt64?, overflow: Bool = false) {
        self.domain = domain; self.metric = metric; self.limit = limit
        self.attemptedUsage = attemptedUsage; self.overflow = overflow
    }
}
