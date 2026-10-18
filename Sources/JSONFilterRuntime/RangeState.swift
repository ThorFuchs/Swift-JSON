// SPDX-License-Identifier: Apache-2.0
import JSON

/// One bounded exact progression, with no host-int iteration guard or eager array.
package struct FilterRangeState {
    private var current: FilterYield
    private let end: JSONNumber
    private let step: JSONNumber
    private var advance = false
    package init(start: JSONNumber, end: JSONNumber, step: JSONNumber, context: inout TransformRuntimeContext) throws {
        guard !step.isZero else { throw FilterLanguageFailure("zeroRangeStep") }
        // Admission precedes sparse progression, including a range with no results.
        for number in [start,end,step] { try context.meter.resetValueBounds(); try JSONAdmission.value(.number(number), meter: &context.meter) }
        current = try FilterValues.produced(.number(start), context: &context)
        self.end = end; self.step = step
    }
    package mutating func next(context: inout TransformRuntimeContext) throws -> FilterYield? {
        try context.work()
        if advance {
            guard case .number(let number) = current.value else { throw TransformRuntimeFailure(.resource, "rangeInvariant") }
            current = try ExactDecimal.binary("+", number, step, context: &context)
        }
        guard case .number(let number) = current.value else { throw TransformRuntimeFailure(.resource, "rangeInvariant") }
        let order = try number.compare(to: end, meter: &context.meter)
        if step.isNegative ? order != .orderedDescending : order != .orderedAscending { try current.release(context: &context); return nil }
        advance = true; return current
    }
}
