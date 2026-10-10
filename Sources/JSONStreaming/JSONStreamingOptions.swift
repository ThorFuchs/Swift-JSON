// SPDX-License-Identifier: Apache-2.0
import JSON
public struct JSONStreamingOptions: Sendable {
    public var limits: JSONLimits
    public var framing: JSONFraming
    public init(limits: JSONLimits = .balanced, framing: JSONFraming = .singleDocument) {
        self.limits = limits; self.framing = framing
    }
}
