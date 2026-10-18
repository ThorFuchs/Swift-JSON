// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONTransform

func require(_ value: Bool) { precondition(value) }

func collect(_ plan: JSONTransformProgram, input: JSON = .null) throws -> [JSON] {
    try plan.withExecution(input: input) { execution in
        var result: [JSON] = []
        while let output = try execution.next() { result.append(output.value) }
        return result
    }.result
}

@main struct TransformConsumer {
    static func main() async throws {
        var witnesses = 0
        try require(collect(JSONTransformProgram.compile("empty")).isEmpty); witnesses += 1
        try require(collect(JSONTransformProgram.compile("null")) == [.null]); witnesses += 1
        let plan = try JSONTransformProgram.compile(".[] | . + 1")
        let root = try JSON.parse("[9007199254740993,0.1]")
        let expected = try JSON.parse("[9007199254740994,1.1]").arrayValue!
        try require(collect(plan, input: root) == expected); witnesses += 1
        try require(collect(plan, input: root) == expected); witnesses += 1
        let scalar = try JSON.parse(#"{"é":1,"e\u0301":2}"#)
        try require(collect(JSONTransformProgram.compile("length"), input: scalar) == [2]); witnesses += 1
        do { _ = try JSONTransformProgram.compile("["); preconditionFailure("compile accepted") }
        catch let failure as JSONTransformFailure { precondition(failure.category == .compilation && failure.byteOffset == 0) }; witnesses += 1
        do { _ = try collect(JSONTransformProgram.compile("1/3")); preconditionFailure("division approximated") }
        catch let failure as JSONTransformFailure { precondition(failure.category == .language) }; witnesses += 1
        var calls = 0
        let inputs = try JSONTransformProgram.compile("try inputs catch null")
        var limits = JSONTransformLimits(); limits[.inputValues] = 2
        do {
            _ = try inputs.withExecution(input: .null, limits: limits, source: { calls += 1; return .null }) { execution in
                let first = try execution.next(); precondition(first?.value == .null)
                precondition(execution.used(.inputValues) == 2 && execution.remainingWorkUnits > 0)
                _ = try execution.next()
            }
            preconditionFailure("input cap reset")
        } catch let failure as JSONTransformFailure { precondition(failure.category == .resource && failure.metric == "inputValues") }
        precondition(calls == 2); witnesses += 1
        let binding = try JSONTransformProgram.compile("$v", variables: ["v"])
        let bound = try binding.withExecution(input: .null, bindings: ["v": root]) { execution in try execution.next()?.value }
        precondition(bound.result == root && bound.statistics[.workUnits] > 0); witnesses += 1
        do {
            _ = try inputs.withExecution(input: .null) { execution in execution.cancel(); _ = try execution.next() }
            preconditionFailure("cancel accepted")
        } catch let failure as JSONTransformFailure { precondition(failure.category == .cancelled) }; witnesses += 1
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for _ in 0..<8 { group.addTask { try collect(plan, input: root) == expected } }
            for try await match in group { precondition(match) }
        }; witnesses += 1
        var narrow = JSONTransformLimits(); narrow.json[.numberDigits] = 1
        do {
            _ = try JSONTransformProgram.compile("12345").withExecution(input: .null, limits: narrow) { e in try e.next() }
            preconditionFailure("compiled literal bypassed execution value bounds")
        } catch let failure as JSONTransformFailure { precondition(failure.category == .resource && failure.metric == "numberDigits") }; witnesses += 1
        print("{\"consumer\":\"JSON+JSONTransform\",\"witnesses\":\(witnesses),\"status\":\"passed\"}")
    }
}
