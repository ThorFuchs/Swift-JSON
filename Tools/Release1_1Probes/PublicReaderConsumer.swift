// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

private struct Reading: Decodable { let count: UInt64; let name: String; let bytes: Data }
private let value = try JSONParser().parse(#"{"users":[{"count":18446744073709551615,"name":"sensor","bytes":"AAH/","nullable":null}]}"#)
private let report = try value.readWithReport { root in
    let user = try root[JSONKey("users")][0]
    let name = try user["name"].requiredString(); precondition(name == "sensor")
    let count = try user["count"].requiredInteger(as: UInt64.self); precondition(count == UInt64.max)
    let missing = try user.presence(of: "missing"); precondition(missing == .absent)
    let nullable = try user.stringPresence(of: "nullable"); precondition(nullable == .null)
    return try user.decode(Reading.self)
}
precondition(report.result.count == UInt64.max && report.result.bytes == Data([0, 1, 255]))
precondition(report.statistics.domain == .core && report.statistics[.numericWorkUnits] > 0)
private let escaped = try value.read { $0 }
do { _ = try escaped.requiredValue(); fatalError("Escaped cursor remained valid") }
catch let error as JSONFailure { precondition(error.code == .invalidOperation) }
print("PUBLIC_READER_CONSUMER passed work=\(report.statistics[.workUnits]) numeric=\(report.statistics[.numericWorkUnits])")
