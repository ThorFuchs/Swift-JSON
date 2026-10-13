// SPDX-License-Identifier: Apache-2.0
import Testing
import WasmAuditKit

@Test func observedProfilesAndPersistenceBoundary() throws { try Probes.profiles(); try Probes.payloadObservation() }
@Test func exactNumbers() throws { try Probes.exactNumbers() }
@Test func scalarIdentityAndOrder() throws { try Probes.scalarKeysAndOrder() }
@Test func strictCodecAndPointer() throws { try Probes.strictCodecAndPointer() }
@Test func nativeCodingAndGuardedScope() throws { try Probes.codingAndScope() }
@Test func cumulativeBudgets() throws { try Probes.cumulativeBudgets() }
@Test func bothPatchStandards() throws { try Probes.patches() }
@Test func ninePinnedSchemaResources() throws { try Probes.resourceRegistry() }
@Test func schemaRegexAndOperationalErrors() throws { try Probes.schemaAndRegex() }
@Test func sharedPlanInvocationIsolation() async throws { try await Probes.sharedPlan() }
@Test func streamCompletionAndStrictNDJSON() async throws { try await Probes.streams() }
@Test func awaitedSink() async throws { try await Probes.awaitedSink() }
@Test func terminalCancellation() async throws { try await Probes.cancellation() }
