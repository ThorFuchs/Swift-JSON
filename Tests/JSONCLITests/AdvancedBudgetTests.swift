// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@testable import JSONFilterRuntime

private struct BudgetEmptyInput:FilterInput{mutating func next(context:inout CLIJobContext)throws->FilterYield?{nil}}
@Test func cliAdvancedCompletionReleasesCollectorsLocationsAndLexicalEnvironments()throws{
    let inputs=try JSONParser().parse(#"{"a":[1,2,3],"é":1,"é":2}"#)
    let cases=[#".a|sort"#,#".a|group_by(.)"#,#".a|unique"#,#"[paths]"#,#"path(.a[])"#,#".a[]+=1"#,#"del(.a[])"#,#"def twice(f):f,f;[twice(.a[])]"#,#".a as [$x,$y,$z]|$x+$y+$z"#,#""x\(.a[])""#,#"walk(.)"#,#"reduce .a[] as $x (0;.+$x)"#]
    for source in cases{
        var compilation=try CLIJobContext();let plan=try FilterCompiler.compile(source,context:&compilation)
        var context=try CLIJobContext(),cursor=BudgetEmptyInput()
        var value=try FilterValues.produced(inputs,context:&context)
        var vm=try FilterVM(program:plan,input:value,context:&context);try value.release(context:&context)
        while var value=try vm.next(input:&cursor,context:&context){try value.release(context:&context)}
        try vm.close(context:&context)
        #expect(context.meter.used(.retainedBytes)==0,"\(source)")
        #expect(context.used(.collectionValues)==0 && context.used(.runtimeFrames)==0 && context.used(.bindings)==0,"\(source)")
    }
}
@Test func cliAdvancedQuotaFailuresUnwindNestedLoopsClosuresAndPathBuilders()throws{
    let input=try JSONParser().parse(#"{"a":[1,2,3]}"#)
    let cases=[#"try (def f:.,f;f) catch null"#,#"try while(true;.) catch null"#,#"try setpath(["b",100];1) catch null"#,#"try [paths] catch null"#,#"try (.a[]|=(.,2)) catch null"#,#"try "x\(.a[])" catch null"#]
    for source in cases{
        var compilation=try CLIJobContext();let plan=try FilterCompiler.compile(source,context:&compilation)
        var failures=0
        for cap:UInt64 in [700,1400,2800,5600]{
            var limits=CLILimits();limits[.retainedBytes]=cap;limits[.runtimeFrames]=32;limits[.totalWorkUnits]=5000
            var context=try CLIJobContext(limits:limits),cursor=BudgetEmptyInput()
            var vm=try FilterVM(program:plan,input:.init(value:input),context:&context)
            do{while var value=try vm.next(input:&cursor,context:&context){try value.release(context:&context)}}
            catch{failures += 1;#expect(!(error is FilterLanguageFailure))}
            try vm.close(context:&context)
            #expect(context.meter.used(.retainedBytes)==0,"\(source) cap=\(cap)")
            #expect(context.used(.collectionValues)==0 && context.used(.runtimeFrames)==0 && context.used(.bindings)==0,"\(source) cap=\(cap) collections=\(context.used(.collectionValues)) frames=\(context.used(.runtimeFrames)) bindings=\(context.used(.bindings))")
        }
        #expect(failures>0,"\(source)")
    }
}
@Test func cliAdvancedLexicalRecursionUsesConfiguredFramesAndCannotCatchResource()throws{
    var compilation=try CLIJobContext();let plan=try FilterCompiler.compile("def down:if .>0 then .-1|down else . end;try (200|down) catch null",context:&compilation)
    var limits=CLILimits();limits[.runtimeFrames]=16
    var context=try CLIJobContext(limits:limits),cursor=BudgetEmptyInput(),vm=try FilterVM(program:plan,input:.init(value:.null),context:&context)
    do{_=try vm.next(input:&cursor,context:&context);Issue.record("Expected frame cap")}
    catch let failure as CLIError{#expect(failure.category == .resource && failure.metric=="runtimeFrames")}
    try vm.close(context:&context)
    #expect(context.used(.runtimeFrames)==0 && context.used(.bindings)==0 && context.meter.used(.retainedBytes)==0)
}

@Test func cliAdvancedCapacityChargeCannotResurrectQueuedLeaseRefunds()throws{
    var limits=CLILimits();limits[.collectionValues]=2
    var context=try CLIJobContext(limits:limits)
    var value:FilterYield?=try FilterValues.array([.null,.null],context:&context)
    #expect(value?.value == .array([.null,.null]))
    value=nil // Destruction enqueues refunds without directly mutating the job.
    try context.charge(.collectionValues,2)
    #expect(context.used(.collectionValues)==2)
    try context.release(.collectionValues,2)
    #expect(context.meter.used(.retainedBytes)==0 && context.used(.collectionValues)==0)
}

@Test func cliAdvancedMalformedSourceReplayNeverTrapsOrBecomesInputSuccess()throws{
    let sources=[#""x\(""#,#""x\()""#,#""x\("y\(1)""#,#"def a:;a"#,#"def a($x;$x):.;a(1;2)"#,#"1 as [|."#,#"reduce 1 as $x (0;)"#,#"@unknown"#,#"(.,.a)=1=2"#,#""\uD800""#,#""\q""#]
    for source in sources{
        var context=try CLIJobContext()
        #expect(throws:FilterCompileFailure.self){_=try FilterCompiler.compile(source,context:&context)}
    }
}
@Test func cliAdvancedCancellationAfterRealLoopProgressIsTerminalAndReclaimsScope()async throws{
    var compilation=try CLIJobContext();let plan=try FilterCompiler.compile("try while(true;.+1) catch null",context:&compilation)
    let task=Task{
        var context=try CLIJobContext(),source=BudgetEmptyInput(),vm=try FilterVM(program:plan,input:.init(value:.number(0)),context:&context)
        context.meter.checkpointObserver={work in if work>=1000{withUnsafeCurrentTask{$0?.cancel()}}}
        var cancelled=false
        do{while var value=try vm.next(input:&source,context:&context){try value.release(context:&context)}}catch is CancellationError{cancelled=true}
        #expect(cancelled && context.used(.totalWorkUnits)>=1000)
        try vm.close(context:&context)
        #expect(context.meter.used(.retainedBytes)==0 && context.used(.collectionValues)==0 && context.used(.bindings)==0 && context.used(.runtimeFrames)==0)
        #expect(throws:CancellationError.self){try context.checkpoint()}
    }
    try await task.value
}
