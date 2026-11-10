// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONTransform

func guideExample() throws {
    let definition = try JSONTransformProgramDefinition.prepare(
        source: "$amount", variables: ["amount"]).result
    let bytes = try definition.encode().result
    let restored = try JSONTransformProgramDefinition.decode(bytes).result
    let compiled = try restored.compile()
    let amount = JSON.number(try JSONNumber(parsing: "9007199254740993"))
    let output = try compiled.result.withExecution(input: .null, bindings: ["amount": amount]) {
        try $0.next()?.value
    }
    precondition(output.result == amount)
    precondition(compiled.statistics[.workUnits] > 0)
}
@main enum Consumer {
    static func main() throws {
        try guideExample()
        let golden = #"{"definition":"swift-json-transform-source","version":1,"dialect":"swift-json-query-v1","source":".","variables":[]}"#
        let definition = try JSONTransformProgramDefinition.prepare(source: ".").result
        let canonical = try definition.encode().result
        precondition(canonical == Array(golden.utf8))
        let names = try JSONTransformProgramDefinition.prepare(source: "$z", variables: ["z","a"]).result
        precondition(names.variableNames == ["a","z"])
        do {
            _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: ["a","a"])
            preconditionFailure("Duplicate name accepted")
        } catch let error as JSONTransformDefinitionFailure { precondition(error == .duplicateVariableName) }
        var limits = JSONTransformLimits(); limits[.workUnits] = 0
        do { _ = try definition.compile(limits: limits); preconditionFailure("Compile budget reset") }
        catch let error as JSONTransformFailure { precondition(error.category == .resource) }
        let report = try JSONTransformProgram.compileWithReport("null,42")
        let output = try report.result.withExecution(input: .null) { execution in
            let first = try execution.next(), second = try execution.next(), end = try execution.next()
            precondition(first?.value == .null && second?.value == 42 && end == nil)
        }
        precondition(report.statistics[.workUnits] > 0 && output.statistics[.workUnits] > 0)
        print("TRANSFORM_BINDINGS passed witnesses=6")
    }
}
