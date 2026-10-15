// SPDX-License-Identifier: Apache-2.0
import JSON

package struct FilterBindingPattern:Sendable {
    package struct Binding:Sendable{let name:String;let path:[JSON]}
    package struct Shape:Sendable{let object:Bool;let path:[JSON]}
    package let bindings:[Binding]
    package let shapes:[Shape]
    package static func compile(_ range:Range<Int>,tokens:[FilterToken],matches:[Int:Int],context:inout CLIJobContext)throws->Self{
        struct Work{let range:Range<Int>;let path:[JSON]}
        var work:[Work]=[],bindings:[Binding]=[],shapes:[Shape]=[]
        try context.meter.retain(40);work.append(.init(range:range,path:[]))
        func top(_ range:Range<Int>,context:inout CLIJobContext)throws->[Int]{
            var result:[Int]=[],i=range.lowerBound
            while i<range.upperBound{try context.work();try context.meter.retain(8);result.append(i);if let close=matches[i],close>i{i=close+1}else{i += 1}}
            return result
        }
        while let item=work.popLast(){
            try context.meter.release(40);try context.work();let span=item.range
            guard !span.isEmpty else{throw FilterCompileFailure("invalidBindingPattern",at:0)}
            let first=tokens[span.lowerBound]
            if span.count==1,case .variable(let name)=first.kind{
                guard !bindings.contains(where:{$0.name==name}) else{throw FilterCompileFailure("duplicatePatternBinding",at:first.range.lowerBound)}
                try context.meter.retain(40+UInt64(name.utf8.count));bindings.append(.init(name:name,path:item.path));continue
            }
            let object=first.text=="{",array=first.text=="["
            guard object || array,matches[span.lowerBound]==span.upperBound-1 else{throw FilterCompileFailure("invalidBindingPattern",at:first.range.lowerBound)}
            try context.meter.retain(32);shapes.append(.init(object:object,path:item.path))
            let inside=(span.lowerBound+1)..<(span.upperBound-1),positions=try top(inside,context:&context)
            defer{try? context.meter.release(UInt64(positions.count)*8)}
            let commas=positions.filter{tokens[$0].text==","}
            if inside.isEmpty{continue}
            let ranges=zip([inside.lowerBound]+commas.map{$0+1},commas+[inside.upperBound])
            var index=0
            for (start,end) in ranges{
                let field=start..<end,segment:JSON,nested:Range<Int>
                if object{
                    let fieldPositions=try top(field,context:&context)
                    defer{try? context.meter.release(UInt64(fieldPositions.count)*8)}
                    guard let colon=fieldPositions.first(where:{tokens[$0].text==":"}),colon==start+1 else{throw FilterCompileFailure("invalidObjectPattern",at:tokens[start].range.lowerBound)}
                    let key:String
                    switch tokens[start].kind{case .name(let name),.literal(.string(let name)):key=name;default:throw FilterCompileFailure("invalidObjectPatternKey",at:tokens[start].range.lowerBound)}
                    segment = .string(key);nested=(colon+1)..<end
                }else{segment = .number(JSONNumber(integer:index));nested=field}
                try context.meter.retain(UInt64(item.path.count+1)*16+40);try context.work(UInt64(item.path.count)+1)
                var path=item.path;path.append(segment);work.append(.init(range:nested,path:path));index += 1
            }
        }
        return .init(bindings:bindings,shapes:shapes)
    }
}
