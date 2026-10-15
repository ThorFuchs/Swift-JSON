// SPDX-License-Identifier: Apache-2.0
import JSON

/// Invocation-only ARC notifications. The job drains refunds before its next
/// checkpoint; destructors cannot replace a meter or reopen terminal health.
package final class CLILeaseRefunds {
    package var retained: UInt64 = 0
    package var collections: UInt64 = 0
    package var failure: (any Error)?
    package func enqueue(retained bytes: UInt64, collections values: UInt64) {
        let (nextBytes, byteOverflow) = retained.addingReportingOverflow(bytes)
        let (nextValues, valueOverflow) = collections.addingReportingOverflow(values)
        if byteOverflow || valueOverflow {
            failure = CLIError(.resource, "counterOverflow", metric: "valueLeaseRefund")
        } else { retained = nextBytes; collections = nextValues }
    }
}
/// A lease holds reservations for one admitted immutable value graph. Selectors
/// share its lifetime; newly constructed graphs undergo full owned admission. It is deliberately not Sendable; only plans are shared.
package final class CLIValueLease {
    private let refunds: CLILeaseRefunds
    package let retained: UInt64
    private let collections: UInt64
    package init(ownedRetained: UInt64, collections: UInt64 = 0,
                 context: inout CLIJobContext) throws {
        try context.checkpoint()
        let metadata = UInt64(48)
        try context.meter.retain(metadata)
        refunds = context.leaseRefunds
        retained = ownedRetained + metadata
        self.collections = collections
    }
    deinit { refunds.enqueue(retained: retained, collections: collections) }
}
/// Immutable JSON payload plus an invocation-owned lifetime. Copies share the same
/// reservation rather than refunding a source still borrowed by another result.
package struct FilterYield {
    package var value: JSON
    package var lease: CLIValueLease?
    package var collectedValues: UInt64
    package init(value: JSON, lease: CLIValueLease? = nil, collectedValues: UInt64 = 0) { self.value = value; self.lease = lease; self.collectedValues = collectedValues }
    package func selecting(_ value: JSON) -> Self {
        let retainedCollections: UInt64
        switch value { case .array, .object: retainedCollections = collectedValues; default: retainedCollections = 0 }
        return .init(value: value, lease: lease, collectedValues: retainedCollections)
    }
    package mutating func release(context: inout CLIJobContext) throws {
        value = .null; lease = nil; collectedValues = 0
        try context.reclaimValueLeases()
    }
}
