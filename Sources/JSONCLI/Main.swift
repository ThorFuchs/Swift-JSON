// SPDX-License-Identifier: Apache-2.0
import Foundation
#if canImport(Dispatch)
import Dispatch
#endif
import JSONCLIEngine
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

@main
struct SwiftJSONCommand {
    static func main() async {
        #if os(WASI)
        // WASI has cooperative owned-work cancellation, with no POSIX signal
        // source. Compilation alone does not qualify CLI host capabilities.
        let status = CLIEngine.runCommandLine()
        exit(status)
        #else
        // A broken downstream pipe is an ordinary I/O failure, never a signal crash.
        _ = signal(SIGPIPE, SIG_IGN)
        _ = signal(SIGINT, SIG_IGN)
        let invocation = Task { CLIEngine.runCommandLine() }
        let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global(qos: .userInitiated))
        let cancelInvocation: @Sendable () -> Void = { invocation.cancel() }
        interrupt.setEventHandler(handler: cancelInvocation)
        interrupt.resume()
        let status = await invocation.value
        interrupt.cancel()
        exit(status)
        #endif
    }
}
