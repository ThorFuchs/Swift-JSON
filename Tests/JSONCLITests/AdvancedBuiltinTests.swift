// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@testable import JSONFilterRuntime

private struct AdvancedEmptyInput:FilterInput{mutating func next(context:inout CLIJobContext)throws->FilterYield?{nil}}
private func advanced(_ source:String,input:String="null")throws->[JSON]{
    var context=try CLIJobContext();let plan=try FilterCompiler.compile(source,context:&context)
    let value=try JSONParser().parse(input)
    var vm=try FilterVM(program:plan,input:.init(value:value),context:&context),cursor=AdvancedEmptyInput(),results:[JSON]=[]
    defer{try? vm.close(context:&context)}
    while var value=try vm.next(input:&cursor,context:&context){results.append(value.value);try value.release(context:&context)}
    return results
}
@Test func cliAdvancedLiteralStringsUseScalarsAndEmptyPatternContracts()throws{
    #expect(try advanced("split(\"\")",input:"\"éé\"")==[.array([.string("e"),.string("́"),.string("é")])])
    #expect(try advanced("indices(\"ana\"),index(\"ana\"),rindex(\"ana\")",input:"\"bananana\"")==[.array([.number(1),.number(3),.number(5)]),.number(1),.number(5)])
    #expect(try advanced("indices(\"\"),index(\"\"),rindex(\"\")",input:"\"abc\"")==[.array([]),.null,.null])
    #expect(try advanced("startswith(\"é\"),endswith(\"\")",input:"\"é\"")==[.boolean(false),.boolean(true)])
    #expect(try advanced("ltrimstr(\"prefix-\")|rtrimstr(\"-suffix\")",input:"\"prefix-x-suffix\"")==[.string("x")])
}
@Test func cliAdvancedContainmentIsRecursiveExactAndDoesNotRequireMultiplicity()throws{
    #expect(try advanced("contains([1,1])",input:"[1,2]")==[.boolean(true)])
    #expect(try advanced("contains({a:[{x:1}]})",input:"{\"a\":[{\"x\":1,\"y\":2}]}")==[.boolean(true)])
    #expect(try advanced("contains({\"é\":1})",input:"{\"é\":1}")==[.boolean(false)])
    #expect(try advanced("contains(\"é\")",input:"\"é\"")==[.boolean(false)])
}
@Test func cliAdvancedScalarConversionHasNoForeignNumberAuthority()throws{
    #expect(try advanced("tonumber+1",input:"\"9007199254740993\"")==[.number(JSONNumber(parsing:"9007199254740994"))])
    #expect(try advanced("try tonumber catch .",input:"\" 1\"")==[.string("invalidNumericText")])
    #expect(try advanced("explode|implode",input:"\"🦊é\"")==[.string("🦊é")])
    #expect(try advanced("try implode catch .",input:"[55296]")==[.string("invalidScalar")])
    #expect(try advanced("ascii_upcase,ascii_downcase",input:"\"éAb\"")==[.string("éAB"),.string("éab")])
    #expect(try advanced("join(\"|\")",input:"[1,\"two\",true,null]")==[.string("1|two|true|")])
}
@Test func cliAdvancedFormattersProduceInertExactText()throws{
    #expect(try advanced("@json",input:"[9007199254740993,0.10]")==[.string("[9007199254740993,0.10]")])
    #expect(try advanced("@html",input:"\"<tag>&\\\"'\"")==[.string("&lt;tag&gt;&amp;&quot;&apos;")])
    #expect(try advanced("@uri",input:"\"é /\"")==[.string("%C3%A9%20%2F")])
    #expect(try advanced("@sh",input:"[\"a b\",\"c'd\",42]")==[.string("'a b' 'c'\\''d' 42")])
    #expect(try advanced("@csv",input:"[\"a\\\"b\",null,true,1]")==[.string("\"a\"\"b\",,true,1")])
    #expect(try advanced("@tsv",input:"[\"a\\tb\",\"line\\n\",null]")==[.string("a\\tb\tline\\n\t")])
}
@Test func cliAdvancedBase64IsStrictAndPreservesUnicodeBytes()throws{
    #expect(try advanced("@base64",input:"\"🦊é\"")==[.string("8J+mimXMgQ==")])
    #expect(try advanced("@base64|@base64d",input:"\"🦊é\"")==[.string("🦊é")])
    for input in ["A===","AB==","Zg=","//==","////"]{
        #expect(throws:FilterLanguageFailure.self){try advanced("@base64d",input:"\"\(input)\"")}
    }
}
@Test func cliAdvancedCollectionSortKeysAreGeneratorsAndStableTiesRetainOrder()throws{
    #expect(try advanced("sort_by(.a,.b)|map(.id)",input:"[{\"id\":1,\"a\":1,\"b\":2},{\"id\":2,\"a\":1,\"b\":1},{\"id\":3,\"a\":1,\"b\":1}]")==[.array([.number(2),.number(3),.number(1)])])
    #expect(try advanced("unique_by(.k)|map(.id)",input:"[{\"id\":1,\"k\":2},{\"id\":2,\"k\":1},{\"id\":3,\"k\":2}]")==[.array([.number(2),.number(1)])])
    #expect(try advanced("group_by(.)",input:"[2,1,2]")==[.array([.array([.number(1)]),.array([.number(2),.number(2)])])])
    #expect(try advanced("min,max",input:"[]")==[.null,.null])
    #expect(try advanced("sort",input:"[true,{},\"x\",2,null,false,[]]")==[.array([.null,.boolean(false),.boolean(true),.number(2),.string("x"),.array([]),.object(try JSONObject())])])
}
@Test func cliAdvancedFlattenUsesExplicitDepthAndEmptyCollectors()throws{
    #expect(try advanced("flatten(1),flatten",input:"[1,[2,[3]],4]")==[.array([.number(1),.number(2),.array([.number(3)]),.number(4)]),.array([.number(1),.number(2),.number(3),.number(4)])])
    #expect(try advanced("first(empty),last(empty)").isEmpty)
    #expect(try advanced("first((1,2,3)),last((1,2,3))")==[.number(1),.number(3)])
}

@Test func cliAdvancedAnyAllAndNthAreDemandDrivenWithEmptyIdentities()throws{
    #expect(try advanced("any,all",input:"[]")==[.boolean(false),.boolean(true)])
    #expect(try advanced("any(.>1),all(.>0)",input:"[1,2]")==[.boolean(true),.boolean(true)])
    #expect(try advanced("any((1,error(\"unreached\"));true)")==[.boolean(true)])
    #expect(try advanced("all((1,error(\"unreached\"));false)")==[.boolean(false)])
    #expect(try advanced("nth((3,1,3);range(0;1000000))")==[.number(3),.number(1),.number(3)])
    #expect(try advanced("nth(999999999999999999999999999999999999; (1,2))").isEmpty)
    #expect(try advanced("nth(2)",input:"[10,11,12]")==[.number(12)])
    #expect(try advanced("nth(2;empty)").isEmpty)
}

@Test func cliAdvancedReduceKeepsLastUpdateAndEmptyUpdateBecomesNull()throws{
    #expect(try advanced("reduce (1,2) as $x (0; .+$x, .+10)")==[.number(20)])
    #expect(try advanced("reduce (1,2) as $x (0; empty)")==[.null])
    #expect(try advanced("reduce (1,2) as $x ((0,10); .+$x)")==[.number(3),.number(13)])
    #expect(try advanced("reduce empty as $x (4; .+$x)")==[.number(4)])
}
@Test func cliAdvancedForeachExtractsEveryUpdateAndKeepsLastAccumulator()throws{
    #expect(try advanced("[foreach (1,2) as $x (0; .+$x, .+10; .)]")==[.array([.number(1),.number(10),.number(12),.number(20)])])
    #expect(try advanced("foreach (1,2) as $x (0; empty; error(\"unreachable\"))").isEmpty)
    #expect(try advanced("[foreach (1,2,3) as $x (0; .+$x)]")==[.array([.number(1),.number(3),.number(6)])])
    #expect(try advanced("reduce .[] as $x (0; .+$x) | (. + 1)", input:"[1,2]")==[.number(4)])
    #expect(try advanced("foreach .[] as $x (0; .+$x) | (. + 1)", input:"[1,2]")==[.number(2),.number(4)])
}

@Test func cliAdvancedLoopsAndRecurseUseOrderedExplicitContinuations()throws{
    #expect(try advanced("1|while(.<4;.+1)")==[.number(1),.number(2),.number(3)])
    #expect(try advanced("1|until(.>=4;.+1)")==[.number(4)])
    #expect(try advanced("[0|recurse(.+1;.<=3)]")==[.array([.number(0),.number(1),.number(2),.number(3)])])
    #expect(try advanced("reduce (1,2) as $x (0; .+$x)|.+1")==[.number(4)])
    #expect(try advanced("[recurse|numbers]",input:"{\"a\":[1,{\"b\":2}]}")==[.array([.number(1),.number(2)])])
}

@Test func cliAdvancedWalkTransformsPostorderAndPreservesExactObjectKeys()throws{
    let expected=try JSONParser().parse("[2,[3],{\"é\":4,\"é\":5}]")
    #expect(try advanced("walk(if type==\"number\" then .+1 else . end)",input:"[1,[2],{\"é\":3,\"é\":4}]")==[expected])
    #expect(try advanced("walk(if type==\"number\" then empty else . end)",input:"{\"a\":1,\"b\":null}")==[try JSONParser().parse("{\"b\":null}")])
}

@Test func cliAdvancedLexicalFunctionsHaveFilterAndValueParameters()throws{
    #expect(try advanced("def twice(f):f,f;twice((1,2))")==[.number(1),.number(2),.number(1),.number(2)])
    #expect(try advanced("def twice(f):f|f;1|twice(.+1)")==[.number(3)])
    #expect(try advanced("def plus($x):.+$x;3|plus((1,2))")==[.number(4),.number(5)])
    #expect(try advanced("0 as $x|def f:$x;1 as $x|f")==[.number(0)])
    #expect(try advanced("def down:if .>0 then .,(.-1|down) else . end;3|down")==[.number(3),.number(2),.number(1),.number(0)])
    #expect(throws:FilterCompileFailure.self){try advanced("def a:b;def b:1;a")}
    #expect(throws:FilterCompileFailure.self){try advanced("def a:1;def a:2;a")}
}

@Test func cliAdvancedInterpolationPreservesGeneratorsNestedStringsAndFormatterBoundaries()throws{
    #expect(try advanced(#""x\((1,2))""#)==[.string("x1"),.string("x2")])
    #expect(try advanced(#""x\(empty)""#).isEmpty)
    #expect(try advanced(#""\((1,2))-\((10,20))""#)==[.string("1-10"),.string("1-20"),.string("2-10"),.string("2-20")])
    #expect(try advanced(#"@uri "query=\(.source)""#,input:#"{"source":"é /"}"#)==[.string("query=%C3%A9%20%2F")])
    #expect(try advanced(#""outer \("inner \(1)")""#)==[.string("outer inner 1")])
    #expect(try advanced(#""literal \\(x)""#)==[.string(#"literal \(x)"#)])
}

@Test func cliAdvancedPathsUseExactRootProvenanceAndCreateContainersWithinCaps()throws{
    #expect(try advanced(#"path(.records[].name)"#,input:#"{"records":[{"name":"Ada"},{"name":"Grace"}]}"#)==[.array([.string("records"),.number(0),.string("name")]),.array([.string("records"),.number(1),.string("name")])])
    #expect(try advanced(#"path(.missing)"#,input:"{}")==[.array([.string("missing")])])
    #expect(throws:FilterLanguageFailure.self){try advanced("path(1+2)")}
    #expect(try advanced(#"setpath(["a",2];7)"#,input:"{}")==[try JSONParser().parse(#"{"a":[null,null,7]}"#)])
    #expect(try advanced(#"getpath(["a",2])"#,input:#"{"a":[null,null,7]}"#)==[.number(7)])
    #expect(try advanced(#"getpath(["missing","x"])"#,input:"{}")==[.null])
}
@Test func cliAdvancedAssignmentsAreStagedAndUpdateTakesOnlyFirstResult()throws{
    #expect(try advanced(".[]=(10,20)",input:"[1,2]")==[.array([.number(10),.number(10)]),.array([.number(20),.number(20)])])
    #expect(try advanced(".[]|=(10,20)",input:"[1,2]")==[.array([.number(10),.number(10)])])
    #expect(try advanced(".[]|=empty",input:"[1,2,3]")==[.array([])])
    #expect(try advanced("(.[0],.[-3])+=1",input:"[1,2,3]")==[.array([.number(2),.number(2),.number(3)])])
    #expect(try advanced(#".a//=error("unreached")"#,input:#"{"a":1}"#)==[try JSONParser().parse(#"{"a":1}"#)])
    #expect(try advanced(#"try ((.,.a)=1) catch ."#,input:#"{"a":2}"#)==[.string("overlappingPaths")])
}
@Test func cliAdvancedDeletionUsesOriginalIndicesAcrossNestedTargets()throws{
    #expect(try advanced(#"delpaths([[0],[1,"x"]])"#,input:#"[{"x":1},{"x":2,"y":3},{"z":4}]"#)==[try JSONParser().parse(#"[{"y":3},{"z":4}]"#)])
    #expect(try advanced(#"del(.records[].active)"#,input:#"{"records":[{"active":true},{"active":false}]}"#)==[try JSONParser().parse(#"{"records":[{},{}]}"#)])
    #expect(try advanced("del(.)",input:"null").isEmpty)
    #expect(try advanced(#"delpaths([["missing"]])"#,input:"{}")==[try JSONParser().parse("{}")])
}

@Test func cliAdvancedPathsEnumerateDiscoveryOrderAndPredicateTruth()throws{
    #expect(try advanced("[paths]",input:#"{"a":1,"b":[true,null,false]}"#)==[try JSONParser().parse(#"[["a"],["b"],["b",0],["b",1],["b",2]]"#)])
    #expect(try advanced("[paths(scalars)]",input:#"{"a":1,"b":[true,null,false]}"#)==[try JSONParser().parse(#"[["a"],["b",0]]"#)])
}

@Test func cliAdvancedDestructuringKeepsScalarKeysAndExplicitMissingNull()throws{
    #expect(try advanced(#". as {"é":$a,"é":$b,missing:$c}|[$a,$b,$c]"#,input:#"{"é":1,"é":2}"#)==[.array([.number(1),.number(2),.null])])
    #expect(try advanced("[1,[2,3]] as [$a,[$b,$c]]|$a+$b+$c")==[.number(6)])
    #expect(try advanced("null as {a:$a}|$a")==[.null])
    #expect(try advanced(#"try (1 as [$a]|$a) catch ."#)==[.string("wrongBindingShape")])
}
