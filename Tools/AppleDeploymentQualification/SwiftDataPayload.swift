// SPDX-License-Identifier: Apache-2.0
import JSON
import SwiftData

@Model final class DeploymentSnapshot {
    @Attribute(.codable) var payload: JSONCodablePayload
    init(payload: JSONCodablePayload) { self.payload = payload }
}
