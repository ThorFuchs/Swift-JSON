// SPDX-License-Identifier: Apache-2.0
extension JSON {
    public var objectValue: JSONObject? { if case .object(let v) = self { return v }; return nil }
    public var arrayValue: [JSON]? { if case .array(let v) = self { return v }; return nil }
    public var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    public var numberValue: JSONNumber? { if case .number(let v) = self { return v }; return nil }
    public var booleanValue: Bool? { if case .boolean(let v) = self { return v }; return nil }
    public var isNull: Bool { if case .null = self { return true }; return false }
    public func requiredMember(_ key: String, limits: JSONLimits = .balanced) throws -> JSON {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        guard case .object(let object) = self else { throw JSONFailure(.typeMismatch, code: .wrongKind) }
        try JSONAdmission.text(key, key: true, meter: &meter)
        guard let value = try object.lookup(key, meter: &meter) else { throw JSONFailure(.missingValue, code: .missingMember) }
        return value
    }
    public func presence(of key: String, limits: JSONLimits = .balanced) throws -> JSONPresence<JSON> {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        guard case .object(let object) = self else { throw JSONFailure(.typeMismatch, code: .wrongKind) }
        try JSONAdmission.text(key, key: true, meter: &meter)
        guard let value = try object.lookup(key, meter: &meter) else { return .absent }
        if case .null = value { return .null }
        return .value(value)
    }
}
