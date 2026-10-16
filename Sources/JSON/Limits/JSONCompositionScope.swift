// SPDX-License-Identifier: Apache-2.0
import Foundation

fileprivate final class JSONCompositionState {
    var context: JSONOperationContext
    init(limits: JSONLimits) throws {
        context = try JSONOperationContext(limits: limits, domain: .core, trackAcceptedCapacities: true)
    }
}

/// A borrowed immutable root admitted by one composition invocation.
///
/// Obtain this handle through ``JSONCompositionScope/withAdmittedRoot(_:_:)`` or
/// ``JSONCompositionScope/withParsedDocument(_:_:)``. It has no public initializer,
/// value accessor or refund. Only its owning scope may resolve against it. The
/// borrowed noncopyable handle cannot be returned, substituted or sent to a task.
public struct JSONCompositionRoot: ~Copyable {
    fileprivate let owner: JSONCompositionState
    fileprivate let value: JSON

    fileprivate init(owner: JSONCompositionState, value: JSON) {
        self.owner = owner
        self.value = value
    }
}

/// One synchronous, noncopyable composition of native and explicitly instrumented work.
///
/// Create a scope with ``JSON/withComposition(limits:_:)``. Native results and
/// external reservations remain logically owned until completion, even if a local
/// value dies. There is no public refund or continuation. This conservative model
/// covers aliases and final output overlap, not arbitrary callback instructions or RSS.
public struct JSONCompositionScope: ~Copyable {
    private let state: JSONCompositionState

    private init(limits: JSONLimits) throws {
        state = try JSONCompositionState(limits: limits)
    }

    /// Executes a native helper on the sole ledger; all owned errors are terminal.
    package borrowing func withMeter<T>(domain: JSONOperationDomain = .core,
                                      _ body: (inout JSONWorkMeter) throws -> T) throws -> T {
        do {
            try state.context.meter.operationDomain(domain)
            let result = try body(&state.context.meter)
            try state.context.meter.operationDomain(.core)
            return result
        } catch {
            state.context.meter.recordFailure(error)
            throw error
        }
    }

    /// Parses strict Data, retaining the exact root, source copy and source map.
    ///
    /// The whole byte-buffer reservation precedes allocation. The input buffer is
    /// conservatively retained in the ledger after parsing; caller Data is excluded.
    /// - Parameter data: Caller-owned UTF-8 input, never fetched or repaired.
    /// - Returns: The exact source-backed document.
    /// - Throws: Original native failure or cancellation; caught failures stay terminal.
    public borrowing func parseDocument(_ data: Data) throws -> JSONDocument {
        try withMeter(domain: .parsing) { meter in
            try meter.require(.inputBytes, UInt64(data.count))
            try meter.retain(UInt64(data.count))
            var bytes: [UInt8] = []
            bytes.reserveCapacity(data.count)
            for byte in data { try meter.work(); bytes.append(byte) }
            return try JSONParser().parseDocument(bytes, source: nil, meter: &meter)
        }
    }

    /// Admits and reserves an existing exact graph without conversion.
    /// - Parameter value: Trusted caller value; its prior construction is caller work.
    /// - Returns: The admitted value. Each call reserves a complete logical graph.
    /// - Throws: Native admission failure or cancellation.
    public borrowing func admitTrusted(_ value: JSON) throws -> JSON {
        try withMeter { meter in
            try JSONAdmission.value(value, meter: &meter, owned: true)
            return value
        }
    }

    /// Admits an immutable graph once and borrows an invocation-bound lookup handle.
    ///
    /// The root graph and one 16-byte logical handle slot remain reserved until
    /// composition completion. Repeated lookups admit their Pointer and selected
    /// result, without traversing or reserving this root again. Each new call to
    /// this method admits a complete graph, including aliases of an earlier root.
    /// - Parameters:
    ///   - value: Trusted caller value; its prior construction is caller work.
    ///   - body: Synchronous work borrowing the immutable admitted root.
    /// - Returns: The callback result; the handle cannot be returned.
    /// - Throws: Native terminal failure, cancellation or callback error.
    public borrowing func withAdmittedRoot<Result>(_ value: JSON,
        _ body: (borrowing JSONCompositionRoot) throws -> Result) throws -> Result {
        try withMeter { try JSONAdmission.value(value, meter: &$0, owned: true) }
        return try borrowingRoot(value, body)
    }

    /// Parses a source-backed document and borrows its already-admitted root.
    ///
    /// Parsing, source bytes, mapping and the root share this invocation's ledger.
    /// The handle adds one logical slot and shares the parsed immutable graph;
    /// it does not perform a second admission of the parsed root. The document
    /// may be returned. Its existing reservation lasts until composition exit.
    /// - Parameters:
    ///   - data: Caller-owned strict UTF-8 input.
    ///   - body: Synchronous work receiving the document and borrowing its root handle.
    /// - Returns: The callback result, which may include the document or selected values.
    /// - Throws: Native terminal failure, cancellation or callback error.
    public borrowing func withParsedDocument<Result>(_ data: Data,
        _ body: (JSONDocument, borrowing JSONCompositionRoot) throws -> Result) throws -> Result {
        let document = try parseDocument(data)
        return try borrowingRoot(document.root) { root in try body(document, root) }
    }

    private borrowing func borrowingRoot<Result>(_ value: JSON,
        _ body: (borrowing JSONCompositionRoot) throws -> Result) throws -> Result {
        try withMeter { meter in
            try meter.work()
            try meter.retain(JSONLogicalWeights.frame)
        }
        let root = JSONCompositionRoot(owner: state, value: value)
        let original = state.context.meter.continuation
        // No inout meter access spans caller code: nested native calls use the
        // same invocation, and a caught owned failure still prevents this return.
        do {
            let result = try body(root)
            try original.check(state.context.meter)
            return result
        } catch {
            try original.check(state.context.meter)
            throw error
        }
    }

    /// Constructs an exact Pointer using this invocation's remaining budget.
    /// - Parameter tokens: Caller-owned decoded tokens.
    /// - Returns: The admitted Pointer.
    /// - Throws: Original native Pointer/admission failure or cancellation.
    public borrowing func pointer(tokens: [String]) throws -> JSONPointer {
        try withMeter(domain: .pointer) { try JSONPointer.fromStrings(tokens, meter: &$0) }
    }

    /// Parses RFC 6901 text using the same ledger.
    /// - Parameter text: Encoded Pointer text; empty selects the root.
    /// - Returns: The admitted Pointer.
    /// - Throws: Original native Pointer/admission failure or cancellation.
    public borrowing func pointer(parsing text: String) throws -> JSONPointer {
        try withMeter(domain: .pointer) { try JSONPointer.parse(text, meter: &$0) }
    }

    /// Decodes a URI fragment exactly once, then parses its Pointer escapes.
    /// - Parameter fragment: Encoded fragment including its leading #.
    /// - Returns: The admitted Pointer.
    /// - Throws: Original native Pointer/admission failure or cancellation.
    public borrowing func pointer(uriFragment fragment: String) throws -> JSONPointer {
        try withMeter(domain: .pointer) { try JSONPointer.uriFragment(fragment, meter: &$0) }
    }

    /// Appends an exact decoded key, reserving the complete resulting Pointer.
    /// - Parameters:
    ///   - pointer: A caller or scope-created Pointer.
    ///   - key: The decoded token, also usable as a strict array index spelling.
    /// - Returns: The admitted appended Pointer.
    /// - Throws: Original native Pointer/admission failure or cancellation.
    public borrowing func appending(_ pointer: JSONPointer, key: String) throws -> JSONPointer {
        try withMeter(domain: .pointer) { try pointer.appending(key: key, meter: &$0) }
    }

    /// Resolves exact keys and strict array indices after admitting both inputs.
    ///
    /// Each input graph and selected output graph is conservatively reserved anew;
    /// aliases never refund prior ownership. Native typed errors are preserved.
    /// - Parameters:
    ///   - pointer: The exact path to resolve.
    ///   - value: A caller or scope-created root.
    /// - Returns: The selected exact value.
    /// - Throws: Original native Pointer/admission failure or cancellation.
    public borrowing func resolve(_ pointer: JSONPointer, in value: JSON) throws -> JSON {
        try withMeter(domain: .pointer) { meter in
            try JSONAdmission.value(value, meter: &meter, owned: true)
            let admitted = try JSONPointer.decodedTokens(pointer.tokens, meter: &meter)
            let result = try admitted.resolve(in: value, meter: &meter)
            try JSONAdmission.value(result, meter: &meter, owned: true)
            return result
        }
    }

    /// Resolves against this invocation's admitted immutable root.
    ///
    /// Owner identity is checked before navigation. Pointer admission and native
    /// navigation consume cumulative work; the selected result graph is reserved
    /// anew, even for aliases or an empty Pointer selecting the entire root.
    /// - Parameters:
    ///   - pointer: Caller or scope-created exact Pointer.
    ///   - root: Borrowed handle produced by this scope's root callback.
    /// - Returns: The selected exact value with a conservative output reservation.
    /// - Throws: Wrong-owner configuration failure, native failure or cancellation.
    public borrowing func resolve(_ pointer: JSONPointer, in root: borrowing JSONCompositionRoot) throws -> JSON {
        try withMeter(domain: .pointer) { meter in
            try meter.work()
            guard root.owner === state else { throw JSONFailure(.configuration, code: .invalidOperation) }
            let admitted = try JSONPointer.decodedTokens(pointer.tokens, meter: &meter)
            let result = try admitted.resolve(in: root.value, meter: &meter)
            try JSONAdmission.value(result, meter: &meter, owned: true)
            return result
        }
    }

    /// Charges instrumented adapter work once to aggregate core work.
    /// - Parameter units: Declared primitive work admitted before performing it.
    /// - Throws: Quota/overflow failure or cancellation, permanently terminal.
    public borrowing func chargeExternalWork(_ units: UInt64) throws {
        try withMeter { try $0.work(units) }
    }

    /// Reserves adapter-owned logical bytes until scope completion, without refund.
    ///
    /// Call before growth. Separate calls count separately even for physical aliases.
    /// Units are adapter-declared logical bytes, not measured heap allocation. This
    /// never charges compiledPlanBytes. Zero does not certify opaque storage as free.
    /// - Parameters:
    ///   - bytes: Logical weight per unit.
    ///   - count: Number of units, multiplied with checked UInt64 arithmetic.
    /// - Throws: Quota/overflow failure or cancellation, permanently terminal.
    public borrowing func reserveExternalLogicalBytes(_ bytes: UInt64, count: UInt64 = 1) throws {
        try withMeter { meter in
            let (total, overflow) = bytes.multipliedReportingOverflow(by: count)
            guard !overflow else {
                throw JSONFailure(.resource, code: .counterOverflow, resource: .init(
                    domain: .core, metric: .retainedBytes, limit: meter.limits[.retainedBytes],
                    attemptedUsage: nil, overflow: true))
            }
            try meter.retain(total)
        }
    }

    /// Checks cancellation and prior terminal failure before adapter work.
    /// - Throws: The original terminal failure or cancellation.
    public borrowing func checkpoint() throws { try withMeter { try $0.checkpoint() } }

    /// Tightens finite limits without resetting work, live reservations or admissions.
    /// - Parameter limits: Requested ceilings, intersected with existing ceilings.
    /// - Throws: Invalid configuration, prior admission/work violation or cancellation.
    public borrowing func restrict(to limits: JSONLimits) throws {
        try withMeter { try $0.restrict(to: limits) }
    }

    fileprivate static func run<T>(limits: JSONLimits,
                                   _ body: (borrowing Self) throws -> T) throws -> JSONOperationReport<T> {
        let scope = try Self(limits: limits)
        let original = scope.state.context.meter.continuation
        do {
            let result = try body(scope)
            try original.check(scope.state.context.meter)
            return .init(result: result, statistics: scope.state.context.meter.statistics())
        } catch {
            // A caller error cannot conceal an earlier native terminal failure or substitution.
            try original.check(scope.state.context.meter)
            throw error
        }
    }
}

extension JSON {
    /// Composes native helpers and instrumented adapter work on one finite ledger.
    ///
    /// The nonescaping synchronous scope is borrowed, noncopyable and not Sendable. Results
    /// may own exact immutable values. Reserve adapter output before allocation;
    /// arbitrary callback instructions remain caller work. Reports are ordinary
    /// values with a public initializer, not unforgeable certification tokens.
    /// - Parameters:
    ///   - limits: Finite inclusive limits for the entire invocation.
    ///   - body: Synchronous work borrowing the invocation's sole scope.
    /// - Returns: The result and one cumulative successful report, including final overlap.
    /// - Throws: Original owned terminal failure, cancellation or caller error; no report on failure.
    public static func withComposition<Result>(limits: JSONLimits = .balanced,
        _ body: (borrowing JSONCompositionScope) throws -> Result) throws -> JSONOperationReport<Result> {
        try JSONCompositionScope.run(limits: limits, body)
    }
}
