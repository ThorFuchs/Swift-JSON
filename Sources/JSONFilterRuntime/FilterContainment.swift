// SPDX-License-Identifier: Apache-2.0
import JSON

/// Recursive containment uses explicit bounded frames and exact scalar matching.
package enum FilterContainment {
    private struct Frame { let left:JSON;let right:JSON;var outer=0;var candidate=0;var waiting=false;var incoming:Bool? }
    package static func contains(_ left:JSON,_ right:JSON,context:inout TransformRuntimeContext)throws->Bool {
        func kind(_ value:JSON)->Int{switch value{case .null:0;case .boolean:1;case .number:2;case .string:3;case .array:4;case .object:5}}
        guard kind(left)==kind(right) else{throw FilterLanguageFailure("containsTypeMismatch")}
        try context.checkpoint();let entry=context.meter.used(.retainedBytes)
        defer{try? context.meter.release(context.meter.used(.retainedBytes)-entry)}
        var stack:[Frame]=[]
        func push(_ left:JSON,_ right:JSON,context:inout TransformRuntimeContext)throws {
            try context.require(.runtimeFrames,context.used(.runtimeFrames)+UInt64(stack.count)+1)
            try context.meter.retain(64);stack.append(.init(left:left,right:right))
        }
        try push(left,right,context:&context)
        while var frame=stack.popLast(){
            try context.meter.release(64);try context.work()
            var completed:Bool?
            switch (frame.left,frame.right){
            case (.array(let a),.array(let b)):
                if let incoming=frame.incoming{frame.incoming=nil;frame.waiting=false;if incoming{frame.outer += 1;frame.candidate=0}else{frame.candidate += 1}}
                if frame.outer==b.count{completed=true}
                else if frame.candidate==a.count{completed=false}
                else{
                    let candidate=a[frame.candidate],target=b[frame.outer]
                    try context.meter.retain(64);stack.append(frame);try push(candidate,target,context:&context);continue
                }
            case (.object(let a),.object(let b)):
                if let incoming=frame.incoming{frame.incoming=nil;if !incoming{completed=false}else{frame.outer += 1}}
                if completed==nil {
                    if frame.outer==b.count{completed=true}
                    else{
                        let member=b.members[frame.outer]
                        if let value=try a.lookup(member.key.string,meter:&context.meter){try context.meter.retain(64);stack.append(frame);try push(value,member.value,context:&context);continue}
                        completed=false
                    }
                }
            case (.string(let a),.string(let b)):
                if b.isEmpty{completed=true}
                else{
                    var source:[UInt32]=[],pattern:[UInt32]=[]
                    let scratch=context.meter.used(.retainedBytes)
                    defer{try? context.meter.release(context.meter.used(.retainedBytes)-scratch)}
                    for scalar in a.unicodeScalars{try context.work();try context.meter.retain(4);source.append(scalar.value)}
                    for scalar in b.unicodeScalars{try context.work();try context.meter.retain(4);pattern.append(scalar.value)}
                    var found=false
                    if pattern.count<=source.count{for position in 0...(source.count-pattern.count){try context.work();var matches=true;for offset in pattern.indices{try context.work();if source[position+offset] != pattern[offset]{matches=false;break}};if matches{found=true;break}}}
                    completed=found
                }
            default:
                completed=kind(frame.left)==kind(frame.right) ? try FilterValues.equals(frame.left,frame.right,context:&context):false
            }
            guard let result=completed else{throw TransformRuntimeFailure(.resource,"containmentInvariant")}
            if stack.isEmpty{return result}
            stack[stack.count-1].incoming=result
        }
        throw TransformRuntimeFailure(.resource,"containmentInvariant")
    }
}
