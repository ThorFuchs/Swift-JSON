// SPDX-License-Identifier: Apache-2.0
import JSON
/// An RFC 7396 merge patch over exact values.
///
/// Object null members remove properties; a root null replaces the root with JSON
/// null. Arrays and other non-object patches replace the selected value whole.
public struct JSONMergePatch: Sendable {
    /// The exact RFC 7396 patch value.
    public let patch: JSON
    /// Stores an RFC 7396 patch value; admission and cumulative work begin during application.
    ///
    /// - Parameters:
    ///   - patch: The exact RFC 7396 patch value, admitted on application.
    public init(_ patch: JSON) { self.patch = patch }
    /// Applies the patch to exclusively owned staging and returns only a complete result.
    ///
    /// - Throws: Patch/navigation/test errors, intermediate capacity failure, resource failure or cancellation.
    ///
    /// - Parameters:
    ///   - value: The value supplied by the caller.
    ///   - options: The value configuration used by this facade or operation.
    public func applying(to value: JSON, options: JSONPatchOptions = .init()) throws -> JSON {
        try applyingWithReport(to: value, options: options).result
    }
    /// Applies a patch with cumulative work and intermediate-stage admission.
    ///
    /// - Returns: The complete result and charged counts; no partial result escapes on failure.
    /// - Throws: Patch/navigation/test errors, resource failure or cancellation.
    ///
    /// - Parameters:
    ///   - value: The value supplied by the caller.
    ///   - options: The value configuration used by this facade or operation.
    public func applyingWithReport(to value: JSON, options: JSONPatchOptions = .init()) throws -> JSONOperationReport<JSON> {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .patch)
        try JSONAdmission.value(value, meter: &meter,owned: true)
        try meter.resetValueBounds(); try JSONAdmission.value(patch, meter: &meter)
        struct Frame {
            var target: JSON
            let patch: JSONObject
            var index = 0
            let returnKey: JSONKey?
        }
        guard case .object(let root) = patch else {
            try JSONPatch.checkStaged(patch, meter: &meter)
            return .init(result: patch, statistics: meter.statistics())
        }
        try meter.retain(JSONLogicalWeights.frame)
        var stack = [Frame(target: value.objectValue == nil ? .object(JSONObject(admitted: [])) : value, patch: root, returnKey: nil)]
        while !stack.isEmpty {
            // Retire replaced immutable targets and operation-local scratch. The active frames
            // still own their targets; re-admit those snapshots without refunding charged work.
            try meter.release(meter.used(.retainedBytes))
            for frame in stack {
                try meter.work(); try meter.retain(JSONLogicalWeights.frame)
                try meter.resetValueBounds(); try JSONAdmission.value(frame.target,meter: &meter,owned: true)
            }
            try meter.work()
            let last = stack.count - 1
            if stack[last].index == stack[last].patch.count {
                let completed = stack.removeLast(); try meter.release(JSONLogicalWeights.frame)
                if let key = completed.returnKey {
                    let parent = stack.count - 1
                    stack[parent].target = try JSONEditing.modify(stack[parent].target, token: key, change: .add(completed.target), meter: &meter)
                    try JSONPatch.checkStaged(stack[parent].target,meter: &meter)
                } else {
                    try JSONPatch.checkStaged(completed.target, meter: &meter)
                    try meter.release(meter.used(.retainedBytes)); try meter.resetValueBounds()
                    try JSONAdmission.value(completed.target,meter: &meter,owned: true)
                    return .init(result: completed.target, statistics: meter.statistics())
                }
                continue
            }
            let member = stack[last].patch.members[stack[last].index]; stack[last].index += 1
            let existing = try stack[last].target.objectValue!.lookup(member.key.string, meter: &meter)
            if member.value.isNull {
                if existing != nil {
                    stack[last].target = try JSONEditing.modify(stack[last].target, token: member.key, change: .remove, meter: &meter)
                }
            } else if case .object(let nested) = member.value {
                try meter.require(.maxDepth, UInt64(stack.count) + 1); try meter.retain(JSONLogicalWeights.frame)
                let target: JSON = existing?.objectValue == nil ? .object(JSONObject(admitted: [])) : existing!
                stack.append(Frame(target: target, patch: nested, returnKey: member.key))
            } else {
                try meter.resetValueBounds(); try JSONAdmission.value(member.value, meter: &meter, owned: true)
                stack[last].target = try JSONEditing.modify(stack[last].target, token: member.key, change: .add(member.value), meter: &meter)
            }
            try JSONPatch.checkStaged(stack[last].target,meter: &meter)
        }
        throw JSONFailure(.patch, code: .invalidOperation)
    }
}
