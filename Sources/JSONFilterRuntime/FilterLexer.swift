// SPDX-License-Identifier: Apache-2.0
import JSON

package enum FilterLexer {
    package static func lex(_ source: String, context: inout CLIJobContext) throws -> [FilterToken] {
        let count = UInt64(source.utf8.count)
        try context.charge(.querySourceBytes, count); try context.meter.retain(count); try context.work(count)
        let bytes = Array(source.utf8)
        enum Job { case scan(Range<Int>), token(FilterToken.Kind,Range<Int>) }
        var tokens: [FilterToken] = [], i = 0, end = bytes.count
        var jobs:[Job]=[]
        func append(_ kind: FilterToken.Kind, _ start: Int, _ end: Int, context: inout CLIJobContext) throws {
            try context.charge(.queryTokens); try context.meter.retain(48)
            tokens.append(.init(kind: kind, range: start..<end))
        }
        func nameStart(_ byte: UInt8) -> Bool { byte == 95 || (65...90).contains(byte) || (97...122).contains(byte) }
        func nameByte(_ byte: UInt8) -> Bool { nameStart(byte) || (48...57).contains(byte) }
        while true {
            if i>=end {
                guard let job=jobs.popLast() else{break}
                try context.meter.release(32)
                switch job{case .scan(let range):i=range.lowerBound;end=range.upperBound;case .token(let kind,let range):try append(kind,range.lowerBound,range.upperBound,context:&context)}
                continue
            }
            try context.work(); let start = i, byte = bytes[i]
            if [9,10,13,32].contains(byte) { i += 1; continue }
            if byte == 35 { while i < end && bytes[i] != 10 { try context.work(); i += 1 }; continue }
            if byte == 34 {
                enum Mode {case string,code(Int)}
                var modes:[Mode]=[.string],position=i+1,segment=i+1,parts:[(Range<Int>,Bool)]=[],closed=false
                var codeStart:Int?
                var scratch:UInt64=0
                defer{try? context.meter.release(scratch)}
                while position<end && !closed {
                    try context.work()
                    let b=bytes[position]
                    guard let mode=modes.last else{throw FilterCompileFailure("invalidStringState",at:position)}
                    switch mode {
                    case .string:
                        if b==92 {
                            guard position+1<end else{break}
                            if bytes[position+1]==40 {
                                if modes.count==1 {
                                    try context.meter.retain(24);scratch += 24;parts.append((segment..<position,false));codeStart=position+2
                                }
                                try context.require(.queryDepth,UInt64(modes.count)+1);try context.meter.retain(16);scratch += 16;modes.append(.code(1));position += 2;continue
                            }
                            position += 2;continue
                        }
                        if b==34 {
                            modes.removeLast()
                            if modes.isEmpty{closed=true;continue}
                            position += 1;continue
                        }
                    case .code(let depth):
                        if b==34{try context.require(.queryDepth,UInt64(modes.count)+1);try context.meter.retain(16);scratch += 16;modes.append(.string);position += 1;continue}
                        if b==35{while position<end && bytes[position] != 10{try context.work();position += 1};continue}
                        if b==40{modes[modes.count-1] = .code(depth+1);try context.require(.queryDepth,UInt64(depth)+1)}
                        if b==41 {
                            if depth==1{
                                modes.removeLast()
                                if modes.count==1,let lower=codeStart{try context.meter.retain(24);scratch += 24;parts.append((lower..<position,true));segment=position+1;codeStart=nil}
                            }else{modes[modes.count-1] = .code(depth-1)}
                        }
                    }
                    position += 1
                }
                guard closed else{throw FilterCompileFailure("unterminatedString",at:start)}
                let stop=position+1
                if parts.isEmpty {
                    let copyBytes=UInt64(stop-start);try context.work(copyBytes);try context.meter.retain(copyBytes);defer{try? context.meter.release(copyBytes)}
                    let value:JSON
                    do{value=try JSONParser().parse(Array(bytes[start..<stop]),meter:&context.meter)}catch let error as JSONFailure where error.category == .syntax{throw FilterCompileFailure("invalidString",at:start)}
                    try append(.literal(value),start,stop,context:&context);i=stop;continue
                }
                try context.meter.retain(24);scratch += 24;parts.append((segment..<position,false))
                var sequence:[Job]=[]
                func schedule(_ job:Job,context:inout CLIJobContext)throws{try context.meter.retain(32);sequence.append(job)}
                try schedule(.token(.generatedName("__interpolate"),start..<stop),context:&context)
                try schedule(.token(.symbol("("),start..<stop),context:&context)
                for (index,part) in parts.enumerated() {
                    if index>0{try schedule(.token(.symbol(";"),start..<stop),context:&context)}
                    if part.1{guard !part.0.isEmpty else{throw FilterCompileFailure("emptyInterpolation",at:part.0.lowerBound)};try schedule(.scan(part.0),context:&context)}
                    else{
                        let size=UInt64(part.0.count)+2;try context.work(size);try context.meter.retain(size);scratch += size
                        var literal:[UInt8]=[34];literal.append(contentsOf:bytes[part.0]);literal.append(34)
                        let value:JSON
                        do{value=try JSONParser().parse(literal,meter:&context.meter)}catch let error as JSONFailure where error.category == .syntax{throw FilterCompileFailure("invalidString",at:part.0.lowerBound)}
                        try schedule(.token(.literal(value),part.0),context:&context)
                    }
                }
                try schedule(.token(.symbol(")"),start..<stop),context:&context)
                try context.meter.retain(32);jobs.append(.scan(stop..<end))
                jobs.append(contentsOf:sequence.reversed());i=end;continue
            }
            if (48...57).contains(byte) {
                i += 1
                while i < end {
                    let b = bytes[i]
                    if (48...57).contains(b) || b == 46 || b == 101 || b == 69 || (b == 43 || b == 45) && (bytes[i-1] == 101 || bytes[i-1] == 69) { try context.work(); i += 1 }
                    else { break }
                }
                let number: JSONNumber
                do { number = try .parse(bytes[start..<i], meter: &context.meter) }
                catch let error as JSONFailure where error.category == .syntax { throw FilterCompileFailure("invalidNumber", at: start) }
                try append(.literal(.number(number)), start, i, context: &context); continue
            }
            if byte == 36 || nameStart(byte) {
                let variable = byte == 36; if variable { i += 1 }
                guard i < end, nameStart(bytes[i]) else { throw FilterCompileFailure("invalidIdentifier", at: start) }
                let textStart = i; i += 1
                while i < end && nameByte(bytes[i]) { try context.work(); i += 1 }
                try context.meter.retain(UInt64(i-textStart)); try context.work(UInt64(i-textStart))
                let text = String(decoding: bytes[textStart..<i], as: UTF8.self)
                let kind: FilterToken.Kind
                if variable { kind = .variable(text) }
                else if text == "true" || text == "false" { kind = .literal(.boolean(text == "true")) }
                else if text == "null" { kind = .literal(.null) }
                else { kind = .name(text) }
                try append(kind, start, i, context: &context); continue
            }
            if i+2<end,bytes[i]==47,bytes[i+1]==47,bytes[i+2]==61{i += 3;try append(.symbol("//="),start,i,context:&context);continue}
            if i+1 < end {
                let pair = String(decoding: bytes[i...i+1], as: UTF8.self)
                if ["..", "//", "==", "!=", "<=", ">=", "|=", "+=", "-=", "*=", "/=", "%="].contains(pair) {
                    i += 2; try append(.symbol(pair), start, i, context: &context); continue
                }
            }
            guard [46,44,124,40,41,91,93,123,125,58,59,63,43,45,42,47,37,60,62,61,64].contains(byte) else { throw FilterCompileFailure("unexpectedByte", at: start) }
            i += 1; try append(.symbol(String(Unicode.Scalar(byte))), start, i, context: &context)
        }
        return tokens
    }
}
