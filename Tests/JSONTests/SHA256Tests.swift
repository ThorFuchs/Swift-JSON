// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import Synchronization
@testable import JSON

private struct DigestVectors: Decodable {
    struct Vector: Decodable { let length: Int; let sha256: String }
    let cases: [Vector]
}
@Test func sha256IndependentKnownAnswersCoverPaddingAndBlockBoundaries() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let fixture = try JSONDecoder().decode(DigestVectors.self, from: Data(contentsOf: root.appendingPathComponent("Fixtures/Integrity/SHA256Vectors.json")))
    #expect(fixture.cases.count == 24)
    for vector in fixture.cases {
        let bytes = (0..<vector.length).map { UInt8(truncatingIfNeeded: $0 * 37 + 11) }
        var meter = try JSONWorkMeter(limits: .offline, domain: .core)
        let result = try JSONSHA256Core.hexadecimal(bytes, accounting: &meter)
        #expect(result == vector.sha256)
        #expect(meter.used(.retainedBytes) == 64)
        try meter.release(64)
        #expect(meter.used(.retainedBytes) == 0)
    }
    for (text, expected) in [
        ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
        ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
        ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    ] {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
        #expect(try JSONSHA256Core.hexadecimal(text.utf8, accounting: &meter) == expected)
    }
    var million = try JSONWorkMeter(limits: .offline, domain: .core)
    #expect(try JSONSHA256Core.hexadecimal(Array(repeating: UInt8(97), count: 1_000_000), accounting: &million)
        == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
}

@Test func sha256SharedWorkAndScratchCeilingsRejectBeforeGrowth() throws {
    let bytes = Array(repeating: UInt8(42), count: 65)
    var observed = try JSONWorkMeter(limits: .balanced, domain: .schemaCompilation)
    try observed.work(17)
    _ = try JSONSHA256Core.hexadecimal(bytes, accounting: &observed)
    let work = observed.used(.workUnits)
    #expect(observed.used(.compileWorkUnits) == work)
    var limits = JSONLimits.balanced; limits[.workUnits] = work
    var exact = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
    try exact.work(17)
    #expect(try JSONSHA256Core.hexadecimal(bytes, accounting: &exact).count == 64)
    limits[.workUnits] = work - 1
    var rejected = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
    try rejected.work(17)
    #expect(throws: JSONFailure.self) { try JSONSHA256Core.hexadecimal(bytes, accounting: &rejected) }
    #expect(rejected.used(.retainedBytes) == 0)
    #expect(throws: JSONFailure.self) { try rejected.work() }
    limits = .balanced; limits[.compiledPlanBytes] = 335
    var scratch = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
    #expect(throws: JSONFailure.self) { try JSONSHA256Core.hexadecimal(bytes, accounting: &scratch) }
    #expect(scratch.used(.retainedBytes) == 0 && scratch.used(.workUnits) == 0)
    for quantum: UInt64 in [1, 16, 1024] {
        let progress = Mutex([UInt64]())
        var configured = JSONLimits.balanced; configured[.cancellationQuantum] = quantum
        var granular = try JSONWorkMeter(limits: configured, domain: .core)
        granular.checkpointObserver = { work in progress.withLock { $0.append(work) } }
        _ = try JSONSHA256Core.hexadecimal(bytes, accounting: &granular)
        let checkpoints = progress.withLock { $0 }
        for (a, b) in zip(checkpoints, checkpoints.dropFirst()) { #expect(b - a <= quantum) }
    }
}

@Test func sha256InputCapacityAndConcurrentInvocationsRemainIndependent() async throws {
    var limits = JSONLimits.balanced; limits[.inputBytes] = 2
    var meter = try JSONWorkMeter(limits: limits, domain: .core)
    #expect(throws: JSONFailure.self) { try JSONSHA256Core.hexadecimal(Array("abc".utf8), accounting: &meter) }
    #expect(meter.used(.retainedBytes) == 0)
    try await withThrowingTaskGroup(of: String.self) { group in
        for _ in 0..<16 {
            group.addTask {
                var owned = try JSONWorkMeter(limits: .balanced, domain: .core)
                return try JSONSHA256Core.hexadecimal(Array("abc".utf8), accounting: &owned)
            }
        }
        var count = 0
        for try await hash in group {
            #expect(hash == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
            count += 1
        }
        #expect(count == 16)
    }
}

@Test func sha256CompressionCancellationLatchesWithoutRetainingScratch() async throws {
    let task = Task { () throws -> UInt64 in
        var meter = try JSONWorkMeter(limits: .balanced, domain: .schemaCompilation)
        meter.checkpointObserver = { work in
            if work >= 1024 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        do {
            _ = try JSONSHA256Core.hexadecimal(Array(repeating: UInt8(97), count: 1024), accounting: &meter)
            Issue.record("Expected cancellation inside compression")
        } catch is CancellationError {
            #expect(meter.used(.retainedBytes) == 0)
            #expect(throws: CancellationError.self) { try meter.checkpoint() }
            return meter.used(.workUnits)
        }
        return 0
    }
    #expect(try await task.value >= 1024)
}
