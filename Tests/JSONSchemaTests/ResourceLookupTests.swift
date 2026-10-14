// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
@testable import JSONSchema

@Test func missingPackagedResourcesAreCheckedAndLookupSharesTheMeter() async throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .schemaCompilation)
    let directory = URL(fileURLWithPath: "/nonexistent-swift-json-resource-qualification")
    do {
        _ = try JSONSchemaRegistry.builtinResourceRoot(in: [directory], meter: &meter)
        Issue.record("Expected checked missing-resource error")
    } catch let error as JSONSchemaCompilationFailure { #expect(error.category == .metaSchema) }
    #expect(meter.used(.workUnits) > 0 && meter.used(.retainedBytes) == 0)
    var limits = JSONLimits.balanced; limits[.stringBytes] = 1
    var bounded = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
    do {
        _ = try JSONSchemaRegistry.builtinResourceRoot(in: [directory], meter: &bounded)
        Issue.record("Expected lookup quota")
    } catch let error as JSONFailure { #expect(error.category == .resource && error.resource?.metric == .stringBytes) }
    let task = Task {
        var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
        var meter = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
        meter.checkpointObserver = { work in if work > 0 { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws: CancellationError.self) { _ = try JSONSchemaRegistry.builtinResourceRoot(in: [directory], meter: &meter) }
        #expect(meter.used(.workUnits) > 0 && meter.used(.retainedBytes) == 0)
    }
    try await task.value
}
