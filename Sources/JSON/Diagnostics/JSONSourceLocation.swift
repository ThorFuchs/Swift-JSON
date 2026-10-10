// SPDX-License-Identifier: Apache-2.0
/// Offsets are zero based; line and UTF-8 byte column are one based when present.
public struct JSONSourceLocation: Sendable, Equatable, Codable {
    public let byteOffset: UInt64
    public let line: UInt64?
    public let column: UInt64?
    public let record: UInt64?
    public init(byteOffset: UInt64, line: UInt64? = nil, column: UInt64? = nil, record: UInt64? = nil) {
        self.byteOffset = byteOffset; self.line = line; self.column = column; self.record = record
    }
}
