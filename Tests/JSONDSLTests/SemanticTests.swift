import JSON
import JSONSchema
import JSONSchemaDSL
import JSONValueDSL
// SPDX-License-Identifier: Apache-2.0
import Testing

private func parity(
    _ declaration: JSONSchemaDocument, _ text: String,
    valid: [String], invalid: [String], registry: JSONSchemaRegistry = .empty
) throws {
    let handwritten = try JSONSchemaDocument(JSONParser().parse(text))
    #expect(try JSONComparison.equals(declaration.raw, handwritten.raw))
    let compiler = JSONSchemaCompiler()
    let authored = try compiler.compile(declaration, registry: registry)
    let manual = try compiler.compile(handwritten, registry: registry)
    let validator = JSONSchemaValidator(options: .init(collectAnnotations: true))
    for (instances, expected) in [(valid, true), (invalid, false)] {
        for text in instances {
            let instance = try JSONParser().parse(text)
            let a = try validator.validate(instance, against: authored)
            let b = try validator.validate(instance, against: manual)
            #expect(a.isValid == expected)
            #expect(a.isValid == b.isValid)
            #expect(a.annotations.map(\.value) == b.annotations.map(\.value))
            #expect(a.annotations.map(\.keywordLocation) == b.annotations.map(\.keywordLocation))
        }
    }
}

private func duplicate(_ body: () throws -> Void) throws {
    do {
        try body()
        Issue.record("Exact duplicate declaration must throw")
    } catch let error as JSONFailure {
        #expect(error.category == .syntax && error.code == .duplicateKey)
        #expect(error.resource == nil)
    }
}

@Test func dslV01ExactIntegersIncludeBoth128BitBoundaries() throws {
    let value = try JSONValueDSL.object {
        Field("large", UInt64(9_007_199_254_740_993))
        Field("signed", Int128.min)
        Field("unsigned", UInt128.max)
    }
    let expected = try JSONParser().parse(
        "{\"large\":9007199254740993,\"signed\":\(Int128.min),\"unsigned\":\(UInt128.max)}")
    #expect(value == expected)
    #expect(try #require(value.objectValue?["signed"]?.numberValue).integer(as: Int128.self) == Int128.min)
    #expect(
        try #require(value.objectValue?["unsigned"]?.numberValue).integer(as: UInt128.self) == UInt128.max)
}

@Test func dslV02ExactDecimalLexemeAndMultipleOfNeverUseEpsilon() throws {
    let tenth = try JSONNumber(parsing: "1.00e-1")
    let value = try JSONValueDSL.object { Field("n", exactNumber: tenth) }
    #expect(try #require(value.objectValue?["n"]?.numberValue).numericText(style: .preserved) == "1.00e-1")
    let schema = try JSONSchemaDSL.document {
        Schema.type(.number)
        Schema.minimum(tenth)
        Schema.multipleOf(tenth)
        Schema.maximum(JSONNumber(integer: 2))
    }
    try parity(
        schema, #"{"type":"number","minimum":1.00e-1,"multipleOf":1.00e-1,"maximum":2}"#,
        valid: ["0.1", "0.3", "2"], invalid: ["0.0999999999999999999999", "0.3000000000000000000001", "2.1"])
}

@Test func dslV04EveryExactDuplicateTableRejects() throws {
    try duplicate {
        _ = try JSONValueDSL.object {
            Field("same", 1)
            Field("same", 2)
        }
    }
    try duplicate {
        _ = try JSONSchemaDSL.document {
            Schema.title("a")
            Schema.title("b")
        }
    }
    try duplicate {
        _ = try JSONSchemaDSL.document {
            Schema.properties {
                Property("id") {}
                Property("id") {}
            }
        }
    }
    try duplicate {
        _ = try JSONSchemaDSL.document {
            Schema.definitions {
                Definition("id") {}
                Definition("id") {}
            }
        }
    }
    try duplicate {
        _ = try JSONSchemaDSL.document {
            Schema.patternProperties {
                PatternProperty("x") {}
                PatternProperty("x") {}
            }
        }
    }
    try duplicate {
        _ = try JSONSchemaDSL.document {
            Schema.dependentSchemas {
                DependentSchema("x") {}
                DependentSchema("x") {}
            }
        }
    }
    try duplicate {
        _ = try JSONSchemaDSL.document {
            Schema.dependentRequired {
                RequiredDependency("x", requires: ["a"])
                RequiredDependency("x", requires: ["b"])
            }
        }
    }
    try duplicate {
        _ = try JSONSchemaDSL.document {
            Schema.vocabulary([("https://e.test/v", false), ("https://e.test/v", false)])
        }
    }
}

@Test func dslV05ScalarKeysLiteralPathsOrderAndEquality() throws {
    let value = try JSONValueDSL.object {
        Field("é", 1)
        Field("e\u{301}", 2)
        Field("a/b~.c", 3)
        Field("", .null)
    }
    let object = try #require(value.objectValue)
    #expect(
        object.members.map { Array($0.key.string.unicodeScalars) }
            == ["é", "e\u{301}", "a/b~.c", ""].map { Array($0.unicodeScalars) })
    #expect(object["é"] == 1 && object["e\u{301}"] == 2)
    #expect(try JSONPointer(parsing: "/a~1b~0.c").resolve(in: value) == 3)
    let reversed = try JSONValueDSL.object {
        Field("", .null)
        Field("a/b~.c", 3)
        Field("e\u{301}", 2)
        Field("é", 1)
    }
    #expect(value == reversed)
    #expect(try JSONWriter().writeString(value) != JSONWriter().writeString(reversed))
    let schema = try JSONSchemaDSL.document {
        Schema.type(.object)
        Schema.properties {
            Property("é") { Schema.constant(1) }
            Property("e\u{301}") { Schema.constant(2) }
        }
        Schema.required("é", "e\u{301}")
    }
    try parity(
        schema,
        #"{"type":"object","properties":{"é":{"const":1},"e\u0301":{"const":2}},"required":["é","e\u0301"]}"#,
        valid: [#"{"é":1,"e\u0301":2}"#], invalid: [#"{"é":1}"#, #"{"é":2,"e\u0301":1}"#])
}

@Test func dslV06ConditionalOmissionHasNoSubstituteValue() throws {
    let include = false
    let value = try JSONValueDSL.object {
        if include { Field("missing", .null) }
        Field("null", .null)
    }
    #expect(try value.presence(of: "missing") == .absent)
    #expect(try value.presence(of: "null") == .null)
    let schema = try JSONSchemaDSL.document {
        if include { Schema.not {} }
        Schema.properties { if include { Property("missing", allowsAll: false) } }
    }
    try parity(schema, #"{"properties":{}}"#, valid: ["null", "{}", #"{"missing":1}"#], invalid: [])
}

@Test func dslV07OnlyExplicitElementsExpand() throws {
    let one = try JSONValueDSL.array {
        Element.array {
            Element(1)
            Element(2)
        }
        Element(.array([3, 4]))
    }
    let expanded = try JSONValueDSL.array { Elements(contentsOf: [.array([1, 2]), 3, 4]) }
    #expect(one == (try JSONParser().parse("[[1,2],[3,4]]")))
    #expect(expanded == (try JSONParser().parse("[[1,2],3,4]")))
}

@Test func dslV08And09FalseTrueEmptyAndNullRemainDistinct() throws {
    let rejecting = try JSONSchemaDSL.boolean(false)
    let accepting = try JSONSchemaDSL.boolean(true)
    let empty = try JSONSchemaDSL.document {}
    #expect(rejecting.raw == .boolean(false) && accepting.raw == .boolean(true))
    #expect(empty.raw.objectValue?.isEmpty == true && empty.raw != rejecting.raw && empty.raw != .null)
    try parity(rejecting, "false", valid: [], invalid: ["null", "{}", "false", "0"])
    try parity(accepting, "true", valid: ["null", "{}", "false", "0"], invalid: [])
    try parity(empty, "{}", valid: ["null", "{}", "false", "0"], invalid: [])
    #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaDocument(.null) }
}

@Test func dslV10RequirednessIsOnlyExplicit() throws {
    let optional = try JSONSchemaDSL.document {
        Schema.properties { Property("n") { Schema.type(.integer) } }
    }
    let required = try JSONSchemaDSL.document {
        Schema.properties { Property("n") { Schema.type(.integer) } }
        Schema.required("n")
    }
    try parity(
        optional, #"{"properties":{"n":{"type":"integer"}}}"#, valid: ["{}", #"{"n":1}"#],
        invalid: [#"{"n":"1"}"#])
    try parity(
        required, #"{"properties":{"n":{"type":"integer"}},"required":["n"]}"#, valid: [#"{"n":1}"#],
        invalid: ["{}", #"{"n":null}"#])
}

@Test func dslV11DefaultAndUnknownMetadataNeverMutateInstances() throws {
    let schema = try JSONSchemaDSL.document {
        Schema.properties {
            Property("n") {
                Schema.type(.integer)
                Schema.defaultValue(7)
            }
        }
        Schema.rawKeyword("x-note", "A declaration, not an instruction")
    }
    let instance = try JSONValueDSL.object {}
    let result = try JSONSchemaValidator().validate(instance, against: JSONSchemaCompiler().compile(schema))
    #expect(result.isValid && instance.objectValue?.isEmpty == true)
    let property = try schema.node(at: JSONPointer(parsing: "/properties/n"))
    #expect(try property.declaration(of: "default") == .value(7))
    #expect(
        try schema.node().declaration(of: "x-note") == .value(.string("A declaration, not an instruction")))
}

@Test func dslV12FormatPolicyStaysWithValidator() throws {
    let schema = try JSONSchemaDSL.document {
        Schema.type(.string)
        Schema.format("email")
    }
    let plan = try JSONSchemaCompiler().compile(schema)
    let annotation = try JSONSchemaValidator(options: .init(collectAnnotations: true)).validate(
        "bad", against: plan)
    #expect(annotation.isValid)
    #expect(
        annotation.annotations.contains { $0.keyword == JSONKey("format") && $0.value == .string("email") })
    #expect(
        try !JSONSchemaValidator(options: .init(formatAssertion: true)).validate("bad", against: plan).isValid
    )
    #expect(
        try JSONSchemaValidator(options: .init(formatAssertion: true)).validate(
            "person@example.test", against: plan
        ).isValid)
}

@Test func dslV13AlternativesAndConditionalsPreserveDeclarations() throws {
    let schema = try JSONSchemaDSL.document {
        Schema.allOf {
            Rule { Schema.type(.integer) }
            Rule { Schema.minimum(JSONNumber(integer: 0)) }
        }
        Schema.anyOf {
            Rule { Schema.multipleOf(JSONNumber(integer: 2)) }
            Rule { Schema.constant(3) }
        }
        Schema.oneOf {
            Rule(false)
            Rule(true)
        }
        Schema.ifSchema { Schema.minimum(JSONNumber(integer: 10)) }
        Schema.thenSchema { Schema.maximum(JSONNumber(integer: 12)) }
        Schema.elseSchema { Schema.maximum(JSONNumber(integer: 6)) }
        Schema.not { Schema.constant(4) }
    }
    try parity(
        schema,
        #"{"allOf":[{"type":"integer"},{"minimum":0}],"anyOf":[{"multipleOf":2},{"const":3}],"oneOf":[false,true],"if":{"minimum":10},"then":{"maximum":12},"else":{"maximum":6},"not":{"const":4}}"#,
        valid: ["0", "2", "3", "6", "10", "12"], invalid: ["-2", "1", "4", "8", "14", "0.1"])
}

@Test func dslV14PointerAnchorAndNestedIdentifierUseCompiler() throws {
    let schema = try JSONSchemaDSL.document {
        Schema.identifier("https://e.test/root")
        Schema.definitions {
            Definition("a/b~") {
                Schema.type(.integer)
                Schema.anchor("small")
            }
            Definition("child") {
                Schema.identifier("child")
                Schema.type(.integer)
            }
        }
        Schema.allOf {
            Rule { Schema.reference("#/$defs/a~1b~0") }
            Rule { Schema.reference("#sm%61ll") }
            Rule { Schema.reference("child") }
        }
    }
    try parity(
        schema,
        ##"{"$id":"https://e.test/root","$defs":{"a/b~":{"type":"integer","$anchor":"small"},"child":{"$id":"child","type":"integer"}},"allOf":[{"$ref":"#/$defs/a~1b~0"},{"$ref":"#sm%61ll"},{"$ref":"child"}]}"##,
        valid: ["1"], invalid: ["\"1\"", "1.1"])
}

@Test func dslV14DynamicScopeAndOfflineRegistryAreUnmodified() throws {
    let base = try JSONSchemaDSL.document {
        Schema.identifier("https://e.test/tree")
        Schema.dynamicAnchor("node")
        Schema.type(.object)
        Schema.properties { Property("child") { Schema.dynamicReference("#node") } }
    }
    let resource = try JSONSchemaDocument(base.raw, retrievalURI: JSONSchemaURI("https://e.test/tree"))
    let registry = try JSONSchemaRegistry(documents: [resource])
    let schema = try JSONSchemaDSL.document {
        Schema.identifier("https://e.test/strict")
        Schema.dynamicAnchor("node")
        Schema.reference("https://e.test/tree")
        Schema.unevaluatedProperties(false)
    }
    try parity(
        schema,
        ##"{"$id":"https://e.test/strict","$dynamicAnchor":"node","$ref":"https://e.test/tree","unevaluatedProperties":false}"##,
        valid: ["{}", #"{"child":{}}"#], invalid: [#"{"extra":1}"#, #"{"child":{"extra":1}}"#],
        registry: registry)
    do {
        _ = try JSONSchemaCompiler().compile(schema)
        Issue.record("Offline resource must be explicitly supplied")
    } catch let error as JSONSchemaCompilationFailure { #expect(error.category == .missingResource) }
}

@Test func dslV15RequiredUnknownVocabularyRemainsAnOperationalFailure() throws {
    let meta = try JSONSchemaDSL.document {
        Schema.identifier("https://e.test/dialect")
        Schema.schemaURI("https://json-schema.org/draft/2020-12/schema")
        Schema.vocabulary([("https://e.test/unknown-vocabulary", true)])
    }
    let registry = try JSONSchemaRegistry(documents: [
        JSONSchemaDocument(meta.raw, retrievalURI: JSONSchemaURI("https://e.test/dialect"))
    ])
    let schema = try JSONSchemaDSL.document {
        Schema.schemaURI("https://e.test/dialect")
        Schema.rawKeyword("custom", .null)
    }
    do {
        _ = try JSONSchemaCompiler().compile(schema, registry: registry)
        Issue.record("Required unknown vocabulary must throw")
    } catch let error as JSONSchemaCompilationFailure { #expect(error.category == .vocabulary) }
}

@Test func dslV16MalformedBoundsAndEmptyAlternativesAreNotRepaired() throws {
    let malformed = [
        try JSONSchemaDSL.document { Schema.minLength(-1) },
        try JSONSchemaDSL.document { Schema.multipleOf(JSONNumber(integer: 0)) },
        try JSONSchemaDSL.document { Schema.oneOf {} },
        try JSONSchemaDSL.document { Schema.required("same", "same") },
    ]
    for declaration in malformed {
        do {
            _ = try JSONSchemaCompiler().compile(declaration)
            Issue.record("Malformed declaration must fail compilation")
        } catch let error as JSONSchemaCompilationFailure {
            #expect(error.category == .schemaSyntax || error.category == .metaSchema)
        }
    }
    let huge = try JSONNumber(parsing: "1e100")
    let schema = try JSONSchemaDSL.document {
        Schema.type(.integer)
        Schema.minimum(huge)
    }
    try parity(
        schema, #"{"type":"integer","minimum":1e100}"#, valid: ["1e100"],
        invalid: ["99999999999999999999999999999999999999999999"])
}

@Test func dslV17ContainsAndUnevaluatedAnnotationsRemainEngineOwned() throws {
    let schema = try JSONSchemaDSL.document {
        Schema.contains { Schema.type(.integer) }
        Schema.minContains(1)
        Schema.maxContains(2)
        Schema.unevaluatedItems(false)
    }
    try parity(
        schema, #"{"contains":{"type":"integer"},"minContains":1,"maxContains":2,"unevaluatedItems":false}"#,
        valid: ["[1]", "[1,2]"], invalid: ["[]", "[1,2,3]", #"[1,"x"]"#])
    let plan = try JSONSchemaCompiler().compile(schema)
    let report = try JSONSchemaValidator(options: .init(collectAnnotations: true)).validate(
        .array([1, 2]), against: plan)
    #expect(report.annotations.contains { $0.keyword == JSONKey("contains") && $0.value == .array([0, 1]) })
}

@Test func dslV17SuccessfulAnyOfBranchesUnionEvaluatedProperties() throws {
    let schema = try JSONSchemaDSL.document {
        Schema.anyOf {
            Rule {
                Schema.properties { Property("a") { Schema.type(.integer) } }
                Schema.required("a")
            }
            Rule {
                Schema.properties { Property("b") { Schema.type(.string) } }
                Schema.required("b")
            }
        }
        Schema.unevaluatedProperties(false)
    }
    try parity(
        schema,
        #"{"anyOf":[{"properties":{"a":{"type":"integer"}},"required":["a"]},{"properties":{"b":{"type":"string"}},"required":["b"]}],"unevaluatedProperties":false}"#,
        valid: [#"{"a":1}"#, #"{"b":"yes"}"#, #"{"a":1,"b":"yes"}"#],
        invalid: ["{}", #"{"a":1,"b":2}"#, #"{"a":1,"extra":1}"#])
}

@Test func dslV20AdditionalKeywordShapeAndScalarLengthParity() throws {
    let schema = try JSONSchemaDSL.document {
        Schema.types([.string, .null])
        Schema.minLength(2)
        Schema.maxLength(3)
        Schema.examples(["e\u{301}", .null])
        Schema.readOnly()
        Schema.writeOnly(false)
        Schema.deprecated(false)
        Schema.contentEncoding("base64")
        Schema.contentMediaType("text/plain")
        Schema.contentSchema { Schema.type(.string) }
    }
    try parity(
        schema,
        #"{"type":["string","null"],"minLength":2,"maxLength":3,"examples":["e\u0301",null],"readOnly":true,"writeOnly":false,"deprecated":false,"contentEncoding":"base64","contentMediaType":"text/plain","contentSchema":{"type":"string"}}"#,
        valid: ["null", #""e\u0301""#, #""abc""#], invalid: [#""é""#, #""abcd""#, "1"])
}

// Draft 2020-12 validation section 6.1.2 recommends nonempty enum arrays but
// does not require them. Preserve the real compiler's empty-set behavior.
@Test func dslEmptyEnumCompilesAndRejectsEveryInstance() throws {
    let schema = try JSONSchemaDSL.document { Schema.enumValues([]) }
    try parity(schema, #"{"enum":[]}"#, valid: [], invalid: ["null", "true", "1", "[]", "{}", #""text""#])
}

@Test func dslNumericObjectAndDependencyFactoriesMatchWrittenVocabulary() throws {
    let schema = try JSONSchemaDSL.document {
        Schema.type(.object); Schema.minProperties(1); Schema.maxProperties(3)
        Schema.propertyNames { Schema.pattern("^[a-z]") }
        Schema.properties {
            Property("n") {
                Schema.type(.integer); Schema.minimum(JSONNumber(integer: 0)); Schema.maximum(JSONNumber(integer: 10))
                Schema.exclusiveMinimum(JSONNumber(integer: 0)); Schema.exclusiveMaximum(JSONNumber(integer: 10))
                Schema.multipleOf(JSONNumber(integer: 3))
            }
            Property("flag") { Schema.type(.boolean) }
        }
        Schema.patternProperties { PatternProperty("^x-") { Schema.type(.string) } }
        Schema.dependentRequired { RequiredDependency("n", requires: ["flag"]) }
        Schema.dependentSchemas { DependentSchema("flag") { Schema.required("n") } }
        Schema.additionalProperties(false)
    }
    try parity(schema, #"{"type":"object","minProperties":1,"maxProperties":3,"propertyNames":{"pattern":"^[a-z]"},"properties":{"n":{"type":"integer","minimum":0,"maximum":10,"exclusiveMinimum":0,"exclusiveMaximum":10,"multipleOf":3},"flag":{"type":"boolean"}},"patternProperties":{"^x-":{"type":"string"}},"dependentRequired":{"n":["flag"]},"dependentSchemas":{"flag":{"required":["n"]}},"additionalProperties":false}"#,
               valid: [#"{"n":3,"flag":false}"#, #"{"n":9,"flag":true,"x-one":"yes"}"#],
               invalid: ["{}", #"{"n":3}"#, #"{"flag":true}"#, #"{"n":0,"flag":true}"#, #"{"n":10,"flag":true}"#, #"{"n":3,"flag":true,"x-a":1}"#, #"{"n":3,"flag":true,"other":1}"#, #"{"n":3,"flag":true,"x-a":"a","x-b":"b"}"#])
}

@Test func dslSchemaValuedApplicatorsAndRawBooleanEscapePreserveMeaning() throws {
    let schema = try JSONSchemaDSL.document {
        Schema.type(.array); Schema.minItems(1); Schema.maxItems(3); Schema.uniqueItems(true)
        Schema.prefixItems { Rule { Schema.type(.string) } }
        Schema.items { Schema.type(.integer) }
        Schema.unevaluatedItems { Schema.type(.integer) }
    }
    try parity(schema, #"{"type":"array","minItems":1,"maxItems":3,"uniqueItems":true,"prefixItems":[{"type":"string"}],"items":{"type":"integer"},"unevaluatedItems":{"type":"integer"}}"#,
               valid: [#"["first"]"#, #"["first",1,2]"#], invalid: ["[]", #"["first",1,1]"#, #"["first","second"]"#, #"["first",1,2,3]"#])
    let object = try JSONSchemaDSL.document { Schema.type(.object); Schema.additionalProperties { Schema.type(.integer) }; Schema.unevaluatedProperties { Schema.type(.integer) } }
    try parity(object, #"{"type":"object","additionalProperties":{"type":"integer"},"unevaluatedProperties":{"type":"integer"}}"#,
               valid: ["{}", #"{"anything":1}"#], invalid: [#"{"anything":"1"}"#])
    let noNames = try JSONSchemaDSL.document { Schema.rawKeyword("propertyNames", .boolean(false)) }
    try parity(noNames, #"{"propertyNames":false}"#, valid: ["{}", "null"], invalid: [#"{"name":1}"#])
}
