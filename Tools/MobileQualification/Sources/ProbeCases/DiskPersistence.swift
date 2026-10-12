// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftData
import JSON

@Model final class ConfigurationSnapshot {
    var name: String
    var applicationSchemaVersion: Int
    @Attribute(.codable) var payload: JSONCodablePayload
    @Attribute(.codable) var optionalPayload: JSONCodablePayload?
    init(name: String, payload: JSONCodablePayload, optional: JSONCodablePayload?) {
        self.name = name; applicationSchemaVersion = 1
        self.payload = payload; optionalPayload = optional
    }
}
@MainActor private func container(_ url: URL) throws -> ModelContainer {
    try ModelContainer(for: ConfigurationSnapshot.self, configurations: ModelConfiguration(url: url))
}
@MainActor private func save(_ url: URL, fixtures: FrozenFixtures) throws {
    try autoreleasepool {
        let store = try container(url)
        let context = ModelContext(store); context.autosaveEnabled = false
        for item in fixtures.cases {
            let payload = try JSONCodablePayload(preserving: JSONParser().parse(item.inner_json))
            context.insert(ConfigurationSnapshot(name: item.id, payload: payload,
                optional: item.id == "null" ? try JSONCodablePayload(preserving: .null) : nil))
        }
        try context.save()
    }
}
@MainActor private func reopenAndUpdate(_ url: URL, fixtures: FrozenFixtures) throws {
    try autoreleasepool {
        let store = try container(url)
        let context = ModelContext(store); context.autosaveEnabled = false
        let rows = try context.fetch(FetchDescriptor<ConfigurationSnapshot>(sortBy: [SortDescriptor(\.name)]))
        try verify(rows.count == 8 && rows.map(\.name) == fixtures.cases.map(\.id).sorted(), "ordinary field sorting")
        for row in rows {
            let fixture = fixtures.cases.first { $0.id == row.name }!
            try verify(exactBytes(row.payload.value()) == Data(fixture.inner_json.utf8), "disk fidelity including scalar/order/lexeme")
            try verify(row.applicationSchemaVersion == 1, "application schema version")
            if row.name == "null" { try verify(row.optionalPayload?.value().isNull == true, "present null attribute") }
            else { try verify(row.optionalPayload == nil, "absent optional attribute") }
        }
        let selection = FetchDescriptor<ConfigurationSnapshot>(predicate: #Predicate { $0.name == "decimal" })
        let decimal = try context.fetch(selection)
        try verify(decimal.count == 1, "ordinary field predicate")
        decimal[0].payload = try JSONCodablePayload(preserving: JSONParser().parse("0.1000e+1"))
        decimal[0].applicationSchemaVersion = 2
        decimal[0].optionalPayload = try JSONCodablePayload(preserving: .null)
        try context.save()
    }
}
// Each phase is executed by a distinct process. Process exit closes the store and
// removes all model/context/container state, including SDK-retained references.
@MainActor public func diskPhase(_ phase: String, url: URL) throws {
    let fixtures = try FrozenFixtures.load()
    if phase == "save" { try save(url, fixtures: fixtures); return }
    try verify(FileManager.default.fileExists(atPath: url.path), "actual disk store exists")
    if phase == "reopen-update" { try reopenAndUpdate(url, fixtures: fixtures); return }
    try verify(phase == "verify-update", "known disk phase")
    try autoreleasepool {
        let store = try container(url), context = ModelContext(store)
        let rows = try context.fetch(FetchDescriptor<ConfigurationSnapshot>(predicate: #Predicate { $0.name == "decimal" }))
        try verify(rows.count == 1 && rows[0].applicationSchemaVersion == 2, "updated ordinary field persisted")
        try verify(exactBytes(rows[0].payload.value()) == Data("0.1000e+1".utf8), "updated lexeme persisted")
        try verify(rows[0].optionalPayload?.value().isNull == true, "updated present null persisted")
    }
}
#if os(macOS)
public func diskPersistence() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("swift-json-disk-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("snapshots.store")
    var products = Bundle.module.bundleURL.deletingLastPathComponent()
    for _ in 0..<5 {
        if FileManager.default.isExecutableFile(atPath: products.appendingPathComponent("MobileQualification").path) { break }
        products.deleteLastPathComponent()
    }
    let executable = products.appendingPathComponent("MobileQualification")
    for phase in ["save", "reopen-update", "verify-update"] {
        let process = Process(), pipe = Pipe()
        process.executableURL = executable
        process.arguments = ["--disk-phase", phase, url.path]
        process.standardOutput = pipe; process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try verify(process.terminationReason == .exit && process.terminationStatus == 0, "disk child process exit " + phase)
        try verify(String(decoding: output, as: UTF8.self).split(separator: "\n").contains(Substring("DISK_PHASE passed phase=" + phase + " rows=8")), "disk child process outcome")
    }
}
#endif
