// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONFilterRuntime

/// An immutable, checked-Sendable compiled program in the existing query dialect.
///
/// No input source, mutable invocation, file or process state is captured. This
/// provisional extraction API uses the same compiler and VM as `swift-json query`.
public struct JSONTransformProgram: Sendable {
    let program: FilterProgram
    let planReservation: UInt64
    let variables: Set<String>

    /// Compiles explicit source using finite native and transform limits.
    /// - Parameters:
    ///   - source: Query source in the documented jq-inspired subset.
    ///   - variables: Names supplied by each invocation, without `$` prefixes.
    ///   - limits: Finite compilation policy; execution has its own bounded scope.
    public static func compile(_ source: String, variables: Set<String> = [],
                               limits: JSONTransformLimits = .init()) throws -> Self {
        do {
            var context = try TransformRuntimeContext(limits: limits.runtime)
            for name in variables {
                try context.charge(.bindings)
                try JSONAdmission.text(name, key: true, meter: &context.meter, owned: true)
            }
            let program = try FilterCompiler.compile(source, variables: variables, context: &context)
            return .init(program: program, planReservation: context.meter.used(.retainedBytes), variables: variables)
        } catch { throw JSONTransformFailure.classify(error) }
    }

    /// Runs a synchronous, invocation-owned throwing pull scope.
    ///
    /// A present null result is distinct from EOF. The scope releases frames,
    /// provider and owned bindings on exit. Extracted JSON copies become caller
    /// storage; keep the output handle alive while using its accounted alias.
    /// A caught operational failure still prevents successful scope completion.
    /// - Parameters:
    ///   - input: Exact native root, admitted under this invocation's limits.
    ///   - bindings: Exact values for precisely the declared variable names.
    ///   - limits: Finite cumulative invocation policy.
    ///   - source: Optional host callback for `input`/`inputs`; no ambient I/O.
    ///   - body: Synchronous caller work pulling ordered zero/one/many outputs.
    public func withExecution<Result>(input: JSON, bindings: [String: JSON] = [:],
                                      limits: JSONTransformLimits = .init(),
                                      source: (() throws -> JSON?)? = nil,
                                      _ body: (borrowing JSONTransformExecution) throws -> Result) throws -> JSONOperationReport<Result> {
        let execution = try JSONTransformExecution.make(plan: self, input: input, bindings: bindings, limits: limits, source: source)
        let result: Result
        do { result = try body(execution) }
        catch {
            // Caller callback errors keep their identity. Cleanup cannot replace
            // the originating failure or reopen the operation ledger.
            do { try execution.close() } catch { execution.recordCleanupFailure(error) }
            throw error
        }
        do {
            try execution.checkCompletion()
            try execution.close()
            return .init(result: result, statistics: execution.statistics)
        } catch {
            let failure = JSONTransformFailure.classify(error)
            do { try execution.close() } catch { execution.recordCleanupFailure(error) }
            throw failure
        }
    }

    /// Compiles on the CLI host's existing cumulative context; no fresh meter.
    package static func compileAccounted(_ source: String, variables: Set<String>,
                                         context: inout TransformRuntimeContext) throws -> Self {
        let program = try FilterCompiler.compile(source, variables: variables, context: &context)
        return .init(program: program, planReservation: 0, variables: variables)
    }
    /// Starts the same VM while borrowing the CLI job's accounting and leases.
    package func makeAccountedExecution(input: FilterYield, bindings: [String: FilterYield],
                                       context: inout TransformRuntimeContext) throws -> FilterVM {
        try FilterVM(program: program, input: input, bindings: bindings, context: &context)
    }
}
