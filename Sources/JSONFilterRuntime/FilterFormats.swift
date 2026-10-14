// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

/// Bounded text encoders. @sh produces inert text and never invokes a process.
package enum FilterFormats {
    package static let names: Set<String> = ["text","json","html","uri","csv","tsv","sh","base64","base64d"]
    package static func apply(_ name:String,value:JSON,context:inout CLIJobContext)throws->FilterYield {
        try context.checkpoint()
        let entry=context.meter.used(.retainedBytes)
        var owned:UInt64=0,output="",bytes:UInt64=0
        defer{try? context.meter.release(context.meter.used(.retainedBytes)-entry-owned)}
        func append(_ text:String,context:inout CLIJobContext)throws {
            for scalar in text.unicodeScalars {
                let size=UInt64(scalar.utf8.count)
                try context.work(size);try context.meter.require(.stringBytes,bytes+size);try context.meter.retain(size)
                output.unicodeScalars.append(scalar);bytes += size
            }
        }
        func text(_ value:JSON,context:inout CLIJobContext)throws->String {try FilterStringBuiltins.text(value,context:&context)}
        func scalar(_ value:JSON,context:inout CLIJobContext)throws->String {
            switch value{case .array,.object:throw FilterLanguageFailure("formatExpectedScalar");case .null:return "";default:return try text(value,context:&context)}
        }
        func quoteShell(_ source:String,context:inout CLIJobContext)throws {
            try append("'",context:&context)
            for scalar in source.unicodeScalars {try append(scalar.value==39 ? "'\\''" : String(scalar),context:&context)}
            try append("'",context:&context)
        }
        switch name {
        case "json":
            try context.meter.resetValueBounds()
            let encoded=try JSONWriter(options:.init(limits:context.meter.limits,numberStyle:.preserved)).write(value,meter:&context.meter)
            try context.work(UInt64(encoded.count));try context.meter.retain(UInt64(encoded.count))
            try append(String(decoding:encoded,as:UTF8.self),context:&context)
        case "text":try append(text(value,context:&context),context:&context)
        case "html":
            for scalar in try text(value,context:&context).unicodeScalars {
                let escaped:String
                switch scalar.value{case 38:escaped="&amp;";case 60:escaped="&lt;";case 62:escaped="&gt;";case 34:escaped="&quot;";case 39:escaped="&apos;";default:escaped=String(scalar)}
                try append(escaped,context:&context)
            }
        case "uri":
            let hex:[UInt8]=Array("0123456789ABCDEF".utf8)
            for byte in try text(value,context:&context).utf8 {
                try context.work()
                if (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || [45,46,95,126].contains(byte){try append(String(Unicode.Scalar(byte)),context:&context)}
                else{try append("%",context:&context);try append(String(Unicode.Scalar(hex[Int(byte>>4)])),context:&context);try append(String(Unicode.Scalar(hex[Int(byte&15)])),context:&context)}
            }
        case "csv","tsv":
            guard case .array(let values)=value else{throw FilterLanguageFailure("formatExpectedArray")}
            for index in values.indices {
                try context.work();if index>0{try append(name=="csv" ? ",":"\t",context:&context)}
                let source=try scalar(values[index],context:&context)
                if name=="csv",case .string=values[index]{try append("\"",context:&context);for scalar in source.unicodeScalars{try append(scalar.value==34 ? "\"\"":String(scalar),context:&context)};try append("\"",context:&context)}
                else if name=="tsv"{for scalar in source.unicodeScalars{let escaped:String;switch scalar.value{case 9:escaped="\\t";case 10:escaped="\\n";case 13:escaped="\\r";case 92:escaped="\\\\";default:escaped=String(scalar)};try append(escaped,context:&context)}}
                else{try append(source,context:&context)}
            }
        case "sh":
            let values:[JSON]
            if case .array(let a)=value{values=a}else{values=[value]}
            for index in values.indices{try context.work();if index>0{try append(" ",context:&context)};if case .string(let source)=values[index]{try quoteShell(source,context:&context)}else{switch values[index]{case .array,.object:throw FilterLanguageFailure("formatExpectedScalar");default:try append(text(values[index],context:&context),context:&context)}}}
        case "base64":
            let alphabet:[UInt8]=Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
            var input:[UInt8]=[]
            for byte in try text(value,context:&context).utf8{try context.work();try context.meter.retain(1);input.append(byte)}
            var index=0
            while index<input.count {
                try context.work();let a=input[index],b=index+1<input.count ? input[index+1]:0,c=index+2<input.count ? input[index+2]:0
                let positions=[Int(a>>2),Int((a&3)<<4|b>>4),Int((b&15)<<2|c>>6),Int(c&63)]
                for position in 0..<4{try append(position==2 && index+1>=input.count || position==3 && index+2>=input.count ? "=":String(Unicode.Scalar(alphabet[positions[position]])),context:&context)}
                index += 3
            }
        case "base64d":
            guard case .string(let source)=value else{throw FilterLanguageFailure("expectedString")}
            var input:[UInt8]=[];for byte in source.utf8{try context.work();try context.meter.retain(1);input.append(byte)}
            guard input.count%4==0 else{throw FilterLanguageFailure("invalidBase64")}
            func digit(_ byte:UInt8)throws->UInt8{switch byte{case 65...90:return byte-65;case 97...122:return byte-97+26;case 48...57:return byte-48+52;case 43:return 62;case 47:return 63;default:throw FilterLanguageFailure("invalidBase64")}}
            var decoded:[UInt8]=[],index=0
            func byte(_ value:UInt8,context:inout CLIJobContext)throws{try context.work();try context.meter.require(.stringBytes,UInt64(decoded.count)+1);try context.meter.retain(1);decoded.append(value)}
            while index<input.count {
                try context.work();let a=try digit(input[index]),b=try digit(input[index+1]);try byte((a<<2)|(b>>4),context:&context)
                if input[index+2]==61{guard index+4==input.count,input[index+3]==61,b&15==0 else{throw FilterLanguageFailure("invalidBase64")}}
                else{let c=try digit(input[index+2]);try byte((b<<4)|(c>>2),context:&context);if input[index+3]==61{guard index+4==input.count,c&3==0 else{throw FilterLanguageFailure("invalidBase64")}}else{let d=try digit(input[index+3]);try byte((c<<6)|d,context:&context)}}
                index += 4
            }
            guard let decoded=String(bytes:decoded,encoding:.utf8) else{throw FilterLanguageFailure("invalidBase64UTF8")}
            try append(decoded,context:&context)
        default:throw FilterCompileFailure("unsupportedFormatter",at:0)
        }
        let result=try FilterValues.produced(.string(output),context:&context);owned=result.lease?.retained ?? 0;return result
    }
}
