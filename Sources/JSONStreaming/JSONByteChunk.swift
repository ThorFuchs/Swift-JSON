// SPDX-License-Identifier: Apache-2.0
import Foundation
/// Caller-owned bytes. Readers admit size before making their own copy.
public struct JSONByteChunk: Sendable, Equatable {
    public let bytes: [UInt8]
    public init(_ bytes: [UInt8]) { self.bytes = bytes }
    public init(_ data: Data) { bytes = Array(data) }
    public var count: Int { bytes.count }
}
