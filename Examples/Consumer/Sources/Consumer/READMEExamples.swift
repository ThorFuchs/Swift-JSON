// SPDX-License-Identifier: Apache-2.0
// Compiled README examples; checked by the documentation lane.
import JSONBridges
import JSONValueDSL
import JSONSchemaDSL
import JSON
import Foundation
import JSONSchema
import JSONPatch
import JSONStreaming
import JSONHTML

func inspectArray<Source: AsyncSequence>(_ source: Source) async throws -> UInt64
where Source.Element == JSONByteChunk {
    var elements: UInt64 = 0
    var completed = false
    for try await event in JSONTopLevelArraySequence(source) {
        switch event {
        case .element(let index, _):
            precondition(index == elements)
            elements += 1
        case .documentCompleted(let summary):
            precondition(summary.records == elements)
            completed = true
        }
    }
    precondition(completed)
    return elements
}

func runREADMEExamples() throws {
    let quick = try JSON.parse(#"{"n":9007199254740993,"note":null}"#)
    let quickCount = try quick.read { try $0["n"].requiredInteger(as: UInt64.self) }
    precondition(quickCount == 9_007_199_254_740_993)
    let quickDecimal = try JSON.number(parsing: "0.1")
    precondition(quickDecimal.numberValue != nil)

    let bridgeCount: UInt64 = 9_007_199_254_740_993
    let bridgeNumber = bridgeCount.jsonNumber() // Trusted, unmetered integer construction.
    let bridgeRecovered = try UInt64(jsonNumber: bridgeNumber)
    precondition(bridgeRecovered == bridgeCount)
    let bridgeTenth = try JSONNumber(parsing: "0.1")
    let bridgeRounded = try Double(jsonNumber: bridgeTenth, policy: .rounded)
    precondition(bridgeRounded == 0.1)

    let authoredTenth = try JSONNumber(parsing: "0.1")
    let authoredJSON = try JSONValueDSL.object {
        Field("amount", exactNumber: authoredTenth)
        Field.array("nested") { Element.array { Element(1); Element(2) } }
    }
    let authoredSchema = try JSONSchemaDSL.document {
        Schema.type(.object)
        Schema.properties {
            Property("amount") { Schema.type(.number); Schema.minimum(authoredTenth) }
        }
        Schema.required("amount")
    }
    let authoredPlan = try JSONSchemaCompiler().compile(authoredSchema)
    let authoredResult = try JSONSchemaValidator().validate(authoredJSON, against: authoredPlan)
    precondition(authoredResult.isValid)

    let parser = JSONParser()
    let value = try parser.parse(#"{"count":9007199254740993,"note":null}"#)
    let count = try JSONPointer(parsing: "/count").resolve(in: value)
    let exact = try count.numberValue!.integer(as: Int64.self)
    precondition(exact == 9_007_199_254_740_993)

    let encoded = try JSONWriter().write(value)
    let roundTrip = try parser.parse(encoded)
    precondition(roundTrip == value)

    let note = try value.presence(of: "note")
    let missing = try value.presence(of: "missing")
    precondition(note == .null)
    precondition(missing == .absent)

    let keys = try JSONObject(members: [
        JSONMember("\u{e9}", value: 1),
        JSONMember("e\u{301}", value: 2)
    ])
    precondition(keys.count == 2)

    struct Reading: Codable, Equatable {
        let count: UInt64
        let label: String
    }

    let reading = Reading(count: 9_007_199_254_740_993, label: "sensor")
    let bytes = try JSONWriter().encode(reading)
    let decoded = try JSONParser().decode(Reading.self, from: bytes)
    precondition(decoded == reading)

    let scoped = try value.readWithReport { root in
        let exactCount = try root["count"].requiredInteger(as: UInt64.self)
        let optionalNote = try root.stringPresence(of: "note")
        return (exactCount, optionalNote)
    }
    precondition(scoped.result.0 == 9_007_199_254_740_993)
    precondition(scoped.result.1 == .null)
    precondition(scoped.statistics[.workUnits] > 0)

    let payload = try JSONCodablePayload(preserving: value)
    let transported = try PropertyListEncoder().encode(payload)
    let restored = try PropertyListDecoder().decode(JSONCodablePayload.self, from: transported)
    let restoredValue = try restored.value()
    precondition(restoredValue == value)

    let schema = try JSONSchemaDocument(parser.parse(
        #"{"type":"object","properties":{"count":{"type":"integer"}},"required":["count"]}"#
    ))
    let plan = try JSONSchemaCompiler().compile(schema)
    let result = try JSONSchemaValidator().validate(value, against: plan)
    precondition(result.isValid)

    let output = try result.output()
    precondition(output.objectValue?["valid"] == true)

    let patch = try JSONPatch(operations: [
        .replace(path: JSONPointer(parsing: "/count"), value: 42)
    ])
    let changed = try patch.applying(to: value)
    let expectedChange = try parser.parse(#"{"count":42,"note":null}"#)
    precondition(changed == .document(expectedChange))

    let merged = try JSONMergePatch(.null).applying(to: value)
    precondition(merged == .null)

    var limits = JSONLimits.conservative
    limits[.inputBytes] = 1_048_576
    limits[.workUnits] = 2_000_000
    let report = try JSONParser(options: .init(limits: limits))
        .parseWithReport(Array(#"{"ready":true}"#.utf8))
    precondition(report.result.objectValue?["ready"] == true)
    precondition(report.statistics[.workUnits] > 0)

    let interactiveHTML = try JSONHTMLRenderer(options: .init(
        title: "Exact values", presentation: .interactive,
        initiallyExpandedDepth: 2, outlineDepth: 3
    )).renderWithReport(value)
    precondition(interactiveHTML.statistics.copyJSONBytes > 0)

    let exportReport = try JSONExportDocument.prepareWithReport(value)
    let markdownItem = try exportReport.result.selecting([.markdown])
    let markdownBytes = try markdownItem.data(for: .markdown)
    precondition(exportReport.operation[.nodes] > 0 && !markdownBytes.isEmpty)

    let richItem = try JSONExportDocument.prepare(value, options: .init(
        formats: [.json, .plainText, .rtf]
    )).selecting([.rtf])
    let richBytes = try richItem.data(for: .rtf)
    precondition(!richBytes.isEmpty)
}
