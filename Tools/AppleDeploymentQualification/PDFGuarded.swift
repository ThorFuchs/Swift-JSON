// SPDX-License-Identifier: Apache-2.0
import JSONHTML

@MainActor func prepare(_ item: JSONExportDocument) async throws {
    if #available(macOS 26.0, iOS 26.0, *) {
        _ = try await item.preparingPDF()
    }
}
