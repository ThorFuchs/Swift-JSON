// SPDX-License-Identifier: Apache-2.0
import Foundation
/// An owned byte chunk delivered by a caller source or accepted by a sink.
///
/// Construction does not enforce limits. Readers check chunk capacity after the
/// source delivers it; the source's prior allocation remains caller-owned.
public struct JSONByteChunk: Sendable, Equatable {
    /// The owned chunk bytes; construction itself does not enforce source admission limits.
    public let bytes: [UInt8]
    /// Owns the delivered bytes; source/sink admission checks occur in the consuming operation.
    ///
    /// - Parameters:
    ///   - bytes: The UTF-8 bytes supplied by the caller.
    public init(_ bytes: [UInt8]) { self.bytes = bytes }
    /// Owns the delivered bytes; source/sink admission checks occur in the consuming operation.
    ///
    /// - Parameters:
    ///   - data: The owned input bytes supplied by the caller.
    public init(_ data: Data) { bytes = Array(data) }
    /// The number of owned bytes in this chunk.
    public var count: Int { bytes.count }
}
