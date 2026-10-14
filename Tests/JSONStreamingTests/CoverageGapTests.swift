// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming

@Test(StreamingTestPolicy.deadline) func qaStreamingWriterFacadePreservesGoldenChunksWithoutEmptyHandoffs() async throws {
    // Independent strict-JSON bytes, including a scalar split across chunks.
    let value = try JSONParser().parse(#"{"s":"🚀","a":[null,false,-1]}"#)
    for size in [1,2,4,64] {
        let sink = SinkBytes()
        try await JSONAsyncWriter(chunkSize:size).write(value) { try await sink.accept($0) }
        let bytes = await sink.bytes, calls = await sink.calls
        #expect(bytes == Array(#"{"s":"🚀","a":[null,false,-1]}"#.utf8))
        #expect(calls == (bytes.count+size-1)/size)
    }
}

@Test(StreamingTestPolicy.deadline) func qaStreamingWriterInvalidConfigurationNeverCallsSink() async throws {
    var limits = JSONLimits.balanced; limits[.chunkBytes] = 2
    let writers = [JSONAsyncWriter(chunkSize:0), JSONAsyncWriter(chunkSize:-1),
        JSONAsyncWriter(options:.init(limits:limits),chunkSize:3),
        JSONAsyncWriter(options:.init(indentation:-1)), JSONAsyncWriter(options:.init(indentation:9))]
    for writer in writers {
        let sink = SinkBytes()
        do { try await writer.write(.null) { try await sink.accept($0) }; Issue.record("Expected invalid configuration") }
        catch let failure as JSONFailure { #expect(failure.category == .configuration && failure.code == .invalidLimits) }
        let calls = await sink.calls; #expect(calls == 0)
    }
}

@Test(StreamingTestPolicy.deadline) func qaStreamingWriterExactChunkAndIndentationBoundsHaveFiniteReports() async throws {
    var limits = JSONLimits.balanced; limits[.chunkBytes] = 4
    let sink = SinkBytes()
    let stats = try await JSONAsyncWriter(options:.init(limits:limits,indentation:0),chunkSize:4).writeWithReport(.null) { try await sink.accept($0) }
    let bytes = await sink.bytes, calls = await sink.calls
    #expect(bytes == Array("null".utf8) && calls == 1)
    #expect(stats[.outputBytes] == 4 && stats[.retainedBytes] == 0)
    let pretty = SinkBytes()
    try await JSONAsyncWriter(options:.init(indentation:8),chunkSize:2).write(.array([true])) { try await pretty.accept($0) }
    let output = await pretty.bytes
    #expect(output == Array("[\n        true\n]".utf8))
}
