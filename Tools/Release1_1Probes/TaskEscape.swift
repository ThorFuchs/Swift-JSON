// SPDX-License-Identifier: Apache-2.0
import JSON
import ReaderProbe
func illegalEscape(_ value: JSON) throws {
    _ = try probeReadWithReport(value) { cursor in
        let work: @Sendable () throws -> String = { try cursor["name"].requiredString() }
        return work
    }
}
