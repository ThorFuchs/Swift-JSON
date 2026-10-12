// SPDX-License-Identifier: Apache-2.0
import JSON
func forbidden(_ cursor: JSONReadCursor) {
    Task.detached { try cursor.requiredValue() }
    _ = try? cursor.requiredValue()
}
