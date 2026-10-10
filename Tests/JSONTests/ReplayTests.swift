// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON

@Test func deterministicMalformedReplayPreservesStrictProgressAndRoundTrips() throws {
    var seed: UInt64 = 0x53574946544a534f
    func random() -> UInt64 { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return seed }
    let base = Array(#"{"a":[true,null,9007199254740993,"é","\uD834\uDD1E"]}"#.utf8)
    var accepted = 0, rejected = 0, operationallyBounded = 0
    for index in 0..<1024 {
        var bytes = base
        let offset = Int(random() % UInt64(bytes.count))
        switch random() % 3 {
        case 0: bytes[offset] = UInt8(truncatingIfNeeded: random())
        case 1: bytes.remove(at: offset)
        default: bytes = Array(bytes.prefix(offset))
        }
        do {
            let value = try JSONParser().parse(bytes); accepted += 1
            #expect(try JSONParser().parse(JSONWriter().write(value)) == value,"Replay seed=0x53574946544a534f case=\(index)")
        } catch let failure as JSONFailure {
            if failure.category == .resource {
                // This fixed mutation creates a legal exponent beyond the advertised profile.
                // Resource exhaustion is an operational outcome, not syntactic invalidity.
                operationallyBounded += 1
                #expect(index == 118 && failure.resource?.metric == .absoluteExponent)
                #expect(bytes == Array(#"{"a":[true,null,900719E254740993,"é","\uD834\uDD1E"]}"#.utf8))
            } else {
                rejected += 1; #expect(failure.category == .syntax,"Replay seed=0x53574946544a534f case=\(index)")
            }
        }
    }
    #expect(accepted > 0 && rejected > 0 && operationallyBounded == 1 && accepted + rejected + operationallyBounded == 1024)
}

@Test func independentCodecFacadesAndExactValuesCanBeSharedAcrossTasks() async throws {
    let parser = JSONParser(), writer = JSONWriter()
    let text = #"{"é":9007199254740993,"e\u0301":0.10000000000000001}"#
    let value = try parser.parse(text)
    try await withThrowingTaskGroup(of: Bool.self) { group in
        for _ in 0..<64 { group.addTask { try parser.parse(writer.write(value)) == value } }
        var completed = 0
        for try await passed in group { #expect(passed); completed += 1 }
        #expect(completed == 64)
    }
}
