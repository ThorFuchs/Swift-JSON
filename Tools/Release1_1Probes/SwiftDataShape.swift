// SPDX-License-Identifier: Apache-2.0
import SwiftData

public struct PayloadShape: Codable, Sendable {
    private let utf8Base64: String
    enum CodingKeys: String, CodingKey { case format, version, utf8Base64 }
    public init(utf8Base64: String) { self.utf8Base64 = utf8Base64 }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("swift-json-value", forKey: .format)
        try c.encode(1, forKey: .version)
        try c.encode(utf8Base64, forKey: .utf8Base64)
    }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard try c.decode(String.self, forKey: .format) == "swift-json-value",
              try c.decode(Int.self, forKey: .version) == 1 else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unsupported payload format"))
        }
        utf8Base64 = try c.decode(String.self, forKey: .utf8Base64)
    }
}
@Model final class ConfigurationSnapshot {
    var name: String
    var applicationSchemaVersion: Int
    @Attribute(.codable) var payload: PayloadShape
    @Attribute(.codable) var optionalPayload: PayloadShape?
    init(name: String, payload: PayloadShape) {
        self.name = name; applicationSchemaVersion = 1
        self.payload = payload; optionalPayload = nil
    }
}
