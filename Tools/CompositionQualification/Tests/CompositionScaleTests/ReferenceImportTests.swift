// SPDX-License-Identifier: Apache-2.0
import CompositionFixtures
import JSON
import Testing

@Test func referenceHeavyImportsPreserveExactValuesAndScalarKeys() throws {
    let cells: [(Int, Int, JSONLimits)] = [(16, 32, .balanced), (128, 64, .balanced), (256, 256, .offline)]
    var completed = 0
    for (definitions, references, limits) in cells {
        let fixture = ReferenceFixture(definitions: definitions, references: references)
        var progress = ImportProgress()
        let report = try JSON.withComposition(limits: limits) {
            try importReferences(fixture, scope: $0, progress: &progress)
        }
        #expect(report.result == (try fixture.expectedSelections()))
        #expect(progress.completedReferences == references)
        #expect(report.statistics[.compiledPlanBytes] == 0)
        #expect(report.statistics[.compileWorkUnits] == 0)
        #expect(report.statistics[.workUnits] > UInt64(fixture.data.count))
        #expect(report.result[0].numberValue?.originalLexeme == "9007199254740993")
        #expect(report.result[1].numberValue?.originalLexeme == "0.0100")
        #expect(report.result[2] == true && report.result[3] == false)
        completed += 1
    }
    #expect(completed == 3)
}

@Test func referenceHeavyDefaultCapacityIsAnExplicitAdoptionLimit() throws {
    // The initial capacity hypothesis failed and remains an adoption blocker.
    // This guards the actual quota behavior; it does not certify this import.
    let fixture = ReferenceFixture(definitions: 128, references: 128)
    var progress = ImportProgress()
    do {
        _ = try JSON.withComposition {
            try importReferences(fixture, scope: $0, progress: &progress)
        }
        Issue.record("Expected the recorded finite numeric-work refusal")
    } catch let failure as JSONFailure {
        #expect(failure.category == .resource)
        #expect(failure.resource?.metric == .numericWorkUnits)
        #expect(failure.resource?.attemptedUsage == 1_000_001)
    }
    #expect(progress.completedReferences == 98)
}

@Test func referenceHeavyImportsEnforceOneCumulativeBoundary() throws {
    let fixture = ReferenceFixture(definitions: 16, references: 32)
    func run(_ limits: JSONLimits) throws -> JSONOperationStatistics {
        var progress = ImportProgress()
        return try JSON.withComposition(limits: limits) {
            try importReferences(fixture, scope: $0, progress: &progress)
        }.statistics
    }
    let probe = try run(.balanced)
    var exact = JSONLimits.balanced
    exact[.workUnits] = probe[.workUnits]
    exact[.retainedBytes] = probe.peakLogicalRetainedBytes
    #expect(try run(exact) == probe)
    for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
        var below = exact
        below[metric] -= 1
        do { _ = try run(below); Issue.record("One-below composition accepted") }
        catch let failure as JSONFailure {
            #expect(failure.category == .resource && failure.resource?.metric == metric)
        }
    }
}

@Test func stagedReferenceDescriptorsKeepOneLedgerAndCompleteTheBoundedTarget() throws {
    func run(_ fixture: ReferenceFixture, _ strategy: ReferenceStrategy,
             limits: JSONLimits = .balanced) throws -> JSONOperationReport<[JSON]> {
        var progress = ImportProgress()
        let report = try JSON.withComposition(limits: limits) {
            try importReferences(fixture, scope: $0, progress: &progress, strategy: strategy)
        }
        #expect(progress.completedReferences == fixture.references)
        #expect(report.result == (try fixture.expectedSelections()))
        return report
    }
    let comparison = ReferenceFixture(definitions: 128, references: 64)
    let original = try run(comparison, .perReferenceRoot)
    let staged = try run(comparison, .stagedReferenceArray)
    #expect(staged.result == original.result)
    #expect(staged.statistics[.workUnits] < original.statistics[.workUnits])
    #expect(staged.statistics.peakLogicalRetainedBytes < original.statistics.peakLogicalRetainedBytes)

    let target = ReferenceFixture(definitions: 128, references: 128)
    let probe = try run(target, .stagedReferenceArray)
    var exact = JSONLimits.balanced
    exact[.workUnits] = probe.statistics[.workUnits]
    exact[.retainedBytes] = probe.statistics.peakLogicalRetainedBytes
    #expect(try run(target, .stagedReferenceArray, limits: exact).statistics == probe.statistics)
    exact[.workUnits] -= 1
    do { _ = try run(target, .stagedReferenceArray, limits: exact); Issue.record("Staging reset work") }
    catch let failure as JSONFailure { #expect(failure.resource?.metric == .workUnits) }
}

@Test func referenceHeavyImportsLatchLateFailureAndCancellation() async throws {
    let bad = ReferenceFixture(definitions: 16, references: 32, missingLast: true)
    var progress = ImportProgress()
    do {
        _ = try JSON.withComposition { scope in
            do { return try importReferences(bad, scope: scope, progress: &progress) }
            catch let failure as JSONFailure {
                #expect(failure.code == .missingTarget)
                return []
            }
        }
        Issue.record("Caught late target failure finalized")
    } catch let failure as JSONFailure { #expect(failure.code == .missingTarget) }
    #expect(progress.completedReferences == 31)

    let fixture = ReferenceFixture(definitions: 16, references: 32)
    let task = Task.detached {
        var progress = ImportProgress()
        return try JSON.withComposition { scope in
            do { return try importReferences(fixture, scope: scope, progress: &progress, cancelAt: 8) }
            catch is CancellationError {
                #expect(progress.completedReferences == 8)
                return []
            }
        }
    }
    do { _ = try await task.value; Issue.record("Caught cancellation finalized") }
    catch is CancellationError {}
}
