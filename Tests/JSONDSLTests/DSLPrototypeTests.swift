import JSON
import JSONDSLCore
import JSONSchema
import JSONSchemaDSL
import JSONValueDSL
// SPDX-License-Identifier: Apache-2.0
import Testing

@Suite struct DSLPrototypeTests {
    @Test func prototypeValueObjectNestedArrayConditionalAndLoop() throws {
        let addOptional = true
        let doc = try JSONValueDSL.object {
            Field("id", UInt64(9_007_199_254_740_993))
            Field("title", "A customer")
            Field("verified", true)
            if addOptional { Field("note", .null) }
            Field.array("tags") {
                Element("one")
                Element("two")
                Element.array {
                    Element(10)
                    Element(20)
                }
                for i in 1...3 { Element(i) }
            }
            Field.object("meta") {
                Field("kind", "demo")
                Field("active", false)
            }
        }
        let o = try #require(doc.objectValue)
        #expect((o.members.map { $0.key.string }) == (["id", "title", "verified", "note", "tags", "meta"]))
        #expect((o["note"]) == (.null))
        #expect((o["tags"]?.arrayValue?.count) == (6))
        #expect((o["tags"]?.arrayValue?[2].arrayValue?.count) == (2))
        #expect((o["meta"]?.objectValue?["kind"]) == (.string("demo")))
    }
    @Test func prototypeEmptyContainersAndNoFlattening() throws {
        let value = try JSONValueDSL.object {
            Field.object("empty") {}
            Field.array("nested") {
                Element.array { Element(1) }
            }
        }
        #expect((value.objectValue?["empty"]?.objectValue?.members.count) == (0))
        let a = try #require(value.objectValue?["nested"]?.arrayValue)
        #expect((a.count) == (1))
        #expect((a[0].arrayValue?.count) == (1))
    }
    @Test func prototypeConditionalAbsenceIsNotNull() throws {
        let show = false
        let doc = try JSONValueDSL.object {
            Field("a", 1)
            if show { Field("b", .null) }
        }
        #expect((doc.objectValue?["b"]) == nil)
        #expect((doc.objectValue?.members.count) == (1))
    }
    @Test func prototypeChoiceAndExplicitFlatten() throws {
        let simple = false
        let doc = try JSONValueDSL.array {
            Element("initial")
            if simple { Element(1) } else { Element(2) }
            Elements(contentsOf: [3, 4])
        }
        let a = try #require(doc.arrayValue)
        #expect((a.count) == (4))
        #expect((a[1]) == (.number(JSONNumber(integer: 2))))
    }
    @Test func prototypeDuplicateValueKeysMustThrow() throws {
        #expect(throws: JSONFailure.self) {
            try JSONValueDSL.object {
                Field("name", "first")
                Field("name", "second")
            }
        }
    }
    @Test func prototypeUnicodeScalarDistinctKeysRemainDistinct() throws {
        let a = "\u{e9}"
        let b = "e\u{301}"
        #expect((a) == (b))  // Swift canonical String equality: demonstration of trap.
        let obj = try JSONValueDSL.object {
            Field(a, 1)
            Field(b, 2)
        }
        #expect((obj.objectValue?.members.count) == (2))
        #expect(!(JSONKey(a) == JSONKey(b)))
    }
    @Test func prototypeSchemaRichDraft202012Shape() throws {
        let schema = try JSONSchemaDSL.document {
            Schema.schemaURI("https://json-schema.org/draft/2020-12/schema")
            Schema.identifier("https://example.test/customer")
            Schema.title("Customer")
            Schema.description("Demo shape")
            Schema.type(.object)
            Schema.minProperties(1)
            Schema.maxProperties(12)
            Schema.properties {
                Property("id") { Schema.reference("#/$defs/ID") }
                Property("name") {
                    Schema.type(.string)
                    Schema.minLength(2)
                    Schema.maxLength(100)
                    Schema.pattern("^[^0-9]+$")
                }
                Property("state") {
                    Schema.enumValues(["new", "active", "closed"])
                    Schema.defaultValue("new")
                }
                Property("orders") {
                    Schema.type(.array)
                    Schema.minItems(0)
                    Schema.uniqueItems(true)
                    Schema.items {
                        Schema.type(.integer)
                        Schema.minimum(JSONNumber(integer: 0))
                    }
                }
                Property("sentinel", allowsAll: false)
            }
            Schema.required("id", "name")
            Schema.patternProperties { PatternProperty("^x-") { Schema.type(.string) } }
            Schema.dependentRequired { RequiredDependency("card", requires: ["billingAddress"]) }
            Schema.dependentSchemas { DependentSchema("country") { Schema.type(.object) } }
            Schema.propertyNames { Schema.type(.string) }
            Schema.additionalProperties(false)
            Schema.unevaluatedProperties(false)
            Schema.definitions {
                Definition("ID") {
                    Schema.type(.integer)
                    Schema.minimum(JSONNumber(integer: 0))
                }
            }
            Schema.rawKeyword("x-internal-note", "preserved")
        }
        let obj = try #require(schema.raw.objectValue)
        #expect((obj["type"]) == (.string("object")))
        #expect((obj["properties"]?.objectValue?.members.count) == (5))
        #expect((obj["$defs"]?.objectValue?.members.count) == (1))
        #expect((obj["x-internal-note"]) == (.string("preserved")))
        #expect((obj["dependentRequired"]?.objectValue?.members.count) == (1))
        let plan = try JSONSchemaCompiler().compile(schema)
        #expect(
            try JSONSchemaValidator().validate(JSONParser().parse(#"{"id":1,"name":"Ada"}"#), against: plan)
                .isValid)
        #expect(
            try !JSONSchemaValidator().validate(JSONParser().parse(#"{"id":-1,"name":"Ada"}"#), against: plan)
                .isValid)
    }
    @Test func prototypeArrayCompositionConditionalAndBooleanSchema() throws {
        let include = true
        let schema = try JSONSchemaDSL.document {
            Schema.type(.array)
            Schema.prefixItems {
                Rule { Schema.type(.string) }
                Rule(false)
                if include { Rule { Schema.type(.number) } }
            }
            Schema.contains { Schema.type(.string) }
            Schema.minContains(1)
            Schema.maxContains(3)
            Schema.unevaluatedItems(false)
            Schema.anyOf {
                Rule { Schema.minItems(1) }
                Rule(true)
            }
            Schema.oneOf {
                Rule(false)
                Rule(true)
            }
            Schema.allOf {
                Rule(true)
                Rule { Schema.maxItems(10) }
            }
            Schema.not { Schema.type(.null) }
            Schema.ifSchema { Schema.minItems(2) }
            Schema.thenSchema { Schema.minItems(3) }
            Schema.elseSchema { Schema.minItems(1) }
        }
        let obj = try #require(schema.raw.objectValue)
        #expect((obj["prefixItems"]?.arrayValue?.count) == (3))
        #expect((obj["oneOf"]?.arrayValue?.count) == (2))
        #expect((obj["allOf"]?.arrayValue?.count) == (2))
        let plan = try JSONSchemaCompiler().compile(schema)
        #expect(try JSONSchemaValidator().validate(.array(["ok"]), against: plan).isValid)
        #expect(try !JSONSchemaValidator().validate(.array(["ok", 1]), against: plan).isValid)
    }
    @Test func prototypeSchemaVocabularyAndAnnotations() throws {
        let c = try JSONSchemaDSL.document {
            Schema.vocabulary([("https://example.test/v", true)])
            Schema.anchor("hello")
            Schema.dynamicAnchor("node")
            Schema.dynamicReference("#node")
            Schema.comment("not an assertion")
            Schema.format("email")
            Schema.contentEncoding("base64")
            Schema.contentMediaType("text/plain")
            Schema.contentSchema { Schema.type(.string) }
            Schema.examples(["Ada", "Grace"])
            Schema.deprecated(true)
            Schema.readOnly(true)
            Schema.writeOnly(false)
        }
        #expect((c.raw.objectValue?["$vocabulary"]) != nil)
        #expect((c.raw.objectValue?["readOnly"]) == (.boolean(true)))
        let plan = try JSONSchemaCompiler().compile(c)
        do {
            _ = try JSONSchemaValidator().validate("person@example.test", against: plan)
            Issue.record("Self dynamic reference is nonproductive, not invalidity")
        } catch let error as JSONSchemaEvaluationFailure {
            #expect(error.category == .nonproductiveReference)
        }
    }
    @Test func prototypeSchemaDuplicateKeywordsAndPropertiesFail() throws {
        #expect(throws: JSONFailure.self) {
            try JSONSchemaDSL.document {
                Schema.type(.object)
                Schema.type(.array)
            }
        }
        #expect(throws: JSONFailure.self) {
            try JSONSchemaDSL.document {
                Schema.properties {
                    Property("id") { Schema.type(.string) }
                    Property("id") { Schema.type(.integer) }
                }
            }
        }
    }
    @Test func prototypeSchemaConditionalsAndLoopsDoNotEmitFalseSchemas() throws {
        let shouldInclude = false
        let schema = try JSONSchemaDSL.document {
            Schema.type(.object)
            Schema.properties {
                for name in ["alpha", "beta"] { Property(name) { Schema.type(.string) } }
                if shouldInclude { Property("absent", allowsAll: false) }
            }
        }
        let props = try #require(schema.raw.objectValue?["properties"]?.objectValue)
        #expect((props.members.map { $0.key.string }) == (["alpha", "beta"]))
        #expect((props["absent"]) == nil)
    }
    @Test func prototypeSchemaBooleanRoot() throws {
        let accepting = try JSONSchemaDSL.boolean(true)
        let rejecting = try JSONSchemaDSL.boolean(false)
        #expect((accepting.raw) == (.boolean(true)))
        #expect((rejecting.raw) == (.boolean(false)))
    }
    @Test func prototypeExactDecimalInputShape() throws {
        let exact = try JSONNumber(parsing: "0.1")
        let value = try JSONValueDSL.object { Field("decimal", exactNumber: exact) }
        #expect((value.objectValue?["decimal"]) == (.number(exact)))
        let zero = try JSONNumber(parsing: "0.0")
        let schema = try JSONSchemaDSL.document {
            Schema.type(.number)
            Schema.multipleOf(exact)
            Schema.minimum(zero)
        }
        #expect((schema.raw.objectValue?["multipleOf"]) == (.number(exact)))
    }
    @Test func prototypePrototypeCapacityAndDepthPreflight() throws {
        var limit = JSONLimits.balanced
        limit[.maxDepth] = 12
        limit[.arrayItems] = 2
        limit[.objectMembers] = 2
        #expect(throws: JSONFailure.self) {
            try JSONValueDSL.array(limits: limit) {
                Element(1)
                Element(2)
                Element(3)
            }
        }
        #expect(throws: JSONFailure.self) {
            try JSONValueDSL.object(limits: limit) {
                Field("a", 1)
                Field("b", 2)
                Field("c", 3)
            }
        }
        var shallow = JSONLimits.balanced
        shallow[.maxDepth] = 1
        #expect(throws: JSONFailure.self) {
            try JSONValueDSL.object(limits: shallow) {
                Field.object("a") { Field.object("b") { Field("c", 1) } }
            }
        }
    }
    @Test func prototypeTypeBuilderNoConflationOfKeywordAndProperty() throws {
        let doc = try JSONSchemaDSL.document {
            Schema.type(.object)
            Schema.properties {
                Property("empty") {}
            }
        }
        #expect(
            (doc.raw.objectValue?["properties"]?.objectValue?["empty"]?.objectValue?.members.count) == (0))
    }
}
