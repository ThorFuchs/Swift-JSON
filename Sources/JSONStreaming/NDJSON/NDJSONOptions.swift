// SPDX-License-Identifier: Apache-2.0
import JSON
public struct NDJSONOptions: Sendable {
    public var limits: JSONLimits
    public init(limits: JSONLimits = .balanced) { self.limits = limits }
}
