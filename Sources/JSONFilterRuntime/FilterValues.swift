// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

package enum FilterValues {
    package static func produced(_ value:JSON, collections:UInt64=0, context:inout CLIJobContext)throws->FilterYield {
        try context.checkpoint()
        let entry=context.meter.used(.retainedBytes)
        do {
            try context.meter.resetValueBounds()
            try JSONAdmission.value(value,meter:&context.meter,owned:true)
            let bytes=context.meter.used(.retainedBytes)-entry
            let lease=try CLIValueLease(ownedRetained:bytes,collections:collections,context:&context)
            return .init(value:value,lease:lease,collectedValues:collections)
        } catch {
            try context.meter.release(context.meter.used(.retainedBytes)-entry)
            throw error
        }
    }
    package static func integer(_ value:Int, context:inout CLIJobContext)throws->FilterYield {
        try context.work(20)
        return try produced(.number(JSONNumber(integer:value)),context:&context)
    }
    package static func array(_ values:[JSON], admittedCollectionCount:Bool=false, context:inout CLIJobContext)throws->FilterYield {
        let count=UInt64(values.count)
        if !admittedCollectionCount { try context.charge(.collectionValues,count) }
        do { return try produced(.array(values),collections:count,context:&context) }
        catch { if !admittedCollectionCount { try context.release(.collectionValues,count) };throw error }
    }
    package static func index(_ value:JSON,key:JSON,context:inout CLIJobContext)throws->JSON {
        switch key {
        case .string(let text):
            switch value {case .null:return .null;case .object(let object):return try object.lookup(text,meter:&context.meter) ?? .null;default:throw FilterLanguageFailure("cannotIndex")}
        case .number(let number):
            guard number.isInteger else {throw FilterLanguageFailure("nonintegralIndex")}
            switch value {
            case .null:return .null
            case .array(let values):
                let length=JSONNumber(integer:values.count),negative=JSONNumber(integer:-values.count)
                if try number.compare(to:length,meter:&context.meter) != .orderedAscending || number.compare(to:negative,meter:&context.meter) == .orderedAscending {return .null}
                let integer=try number.integer(as:Int.self,meter:&context.meter)
                return values[integer < 0 ? values.count+integer:integer]
            default:throw FilterLanguageFailure("cannotIndex")
            }
        default:throw FilterLanguageFailure("invalidIndexKind")
        }
    }
    package static func equals(_ a: JSON, _ b: JSON, context: inout CLIJobContext) throws -> Bool {
        try context.checkpoint()
        let entry = context.meter.used(.retainedBytes)
        defer { try? context.meter.release(context.meter.used(.retainedBytes) - entry) }
        return try JSONComparison.equals(a, b, meter: &context.meter)
    }
    package static func has(_ value:JSON,key:JSON,context:inout CLIJobContext)throws->Bool {
        switch (value,key) {
        case (.object(let object),.string(let text)):return try object.lookup(text,meter:&context.meter) != nil
        case (.array(let values),.number(let number)):
            guard number.isInteger else {throw FilterLanguageFailure("nonintegralIndex")}
            return try number.compare(to:JSONNumber(integer:0),meter:&context.meter) != .orderedAscending && number.compare(to:JSONNumber(integer:values.count),meter:&context.meter) == .orderedAscending
        default:throw FilterLanguageFailure("invalidHasDomain")
        }
    }
    package static func textCompare(_ a:String,_ b:String,context:inout CLIJobContext)throws->Int {
        var left=a.utf8.makeIterator(),right=b.utf8.makeIterator()
        while true {
            try context.work();let a=left.next(),b=right.next()
            if a==b {if a==nil{return 0};continue}
            guard let a else{return -1};guard let b else{return 1}
            return a<b ? -1:1
        }
    }
    package static func sortedMembers(_ object:JSONObject,context:inout CLIJobContext)throws->[JSONMember] {
        let bytes=UInt64(object.count)*JSONLogicalWeights.member
        try context.meter.retain(bytes*2)
        var completed = false
        defer { if !completed { try? context.meter.release(bytes*2) } }
        try context.work(UInt64(object.count))
        var values=object.members, scratch=object.members, width=1
        while width<values.count {
            var start=0
            while start<values.count {
                let middle=min(start+width,values.count),end=min(middle+width,values.count)
                var a=start,b=middle,destination=start
                while a<middle || b<end {
                    try context.work()
                    if try b==end || a<middle && (textCompare(values[a].key.string,values[b].key.string,context:&context))<=0 {scratch[destination]=values[a];a += 1}
                    else{scratch[destination]=values[b];b += 1}
                    destination += 1
                }
                start=end
            }
            swap(&values,&scratch)
            if width>values.count/2{break};width *= 2
        }
        try context.meter.release(bytes); completed = true
        return values
    }
    package static func compare(_ a:JSON,_ b:JSON,context:inout CLIJobContext)throws->Int {
        func rank(_ v:JSON)->Int {switch v{case .null:0;case .boolean(false):1;case .boolean(true):2;case .number:3;case .string:4;case .array:5;case .object:6}}
        var pending:[(JSON,JSON)]=[]
        try context.meter.retain(16);pending.append((a,b))
        defer{try? context.meter.release(UInt64(pending.count)*16)}
        while let (a,b)=pending.popLast() {
            try context.meter.release(16);try context.work()
            let ra=rank(a),rb=rank(b);if ra != rb{return ra<rb ? -1:1}
            switch (a,b) {
            case (.null,.null),(.boolean,.boolean):break
            case (.number(let a),.number(let b)):
                let result=try a.compare(to:b,meter:&context.meter)
                if result != .orderedSame{return result == .orderedAscending ? -1:1}
            case (.string(let a),.string(let b)):
                let result=try textCompare(a,b,context:&context);if result != 0{return result}
            case (.array(let a),.array(let b)):
                // Length is a final sentinel, after the common lexicographic prefix.
                if a.count != b.count {try context.meter.retain(16);pending.append((.number(JSONNumber(integer:a.count)),.number(JSONNumber(integer:b.count))))}
                for i in (0..<min(a.count,b.count)).reversed(){try context.work();try context.meter.retain(16);pending.append((a[i],b[i]))}
            case (.object(let ao),.object(let bo)):
                let a=try sortedMembers(ao,context:&context)
                defer{try? context.meter.release(UInt64(a.count)*JSONLogicalWeights.member)}
                let b=try sortedMembers(bo,context:&context)
                defer{try? context.meter.release(UInt64(b.count)*JSONLogicalWeights.member)}
                for i in 0..<min(a.count,b.count){let result=try textCompare(a[i].key.string,b[i].key.string,context:&context);if result != 0{return result}}
                if a.count != b.count{return a.count<b.count ? -1:1}
                for i in a.indices.reversed(){try context.work();try context.meter.retain(16);pending.append((a[i].value,b[i].value))}
            default:throw FilterLanguageFailure("invalidComparison")
            }
        }
        return 0
    }
    package static func bound(_ value:JSON?,length:Int,default fallback:Int,context:inout CLIJobContext)throws->Int {
        guard let value else{return fallback}
        guard case .number(let number)=value,number.isInteger else{throw FilterLanguageFailure("invalidSliceBound")}
        if try number.compare(to:JSONNumber(integer:length),meter:&context.meter) != .orderedAscending{return length}
        if try number.compare(to:JSONNumber(integer:-length),meter:&context.meter) == .orderedAscending{return 0}
        let index=try number.integer(as:Int.self,meter:&context.meter)
        return index<0 ? length+index:index
    }
    package static func slice(_ value:JSON,start:JSON?,end:JSON?,context:inout CLIJobContext)throws->FilterYield {
        if case .null=value{return .init(value:.null)}
        switch value {
        case .array(let values):
            let lower=try bound(start,length:values.count,default:0,context:&context),upper=try bound(end,length:values.count,default:values.count,context:&context)
            let count=max(0,upper-lower)
            try context.charge(.collectionValues,UInt64(count))
            var transferred=false, scratch:UInt64=0
            defer { try? context.meter.release(scratch); if !transferred { try? context.release(.collectionValues, UInt64(count)) } }
            try context.meter.retain(UInt64(count)*16); scratch=UInt64(count)*16; try context.work(UInt64(count))
            let result=Array(values[lower..<(lower+count)])
            let output=try array(result,admittedCollectionCount:true,context:&context);transferred=true;return output
        case .string(let text):
            var length=0
            for _ in text.unicodeScalars{try context.work();length += 1}
            let lower=try bound(start,length:length,default:0,context:&context),upper=try bound(end,length:length,default:length,context:&context)
            var output="",offset=0,bytes:UInt64=0
            defer { try? context.meter.release(bytes) }
            for scalar in text.unicodeScalars {
                try context.work()
                if offset>=lower && offset<upper {
                    let size=UInt64(scalar.utf8.count);try context.meter.require(.stringBytes,bytes+size);try context.meter.retain(size);bytes += size
                    output.unicodeScalars.append(scalar)
                }
                offset += 1
            }
            return try produced(.string(output),context:&context)
        default:throw FilterLanguageFailure("cannotSlice")
        }
    }
}
