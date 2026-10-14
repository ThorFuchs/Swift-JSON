// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONHTML
import JSONSchema
import JSONFilterRuntime
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Failure diagnostics use prepaid, finite work and ownership. A terminal native
/// ledger is never replaced just to serialize an error; payload bytes are absent.
package struct CLIDiagnostics {
    private var allowance: UInt64 = 0
    package init(context: inout CLIJobContext) throws { try reserve(256, context: &context) }
    package mutating func reserve(_ bytes: UInt64, context: inout CLIJobContext) throws {
        guard bytes > allowance else { return }
        let extra = bytes - allowance
        try context.work(extra * 8 + 1); try context.meter.retain(extra * 4)
        allowance = bytes
    }
    package static func classify(_ error: any Error) -> CLIError {
        if let error = error as? CLIError { return error }
        if let failure = error as? FilterCompileFailure { return .init(.compile, failure.code, byteOffset: UInt64(failure.offset)) }
        if let failure = error as? FilterLanguageFailure { return .init(.language, failure.code) }
        if error is CancellationError { return .init(.cancelled, "cancelled") }
        if let error = error as? JSONFailure {
            let category: CLIError.Category = error.category == .resource ? .resource : (error.category == .configuration ? .usage : .input)
            return .init(category, error.code.rawValue, metric: error.resource?.metric.rawValue, limit: error.resource?.limit, attemptedUsage: error.resource?.attemptedUsage, overflow: error.resource?.overflow ?? (error.code == .counterOverflow), byteOffset: error.location?.byteOffset)
        }
        if let failure = error as? JSONHTMLFailure {
            switch failure {
            case .invalidConfiguration: return .init(.usage, "invalidHTMLConfiguration")
            case .limitExceeded(let metric, let limit, let attempted): return .init(.resource, "limitExceeded", metric: metric.rawValue, limit: limit, attemptedUsage: attempted)
            case .counterOverflow(let metric): return .init(.resource, "counterOverflow", metric: metric.rawValue, overflow: true)
            }
        }
        if let failure = error as? JSONSchemaCompilationFailure { return .init(.input, "schemaCompilation." + failure.category.rawValue) }
        if let failure = error as? JSONSchemaEvaluationFailure { return .init(.input, "schemaEvaluation." + failure.category.rawValue) }
        // Schema errors remain operational; no unknown error becomes validation false.
        return .init(.input, "operationFailed")
    }
    package func emit(error: CLIError?, completed: Bool, wantsReport: Bool, json: Bool, context: inout CLIJobContext) {
        let capacity = min(allowance, context.limits[.diagnosticBytes])
        guard capacity > 0 else { return }
        var output = "", used: UInt64 = 0
        func append(_ parts: [String], to text: inout String, count: inout UInt64, maximum: UInt64) -> Bool {
            var size: UInt64 = 0
            for part in parts { size += UInt64(part.utf8.count) }
            guard size <= maximum - min(count, maximum) else { return false }
            for part in parts { text += part }
            count += size; return true
        }
        if let error {
            // All codes and metric names are fixed ASCII identifiers, never instance text.
            var parts = json ? ["{\"kind\":\"diagnostic\",\"version\":1,\"category\":\"", error.category.rawValue, "\",\"code\":\"", error.code, "\"}\n"] : ["swift-json: ", error.category.rawValue, ": ", error.code, "\n"]
            if json {
                parts.removeLast()
                parts += ["\"", ",\"metric\":", error.metric.map { "\"" + $0 + "\"" } ?? "null",
                          ",\"limit\":", error.limit.map(String.init) ?? "null",
                          ",\"attemptedUsage\":", error.attemptedUsage.map(String.init) ?? "null",
                          ",\"overflow\":", String(error.overflow),
                          ",\"byteOffset\":", error.byteOffset.map(String.init) ?? "null", "}\n"]
            }
            _ = append(parts, to: &output, count: &used, maximum: capacity)
        }
        if wantsReport {
            var report = "", count: UInt64 = 0, fits = true
            func part(_ parts: String...) { if fits { fits = append(parts, to: &report, count: &count, maximum: capacity - used) } }
            let statistics = context.meter.statistics()
            let workLimit = min(context.limits[.totalWorkUnits], context.meter.limits[.workUnits])
            let remaining = workLimit - min(workLimit, context.used(.totalWorkUnits))
            part("{\"kind\":\"report\",\"version\":1,\"completed\":", String(completed))
            part(",\"inputRecords\":", String(context.used(.totalRecords)))
            part(",\"outputResults\":", String(context.used(.totalResults)))
            part(",\"committedOutputResults\":", String(context.committedResults))
            part(",\"totalInputBytes\":", String(context.used(.totalInputBytes)))
            part(",\"totalOutputBytes\":", String(context.used(.totalOutputBytes)))
            part(",\"totalWorkUnits\":", String(context.used(.totalWorkUnits)))
            part(",\"peakLogicalRetainedBytes\":", String(statistics.peakLogicalRetainedBytes))
            part(",\"remainingWorkUnits\":", String(remaining))
            part(",\"limitsOrigin\":{\"profile\":\"", context.limits.profileName,
                 "\",\"overrideFileApplied\":", String(context.limitsFileApplied),
                 ",\"maxIssues\":", context.maxIssues.map(String.init) ?? "null", "}")
            part(",\"resolvedLimits\":{\"cli\":{")
            for (index, metric) in CLIResourceMetric.allCases.enumerated() {
                if !fits { break }
                part(index == 0 ? "" : ",", "\"", metric.rawValue, "\":", String(context.limits[metric]))
            }
            part("},\"json\":{")
            for (index, metric) in JSONResourceMetric.allCases.enumerated() {
                if !fits { break }
                part(index == 0 ? "" : ",", "\"", metric.rawValue, "\":", String(context.meter.limits[metric]))
            }
            part("}},\"arithmeticPolicy\":\"", context.divisionScale.map { "half-even-scale-\($0)" } ?? "exact",
                 "\",\"roundedDivisions\":", String(context.roundedDivisions), ",\"failure\":")
            if let error { part("{\"category\":\"", error.category.rawValue, "\",\"code\":\"", error.code, "\"}") }
            else { part("null") }
            part("}\n")
            // A bounded incomplete report is discarded before stderr handoff.
            if fits { _ = append([report], to: &output, count: &used, maximum: capacity) }
        }
        let bytes = Array(output.utf8)
        guard context.acceptTerminalDiagnostics(UInt64(bytes.count)), !bytes.isEmpty else { return }
        // Best effort has a fixed four-poll bound and no retry growth after terminal error.
        let flags = fcntl(STDERR_FILENO, F_GETFL)
        guard flags >= 0, fcntl(STDERR_FILENO, F_SETFL, flags | O_NONBLOCK) == 0 else { return }
        defer { _ = fcntl(STDERR_FILENO, F_SETFL, flags) }
        var offset = 0
        for _ in 0..<4 {
            if offset == bytes.count { break }
            var state = pollfd(fd: STDERR_FILENO, events: Int16(POLLOUT), revents: 0)
            guard unsafe poll(&state, 1, 100) > 0 else { continue }
            let count = bytes.withUnsafeBytes {
                #if canImport(Darwin)
                unsafe Darwin.write(STDERR_FILENO, $0.baseAddress!.advanced(by: offset), bytes.count - offset)
                #else
                unsafe Glibc.write(STDERR_FILENO, $0.baseAddress!.advanced(by: offset), bytes.count - offset)
                #endif
            }
            guard count > 0 else { break }; offset += count
        }
    }
}
