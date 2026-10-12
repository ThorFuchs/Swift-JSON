// SPDX-License-Identifier: Apache-2.0
import Foundation
import ProbeCases
@main struct Runtime {
    static func main() async throws {
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--disk-phase" {
            let phase = CommandLine.arguments[2], url = URL(fileURLWithPath: CommandLine.arguments[3])
            try await MainActor.run { try diskPhase(phase, url: url) }
            print("DISK_PHASE passed phase=" + phase + " rows=8")
            return
        }
        try publicBehavior(); print("PUBLIC_BEHAVIOR passed fixtures=8")
        try await streamAndCancellation(); print("STREAM_CANCELLATION passed")
        #if os(macOS)
        try diskPersistence(); print("DISK_PERSISTENCE passed containers=3 rows=8")
        print("MOBILE_QUALIFICATION passed cases=3")
        #else
        print("DISK_PERSISTENCE requires three separate phase processes")
        print("MOBILE_QUALIFICATION passed cases=2")
        #endif
    }
}
