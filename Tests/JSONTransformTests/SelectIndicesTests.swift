// SPDX-License-Identifier: Apache-2.0
// Public-consumer tests for JSONTransformProgram.selectIndices(in:).
import Testing
import JSON
import JSONTransform

private func selectIndicesPlan(_ source: String) throws -> JSONTransformProgram {
    try JSONTransformProgramDefinition.prepare(source: source, variables: ["values"]).result.compile().result
}

@Test func selectionIndicesMatchTheManualSelectionLoopExactly() throws {
    let row = try JSON.parse(#"{"enabled":true,"amount":9007199254740993}"#)
    let off = try JSON.parse(#"{"enabled":false}"#)
    let population = [row, off, row, off, row]
    for source in [".[] | select($values[.].enabled)", "[.[] | select($values[.].enabled)] | reverse | .[]",
                   ".[] | select($values[.].enabled) | (., .)", "empty"] {
        let plan = try selectIndicesPlan(source)
        let manual = try plan.withSelection(population: population) { scope in
            var positions: [JSONTransformSelectionPosition] = []
            while let position = try scope.next() { positions.append(position) }
            return positions
        }
        let shortcut = try plan.selectIndices(in: population)
        #expect(shortcut.result == (try manual.result.map { try manual.completion.ordinal(of: $0) }), "\(source)")
        #expect(shortcut.completion.populationCount == 5 && shortcut.completion.outputCount == manual.completion.outputCount)
        // Positions stay alive until EOF in both forms, so the accounting snapshot is identical.
        #expect(shortcut.completion.statistics == manual.completion.statistics, "\(source)")
    }
    #expect(try selectIndicesPlan(".[] | select($values[.].enabled) | (., .)").selectIndices(in: population).result
            == [0, 0, 2, 2, 4, 4])
    #expect(try selectIndicesPlan("empty").selectIndices(in: []).result.isEmpty)
}

@Test func selectionIndicesKeepRefusalsAndBindings() throws {
    let population: [JSON] = [1, 2, 3]
    let outOfRange = try selectIndicesPlan(".[] | . + 3")
    #expect(throws: (any Error).self) { _ = try outOfRange.selectIndices(in: population) }
    let fraction = try selectIndicesPlan(".[] | . + 0.5")
    #expect(throws: (any Error).self) { _ = try fraction.selectIndices(in: population) }
    let bound = try JSONTransformProgramDefinition.prepare(source: ".[] | select($values[.] > $floor)",
                                                           variables: ["values", "floor"]).result.compile().result
    #expect(try bound.selectIndices(in: population, bindings: ["floor": 1]).result == [1, 2])
    var limits = JSONTransformSelectionLimits(); limits.maximumPopulationValues = 2
    #expect(throws: (any Error).self) { _ = try bound.selectIndices(in: population, bindings: ["floor": 1], limits: limits) }
}
