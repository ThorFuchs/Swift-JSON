// SPDX-License-Identifier: Apache-2.0
import JSON
public struct JSONPatchOptions: Sendable {
    public var limits: JSONLimits
    public init(limits: JSONLimits = .balanced) { self.limits = limits }
}
