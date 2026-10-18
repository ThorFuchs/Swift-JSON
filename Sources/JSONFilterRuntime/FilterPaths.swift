// SPDX-License-Identifier: Apache-2.0
import JSON

/// Path arrays retain their dialect identity, independent of Pointer token syntax.
package enum FilterPaths {
    package static func segments(_ value:JSON,context:inout TransformRuntimeContext)throws->[JSON]{
        guard case .array(let values)=value else{throw FilterLanguageFailure("expectedPathArray")}
        for segment in values{try context.work();switch segment{case .string:break;case .number(let n):guard n.isInteger else{throw FilterLanguageFailure("invalidPathSegment")};default:throw FilterLanguageFailure("invalidPathSegment")}}
        return values
    }
    package static func get(_ input:JSON,path:[JSON],context:inout TransformRuntimeContext)throws->JSON{
        var value=input
        for segment in path{try context.work();value=try FilterValues.index(value,key:segment,context:&context)}
        return value
    }
    private static func index(_ number:JSONNumber,count:Int,creating:Bool,context:inout TransformRuntimeContext)throws->Int?{
        guard number.isInteger else{throw FilterLanguageFailure("invalidPathSegment")}
        if number.isNegative{
            if try number.compare(to:JSONNumber(integer:-count),meter:&context.meter) == .orderedAscending{return nil}
            return count + (try number.integer(as:Int.self,meter:&context.meter))
        }
        if !creating,try number.compare(to:JSONNumber(integer:count),meter:&context.meter) != .orderedAscending{return nil}
        if creating{
            let limit=context.meter.limits[.arrayItems]
            if try number.compare(to:JSONNumber(integer:limit),meter:&context.meter) != .orderedAscending{
                let attempted:UInt64?
                do{let value=try number.integer(as:UInt64.self,meter:&context.meter);let(next,overflow)=value.addingReportingOverflow(1);attempted=overflow ? nil:next}
                catch let failure as JSONFailure where failure.category == .conversion{attempted=nil}
                let error=JSONFailure(.resource,code:attempted==nil ? .counterOverflow:.limitExceeded,resource:.init(domain:context.meter.domain,metric:.arrayItems,limit:limit,attemptedUsage:attempted,overflow:attempted==nil));context.latch(error);throw error
            }
        }
        return try number.integer(as:Int.self,meter:&context.meter)
    }
    package static func set(_ input:JSON,path:[JSON],replacement:JSON?,context:inout TransformRuntimeContext)throws->FilterYield?{
        try context.checkpoint();let entry=context.meter.used(.retainedBytes)
        var owned:UInt64=0,collections:UInt64=0,transferred=false
        defer{try? context.meter.release(context.meter.used(.retainedBytes)-entry-owned);if !transferred{try? context.release(.collectionValues,collections)}}
        if path.isEmpty{guard let replacement else{return nil};let result=try FilterValues.produced(replacement,context:&context);owned=result.lease?.retained ?? 0;return result}
        struct Ancestor{let value:JSON;let segment:JSON}
        var ancestors:[Ancestor]=[],current=input
        var noChange=false
        for offset in path.indices{
            try context.work();try context.meter.require(.maxDepth,UInt64(offset)+1)
            let segment=path[offset]
            if case .null=current{
                if replacement==nil{noChange=true;break}
                switch segment{case .string:current = .object(JSONObject(empty:()));case .number(let n):guard !n.isNegative else{throw FilterLanguageFailure("invalidNegativePath")};current = .array([]);default:throw FilterLanguageFailure("invalidPathSegment")}
            }
            var child:JSON = .null
            switch (current,segment){
            case (.object(let object),.string(let key)):child=try object.lookup(key,meter:&context.meter) ?? .null
            case (.array(let values),.number(let n)):
                guard let index=try index(n,count:values.count,creating:replacement != nil,context:&context) else{if replacement==nil{noChange=true;break};throw FilterLanguageFailure("invalidNegativePath")}
                child=index<values.count ? values[index]:.null
            default:throw FilterLanguageFailure("wrongPathContainer")
            }
            if noChange{break}
            try context.meter.retain(48);ancestors.append(.init(value:current,segment:segment));current=child
        }
        var candidate:JSON?
        if noChange{candidate=input}
        else{
            candidate=replacement
            while let ancestor=ancestors.popLast(){
                try context.work();try context.meter.release(48)
                switch (ancestor.value,ancestor.segment){
                case (.object(let object),.string(let key)):
                    var members:[JSONMember]=[],found=false
                    for member in object{
                        try context.work()
                        if try JSONComparison.textEquals(member.key.string,key,meter:&context.meter){found=true;if let value=candidate{try context.meter.retain(24);members.append(.init(member.key,value:value))}}
                        else{try context.meter.retain(24);members.append(member)}
                    }
                    if !found,let value=candidate{try context.meter.require(.objectMembers,UInt64(members.count)+1);try context.meter.retain(24);members.append(.init(try JSONKey(key,meter:&context.meter),value:value))}
                    candidate = .object(try JSONObject.indexed(admitted:members,meter:&context.meter))
                case (.array(let values),.number(let number)):
                    guard let index=try index(number,count:values.count,creating:candidate != nil,context:&context) else{candidate=ancestor.value;continue}
                    let count=candidate == nil ? values.count-1:max(values.count,index+1)
                    try context.meter.require(.arrayItems,UInt64(count));try context.charge(.collectionValues,UInt64(count));collections += UInt64(count)
                    try context.meter.retain(UInt64(count)*16);var output:[JSON]=[]
                    for offset in 0..<max(values.count,index+1){
                        try context.work()
                        if offset==index{if let value=candidate{output.append(value)};continue}
                        output.append(offset<values.count ? values[offset]:.null)
                    }
                    candidate = .array(output)
                default:throw FilterLanguageFailure("wrongPathContainer")
                }
            }
        }
        guard let candidate else{return nil}
        let result=try FilterValues.produced(candidate,collections:collections,context:&context);owned=result.lease?.retained ?? 0;transferred=true;return result
    }
    package static func same(_ a:[JSON],_ b:[JSON],context:inout TransformRuntimeContext)throws->Bool{
        guard a.count==b.count else{return false}
        for index in a.indices{try context.work();if try !FilterValues.equals(a[index],b[index],context:&context){return false}};return true
    }
    package static func prefix(_ a:[JSON],_ b:[JSON],context:inout TransformRuntimeContext)throws->Bool{
        guard a.count<b.count else{return false}
        for index in a.indices{try context.work();if try !FilterValues.equals(a[index],b[index],context:&context){return false}};return true
    }
    package static func normalized(_ input:JSON,path:[JSON],context:inout TransformRuntimeContext)throws->[JSON]{
        var result:[JSON]=[],current=input
        for segment in path{
            try context.work();var normalized=segment
            if case .array(let values)=current,case .number(let n)=segment,n.isNegative,let index=try index(n,count:values.count,creating:false,context:&context){normalized = .number(JSONNumber(integer:index))}
            try context.meter.retain(16);result.append(normalized);current=try FilterValues.index(current,key:normalized,context:&context)
        }
        return result
    }
    package static func targets(_ input:JSON,paths:[[JSON]],context:inout TransformRuntimeContext)throws->[[JSON]]{
        var result:[[JSON]]=[]
        for path in paths{
            try context.work();let normalized=try normalized(input,path:path,context:&context)
            var duplicate=false
            for prior in result{if try same(prior,normalized,context:&context){duplicate=true;break};if try prefix(prior,normalized,context:&context) || prefix(normalized,prior,context:&context){throw FilterLanguageFailure("overlappingPaths")}}
            if !duplicate{try context.meter.retain(24);result.append(normalized)}
        }
        return result
    }
    package static func deletionOrder(_ paths:[[JSON]],context:inout TransformRuntimeContext)throws->[Int]{
        var result:[Int]=[]
        for index in paths.indices{
            try context.work();try context.meter.retain(8);var position=result.count
            while position>0{
                let prior=result[position-1],a=paths[index],b=paths[prior]
                var before=false
                for offset in 0..<min(a.count,b.count){
                    try context.work()
                    if try FilterValues.equals(a[offset],b[offset],context:&context){continue}
                    if case .number(let x)=a[offset],case .number(let y)=b[offset]{before=try x.compare(to:y,meter:&context.meter) == .orderedDescending}
                    break
                }
                if !before{break};position -= 1
            }
            result.insert(index,at:position)
        }
        return result
    }
}
