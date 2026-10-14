// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONStreaming
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

private struct Bytes: AsyncSequence {
    typealias Element = JSONByteChunk
    let bytes: [UInt8]
    struct Iterator: AsyncIteratorProtocol {
        let bytes: [UInt8]
        var index = 0
        mutating func next() async -> JSONByteChunk? {
            guard index < bytes.count else { return nil }
            let end = Swift.min(index + 16384, bytes.count)
            defer { index = end }
            return .init(Array(bytes[index..<end]))
        }
    }
    func makeAsyncIterator() -> Iterator { .init(bytes: bytes) }
}
@main struct CLIExactCompare {
    static func main() async {
        do {
            let arguments = CommandLine.arguments
            guard arguments.count == 3 else { throw NSError(domain: "qualification", code: 2) }
            let actual = try bounded(arguments[1]), expected = try bounded(arguments[2])
            let declaration = try JSONParser().parse(expected)
            guard case .array(let texts) = declaration else { throw NSError(domain: "qualification", code: 2) }
            // CLI result streams may be empty. The library's value sequence
            // requires a record; verify the zero-result contract explicitly.
            if texts.isEmpty {
                guard actual.allSatisfy({ [9,10,13,32].contains($0) }) else { throw NSError(domain: "qualification", code: 1) }
                print("NATIVE_EXACT_COMPARE passed values=0"); return
            }
            var iterator = JSONValueSequence(Bytes(bytes: actual), options: .init(framing: .whitespaceSeparatedValues)).makeAsyncIterator()
            var count = 0
            for text in texts {
                guard case .string(let raw) = text, let actual = try await iterator.next() else { throw NSError(domain: "qualification", code: 1) }
                let expected = try JSONParser().parse(raw)
                guard try JSONComparison.equals(actual, expected) else { throw NSError(domain: "qualification", code: 1) }
                count += 1
            }
            guard try await iterator.next() == nil else { throw NSError(domain: "qualification", code: 1) }
            print("NATIVE_EXACT_COMPARE passed values=\(count)")
        } catch { FileHandle.standardError.write(Data("NATIVE_EXACT_COMPARE failed\n".utf8)); exit(1) }
    }
    private static func bounded(_ path: String) throws -> [UInt8] {
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? handle.close() }
        var bytes: [UInt8] = []
        while let data = try handle.read(upToCount: 16384), !data.isEmpty {
            guard bytes.count + data.count <= 33554432 else { throw NSError(domain: "qualification", code: 2) }
            bytes.append(contentsOf: data)
        }
        return bytes
    }
}
