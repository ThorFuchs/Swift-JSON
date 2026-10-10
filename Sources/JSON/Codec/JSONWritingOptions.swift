// SPDX-License-Identifier: Apache-2.0
public struct JSONWritingOptions: Sendable {
    public enum KeyOrder: Sendable { case insertion, scalar }
    public var limits: JSONLimits
    public var indentation: Int?
    public var keyOrder: KeyOrder
    public var numberStyle: JSONNumberTextStyle
    public init(limits: JSONLimits = .balanced, indentation: Int? = nil,
                keyOrder: KeyOrder = .insertion, numberStyle: JSONNumberTextStyle = .normalized) {
        self.limits = limits; self.indentation = indentation; self.keyOrder = keyOrder; self.numberStyle = numberStyle
    }
}
