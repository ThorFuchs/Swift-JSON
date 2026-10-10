// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@Test func statisticsRemainCumulativeAcrossRecordAndValueScopes() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .streaming)
    try meter.charge(.nodes, 2); try meter.charge(.inputBytes, 10); try meter.charge(.totalInputBytes, 10); try meter.work(3)
    try meter.retain(20); try meter.resetRecord(liveBytes: 4)
    try meter.charge(.nodes, 3); try meter.charge(.inputBytes, 5); try meter.charge(.totalInputBytes, 5); try meter.work(7)
    let stats = meter.statistics()
    #expect(stats[.nodes] == 5 && stats[.inputBytes] == 15 && stats[.totalInputBytes] == 15)
    #expect(stats[.workUnits] == 10 && stats[.totalWorkUnits] == 10)
    #expect(stats[.retainedBytes] == 4 && stats.peakLogicalRetainedBytes == 20)
    #expect(meter.used(.nodes) == 3 && meter.used(.workUnits) == 7)
}
@Test func repeatedRegexSearchesReportCumulativeSearchWork() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .schemaEvaluation)
    try meter.work(3, subsystem: .regexSearchWorkUnits); try meter.beginRegexSearch()
    try meter.work(4, subsystem: .regexSearchWorkUnits)
    #expect(meter.used(.regexSearchWorkUnits) == 4)
    #expect(meter.statistics()[.regexSearchWorkUnits] == 7)
}
@Test func cumulativeReportCounterOverflowIsCheckedBeforeAdmission() throws {
    var limits = JSONLimits.balanced; limits[.nodes] = UInt64(Int.max) - 1
    var meter = try JSONWorkMeter(limits: limits, domain: .core)
    try meter.charge(.nodes, UInt64(Int.max) - 1); try meter.resetValueBounds()
    try meter.charge(.nodes, UInt64(Int.max) - 1); try meter.resetValueBounds()
    do { try meter.charge(.nodes, 4); Issue.record("Cumulative report must not wrap") }
    catch let failure as JSONFailure { #expect(failure.code == .counterOverflow && failure.resource?.metric == .nodes) }
    #expect(meter.used(.nodes) == 0)
}
