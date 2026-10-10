// SPDX-License-Identifier: Apache-2.0
public struct JSONParsingOptions: Sendable {
    public var limits: JSONLimits
    public init(limits: JSONLimits = .balanced) { self.limits = limits }
}
