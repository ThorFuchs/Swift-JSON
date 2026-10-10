// SPDX-License-Identifier: Apache-2.0
/// Exact decoded scalar identity; Swift String's canonical equality is not used.
public struct JSONKey: Sendable, Hashable, ExpressibleByStringLiteral {
    public let string: String
    private let fingerprint: UInt64
    public init(_ string: String) {
        self.string = string
        var hash: UInt64 = 14695981039346656037
        for byte in string.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        fingerprint = hash
    }
    package init(_ string: String, meter: inout JSONWorkMeter, subsystem: JSONResourceMetric? = nil) throws {
        self.string = string
        var hash: UInt64 = 14695981039346656037
        for byte in string.utf8 { try meter.work(subsystem: subsystem); hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        fingerprint = hash
    }
    public init(stringLiteral value: String) { self.init(value) }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.fingerprint == rhs.fingerprint && lhs.string.utf8.elementsEqual(rhs.string.utf8)
    }
    public func hash(into hasher: inout Hasher) { hasher.combine(fingerprint) }
}

extension JSONKey: Codable {
    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        if let native = decoder as? JSONNativeDecoder { self = try Self(text,meter: &native.state.meter) }
        else { self.init(text) }
    }
    public func encode(to encoder: any Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(string) }
}
