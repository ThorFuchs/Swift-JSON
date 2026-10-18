// SPDX-License-Identifier: Apache-2.0
import JSON

package enum FilterPrimitiveBuiltins {
    package static func apply(_ name:String,value:JSON,argument:JSON?=nil,context:inout TransformRuntimeContext)throws->FilterYield? {
        try context.work()
        switch name {
        case "empty":return nil
        case "not":return try FilterValues.produced(.boolean(!FilterTruth.test(value)),context:&context)
        case "values":if case .null=value{return nil};return .init(value:value)
        case "has":guard let argument else{throw FilterLanguageFailure("wrongArity")};return try FilterValues.produced(.boolean(FilterValues.has(value,key:argument,context:&context)),context:&context)
        case "type":
            let text:String
            switch value{case .null:text="null";case .boolean:text="boolean";case .number:text="number";case .string:text="string";case .array:text="array";case .object:text="object"}
            return try FilterValues.produced(.string(text),context:&context)
        case "length":
            switch value {
            case .null:return try FilterValues.integer(0,context:&context)
            case .array(let a):return try FilterValues.integer(a.count,context:&context)
            case .object(let o):return try FilterValues.integer(o.count,context:&context)
            case .string(let s):var count=0;for _ in s.unicodeScalars{try context.work();count += 1};return try FilterValues.integer(count,context:&context)
            case .number(let n):let c=n.components;let components=DecimalComponents(negative:false,digits:c.digits,exponent:c.exponent);return try FilterValues.produced(.number(JSONNumber(components:components)),context:&context)
            case .boolean:throw FilterLanguageFailure("invalidLengthDomain")
            }
        case "utf8bytelength":
            guard case .string(let text)=value else{throw FilterLanguageFailure("expectedString")}
            var count=0;for _ in text.utf8{try context.work();count += 1};return try FilterValues.integer(count,context:&context)
        case "keys","keys_unsorted":
            let count:Int
            switch value{case .object(let o):count=o.count;case .array(let a):count=a.count;default:throw FilterLanguageFailure("expectedContainer")}
            try context.charge(.collectionValues,UInt64(count))
            var scratch:UInt64=0,transferred=false
            defer { try? context.meter.release(scratch); if !transferred { try? context.release(.collectionValues,UInt64(count)) } }
            try context.meter.retain(UInt64(count)*16);scratch=UInt64(count)*16
            var values:[JSON]=[]
            switch value {
            case .object(let o):
                if name=="keys" {
                    let members=try FilterValues.sortedMembers(o,context:&context)
                    defer{try? context.meter.release(UInt64(count)*JSONLogicalWeights.member)}
                    for member in members{try context.work();values.append(.string(member.key.string))}
                } else {for member in o{try context.work();values.append(.string(member.key.string))}}
            case .array:for index in 0..<count{try context.work(20);values.append(.number(JSONNumber(integer:index)))}
            default:throw FilterLanguageFailure("expectedContainer")
            }
            let output=try FilterValues.array(values,admittedCollectionCount:true,context:&context)
            transferred=true;return output
        case "arrays","objects","iterables","booleans","numbers","normals","finites","strings","nulls","scalars":
            let selected:Bool
            switch value {
            case .array:selected=name=="arrays" || name=="iterables"
            case .object:selected=name=="objects" || name=="iterables"
            case .boolean:selected=name=="booleans" || name=="scalars"
            case .number(let n):selected=["numbers","finites","scalars"].contains(name) || name=="normals" && !n.isZero
            case .string:selected=name=="strings" || name=="scalars"
            case .null:selected=name=="nulls" || name=="scalars"
            }
            return selected ? .init(value:value):nil
        default:throw FilterLanguageFailure("unsupportedBuiltin")
        }
    }
}
