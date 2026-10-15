// SPDX-License-Identifier: Apache-2.0
import JSON

package enum FilterCollectionBuiltins {
    package static let arities:[String:Set<Int>]=["sort":[0],"sort_by":[1],"group_by":[1],"unique":[0],"unique_by":[1],"min":[0],"max":[0],"min_by":[1],"max_by":[1],"reverse":[0],"flatten":[0,1],"first":[0,1],"last":[0,1],"nth":[1,2],"any":[0,1,2],"all":[0,1,2]]
    package struct Keyed {package let value:JSON;package let keys:[JSON]}
    package static func ordered(_ source:[Keyed],context:inout CLIJobContext)throws->[Keyed] {
        let bytes=UInt64(source.count)*32
        try context.meter.retain(bytes*2)
        var completed=false
        defer{if !completed{try? context.meter.release(bytes*2)}}
        try context.work(UInt64(source.count));var values=source,scratch=source,width=1
        while width<values.count {
            var start=0
            while start<values.count {
                let middle=min(start+width,values.count),end=min(middle+width,values.count)
                var a=start,b=middle,destination=start
                while a<middle || b<end {
                    try context.work()
                    if try b==end || a<middle && FilterValues.compare(.array(values[a].keys),.array(values[b].keys),context:&context)<=0{scratch[destination]=values[a];a += 1}
                    else{scratch[destination]=values[b];b += 1};destination += 1
                }
                start=end
            }
            swap(&values,&scratch);if width>values.count/2{break};width *= 2
        }
        try context.meter.release(bytes);completed=true;return values
    }
    package static func keyed(_ name:String,values:[Keyed],context:inout CLIJobContext)throws->FilterYield {
        try context.checkpoint();let entry=context.meter.used(.retainedBytes)
        var owned:UInt64=0,slots:UInt64=0,transferred=false
        defer{try? context.meter.release(context.meter.used(.retainedBytes)-entry-owned);if !transferred{try? context.release(.collectionValues,slots)}}
        let ordered=try ordered(values,context:&context)
        func append(_ value:JSON,to array:inout [JSON],context:inout CLIJobContext)throws{
            try context.charge(.collectionValues);slots += 1;try context.meter.require(.arrayItems,UInt64(array.count)+1);try context.meter.retain(16);try context.work();array.append(value)
        }
        let result:JSON
        if name=="min" || name=="min_by"{result=ordered.first?.value ?? .null}
        else if name=="max" || name=="max_by"{
            // Stable ties select the first source value with the maximal key.
            if let last=ordered.last{var index=ordered.count-1;while try index>0 && FilterValues.compare(.array(ordered[index-1].keys),.array(last.keys),context:&context)==0{try context.work();index -= 1};result=ordered[index].value}else{result = .null}
        } else if name=="group_by" {
            var groups:[JSON]=[],group:[JSON]=[],previous:Keyed?
            for value in ordered {
                try context.work()
                if let previous,try FilterValues.compare(.array(previous.keys),.array(value.keys),context:&context) != 0{try append(.array(group),to:&groups,context:&context);group=[]}
                try append(value.value,to:&group,context:&context);previous=value
            }
            if !group.isEmpty{try append(.array(group),to:&groups,context:&context)}
            result = .array(groups)
        } else {
            var output:[JSON]=[],previous:Keyed?
            for value in ordered {
                try context.work()
                if name=="unique" || name=="unique_by",let previous,try FilterValues.compare(.array(previous.keys),.array(value.keys),context:&context)==0{continue}
                try append(value.value,to:&output,context:&context);previous=value
            }
            result = .array(output)
        }
        let output=try FilterValues.produced(result,collections:slots,context:&context);owned=output.lease?.retained ?? 0;transferred=true;return output
    }
    package static func flattened(_ source:JSON,depth:Int?,context:inout CLIJobContext)throws->FilterYield {
        guard case .array(let array)=source else{throw FilterLanguageFailure("expectedArray")}
        try context.checkpoint();let entry=context.meter.used(.retainedBytes)
        var owned:UInt64=0,slots:UInt64=0,transferred=false
        defer{try? context.meter.release(context.meter.used(.retainedBytes)-entry-owned);if !transferred{try? context.release(.collectionValues,slots)}}
        var pending:[(JSON,Int?)]=[],output:[JSON]=[]
        for value in array.reversed(){try context.work();try context.meter.retain(24);pending.append((value,depth))}
        while let (value,depth)=pending.popLast(){
            try context.work();try context.meter.release(24)
            if case .array(let array)=value,depth.map({$0>0}) ?? true{for value in array.reversed(){try context.work();try context.meter.retain(24);pending.append((value,depth.map{$0-1}))}}
            else{try context.charge(.collectionValues);slots += 1;try context.meter.require(.arrayItems,slots);try context.meter.retain(16);output.append(value)}
        }
        let result=try FilterValues.produced(.array(output),collections:slots,context:&context);owned=result.lease?.retained ?? 0;transferred=true;return result
    }
}
