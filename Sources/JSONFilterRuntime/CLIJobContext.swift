// SPDX-License-Identifier: Apache-2.0
import JSON

/// CLI-only quotas. Core metric identifiers and their 49 meanings remain unchanged.
package enum CLIResourceMetric: String, CaseIterable, Sendable {
    case argvBytes, querySourceBytes, queryTokens, astNodes, queryDepth
    case runtimeFrames, bindings, collectionValues, totalInputBytes, totalOutputBytes
    case totalRecords, totalResults, totalWorkUnits, retainedBytes, diagnosticBytes, diskStagingBytes
    package var index: Int {
        switch self {
        case .argvBytes: 0
        case .querySourceBytes: 1
        case .queryTokens: 2
        case .astNodes: 3
        case .queryDepth: 4
        case .runtimeFrames: 5
        case .bindings: 6
        case .collectionValues: 7
        case .totalInputBytes: 8
        case .totalOutputBytes: 9
        case .totalRecords: 10
        case .totalResults: 11
        case .totalWorkUnits: 12
        case .retainedBytes: 13
        case .diagnosticBytes: 14
        case .diskStagingBytes: 15
        }
    }
    package var cumulative: Bool {
        switch self {
        case .totalInputBytes, .totalOutputBytes, .totalRecords, .totalResults, .totalWorkUnits, .diskStagingBytes: true
        default: false
        }
    }
}
package struct CLILimits: Sendable, Equatable {
    package var core: JSONLimits
    package let profileName: String
    private var caps: [UInt64]
    package init(profile: JSONResourceProfile = .balanced) {
        core = .init(profile: profile)
        switch profile {
        case .conservative: profileName = "conservative"; caps = [32768,32768,8192,4096,128,1024,128,65536,67108864,67108864,65536,65536,16777216,16777216,8192,67108864]
        case .balanced: profileName = "balanced"; caps = [262144,262144,65536,32768,512,8192,1024,1048576,1073741824,1073741824,1048576,1048576,268435456,134217728,65536,1073741824]
        case .offline: profileName = "offline"; caps = [1048576,1048576,262144,131072,2048,32768,4096,8388608,17179869184,17179869184,8388608,8388608,2147483648,536870912,262144,17179869184]
        }
    }
    package subscript(_ metric: CLIResourceMetric) -> UInt64 {
        get { caps[metric.index] }
        set { caps[metric.index] = newValue }
    }
    package func validate() throws {
        try core.validate()
        for metric in CLIResourceMetric.allCases {
            let cap = self[metric]
            guard cap < UInt64.max, metric.cumulative || cap < UInt64(Int.max) else { throw CLIError(.usage, "invalidLimits") }
        }
    }
    package var effectiveCore: JSONLimits {
        var result = core
        result[.workUnits] = min(result[.workUnits], self[.totalWorkUnits])
        result[.retainedBytes] = min(result[.retainedBytes], self[.retainedBytes])
        return result
    }
}
package struct CLIError: Error, Sendable, Equatable {
    package enum Category: String, Sendable { case usage, compile, language, input, resource, io, cancelled }
    package let category: Category
    package let code: String
    package let metric: String?
    package init(_ category: Category, _ code: String, metric: String? = nil) {
        self.category = category; self.code = code; self.metric = metric
    }
    package var exit: Int32 {
        switch category {
        case .usage: 2
        case .compile: 3
        case .language, .input: 5
        case .resource: 6
        case .io: 7
        case .cancelled: 130
        }
    }
}
/// One noncopyable job spans argv, files, native grammars, query execution and output.
/// Mutable runtime state belongs to the invocation; immutable plans may be shared.
package struct CLIJobContext: ~Copyable {
    package var meter: JSONWorkMeter
    package private(set) var limits: CLILimits
    private var counters = Array(repeating: UInt64(0), count: CLIResourceMetric.allCases.count)
    private var failure: (any Error)?
    package var limitsFileApplied = false
    package var maxIssues: UInt64? = nil
    package var roundedDivisions: UInt64 = 0
    package var divisionScale: Int? = nil
    package var committedResults: UInt64 = 0
    package init(limits: CLILimits = .init()) throws {
        try limits.validate()
        meter = try .init(limits: limits.effectiveCore, domain: .parsing, trackAcceptedCapacities: true)
        self.limits = limits
    }
    package mutating func checkpoint() throws {
        if let failure { throw failure }
        do { try meter.checkpoint() }
        catch { latch(error); throw error }
    }
    package mutating func latch(_ error: any Error) { if failure == nil { failure = error; meter.recordFailure(error) } }
    package func used(_ metric: CLIResourceMetric) -> UInt64 {
        switch metric {
        case .totalWorkUnits: meter.used(.workUnits)
        case .retainedBytes: meter.used(.retainedBytes)
        default: counters[metric.index]
        }
    }
    package mutating func require(_ metric: CLIResourceMetric, _ attempted: UInt64) throws {
        try checkpoint()
        guard attempted <= limits[metric] else {
            let error = CLIError(.resource, "limitExceeded", metric: metric.rawValue)
            latch(error); throw error
        }
    }
    package mutating func charge(_ metric: CLIResourceMetric, _ amount: UInt64 = 1) throws {
        let (next, overflow) = used(metric).addingReportingOverflow(amount)
        guard !overflow else { let error = CLIError(.resource, "counterOverflow", metric: metric.rawValue); latch(error); throw error }
        try require(metric, next)
        switch metric {
        case .totalWorkUnits: try meter.work(amount)
        case .retainedBytes: try meter.retain(amount)
        default: counters[metric.index] = next
        }
    }
    package mutating func release(_ metric: CLIResourceMetric, _ amount: UInt64) throws {
        guard !metric.cumulative, amount <= used(metric) else { throw CLIError(.usage, "invalidRefund") }
        if metric == .retainedBytes { try meter.release(amount) }
        else { counters[metric.index] -= amount }
    }
    package mutating func work(_ amount: UInt64 = 1) throws { try charge(.totalWorkUnits, amount) }
    package mutating func domain(_ domain: JSONOperationDomain) throws { try meter.operationDomain(domain) }
    /// The only post-terminal accounting mutation spends previously reserved diagnostic work.
    /// It cannot reopen data operations, refund work or exceed aggregate diagnostic capacity.
    package mutating func acceptTerminalDiagnostics(_ bytes: UInt64) -> Bool {
        let (next, overflow) = counters[CLIResourceMetric.diagnosticBytes.index].addingReportingOverflow(bytes)
        guard !overflow, next <= limits[.diagnosticBytes] else { return false }
        counters[CLIResourceMetric.diagnosticBytes.index] = next
        return true
    }
    package mutating func configure(_ requested: CLILimits) throws {
        try requested.validate(); try checkpoint()
        for metric in CLIResourceMetric.allCases { guard used(metric) <= requested[metric] else { throw CLIError(.resource, "limitExceeded", metric: metric.rawValue) } }
        try meter.configure(requested.effectiveCore)
        limits = requested
    }
}
