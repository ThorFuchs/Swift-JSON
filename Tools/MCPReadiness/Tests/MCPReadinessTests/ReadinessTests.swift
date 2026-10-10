// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema
import MCPReadinessKit

@Test func frozenRootedVectorsAndPublicFidelityAreQualified() throws {
    let receipt = try runReadiness()
    #expect(receipt.outcomes.count == 20 && receipt.positiveCases == 8 && receipt.negativeCases == 12)
    #expect(receipt.operationalErrors == 2 && receipt.selectedDefinitions.count == 4)
    #expect(receipt.outcomes.allSatisfy { $0.expected == $0.actual })
}
@Test func individuallyAffordableStagesExceedAnAggregateBudget() throws {
    let baseline = try runCumulativeOperation(limits: .balanced)
    let costs = baseline.stages.map(\.work)
    let total = costs.reduce(UInt64(0), +), largest = costs.max()!
    #expect(largest < total)
    var limits = JSONLimits.balanced; limits[.workUnits] = total - 1
    // Every original stage fits this allowance in isolation, yet the composed
    // operation must terminate rather than write with a freshly reset allowance.
    #expect(costs.allSatisfy { $0 <= limits[.workUnits] })
    #expect(throws: JSONFailure.self) { try runCumulativeOperation(limits: limits) }
    limits[.workUnits] = total
    #expect(try runCumulativeOperation(limits: limits).remaining == 0)
}
@Test func failedStagePermanentlyTerminatesTheCallerAccount() throws {
    var limits = JSONLimits.balanced; limits[.workUnits] = 1
    var account = try RemainingWork(limits: limits)
    #expect(throws: JSONFailure.self) { try account.perform("parse") { try JSONParser(options: .init(limits: $0)).parseWithReport(Array("[1,2]".utf8)) } }
    #expect(account.terminated && account.stages.isEmpty)
    #expect(throws: RemainingWork.Failure.self) { try account.perform("retry") { try JSONParser(options: .init(limits: $0)).parseWithReport(Array("null".utf8)) } }
}
