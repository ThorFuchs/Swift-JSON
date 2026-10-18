// SPDX-License-Identifier: Apache-2.0
import JSONFilterRuntime

// Process exit policy belongs to the CLI host, never the transformation library.
extension CLIError {
    package var exit: Int32 {
        switch category {
        case .usage: 2
        case .compile: 3
        case .language, .input: 5
        case .resource: 6
        case .io: 7
        case .cancelled: 130
        }
    }
}
