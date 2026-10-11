// SPDX-License-Identifier: Apache-2.0
import JSON
import ReaderProbe
func transferCursor(_ value: JSON) throws {
    _ = try probeReadWithReport(value) { cursor in
        Task.detached { try cursor["name"].requiredString() }
    }
}
