// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@Test func diagnosticNeverRetainsCallerErrorDescription() {
    struct CallerError: Error { let text: String }
    let diagnostic = JSONDiagnostic(CallerError(text: String(repeating: "private", count: 1000)))
    #expect(diagnostic.kind == .callerError && diagnostic.failure == nil)
    #expect(JSONDiagnostic(CancellationError()).kind == .cancellation)
    #expect(JSONDiagnostic(JSONFailure(.syntax, code: .unexpectedEOF)).kind == .failure)
}
