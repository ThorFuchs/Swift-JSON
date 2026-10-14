// SPDX-License-Identifier: Apache-2.0
import JSON

/// An invocation-only root identity. Path expressions cannot borrow an address
/// from another input/root or turn a computed value into an assignable location.
package final class FilterLocationRoot {
    private let lease:CLIValueLease
    package init(context:inout CLIJobContext)throws{
        try context.meter.retain(32)
        do{lease=try CLIValueLease(ownedRetained:32,context:&context)}catch{try context.meter.release(32);throw error}
    }
}
package struct FilterLocation {
    package let root:FilterLocationRoot
    package let segments:[JSON]
    private let lease:CLIValueLease?
    package init(root:FilterLocationRoot){self.root=root;segments=[];lease=nil}
    private init(root:FilterLocationRoot,segments:[JSON],lease:CLIValueLease?){self.root=root;self.segments=segments;self.lease=lease}
    package func appending(_ segment:JSON,context:inout CLIJobContext)throws->Self{
        switch segment{case .string:break;case .number(let n):guard n.isInteger else{throw FilterLanguageFailure("invalidPathSegment")};default:throw FilterLanguageFailure("invalidPathSegment")}
        let count=UInt64(segments.count)+1,bytes=count*16
        try context.meter.require(.arrayItems,count);try context.meter.retain(bytes)
        defer{try? context.meter.release(bytes)}
        try context.work(count);var values=segments;values.append(segment)
        let value=try FilterValues.array(values,context:&context)
        return .init(root:root,segments:values,lease:value.lease)
    }
}
