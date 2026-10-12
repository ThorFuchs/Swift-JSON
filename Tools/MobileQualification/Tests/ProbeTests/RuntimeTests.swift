// SPDX-License-Identifier: Apache-2.0
import Testing
import ProbeCases
@Test func publicProductsAndPayloadFixtures() throws { try publicBehavior() }
@Test func awaitedStreamsAndCancellation() async throws { try await streamAndCancellation() }
@Test @MainActor func swiftDataDiskTeardownReopenAndUpdate() throws { try diskPersistence() }
