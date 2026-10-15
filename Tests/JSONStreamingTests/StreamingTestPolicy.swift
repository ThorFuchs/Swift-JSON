// SPDX-License-Identifier: Apache-2.0
import Testing

enum StreamingTestPolicy {
    static var deadline: any TestTrait {
        #if os(WASI)
        // The pinned SDK's time-limit timer blocks its cooperative executor,
        // even for an immediately returning async body (see Portability.md).
        // WASI runs these identical cases under an interruptible 120-second
        // host process-group watchdog instead. This trait skips no test.
        return Tag.List.tags()
        #else
        return TimeLimitTrait.timeLimit(.minutes(1))
        #endif
    }
}
