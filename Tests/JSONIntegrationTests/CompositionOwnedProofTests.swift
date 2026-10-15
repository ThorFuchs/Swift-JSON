// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONSchema

// Native-only rendezvous is supplementary to the unrelated public package. It
// uses the existing invocation-owned observer; it is not an accounting oracle.
@Test func jcompOwnedCancellationOccursInsideNativeWork() async throws {
    for stage in 0..<7 {
        let seen = Mutex<UInt64?>(nil)
        let task = Task.detached {
            var limits = JSONLimits.offline; limits[.cancellationQuantum] = 1
            let threshold: UInt64 = stage == 1 ? 4200 : stage == 4 ? 6 : 32
            return try JSON.withComposition(limits: limits) { scope in
                try scope.withMeter { meter in
                    meter.checkpointObserver = { work in
                        if work >= threshold {
                            seen.withLock { if $0 == nil { $0 = work } }
                            withUnsafeCurrentTask { $0?.cancel() }
                        }
                    }
                }
                do {
                    switch stage {
                    case 0, 1:
                        _ = try scope.parseDocument(Data(("\"" + String(repeating: "a", count: 4096) + "\"").utf8))
                    case 2: _ = try scope.pointer(parsing: "/" + String(repeating: "a", count: 4096))
                    case 3: _ = try scope.uri("https://example.invalid/" + String(repeating: "a", count: 4096))
                    case 4: try scope.chargeExternalWork(5) // Cancellation must occur in report copying.
                    case 5:
                        for _ in 0..<128 { try scope.chargeExternalWork(1) }
                    default:
                        let path = try scope.pointer(tokens: [])
                        _ = try scope.resolve(path, in: .array(Array(repeating: .null, count: 256)))
                    }
                } catch is CancellationError { }
                return 1
            }
        }
        do { _ = try await task.value; Issue.record("caught cancellation completed at stage \(stage)") }
        catch is CancellationError { }
        #expect(seen.withLock { $0 != nil })
        if stage == 1 { #expect(seen.withLock { ($0 ?? 0) > 4098 }) }
    }
}

@Test func jcompOriginalHealthAndIdentitySurvivePackageSubstitution() throws {
    for stage in 0..<3 {
        do {
            _ = try JSON.withComposition { scope in
                try scope.withMeter { meter in
                    if stage == 1 {
                        do { try meter.work(UInt64.max) } catch { }
                    } else if stage == 2 {
                        do { try meter.retain(UInt64.max) } catch { }
                    }
                    // Impossible through public API; exercise the original
                    // continuation's identity and first-cause check directly.
                    meter = try JSONWorkMeter(limits: .balanced, domain: .core)
                }
                return 1
            }
            Issue.record("substituted native ledger completed")
        } catch let failure as JSONFailure {
            if stage == 0 { #expect(failure.category == .configuration && failure.code == .invalidOperation) }
            if stage == 1 { #expect(failure.resource?.metric == .workUnits) }
            if stage == 2 { #expect(failure.resource?.metric == .retainedBytes) }
        }
    }
}
