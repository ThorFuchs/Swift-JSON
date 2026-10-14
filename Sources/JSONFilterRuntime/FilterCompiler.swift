// SPDX-License-Identifier: Apache-2.0
import JSON

/// Token-range compilation uses an explicit work stack and flat node IDs.
/// Source depth never becomes Swift call-stack depth.
package enum FilterCompiler {
    private struct Work {
        let range: Range<Int>
        let destination: Int
        let depth: UInt64
        let variables: Set<String>
    }
    package static let builtinArities: [String: Set<Int>] = [
        "select":[1], "map":[1], "map_values":[1], "has":[1], "length":[0], "utf8bytelength":[0], "type":[0],
        "keys":[0], "keys_unsorted":[0], "values":[0], "empty":[0], "not":[0],
        "arrays":[0], "objects":[0], "iterables":[0], "booleans":[0], "numbers":[0], "normals":[0], "finites":[0], "strings":[0], "nulls":[0], "scalars":[0],
        "error":[0,1], "input":[0], "inputs":[0],
        "add":[0], "abs":[0], "floor":[0], "ceil":[0], "trunc":[0], "round":[0], "range":[1,2,3]
    ]
    package static func compile(_ source: String, variables: Set<String> = ["ARGS"], context: inout CLIJobContext) throws -> FilterProgram {
        try context.domain(.core)
        let tokens = try FilterLexer.lex(source, context: &context)
        guard !tokens.isEmpty else { throw FilterCompileFailure("emptyFilter", at: 0) }
        var matches: [Int:Int] = [:], nesting: [(Int,String)] = []
        for i in tokens.indices {
            try context.work()
            guard let text = tokens[i].text else { continue }
            if ["(","[","{","if"].contains(text) {
                try context.require(.queryDepth, UInt64(nesting.count)+1); try context.meter.retain(32)
                nesting.append((i,text))
            } else if [")","]","}","end"].contains(text) {
                guard let open = nesting.popLast(), ["(":")","[":"]","{":"}","if":"end"][open.1] == text else { throw FilterCompileFailure("unmatchedDelimiter", at: tokens[i].range.lowerBound) }
                try context.work(); try context.meter.retain(32); try context.meter.release(32)
                matches[open.0] = i; matches[i] = open.0
            }
        }
        guard nesting.isEmpty else { throw FilterCompileFailure("unclosedDelimiter", at: tokens[nesting.last!.0].range.lowerBound) }
        var nodes: [FilterProgram.Node] = [], ranges: [Range<Int>] = [], work: [Work] = []
        func slot(_ span: Range<Int>, depth: UInt64, variables: Set<String>, context: inout CLIJobContext) throws -> Int {
            guard !span.isEmpty else { throw FilterCompileFailure("missingExpression", at: source.utf8.count) }
            try context.require(.queryDepth, depth); try context.charge(.astNodes); try context.meter.retain(128)
            let id = nodes.count; nodes.append(.pending); ranges.append(tokens[span.lowerBound].range.lowerBound..<tokens[span.upperBound-1].range.upperBound)
            try context.meter.retain(48); work.append(.init(range:span,destination:id,depth:depth,variables:variables)); return id
        }
        var taskScratch: UInt64 = 0
        func top(_ span: Range<Int>, context: inout CLIJobContext) throws -> [Int] {
            var result: [Int] = [], i = span.lowerBound
            while i < span.upperBound {
                try context.work(); try context.meter.retain(8); taskScratch += 8; result.append(i)
                if let close = matches[i], close > i { i = close + 1 } else { i += 1 }
            }
            return result
        }
        let root = try slot(0..<tokens.count, depth: 1, variables: variables, context: &context)
        while let task = work.popLast() {
            try context.meter.release(48); try context.work()
            taskScratch = 0
            defer { try? context.meter.release(taskScratch) }
            var span = task.range
            while tokens[span.lowerBound].text == "(", matches[span.lowerBound] == span.upperBound-1 {
                try context.work(); span = (span.lowerBound+1)..<(span.upperBound-1)
                guard !span.isEmpty else { throw FilterCompileFailure("missingExpression", at: ranges[task.destination].lowerBound) }
            }
            let lo = span.lowerBound, hi = span.upperBound, first = tokens[lo].text
            func child(_ range: Range<Int>, context: inout CLIJobContext) throws -> Int { try slot(range,depth:task.depth+1,variables:task.variables,context:&context) }
            let positions = try top(span, context:&context)
            if (first == "if" || first == "elif") && tokens[hi-1].text == "end" {
                guard tokens[hi-1].text == "end" else { throw FilterCompileFailure("missingEnd", at: tokens[lo].range.lowerBound) }
                let inner = try top((lo+1)..<(hi-1),context:&context)
                guard let then = inner.first(where:{tokens[$0].text == "then"}), let branch = inner.first(where:{tokens[$0].text == "else" || tokens[$0].text == "elif"}), then < branch else { throw FilterCompileFailure("invalidConditional", at: tokens[lo].range.lowerBound) }
                let condition = try child((lo+1)..<then,context:&context), yes = try child((then+1)..<branch,context:&context)
                let no = try child(tokens[branch].text == "elif" ? branch..<hi : (branch+1)..<(hi-1),context:&context)
                nodes[task.destination] = .conditional(condition,yes,no); continue
            }
            var resolved = false
            let precedences = [["|"], [","], ["//"], ["=" ,"|=","+=","-=","*=","/=","%="], ["or"], ["and"], ["==","!=","<",">","<=",">="], ["+","-"], ["*","/","%"]]
            for (level, operators) in precedences.enumerated() {
                var found: [Int] = []
                for position in positions where position > lo && position+1 < hi {
                    try context.work()
                    if let name = tokens[position].text, operators.contains(name) {
                        let previous = tokens[position-1].text
                        // Unary minus is not an infix split after an operator or delimiter.
                        if name == "-", previous.map({ ["|",",","//","+","-","*","/","%","=","(","[",":",";"].contains($0) }) == true { continue }
                        try context.meter.retain(8); taskScratch += 8; found.append(position)
                    }
                }
                if found.isEmpty { continue }
                if level == 3 { throw FilterCompileFailure("assignmentNotYetQualified", at: tokens[found[0]].range.lowerBound) }
                if level == 6 && found.count > 1 { throw FilterCompileFailure("chainedComparison", at: tokens[found[1]].range.lowerBound) }
                let position = level == 0 || level == 2 ? found.first! : found.last!, op = tokens[position].text!
                if op == "|", let binding = positions.first(where: { $0 < position && tokens[$0].text == "as" }) {
                    guard binding+2 == position, case .variable(let name) = tokens[binding+1].kind else { throw FilterCompileFailure("invalidBinding", at: tokens[binding].range.lowerBound) }
                    let lhs = try child(lo..<binding,context:&context)
                    var variables = task.variables; variables.insert(name)
                    let rhs = try slot((position+1)..<hi,depth:task.depth+1,variables:variables,context:&context)
                    nodes[task.destination] = .bind(lhs,name,rhs)
                } else {
                    let a = try child(lo..<position,context:&context), b = try child((position+1)..<hi,context:&context)
                    nodes[task.destination] = op == "|" ? .pipe(a,b) : op == "," ? .comma(a,b) : op == "//" ? .fallback(a,b) : .binary(op,a,b)
                }
                resolved = true; break
            }
            if resolved { continue }
            if first == "try" {
                let caught = positions.first(where:{tokens[$0].text == "catch"})
                let body = try child((lo+1)..<(caught ?? hi),context:&context)
                let handler = try caught.map { try child(($0+1)..<hi,context:&context) }
                nodes[task.destination] = .attempt(body,handler); continue
            }
            if first == "-" || first == "+" {
                if first == "-", span.count == 2, case .literal(.number(let number)) = tokens[lo+1].kind, let lexeme = number.originalLexeme {
                    let bytes = UInt64(lexeme.utf8.count) + 1
                    try context.meter.retain(bytes); try context.work(bytes)
                    defer { try? context.meter.release(bytes) }
                    var token: [UInt8] = [45]; token.append(contentsOf: lexeme.utf8)
                    let negative = try JSONNumber.parse(token,meter:&context.meter)
                    nodes[task.destination] = .literal(.number(negative))
                } else { nodes[task.destination] = .unary(first!,try child((lo+1)..<hi,context:&context)) }
                continue
            }
            if tokens[hi-1].text == "?" { nodes[task.destination] = .optional(try child(lo..<(hi-1),context:&context)); continue }
            if tokens[hi-1].text == "]", let open = matches[hi-1], open > lo {
                let base = try child(lo..<open,context:&context)
                if open+1 == hi-1 { nodes[task.destination] = .iterate(base) }
                else if let colon = try top((open+1)..<(hi-1),context:&context).first(where:{tokens[$0].text == ":"}) {
                    let start = open+1 < colon ? try child((open+1)..<colon,context:&context) : nil
                    let end = colon+1 < hi-1 ? try child((colon+1)..<(hi-1),context:&context) : nil
                    nodes[task.destination] = .slice(base,start,end)
                } else { nodes[task.destination] = .index(base,try child((open+1)..<(hi-1),context:&context)) }
                continue
            }
            if let dot = positions.last(where:{tokens[$0].text == "." && $0+2 == hi}),
               { if case .name = tokens[dot+1].kind { return true }; if case .literal(.string) = tokens[dot+1].kind { return true }; return false }() {
                let key: String
                switch tokens[dot+1].kind { case .name(let text), .literal(.string(let text)): key = text; default: throw FilterCompileFailure("invalidField", at: tokens[dot].range.lowerBound) }
                let base: Int
                if dot == lo { base = nodes.count; try context.charge(.astNodes); try context.meter.retain(128); nodes.append(.identity); ranges.append(tokens[dot].range) }
                else { base = try child(lo..<dot,context:&context) }
                let keyID = nodes.count; try context.charge(.astNodes); try context.meter.retain(128); nodes.append(.literal(.string(key))); ranges.append(tokens[dot+1].range)
                nodes[task.destination] = .index(base,keyID); continue
            }
            if first == "[", matches[lo] == hi-1 {
                if span.count == 2 { nodes[task.destination] = .literal(.array([])) }
                else { nodes[task.destination] = .array(try child((lo+1)..<(hi-1),context:&context)) }
                continue
            }
            if first == "{", matches[lo] == hi-1 {
                let inner = (lo+1)..<(hi-1); try context.meter.retain(UInt64(inner.count) * 24); taskScratch += UInt64(inner.count) * 24; let separators = try top(inner,context:&context).filter{tokens[$0].text == ","}
                var starts = [inner.lowerBound] + separators.map{$0+1}, ends = separators + [inner.upperBound], fields: [(Int,Int)] = []
                if inner.isEmpty { starts=[]; ends=[] }
                for (start,end) in zip(starts,ends) {
                    try context.work(); guard start < end else { throw FilterCompileFailure("invalidObject",at:tokens[lo].range.lowerBound) }
                    let field = start..<end, colon = try top(field,context:&context).first(where:{tokens[$0].text == ":"})
                    let key: Int, value: Int
                    if let colon {
                        if colon == start+1, case .name(let name) = tokens[start].kind {
                            key=nodes.count;try context.charge(.astNodes);try context.meter.retain(128);nodes.append(.literal(.string(name)));ranges.append(tokens[start].range)
                        } else { key=try child(start..<colon,context:&context) }
                        value=try child((colon+1)..<end,context:&context)
                    } else if end == start+1, case .name(let name)=tokens[start].kind {
                        key=nodes.count;try context.charge(.astNodes);try context.meter.retain(128);nodes.append(.literal(.string(name)));ranges.append(tokens[start].range)
                        let identity=nodes.count;try context.charge(.astNodes);try context.meter.retain(128);nodes.append(.identity);ranges.append(tokens[start].range)
                        value=nodes.count;try context.charge(.astNodes);try context.meter.retain(128);nodes.append(.index(identity,key));ranges.append(tokens[start].range)
                    } else { throw FilterCompileFailure("invalidObjectField",at:tokens[start].range.lowerBound) }
                    try context.meter.retain(16);fields.append((key,value))
                }
                nodes[task.destination] = .object(fields);continue
            }
            if case .name(let name)=tokens[lo].kind, span.count == 1 || span.count > 2 && tokens[lo+1].text == "(" && matches[lo+1] == hi-1 {
                guard let arities = builtinArities[name] else { throw FilterCompileFailure("unsupportedFunction",at:tokens[lo].range.lowerBound) }
                var arguments: [Int] = []
                if span.count > 2 {
                    let inside=(lo+2)..<(hi-1)
                    try context.meter.retain(UInt64(inside.count) * 16); taskScratch += UInt64(inside.count) * 16
                    let semis=try top(inside,context:&context).filter{tokens[$0].text == ";"}
                    if !inside.isEmpty { for (start,end) in zip([inside.lowerBound]+semis.map{$0+1},semis+[inside.upperBound]) { arguments.append(try child(start..<end,context:&context)) } }
                }
                guard arities.contains(arguments.count) else { throw FilterCompileFailure("wrongArity",at:tokens[lo].range.lowerBound) }
                nodes[task.destination] = .call(name,arguments);continue
            }
            if span.count == 1 {
                switch tokens[lo].kind {
                case .literal(let value): nodes[task.destination] = .literal(value)
                case .variable(let name): guard task.variables.contains(name) else { throw FilterCompileFailure("unboundVariable",at:tokens[lo].range.lowerBound) };nodes[task.destination] = .variable(name)
                case .symbol("."): nodes[task.destination] = .identity
                case .symbol(".."): nodes[task.destination] = .recursive
                default: throw FilterCompileFailure("unexpectedToken",at:tokens[lo].range.lowerBound)
                }
                continue
            }
            throw FilterCompileFailure("unexpectedExpression",at:tokens[lo].range.lowerBound)
        }
        for node in nodes { try context.work(); if case .pending=node { throw FilterCompileFailure("incompleteIR",at:0) } }
        return .init(nodes:nodes,root:root,sourceRanges:ranges)
    }
}
