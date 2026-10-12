// SPDX-License-Identifier: Apache-2.0
import JSON
func forbidden(_ cursor: JSONReadCursor) {
    let closure: @Sendable () throws -> JSON = { try cursor.requiredValue() }
    _ = closure
}
