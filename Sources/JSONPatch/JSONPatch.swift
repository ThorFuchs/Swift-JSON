// SPDX-License-Identifier: Apache-2.0
import JSON
public struct JSONPatch: Sendable {
    public let operations: [JSONPatchOperation]
    public init(operations: [JSONPatchOperation], limits: JSONLimits = .balanced) throws {
        var meter = try JSONWorkMeter(limits: limits, domain: .patch)
        try meter.require(.operations, UInt64(operations.count))
        for operation in operations { try meter.work(); _ = try JSONPointer.decodedTokens(operation.path.tokens, meter: &meter) }
        self.operations = operations
    }
    /// Irrelevant extra members are ignored as RFC 6902 specifies.
    public init(json: JSON, options: JSONPatchOptions = .init()) throws {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .patch)
        try JSONAdmission.value(json, meter: &meter)
        guard case .array(let values) = json else { throw JSONFailure(.patch, code: .invalidOperation) }
        try meter.require(.operations, UInt64(values.count))
        var operations: [JSONPatchOperation] = []
        for value in values {
            guard case .object(let object) = value else { throw JSONFailure(.patch, code: .invalidOperation) }
            func text(_ key: String, meter: inout JSONWorkMeter) throws -> String {
                guard let value = try object.lookup(key, meter: &meter), case .string(let string) = value else { throw JSONFailure(.patch, code: .invalidOperation) }
                return string
            }
            func payload(meter: inout JSONWorkMeter) throws -> JSON {
                guard let value = try object.lookup("value", meter: &meter) else { throw JSONFailure(.patch, code: .invalidOperation) }; return value
            }
            let name = try text("op", meter: &meter), path = try JSONPointer.parse(text("path", meter: &meter), meter: &meter)
            let operation: JSONPatchOperation
            switch name {
            case "add": operation = .add(path: path, value: try payload(meter: &meter))
            case "remove": operation = .remove(path: path)
            case "replace": operation = .replace(path: path, value: try payload(meter: &meter))
            case "test": operation = .test(path: path, value: try payload(meter: &meter))
            case "move": operation = .move(from: try JSONPointer.parse(text("from", meter: &meter), meter: &meter), path: path)
            case "copy": operation = .copy(from: try JSONPointer.parse(text("from", meter: &meter), meter: &meter), path: path)
            default: throw JSONFailure(.patch, code: .invalidOperation)
            }
            try meter.retain(JSONLogicalWeights.frame); operations.append(operation)
        }
        self.operations = operations
    }
    package static func checkStaged(_ value: JSON, meter: inout JSONWorkMeter) throws {
        try meter.resetValueBounds(); try JSONAdmission.value(value, meter: &meter)
        var cursor = JSONWritingCursor(value: value, options: .init(limits: meter.limits))
        while try cursor.next(meter: &meter) != nil { try meter.charge(.outputBytes) }
    }
    public func applying(to value: JSON, options: JSONPatchOptions = .init()) throws -> JSONPatchResult { try applyingWithReport(to: .document(value), options: options).result }
    public func applying(to value: JSONPatchResult, options: JSONPatchOptions = .init()) throws -> JSONPatchResult { try applyingWithReport(to: value, options: options).result }
    public func applyingWithReport(to initial: JSONPatchResult, options: JSONPatchOptions = .init()) throws -> JSONOperationReport<JSONPatchResult> {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .patch)
        var staged: JSON?
        if case .document(let value) = initial { staged = value; try JSONAdmission.value(value, meter: &meter, owned: true) }
        for operation in operations {
            do {
            try meter.charge(.operations); try meter.work()
            let path = try JSONPointer.decodedTokens(operation.path.tokens, meter: &meter)
            switch operation {
            case .add(_, let value):
                try meter.resetValueBounds(); try JSONAdmission.value(value, meter: &meter, owned: true)
                if path.tokens.isEmpty { staged = value }
                else { guard let current = staged else { throw JSONFailure(.patch, code: .missingTarget) }; staged = try JSONEditing.edit(current, at: path, change: .add(value), meter: &meter) }
            case .remove, .replace:
                guard let current = staged else { throw JSONFailure(.patch, code: .missingTarget) }
                if case .replace(_, let value) = operation {
                    try meter.resetValueBounds(); try JSONAdmission.value(value, meter: &meter, owned: true)
                    staged = try JSONEditing.edit(current, at: path, change: .replace(value), meter: &meter)
                } else { staged = try JSONEditing.edit(current, at: path, change: .remove, meter: &meter) }
            case .test(_, let expected):
                guard let current = staged else { throw JSONFailure(.patch, code: .missingTarget) }
                let selected = try path.resolve(in: current, meter: &meter)
                try JSONAdmission.value(expected, meter: &meter)
                guard try JSONComparison.equals(selected, expected, meter: &meter) else { throw JSONFailure(.patch, code: .failedTest) }
            case .move(let source, _), .copy(let source, _):
                guard let current = staged else { throw JSONFailure(.patch, code: .missingTarget) }
                let source = try JSONPointer.decodedTokens(source.tokens, meter: &meter)
                let selected = try source.resolve(in: current, meter: &meter)
                if case .move = operation {
                    var prefix = source.tokens.count < path.tokens.count
                    if prefix {
                        for (a, b) in zip(source.tokens, path.tokens) {
                            if try !JSONComparison.textEquals(a.string, b.string, meter: &meter) { prefix = false; break }
                        }
                    }
                    guard !prefix else { throw JSONFailure(.patch, code: .invalidOperation) }
                    var identical = source.tokens.count == path.tokens.count
                    if identical {
                        for (a, b) in zip(source.tokens, path.tokens) {
                            if try !JSONComparison.textEquals(a.string, b.string, meter: &meter) { identical = false; break }
                        }
                    }
                    if identical {
                        // The selected value and path already exist; no staged graph changes.
                        try meter.release(meter.used(.retainedBytes))
                        if let staged { try meter.resetValueBounds(); try JSONAdmission.value(staged,meter: &meter,owned: true) }
                        continue
                    }
                    staged = try JSONEditing.edit(current, at: source, change: .remove, meter: &meter)
                }
                try meter.resetValueBounds(); try JSONAdmission.value(selected, meter: &meter, owned: true)
                if path.tokens.isEmpty { staged = selected }
                else { guard let target = staged else { throw JSONFailure(.patch, code: .missingTarget) }; staged = try JSONEditing.edit(target, at: path, change: .add(selected), meter: &meter) }
            }
            if let staged { try Self.checkStaged(staged, meter: &meter) }
            }
            // Operation-local Pointer, comparison, writer and replaced ancestor state is gone.
            // Rebase the invocation-owned staged value; lifetime work/admissions are not refunded.
            try meter.release(meter.used(.retainedBytes))
            if let staged { try meter.resetValueBounds(); try JSONAdmission.value(staged,meter: &meter,owned: true) }
        }
        let result: JSONPatchResult = staged.map { .document($0) } ?? .removed
        return .init(result: result, statistics: meter.statistics())
    }
}
