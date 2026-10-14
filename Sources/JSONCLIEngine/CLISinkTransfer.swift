// SPDX-License-Identifier: Apache-2.0
import JSONFilterRuntime

/// One synchronous, invocation-owned handoff at a time. Foreign callback work
/// is outside owned instruction accounting; all retries/progress are charged.
package enum CLISinkTransfer {
    package static func writeAll(count: Int, context: inout CLIJobContext,
                                 write: (Range<Int>, inout CLIJobContext) throws -> Int?) throws {
        var offset = 0
        do {
            while offset < count {
                try context.work()
                let range = offset..<min(count, offset + min(16384, count - offset))
                guard let accepted = try write(range, &context) else { continue }
                guard accepted > 0 else { throw CLIError(.io, "noProgress") }
                guard accepted <= range.count else { throw CLIError(.io, "invalidSinkProgress") }
                offset += accepted // accepted <= remaining, so the sum cannot overflow.
            }
            try context.checkpoint()
        } catch {
            context.latch(error)
            throw error
        }
    }
}
