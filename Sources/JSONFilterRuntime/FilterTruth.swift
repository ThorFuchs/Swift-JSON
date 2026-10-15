// SPDX-License-Identifier: Apache-2.0
import JSON
package enum FilterTruth {
    package static func test(_ value: JSON) -> Bool {
        switch value { case .null, .boolean(false): false; default: true }
    }
}
