// SPDX-License-Identifier: Apache-2.0
/// Stable fields only; creating a diagnostic never walks the rejected input.
public struct JSONDiagnostic: Sendable, Equatable {
    public enum Kind: String, Sendable { case failure, cancellation, callerError }
    public let kind: Kind
    public let failure: JSONFailure?
    public init(_ error: any Error) {
        if let error = error as? JSONFailure { kind = .failure; failure = error }
        else if error is CancellationError { kind = .cancellation; failure = nil }
        else { kind = .callerError; failure = nil }
    }
}
