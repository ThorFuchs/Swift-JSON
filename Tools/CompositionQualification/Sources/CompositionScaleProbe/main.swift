// SPDX-License-Identifier: Apache-2.0
import CompositionFixtures
import Foundation
import JSON

struct Cell: Encodable {
    let name: String
    let definitions: Int
    let references: Int
    let profile: String
    let strategy: String
    let expected: String
    let capacityGoal: String
    let outcome: String
    let completedReferences: Int
    let inputBytes: Int
    let seconds: Double
    let work: UInt64?
    let logicalPeak: UInt64?
    let metric: String?
    let attemptedUsage: UInt64?
}
let arguments = CommandLine.arguments
guard arguments.count == 3 else { fatalError("Expected output JSON and fixture directory paths") }
let output = URL(fileURLWithPath: arguments[1])
let fixtureDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
let cells: [(String, Int, Int, String, JSONLimits, ReferenceStrategy, String)] = [
    ("balanced-16-32", 16, 32, "balanced", .balanced, .perReferenceRoot, "completed"),
    ("balanced-128-64", 128, 64, "balanced", .balanced, .perReferenceRoot, "completed"),
    ("balanced-128-128", 128, 128, "balanced", .balanced, .perReferenceRoot, "operational_error"),
    ("offline-256-256", 256, 256, "offline", .offline, .perReferenceRoot, "completed"),
    ("balanced-1024-1024", 1024, 1024, "balanced", .balanced, .perReferenceRoot, "operational_error"),
    ("offline-1024-1024", 1024, 1024, "offline", .offline, .perReferenceRoot, "operational_error"),
    ("staged-balanced-128-128", 128, 128, "balanced", .balanced, .stagedReferenceArray, "completed"),
    ("staged-offline-512-256", 512, 256, "offline", .offline, .stagedReferenceArray, "completed")
]
var rows: [Cell] = []
for (name, definitions, references, profile, limits, strategy, expected) in cells {
    let fixture = ReferenceFixture(definitions: definitions, references: references)
    try fixture.data.write(to: fixtureDirectory.appendingPathComponent(name + ".json"))
    let oracle = try fixture.expectedSelections()
    var progress = ImportProgress()
    let clock = ContinuousClock(), start = clock.now
    var work: UInt64?, peak: UInt64?, metric: String?, attempted: UInt64?
    let outcome: String
    do {
        let report = try JSON.withComposition(limits: limits) {
            try importReferences(fixture, scope: $0, progress: &progress, strategy: strategy)
        }
        precondition(report.result == oracle && progress.completedReferences == references)
        work = report.statistics[.workUnits]; peak = report.statistics.peakLogicalRetainedBytes
        precondition(report.statistics[.compiledPlanBytes] == 0 && report.statistics[.compileWorkUnits] == 0)
        outcome = "completed"
    } catch let failure as JSONFailure {
        guard failure.category == .resource else { throw failure }
        outcome = "operational_error"
        metric = failure.resource?.metric.rawValue; attempted = failure.resource?.attemptedUsage
        precondition(progress.completedReferences < references)
    }
    let duration = start.duration(to: clock.now)
    let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    rows.append(Cell(name: name, definitions: definitions, references: references, profile: profile, strategy: strategy.rawValue,
                     expected: expected, capacityGoal: name == "balanced-128-128" ? "completed" : expected,
                     outcome: outcome, completedReferences: progress.completedReferences,
                     inputBytes: fixture.data.count, seconds: seconds, work: work, logicalPeak: peak,
                     metric: metric, attemptedUsage: attempted))
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(rows).write(to: output)
let met = rows.filter { $0.outcome == $0.expected }.count
print("COMPOSITION_SCALE observed cells=\(rows.count) behavior_expectations_met=\(met)")
