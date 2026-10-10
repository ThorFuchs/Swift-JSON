// SPDX-License-Identifier: Apache-2.0
/// Exact decoded-scalar key matching; no case folding or canonical normalization.
public struct JSONRedaction: Sendable {
    public var keys: [JSONKey]
    public init(keys: [JSONKey] = ["password", "secret", "token", "access_token", "refresh_token", "api_key", "authorization", "client_secret", "private_key"]) { self.keys = keys }
    package func matches(_ key: JSONKey, meter: inout JSONWorkMeter) throws -> Bool {
        for candidate in keys { if try JSONComparison.textEquals(candidate.string, key.string, meter: &meter) { return true } }
        return false
    }
}
