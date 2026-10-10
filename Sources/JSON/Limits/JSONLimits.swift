// SPDX-License-Identifier: Apache-2.0
/// Stable resource identifiers. Units and initial policy are in ResourceLimits.md.
public enum JSONResourceMetric: String, CaseIterable, Sendable, Codable {
    case inputBytes
    case maxDepth
    case nodes
    case objectMembers
    case arrayItems
    case stringBytes
    case aggregateTextBytes
    case keyBytes
    case numberDigits
    case numberTokenBytes
    case absoluteExponent
    case retainedBytes
    case workUnits
    case numericWorkUnits
    case outputBytes
    case sourceMapEntries
    case issues
    case diagnosticBytes
    case cancellationQuantum
    case schemaDocuments
    case schemaBytes
    case schemaNodes
    case referenceEdges
    case compileWorkUnits
    case compiledPlanBytes
    case evaluationWorkUnits
    case evaluationFrames
    case annotationEntries
    case annotationBytes
    case regexPatternBytes
    case aggregateRegexPatternBytes
    case regexProgramInstructions
    case regexCompileWorkUnits
    case regexSearchWorkUnits
    case aggregateRegexWorkUnits
    case regexRetainedBytes
    case regexCaptureGroups
    case chunkBytes
    case pendingEvents
    case pendingValues
    case totalInputBytes
    case totalRecords
    case totalWorkUnits
    case operations
    case pointerBytes
    case pointerTokens
    case patchWorkUnits
    case totalScannedNodes
    case maxReusableBufferBytes

    package var index: Int {
        switch self {
        case .inputBytes: 0
        case .maxDepth: 1
        case .nodes: 2
        case .objectMembers: 3
        case .arrayItems: 4
        case .stringBytes: 5
        case .aggregateTextBytes: 6
        case .keyBytes: 7
        case .numberDigits: 8
        case .numberTokenBytes: 9
        case .absoluteExponent: 10
        case .retainedBytes: 11
        case .workUnits: 12
        case .numericWorkUnits: 13
        case .outputBytes: 14
        case .sourceMapEntries: 15
        case .issues: 16
        case .diagnosticBytes: 17
        case .cancellationQuantum: 18
        case .schemaDocuments: 19
        case .schemaBytes: 20
        case .schemaNodes: 21
        case .referenceEdges: 22
        case .compileWorkUnits: 23
        case .compiledPlanBytes: 24
        case .evaluationWorkUnits: 25
        case .evaluationFrames: 26
        case .annotationEntries: 27
        case .annotationBytes: 28
        case .regexPatternBytes: 29
        case .aggregateRegexPatternBytes: 30
        case .regexProgramInstructions: 31
        case .regexCompileWorkUnits: 32
        case .regexSearchWorkUnits: 33
        case .aggregateRegexWorkUnits: 34
        case .regexRetainedBytes: 35
        case .regexCaptureGroups: 36
        case .chunkBytes: 37
        case .pendingEvents: 38
        case .pendingValues: 39
        case .totalInputBytes: 40
        case .totalRecords: 41
        case .totalWorkUnits: 42
        case .operations: 43
        case .pointerBytes: 44
        case .pointerTokens: 45
        case .patchWorkUnits: 46
        case .totalScannedNodes: 47
        case .maxReusableBufferBytes: 48
        }
    }
}

public enum JSONResourceProfile: Sendable { case conservative, balanced, offline }

/// Finite inclusive limits. Policy values are initial and require native calibration.
public struct JSONLimits: Sendable, Equatable {
    private var maxima: [UInt64]

    public init(profile: JSONResourceProfile = .balanced) {
        switch profile {
        case .conservative: maxima = [4194304, 64, 100000, 20000, 100000, 1048576, 4194304, 16384, 1024, 2048, 100000, 16777216, 8000000, 250000, 4194304, 100000, 32, 65536, 1024, 16, 4194304, 20000, 20000, 4000000, 8388608, 2000000, 256, 20000, 2097152, 4096, 65536, 20000, 250000, 100000, 250000, 2097152, 128, 65536, 1, 1, 268435456, 100000, 512000000, 128, 4096, 64, 2000000, 2000000, 524288]
        case .balanced: maxima = [33554432, 128, 1000000, 100000, 1000000, 8388608, 16777216, 65536, 4096, 8192, 1000000, 67108864, 64000000, 1000000, 33554432, 1000000, 128, 262144, 1024, 128, 33554432, 100000, 200000, 32000000, 33554432, 16000000, 1024, 100000, 8388608, 16384, 262144, 100000, 2000000, 500000, 2000000, 8388608, 512, 262144, 1, 1, 1073741824, 1000000, 2147483648, 1024, 16384, 128, 16000000, 16000000, 2097152]
        case .offline: maxima = [268435456, 256, 4000000, 500000, 4000000, 67108864, 134217728, 262144, 16384, 32768, 10000000, 536870912, 512000000, 8000000, 268435456, 4000000, 512, 1048576, 1024, 512, 268435456, 1000000, 2000000, 256000000, 268435456, 128000000, 4096, 1000000, 67108864, 65536, 2097152, 1000000, 16000000, 4000000, 16000000, 67108864, 2048, 1048576, 1, 1, 68719476736, 16000000, 137438953472, 10000, 65536, 256, 128000000, 128000000, 8388608]
        }
    }
    public static let conservative = Self(profile: .conservative)
    public static let balanced = Self(profile: .balanced)
    public static let offline = Self(profile: .offline)

    public subscript(metric: JSONResourceMetric) -> UInt64 {
        get { maxima[metric.index] }
        set { maxima[metric.index] = newValue }
    }

    /// Rejects unsupported capacity and cancellation configurations at operation entry.
    public func validate() throws {
        for metric in JSONResourceMetric.allCases {
            guard self[metric] < UInt64(Int.max) else {
                throw JSONFailure(.configuration, code: .invalidLimits)
            }
        }
        guard (1...1024).contains(self[.cancellationQuantum]),
              self[.pendingEvents] <= 1, self[.pendingValues] <= 1 else {
            throw JSONFailure(.configuration, code: .invalidLimits)
        }
    }
}

/// Version 1 logical weights; these are not measurements of heap size or RSS.
public enum JSONLogicalWeights {
    public static let version: UInt32 = 1
    public static let node: UInt64 = 32
    public static let member: UInt64 = 24
    public static let arraySlot: UInt64 = 16
    public static let frame: UInt64 = 16
    public static let sourceMapEntry: UInt64 = 32
    public static let indexSlot: UInt64 = 32
    public static let annotationEntry: UInt64 = 32
    public static let regexInstruction: UInt64 = 16
    public static let regexStateRecord: UInt64 = 32
}

extension JSONLimits {
    package func intersection(_ other: Self) throws -> Self {
        try validate(); try other.validate()
        var result = self
        for metric in JSONResourceMetric.allCases { result[metric] = min(self[metric], other[metric]) }
        return result
    }
}
