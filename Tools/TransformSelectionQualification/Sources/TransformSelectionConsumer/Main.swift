// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONTransform

func selectionGuideExample() throws {
    let definition = try JSONTransformProgramDefinition.prepare(
        source: ".[] | select($values[.].enabled)", variables: ["values"]).result
    let plan = try definition.compile().result
    let row = try JSON.parse(#"{"enabled":true,"amount":9007199254740993}"#)
    let report = try plan.withSelection(population: [row, row]) { scope in
        var positions: [JSONTransformSelectionPosition] = []
        while let position = try scope.next() { positions.append(position) }
        return positions
    }
    let ordinals = try report.result.map { try report.completion.ordinal(of: $0) }
    precondition(ordinals == [0, 1])
    precondition(report.completion.populationCount == 2)
    precondition(report.completion.outputCount == 2)
}
private func run(_ source: String, _ population: [JSON], limits: JSONTransformSelectionLimits = .init()) throws -> JSONTransformSelectionReport<[JSONTransformSelectionPosition]> {
    try JSONTransformProgram.compile(source, variables: ["values"]).withSelection(population: population, limits: limits) { s in
        var positions: [JSONTransformSelectionPosition] = []
        while let p = try s.next() { positions.append(p) }; return positions
    }
}
private enum ConsumerError: Error { case provider }
@main enum Consumer {
    static func main() throws {
        var witnesses: [String] = []
        try selectionGuideExample(); witnesses.append("compiled-guide")
        let ordered = try run("1,0,1", [42,42])
        precondition(ordered.result.map(\.ordinal) == [1,0,1]); witnesses.append("order-repeats")
        let empty = try run("empty", [])
        precondition(empty.completion.outputCount == 0 && empty.completion.populationCount == 0); witnesses.append("empty-eof")
        do {
            _ = try JSONTransformProgram.compile("try (0,null) catch 0", variables: ["values"]).withSelection(population: [42]) { s in
                let first = try s.next(); precondition(first?.ordinal == 0)
                do { _ = try s.next(); preconditionFailure("Invalid position accepted") }
                catch let e as JSONTransformSelectionFailure { precondition(e == .invalidPosition) }
            }
            preconditionFailure("Caught boundary error certified")
        } catch let e as JSONTransformSelectionFailure { precondition(e == .invalidPosition) }
        witnesses.append("late-invalid")
        let other = try run("0", [42,42])
        do { _ = try other.completion.ordinal(of: ordered.result[0]); preconditionFailure("Foreign position accepted") }
        catch let e as JSONTransformSelectionFailure { precondition(e == .foreignPosition) }
        witnesses.append("foreign-owner")
        let parameterized = try JSONTransformProgram.compile(".[] | select($values[.] >= $minimum)", variables: ["values","minimum"])
        let selection = try parameterized.withSelection(population: [1,2,3], bindings: ["minimum":2]) { s in
            var ids: [UInt64] = []; while let p = try s.next() { ids.append(p.ordinal) }; return ids
        }
        precondition(selection.result == [1,2]); witnesses.append("bindings")
        var escaped: JSONTransformSelectionScope?
        var position: JSONTransformSelectionPosition?
        var completion: JSONTransformSelectionCompletion?
        do {
            let report = try JSONTransformProgram.compile("0", variables: ["values"]).withSelection(population: [.string(String(repeating:"x",count:8192))]) { s in
                escaped = s; position = try s.next(); let eof = try s.next(); precondition(eof == nil)
            }
            completion = report.completion
        }
        let owner = escaped!
        let retained = try withExtendedLifetime(position) { try owner.report()[.retainedBytes] }
        precondition(retained > 8192); position = nil
        let identityOnly = try withExtendedLifetime(completion) { try owner.report()[.retainedBytes] }
        precondition(identityOnly > 0 && identityOnly < 8192); completion = nil
        let settled = try owner.report(); precondition(settled[.retainedBytes] == 0)
        do { _ = try owner.next(); preconditionFailure("Escaped scope resumed") }
        catch let e as JSONTransformFailure { precondition(e.code == "scopeClosed") }
        witnesses.append("terminal-refunds")
        var calls = 0
        do {
            _ = try JSONTransformProgram.compile("try input catch 0", variables: ["values"]).withSelection(population: [42], source: { calls += 1; throw ConsumerError.provider }) { s in
                for _ in 0..<2 {
                    do { _ = try s.next(); preconditionFailure("Provider error swallowed") }
                    catch let e as JSONTransformFailure { precondition(e.category == .provider) }
                }
            }
            preconditionFailure("Provider error certified")
        } catch let e as JSONTransformFailure { precondition(e.category == .provider) }
        precondition(calls == 1); witnesses.append("provider-terminal")
        let measured = try run(".[]", [1,2,3])
        var limits = JSONTransformSelectionLimits(); limits.transform[.workUnits] = measured.completion.statistics[.workUnits]
        _ = try run(".[]", [1,2,3], limits: limits)
        limits.transform[.workUnits] -= 1
        do { _ = try run(".[]", [1,2,3], limits: limits); preconditionFailure("Budget reset") }
        catch let e as JSONTransformFailure { precondition(e.category == .resource) }
        witnesses.append("cumulative-work")
        var failed: JSONTransformSelectionScope?
        do {
            _ = try JSONTransformProgram.compile("0", variables: ["values"]).withSelection(population: [42]) { s in
                failed = s; s.cancel()
                do { _ = try s.next(); preconditionFailure("Cancel ignored") }
                catch let e as JSONTransformFailure { precondition(e.category == .cancelled) }
            }
            preconditionFailure("Cancelled invocation certified")
        } catch let e as JSONTransformFailure { precondition(e.category == .cancelled) }
        let terminal = try failed!.report(); precondition(terminal[.retainedBytes] == 0)
        witnesses.append("cancellation")
        precondition(witnesses.count == 10)
        print("TRANSFORM_SELECTION passed witnesses=10")
    }
}
