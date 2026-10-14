// SPDX-License-Identifier: Apache-2.0
import Foundation
import Dispatch
import JSONCLIEngine
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main
struct SwiftJSONCommand {
    static func main() async {
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
    }
}
