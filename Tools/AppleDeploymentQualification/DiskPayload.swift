// SPDX-License-Identifier: Apache-2.0
import Foundation
import CryptoKit
import JSON
import JSONSchema

private struct Fixtures: Decodable {
    struct Item: Decodable {
        let inner_json: String
        let inner_utf8_sha256: String
    }
    let cases: [Item]
}

// Each phase is a separate process. This tests the public exact envelope on disk;
// it makes no SwiftData `.codable` or database durability claim on these runtimes.
@main struct DiskPayload {
    static func main() throws {
        precondition(CommandLine.arguments.count == 3)
        let phase = CommandLine.arguments[1]
        if phase == "uri-probe" {
            let base = URL(string: "urn:swift-json:root")!
            let reference = "#/$defs/value"
            let foundation = URL(string: reference, relativeTo: base)!.absoluteURL.absoluteString
            FileHandle.standardError.write(Data("FOUNDATION_URI_REFERENCE actual=\(foundation) expected=urn:swift-json:root#/$defs/value\n".utf8))
            let url = Bundle.module.url(forResource: "URIResolution", withExtension: "json")!
            let cases = try JSONParser().parse(Data(contentsOf: url)).objectValue!["cases"]!.arrayValue!
            precondition(cases.count == 54)
            for item in cases {
                let object = item.objectValue!
                let input = object["base"]!.stringValue!, fragment = object["reference"]!.stringValue!
                let expected = object["expected"]!.stringValue!
                let admitted = try JSONSchemaURI(input)
                let result = try JSONSchemaURI(fragment, relativeTo: admitted)
                FileHandle.standardError.write(Data("URI_CASE base=\(admitted.string) reference=\(fragment) actual=\(result.string) expected=\(expected)\n".utf8))
                precondition(result.string == expected)
            }
            print("URI_COMPATIBILITY passed cases=54")
            return
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let fixtureURL = Bundle.module.url(forResource: "version1", withExtension: "json")!
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: fixtureURL))
        precondition(fixtures.cases.count == 8)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        for (index, fixture) in fixtures.cases.enumerated() {
            let bytes = Data(fixture.inner_json.utf8)
            precondition(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() == fixture.inner_utf8_sha256)
            let file = directory.appendingPathComponent("payload-\(index).plist")
            switch phase {
            case "save":
                precondition(!FileManager.default.fileExists(atPath: file.path))
                let payload = try JSONCodablePayload(preserving: JSONParser().parse(bytes))
                try encoder.encode(payload).write(to: file, options: .atomic)
            case "reopen-update":
                let payload = try PropertyListDecoder().decode(JSONCodablePayload.self, from: Data(contentsOf: file))
                let restored = try JSONWriter(options: .init(numberStyle: .preserved)).write(payload.value())
                precondition(restored == bytes)
                // Persist a changed envelope, so the third process cannot pass by
                // reading the original fixture or an unchanged in-memory value.
                let changed = try JSONCodablePayload(preserving: .array([payload.value(), .null]))
                try encoder.encode(changed).write(to: file, options: .atomic)
            case "verify-update":
                let payload = try PropertyListDecoder().decode(JSONCodablePayload.self, from: Data(contentsOf: file))
                let expected = Data([0x5B]) + bytes + Data(",null]".utf8)
                let restored = try JSONWriter(options: .init(numberStyle: .preserved)).write(payload.value())
                precondition(restored == expected)
            default:
                preconditionFailure("Unknown disk phase")
            }
        }
        print("DISK_PAYLOAD passed phase=\(phase) fixtures=8")
    }
}
