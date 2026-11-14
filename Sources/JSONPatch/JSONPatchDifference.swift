// SPDX-License-Identifier: Apache-2.0
// RFC 6902 facade over the shared bounded structural difference in JSON.
import JSON

extension JSONPatch {
    package init(admitted operations: [JSONPatchOperation]) { self.operations = operations }

    /// Computes a patch that turns `source` into `target` when applied to `source`.
    ///
    /// The difference is structural and deterministic, not a minimal edit script:
    ///
    /// - Equal values, using the exact model's equality (decimal value, decoded
    ///   scalars, order-independent objects), produce no operation. `1.0` and `1`
    ///   are equal, so neither is replaced by the other.
    /// - Object members are compared by exact key, in source order: members only in
    ///   `source` are removed and shared members are compared recursively. Members
    ///   only in `target` are then added in `target` order. A changed member order
    ///   alone produces no operation, because object equality ignores order.
    /// - Arrays keep their longest equal prefix and suffix. The remaining elements
    ///   are compared pairwise by position; surplus `source` elements are removed
    ///   from the highest index down, and surplus `target` elements are added in order.
    ///   Elements are never moved or copied, so an inserted element at the front
    ///   of a long array can produce many operations.
    /// - Values of different kinds, and unequal scalars, are replaced. A root
    ///   change replaces the root through the empty Pointer.
    ///
    /// The result contains no `test`, `move` or `copy` operations. JSONHTML's
    /// difference view uses the same comparison.
    ///
    /// - Returns: A patch whose application to `source` yields a value equal to `target`.
    /// - Throws: Resource failure for oversized inputs, operation counts or Pointer
    ///   lengths, or cancellation.
    ///
    /// - Parameters:
    ///   - source: The value the patch will be applied to.
    ///   - target: The value the patch must produce.
    ///   - options: Finite limits for admission, comparison and the produced operations.
    public static func difference(from source: JSON, to target: JSON, options: JSONPatchOptions = .init()) throws -> JSONPatch {
        try differenceWithReport(from: source, to: target, options: options).result
    }
    /// Computes the structural difference with cumulative work accounting.
    ///
    /// See ``difference(from:to:options:)`` for the semantics.
    ///
    /// - Returns: The patch and the charged counts of the single invocation ledger.
    /// - Throws: Resource failure for oversized inputs, operation counts or Pointer
    ///   lengths, or cancellation.
    ///
    /// - Parameters:
    ///   - source: The value the patch will be applied to.
    ///   - target: The value the patch must produce.
    ///   - options: Finite limits for admission, comparison and the produced operations.
    public static func differenceWithReport(from source: JSON, to target: JSON, options: JSONPatchOptions = .init()) throws -> JSONOperationReport<JSONPatch> {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .patch)
        let patch = try difference(from: source, to: target, meter: &meter)
        return .init(result: patch, statistics: meter.statistics())
    }
    package static func difference(from source: JSON, to target: JSON, meter: inout JSONWorkMeter) throws -> JSONPatch {
        try JSONAdmission.value(source, meter: &meter)
        try meter.resetValueBounds(); try JSONAdmission.value(target, meter: &meter)
        var operations: [JSONPatchOperation] = []
        for operation in try JSONDifferenceWalker.operations(from: source, to: target, meter: &meter) {
            try meter.work()
            let path = try JSONPointer.decodedTokens(operation.path, meter: &meter)
            switch operation.kind {
            case .add: operations.append(.add(path: path, value: operation.value ?? .null))
            case .remove: operations.append(.remove(path: path))
            case .replace: operations.append(.replace(path: path, value: operation.value ?? .null))
            }
        }
        return JSONPatch(admitted: operations)
    }
}
