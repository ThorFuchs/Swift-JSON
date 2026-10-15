// SPDX-License-Identifier: Apache-2.0
import JSON

/// Literal Unicode-scalar operations. Work and all construction overlaps are
/// charged; no Foundation regex/canonical string matching is an authority.
package enum FilterStringBuiltins {
    package static let arities: [String: Set<Int>] = ["contains":[1],"startswith":[1],"endswith":[1],"split":[1],"join":[1],"indices":[1],"index":[1],"rindex":[1],"tostring":[0],"tonumber":[0],"ascii_upcase":[0],"ascii_downcase":[0],"ltrimstr":[1],"rtrimstr":[1],"explode":[0],"implode":[0]]
    package static func apply(_ name: String, value: JSON, argument: JSON? = nil, context: inout CLIJobContext) throws -> FilterYield {
        try context.checkpoint()
        let entry = context.meter.used(.retainedBytes)
        var owned: UInt64 = 0, collections: UInt64 = 0, transferred = false
        defer {
            try? context.meter.release(context.meter.used(.retainedBytes) - entry - owned)
            if !transferred { try? context.release(.collectionValues, collections) }
        }
        func append(_ scalar: Unicode.Scalar, to text: inout String, context: inout CLIJobContext) throws {
            let size = UInt64(scalar.utf8.count)
            try context.work(size); try context.meter.require(.stringBytes, UInt64(text.utf8.count) + size); try context.meter.retain(size)
            text.unicodeScalars.append(scalar)
        }
        func arraySlot(context: inout CLIJobContext) throws {
            try context.charge(.collectionValues); collections += 1
            try context.meter.require(.arrayItems, collections); try context.meter.retain(16)
        }
        let result: JSON
        if name == "contains" {
            guard let argument else { throw FilterLanguageFailure("wrongArity") }
            result = .boolean(try FilterContainment.contains(value,argument,context:&context))
        }
        else if name == "tostring" { result = .string(try text(value, context: &context)) }
        else if name == "tonumber" {
            if case .number = value { result = value }
            else {
                guard case .string(let source) = value else { throw FilterLanguageFailure("expectedNumericText") }
                do { result = .number(try JSONNumber.parse(source.utf8, meter: &context.meter)) }
                catch let failure as JSONFailure where failure.category == .syntax { throw FilterLanguageFailure("invalidNumericText") }
            }
        } else if name == "join" {
            guard case .array(let values) = value, case .string(let separator) = argument else { throw FilterLanguageFailure("invalidJoinDomain") }
            var output = ""
            for index in values.indices {
                try context.work()
                if index > 0 { for scalar in separator.unicodeScalars { try append(scalar,to:&output,context:&context) } }
                switch values[index] {
                case .null: break
                case .array,.object: throw FilterLanguageFailure("cannotJoinContainer")
                default:
                    try usingText(values[index],context:&context) { source,context in
                        for scalar in source.unicodeScalars { try append(scalar,to:&output,context:&context) }
                    }
                }
            }
            result = .string(output)
        } else if name == "implode" {
            guard case .array(let values) = value else { throw FilterLanguageFailure("expectedScalarArray") }
            var output = ""
            for value in values {
                guard case .number(let n) = value, n.isInteger, !n.isNegative else { throw FilterLanguageFailure("invalidScalar") }
                let point: UInt32
                do { point = try n.integer(as:UInt32.self,meter:&context.meter) }
                catch let failure as JSONFailure where failure.category == .conversion { throw FilterLanguageFailure("invalidScalar") }
                guard let scalar = Unicode.Scalar(point) else { throw FilterLanguageFailure("invalidScalar") }
                try append(scalar,to:&output,context:&context)
            }
            result = .string(output)
        } else {
            guard case .string(let source) = value else { throw FilterLanguageFailure("expectedString") }
            if name == "ascii_upcase" || name == "ascii_downcase" {
                var output = ""
                for scalar in source.unicodeScalars {
                    let point=scalar.value
                    let mapped=name == "ascii_upcase" && (97...122).contains(point) ? point-32 : name == "ascii_downcase" && (65...90).contains(point) ? point+32 : point
                    guard let scalar=Unicode.Scalar(mapped) else { throw CLIError(.resource,"scalarInvariant") }
                    try append(scalar,to:&output,context:&context)
                }
                result = .string(output)
            } else if name == "explode" {
                var values:[JSON]=[]
                for scalar in source.unicodeScalars { try context.work(20);try arraySlot(context:&context);values.append(.number(JSONNumber(integer:scalar.value))) }
                result = .array(values)
            } else {
                guard case .string(let separator) = argument else { throw FilterLanguageFailure("expectedString") }
                if name == "split" { result = .array(try FilterOperators.split(source, separator: separator, context: &context, collectionCount: &collections)) }
                else {
                    let scalars=try scalarArray(source,context:&context),pattern=try scalarArray(separator,context:&context)
                    func match(_ position:Int,context:inout CLIJobContext)throws->Bool {
                        guard position>=0,position<=scalars.count,pattern.count<=scalars.count-position else{return false}
                        for index in pattern.indices {try context.work();if scalars[position+index].value != pattern[index].value{return false}}
                        return true
                    }
                    switch name {
                    case "startswith","endswith","contains":
                        let found:Bool
                        if name=="startswith"{found=try match(0,context:&context)}
                        else if name=="endswith"{found=try match(scalars.count-pattern.count,context:&context)}
                        else {var candidate=false;for index in 0...scalars.count{try context.work();if try match(index,context:&context){candidate=true;break}};found=candidate}
                        result = .boolean(found)
                    case "ltrimstr","rtrimstr":
                        let at=name=="ltrimstr" ? 0 : scalars.count-pattern.count
                        let matched=try match(at,context:&context)
                        let lower=name=="ltrimstr" && matched ? pattern.count:0
                        let upper=name=="rtrimstr" && matched ? scalars.count-pattern.count:scalars.count
                        var output="";for index in lower..<upper{try append(scalars[index],to:&output,context:&context)};result = .string(output)
                    case "indices","index","rindex":
                        var indices:[JSON]=[],found:Int?
                        if !pattern.isEmpty {for index in 0..<scalars.count {try context.work();if try match(index,context:&context){found=index;if name=="indices"{try arraySlot(context:&context);try context.work(20);indices.append(.number(JSONNumber(integer:index)))};if name=="index"{break}}}}
                        result=name=="indices" ? .array(indices) : found.map{.number(JSONNumber(integer:$0))} ?? .null
                    default:throw FilterLanguageFailure("unknownStringBuiltin")
                    }
                }
            }
        }
        let output=try FilterValues.produced(result,collections:collections,context:&context)
        owned=output.lease?.retained ?? 0;transferred=true;return output
    }
    private static func scalarArray(_ text:String,context:inout CLIJobContext)throws->[Unicode.Scalar] {
        var result:[Unicode.Scalar]=[]
        for scalar in text.unicodeScalars {try context.work();try context.meter.retain(4);result.append(scalar)}
        return result
    }
    /// The callback consumes text while its construction reservation is live.
    /// New callback storage is separately charged and survives the scratch refund.
    package static func usingText<Result>(_ value:JSON,context:inout CLIJobContext,
                                          _ body:(String,inout CLIJobContext)throws->Result)throws->Result {
        if case .string(let text)=value{return try body(text,&context)}
        try context.checkpoint();let entry=context.meter.used(.retainedBytes)
        var handedOff=false,scratch:UInt64=0
        defer{try? context.meter.release(handedOff ? scratch:context.meter.used(.retainedBytes)-entry)}
        let source=try text(value,context:&context)
        scratch=context.meter.used(.retainedBytes)-entry;handedOff=true
        return try body(source,&context)
    }
    package static func text(_ value:JSON,context:inout CLIJobContext)throws->String {
        if case .string(let text)=value{return text}
        try context.meter.resetValueBounds()
        let bytes=try JSONWriter(options:.init(limits:context.meter.limits,numberStyle:.preserved)).write(value,meter:&context.meter)
        try context.work(UInt64(bytes.count));try context.meter.retain(UInt64(bytes.count))
        return String(decoding:bytes,as:UTF8.self)
    }
}
