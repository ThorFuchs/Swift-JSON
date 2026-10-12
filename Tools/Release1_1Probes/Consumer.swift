// SPDX-License-Identifier: Apache-2.0
import JSON
import ReaderProbe
struct Model: Decodable { let count: UInt64 }
let value = try JSONParser().parse(#"{"users":[{"name":"Ada","empty":null,"model":{"count":9007199254740993}}]}"#)
let report = try probeReadWithReport(value) { root in
    let user = try root["users"][0]
    let name = try user[JSONKey("name")].requiredString()
    guard case .absent = try user.presence(of: "missing"),
          case .null = try user.presence(of: "empty"),
          case .value(let present) = try user.presence(of: "name") else { fatalError("Presence mismatch") }
    let presentName = try present.requiredString()
    precondition(presentName == name)
    let count = try user["model"]["count"].requiredInteger(as: UInt64.self)
    let model = try user["model"].decode(Model.self)
    precondition(model.count == count)
    return name
}
precondition(report.result == "Ada")
precondition(report.statistics[.workUnits] > 0)
precondition(report.statistics[.numericWorkUnits] > 0)
print("READER_CONSUMER passed chains=String/JSONKey/Int presence=absent/null/value exact=9007199254740993 domain=\(report.statistics.domain) work=\(report.statistics[.workUnits]) numeric=\(report.statistics[.numericWorkUnits])")
