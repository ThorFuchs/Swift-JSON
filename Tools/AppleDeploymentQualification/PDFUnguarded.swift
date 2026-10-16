// SPDX-License-Identifier: Apache-2.0
import JSONHTML

@MainActor func prepare(_ item: JSONExportDocument) async throws {
    _ = try await item.preparingPDF()
}
