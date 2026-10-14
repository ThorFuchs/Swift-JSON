// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

private func gapPlan(_ text: String) throws -> CompiledJSONSchema {
    try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(text)))
}
private func gapCompilation(_ category: JSONSchemaCompilationFailure.Category, _ body: () throws -> Void) {
    do { try body(); Issue.record("Expected compilation failure \(category)") }
    catch let failure as JSONSchemaCompilationFailure { #expect(failure.category == category) }
    catch { Issue.record("Unexpected operational error: \(error)") }
}

@Test func qaSchemaMalformedStandardKeywordShapesAreOperationalFailures() throws {
    let values = [#"{"type":[]}"#, #"{"type":["string",1]}"#, #"{"title":1}"#, #"{"$defs":[]}"#,
        #"{"$vocabulary":[]}"#, #"{"$vocabulary":{"https://e.test/vocab":1}}"#, #"{"enum":true}"#,
        #"{"examples":{}}"#, #"{"dependentRequired":[]}"#, #"{"dependentRequired":{"x":[1]}}"#,
        #"{"minimum":false}"#, #"{"maximum":"2"}"#, #"{"exclusiveMinimum":null}"#,
        #"{"exclusiveMaximum":[]}"#, #"{"uniqueItems":0}"#, #"{"deprecated":"yes"}"#,
        #"{"readOnly":1}"#, #"{"writeOnly":null}"#]
    for text in values { gapCompilation(.schemaSyntax) { _ = try gapPlan(text) } }
    gapCompilation(.rootKind) { _ = try gapPlan("[]") }
    // A successfully compiled assertion produces ordinary invalidity, not an error.
    let verdict = try JSONSchemaValidator().validate("wrong", against: gapPlan(#"{"type":"number"}"#))
    #expect(!verdict.isValid && verdict.diagnosticsComplete && !verdict.issues.isEmpty)
}

@Test func qaSchemaMalformedAnchorsAndReferencesHaveExactFailureCategories() throws {
    for anchor in ["", "a!", "a/b", "a b"] {
        let raw = JSON.object(try JSONObject(members:[.init("$anchor",value:.string(anchor))]))
        gapCompilation(.anchor) { _ = try JSONSchemaCompiler().compile(JSONSchemaDocument(raw)) }
    }
    for text in [##"{"$ref":"#/$defs/~2"}"##, ##"{"$ref":"#missing"}"##,
                 ##"{"$defs":{"value":false},"$ref":"#/$defs/value/type"}"##] {
        gapCompilation(.reference) { _ = try gapPlan(text) }
    }
    gapCompilation(.identifier) { _ = try gapPlan(#"{"$ref":"https://e.test/%ZZ"}"#) }
    gapCompilation(.schemaSyntax) { _ = try gapPlan(#"{"pattern":"[z-a]"}"#) }
}

@Test func qaSchemaURIIdentityFragmentRemovalAndRelativeResolutionAreOffline() throws {
    let a = try JSONSchemaURI("HTTPS://EXAMPLE.TEST:443/a/../b/%7e#/$defs/value")
    let b = try JSONSchemaURI("https://example.test:443/b/~#/$defs/value")
    #expect(a == b && a.hashValue == b.hashValue && Set([a,b]).count == 1)
    #expect(a.fragment == "/$defs/value")
    let resource = try a.removingFragment()
    #expect(resource.string == "https://example.test:443/b/~" && resource.fragment == nil)
    #expect(try resource.removingFragment() == resource)
    #expect(try JSONSchemaURI("../c#anchor",relativeTo:resource).string == "https://example.test:443/c#anchor")
    for text in ["https://e.test/a b", "https://e.test/\\a", "https://e.test/\u{7f}", "relative/path", "https://e.test/%"] {
        gapCompilation(.identifier) { _ = try JSONSchemaURI(text) }
    }
    var limits = JSONLimits.balanced; limits[.stringBytes] = 3
    do { _ = try a.removingFragment(limits:limits); Issue.record("Expected bounded URI refusal") }
    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .stringBytes) }
}

@Test func qaSchemaRegistryConflictingNormalizedIDsCannotReplaceAPlan() throws {
    let first = try JSONSchemaDocument(JSONParser().parse(#"{"$id":"https://e.test:443/value","type":"string"}"#),retrievalURI:JSONSchemaURI("https://e.test/first"))
    let second = try JSONSchemaDocument(JSONParser().parse(#"{"$id":"HTTPS://E.TEST:443/value","type":"number"}"#),retrievalURI:JSONSchemaURI("https://e.test/second"))
    let registry = try JSONSchemaRegistry(documents:[first,second])
    gapCompilation(.identifier) { _ = try JSONSchemaCompiler().compile(JSONSchemaDocument(true),registry:registry) }
    let stable = try JSONSchemaCompiler().compile(first)
    #expect(try JSONSchemaValidator().validate("valid",against:stable).isValid)
    #expect(try JSONSchemaValidator().validate(1,against:stable).isValid == false)
}

@Test func qaSchemaEscapedDiagnosticPathsIdentifyExactScalarMembers() throws {
    let plan = try gapPlan(#"{"$id":"https://e.test/root","properties":{"/~":{"type":"number"},"é":false,"e\u0301":true}}"#)
    let input = try JSONParser().parse(#"{"/~":"wrong","é":1,"e\u0301":2}"#)
    let result = try JSONSchemaValidator().validate(input,against:plan)
    #expect(!result.isValid && result.issues.count == 2)
    let issue = try #require(result.issues.first { $0.instanceLocation.string == "/~1~0" })
    #expect(issue.keywordLocation.string == "/properties/~1~0/type")
    #expect(issue.absoluteKeywordLocation?.string == "https://e.test/root#/properties/~1~0/type")
    #expect(result.issues.contains { $0.instanceLocation.tokens == [JSONKey("é")] })
    #expect(!result.issues.contains { $0.instanceLocation.tokens == [JSONKey("e\u{301}")] })
}

@Test func qaSchemaEmptyArrayAndNonStringAnnotationApplicability() throws {
    let arrayPlan = try gapPlan(#"{"prefixItems":[true],"items":true,"unevaluatedItems":false}"#)
    let validator = JSONSchemaValidator(options:.init(collectAnnotations:true))
    let empty = try validator.validate(.array([]),against:arrayPlan)
    #expect(empty.isValid)
    #expect(empty.annotations.contains { $0.keyword == JSONKey("prefixItems") && $0.value == true })
    let nonEmpty = try validator.validate(.array([1,2]),against:arrayPlan)
    #expect(nonEmpty.isValid)
    let contentPlan = try gapPlan(#"{"format":"email","contentEncoding":"base64","contentMediaType":"application/json","contentSchema":false}"#)
    let numeric = try validator.validate(1,against:contentPlan)
    #expect(numeric.isValid && numeric.annotations.isEmpty)
    let text = try validator.validate("not asserted",against:contentPlan)
    #expect(text.isValid)
    #expect(text.annotations.contains { $0.keyword == JSONKey("contentEncoding") && $0.value == "base64" })
}

@Test func qaSchemaBestEffortByteRefusalPreservesInvalidityAndExactAccounting() throws {
    let plan = try gapPlan(#"{"properties":{"/~":false}}"#), value = try JSONParser().parse(#"{"/~":null}"#)
    var limits = JSONLimits.balanced; limits[.diagnosticBytes] = 0
    do { _ = try JSONSchemaValidator(options:.init(limits:limits)).validate(value,against:plan); Issue.record("Expected diagnostic refusal") }
    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .diagnosticBytes) }
    let report = try JSONSchemaValidator(options:.init(limits:limits,diagnosticPolicy:.bestEffort)).validateWithReport(value,against:plan)
    #expect(!report.result.isValid && !report.result.diagnosticsComplete && report.result.issues.isEmpty)
    #expect(report.statistics[.diagnosticBytes] == 0 && report.statistics[.evaluationWorkUnits] > 0)
}

@Test func qaSchemaURIFormatsExerciseIPvFutureAuthorityAndPrivateIRIRanges() throws {
    let cases: [(String,String,Bool)] = [
        ("uri","https://[v1.a:b]/",true), ("uri","https://[Vf.a!]/",true),
        ("uri","https://[v.a]/",false), ("uri","https://[v1.]/",false),
        ("uri","https://[v1.a^]/",false), ("uri","https://[v1.a",false),
        ("uri","https://[::1]x/",false), ("uri","https://host:abc/",false),
        ("uri","https://[v1.a]:80/",true), ("uri","https://user@other@host/",false),
        ("iri","https://e.test/?q=\u{f0000}",true), ("iri","https://e.test/#\u{f0000}",false),
        ("iri","https://e.test/\u{e000}",false), ("iri","https://e.test/\u{ffff}",false),
        ("uri","https://e.test/é",false)]
    let validator = JSONSchemaValidator(options:.init(formatAssertion:true))
    for (format,input,expected) in cases {
        let raw = JSON.object(try JSONObject(members:[.init("format",value:.string(format))]))
        let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(raw))
        let result = try validator.validate(.string(input),against:plan)
        #expect(result.isValid == expected)
        #expect(result.diagnosticsComplete)
    }
}

@Test func qaSchemaURITemplatePrefixLimitsAndPercentVariablesUseStrictGrammar() throws {
    let plan = try gapPlan(#"{"format":"uri-template"}"#)
    let validator = JSONSchemaValidator(options:.init(formatAssertion:true))
    for (text,valid) in [("{value:9999}",true), ("{value:10000}",false), ("{value:0}",false),
        ("{a.%41,b*}",true), ("{a.%GG}",false), ("{.a..b}",false), ("{value:}",false), ("{%41}",true)] {
        #expect(try validator.validate(.string(text),against:plan).isValid == valid)
    }
}

@Test func qaSchemaBestEffortDiagnosticsCannotSwallowOwnedWorkOrAnnotations() throws {
    let plan = try gapPlan(#"{"allOf":[{"properties":{"/~":false}},false]}"#)
    let value = try JSONParser().parse(#"{"/~":null}"#)
    var limits = JSONLimits.balanced; limits[.diagnosticBytes] = 0
    let report = try JSONSchemaValidator(options:.init(limits:limits,diagnosticPolicy:.bestEffort)).validateWithReport(value,against:plan)
    #expect(!report.result.isValid && !report.result.diagnosticsComplete)
    #expect(report.result.issues.isEmpty && report.statistics[.diagnosticBytes] == 0)
    limits[.evaluationWorkUnits] = report.statistics[.evaluationWorkUnits] - 1
    do { _ = try JSONSchemaValidator(options:.init(limits:limits,diagnosticPolicy:.bestEffort)).validate(value,against:plan); Issue.record("Work exhaustion became invalidity") }
    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .evaluationWorkUnits) }
    let annotationPlan = try gapPlan(#"{"title":"metadata"}"#)
    limits = .balanced; limits[.annotationBytes] = 0
    do { _ = try JSONSchemaValidator(options:.init(limits:limits,diagnosticPolicy:.bestEffort,collectAnnotations:true)).validate(value,against:annotationPlan); Issue.record("Annotation exhaustion was omitted") }
    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .annotationBytes) }
}
