// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema
import JSONValueDSL
import JSONSchemaDSL
import JSONTransform
import JSONInspection

@Test func consolidationAuthoredValuesValidateTransformAndTraverseWithoutScalarLoss() throws {
    let value = try JSONValueDSL.object {
        Field.array("nodes") {
            Element.object {
                Field("id", "é")
                Field("count", UInt64(9_007_199_254_740_993))
            }
            Element.object { Field("id", "e\u{301}") }
        }
        Field.array("edges") {
            Element.object {
                Field("from", "é")
                Field("to", "e\u{301}")
            }
        }
    }
    let schema = try JSONSchemaDSL.document {
        Schema.type(.object)
        Schema.properties {
            Property("nodes") { Schema.type(.array) }
            Property("edges") { Schema.type(.array) }
        }
        Schema.required("nodes", "edges")
    }
    let validation = try JSONSchemaValidator().validate(value, against: JSONSchemaCompiler().compile(schema))
    #expect(validation.isValid)
    let program = try JSONTransformProgram.compile(".nodes[].count")
    let evaluation = try program.withExecution(input: value) { execution in
        let first = try #require(try execution.next())
        let second = try #require(try execution.next())
        #expect(first.value == .number(try JSONNumber(parsing: "9007199254740993")))
        #expect(second.value == .null)
        #expect(try execution.next() == nil)
    }
    #expect(evaluation.statistics[.workUnits] > 0)
    let graph = try JSONGraphProjection.build(document: JSONDocument(root: value), profile: .init(
        nodesAt: [.key("nodes")], edgesAt: [.key("edges")],
        nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to"))
    #expect(graph.result.nodeCount == 2)
    #expect(graph.result.edgeCount == 1)
    #expect(try graph.result.breadthFirst(fromNode: 0).result == [0, 1])
    #expect(graph.statistics[.workUnits] > 0)
}

@Test func consolidationAuthoredInputCannotReopenFailedTransformLedger() throws {
    let value = try JSONValueDSL.array { Element(1); Element(2) }
    let program = try JSONTransformProgram.compile(".[]")
    var limits = JSONTransformLimits()
    limits[.results] = 1
    do {
        _ = try program.withExecution(input: value, limits: limits) { execution in
            #expect(try execution.next()?.value == 1)
            do {
                _ = try execution.next()
                Issue.record("The second result exceeded the invocation cap without throwing")
            } catch let failure as JSONTransformFailure {
                #expect(failure.category == .resource)
                #expect(failure.code == "limitExceeded")
                #expect(failure.metric == "results")
            }
        }
        Issue.record("Catching an owned failure reopened scope completion")
    } catch let failure as JSONTransformFailure {
        #expect(failure.category == .resource)
        #expect(failure.code == "limitExceeded")
        #expect(failure.metric == "results")
    }
}
