// SPDX-License-Identifier: Apache-2.0
// Original implementation of a bounded structural difference producing RFC 6902 operations.
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
    /// - Object members are compared by exact key. Members only in `source` are
    ///   removed, members only in `target` are added in `target` order, and shared
    ///   members are compared recursively. A changed member order alone produces no
    ///   operation, because object equality ignores order.
    /// - Arrays keep their longest equal prefix and suffix. The remaining elements
    ///   are compared pairwise by position; surplus `source` elements are removed
    ///   from the highest index down, and surplus `target` elements are added in order.
    ///   Elements are never moved or copied, so an inserted element at the front
    ///   of a long array can produce many operations.
    /// - Values of different kinds, and unequal scalars, are replaced. A root
    ///   change replaces the root through the empty Pointer.
    ///
    /// The result contains no `test`, `move` or `copy` operations.
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
        enum Step {
            /// Compare two values found at the same path.
            case compare(path: [JSONKey], source: JSON, target: JSON)
            /// Emit an operation after the steps pushed before it have run.
            case emit(JSONPatchOperation)
        }
        var operations: [JSONPatchOperation] = []
        var stack: [Step] = []
        func push(_ step: Step, meter: inout JSONWorkMeter) throws {
            try meter.work(); try meter.retain(JSONLogicalWeights.frame); stack.append(step)
        }
        func pointer(_ path: [JSONKey], meter: inout JSONWorkMeter) throws -> JSONPointer {
            try JSONPointer.decodedTokens(path, meter: &meter)
        }
        func extended(_ path: [JSONKey], _ key: JSONKey, meter: inout JSONWorkMeter) throws -> [JSONKey] {
            try meter.require(.pointerTokens, UInt64(path.count) + 1)
            for _ in path { try meter.work() }
            try meter.retain(16); return path + [key]
        }
        func index(_ value: Int, meter: inout JSONWorkMeter) throws -> JSONKey {
            try JSONKey(String(value), meter: &meter)
        }
        try push(.compare(path: [], source: source, target: target), meter: &meter)
        while let step = stack.popLast() {
            try meter.release(JSONLogicalWeights.frame); try meter.work()
            switch step {
            case .emit(let operation):
                try meter.require(.operations, UInt64(operations.count) + 1)
                try meter.retain(JSONLogicalWeights.frame); operations.append(operation)
            case .compare(let path, .object(let a), .object(let b)):
                // Steps are pushed in reverse so they run in source/target order.
                var pending: [Step] = []
                for member in a {
                    try meter.work()
                    if try b.lookup(member.key.string, meter: &meter) == nil {
                        pending.append(.emit(.remove(path: try pointer(extended(path, member.key, meter: &meter), meter: &meter))))
                    }
                }
                for member in b {
                    try meter.work()
                    let childPath = try extended(path, member.key, meter: &meter)
                    if let existing = try a.lookup(member.key.string, meter: &meter) {
                        pending.append(.compare(path: childPath, source: existing, target: member.value))
                    } else {
                        pending.append(.emit(.add(path: try pointer(childPath, meter: &meter), value: member.value)))
                    }
                }
                for item in pending.reversed() { try push(item, meter: &meter) }
            case .compare(let path, .array(let a), .array(let b)):
                let shared = min(a.count, b.count)
                var prefix = 0
                while prefix < shared, try JSONComparison.equals(a[prefix], b[prefix], meter: &meter) { prefix += 1 }
                var suffix = 0
                while suffix < shared - prefix,
                      try JSONComparison.equals(a[a.count - 1 - suffix], b[b.count - 1 - suffix], meter: &meter) { suffix += 1 }
                let middleA = a.count - prefix - suffix, middleB = b.count - prefix - suffix
                let paired = min(middleA, middleB)
                var pending: [Step] = []
                for offset in 0..<paired {
                    try meter.work()
                    let position = prefix + offset
                    pending.append(.compare(path: try extended(path, index(position, meter: &meter), meter: &meter),
                                            source: a[position], target: b[position]))
                }
                // Highest index first, so each removal leaves lower indices in place.
                for position in stride(from: prefix + middleA - 1, through: prefix + paired, by: -1) {
                    try meter.work()
                    pending.append(.emit(.remove(path: try pointer(extended(path, index(position, meter: &meter), meter: &meter), meter: &meter))))
                }
                for position in (prefix + paired)..<(prefix + middleB) {
                    try meter.work()
                    pending.append(.emit(.add(path: try pointer(extended(path, index(position, meter: &meter), meter: &meter), meter: &meter),
                                              value: b[position])))
                }
                for item in pending.reversed() { try push(item, meter: &meter) }
            case .compare(let path, let a, let b):
                if try !JSONComparison.equals(a, b, meter: &meter) {
                    try push(.emit(.replace(path: try pointer(path, meter: &meter), value: b)), meter: &meter)
                }
            }
        }
        return JSONPatch(admitted: operations)
    }
}
