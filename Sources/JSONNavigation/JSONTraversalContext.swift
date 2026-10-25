// SPDX-License-Identifier: Apache-2.0
import JSON

/// Package-only synchronous capability. No state/meter reference is returned.
/// An inout capability and Copyable reducer state prevent owned-capability escape.
package struct JSONTraversalContext: ~Copyable {
    private let scope: JSONReadScope
    internal init(scope: JSONReadScope) { self.scope = scope }

    private func perform<T>(at path: [JSONLocationComponent] = [],
                            _ body: (JSONCodingState) throws -> T) throws -> T {
        do { return try scope.run(path, body) }
        catch {
            let state = try scope.check()
            state.meter.recordFailure(error)
            throw error
        }
    }

    package mutating func work(_ units: UInt64 = 1) throws {
        try perform { try $0.meter.work(units) }
    }
    package mutating func retain(_ bytes: UInt64) throws {
        try perform { try $0.meter.retain(bytes) }
    }
    package mutating func release(_ bytes: UInt64) throws {
        try perform { try $0.meter.release(bytes) }
    }
    package mutating func checkpoint() throws { _ = try scope.check() }
    package mutating func recordFailure(_ error: any Error) throws {
        let state = try scope.check() // original terminal health takes precedence
        state.meter.recordFailure(error)
    }
    package mutating func equalKeys(_ lhs: JSONKey, _ rhs: JSONKey) throws -> Bool {
        try perform { try JSONComparison.textEquals(lhs.string, rhs.string, meter: &$0.meter) }
    }
    /// Compare only original positions in one already-admitted physical array.
    /// Selection, comparison scratch and terminal health use the owning ledger;
    /// neither the source values nor the mutable scope/meter escape this delegate.
    package mutating func equalArrayElements(at path: [JSONLocationComponent], lhs: Int, rhs: Int) throws -> Bool {
        try perform(at: path) { state in
            try state.meter.work()
            guard case .array(let array) = try scope.select(path, state: state) else {
                throw JSONFailure(.typeMismatch, code: .wrongKind)
            }
            guard lhs >= 0, rhs >= 0 else { throw JSONFailure(.configuration, code: .invalidIndex) }
            guard lhs < array.count, rhs < array.count else { throw JSONFailure(.missingValue, code: .missingTarget) }
            try state.meter.work(2)
            return try JSONComparison.equals(array[lhs], array[rhs], meter: &state.meter)
        }
    }
    /// Scalar-exact comparison charged to the original admitted scope.
    package mutating func equalStrings(_ lhs: String, _ rhs: String) throws -> Bool {
        try perform { try JSONComparison.textEquals(lhs, rhs, meter: &$0.meter) }
    }
    /// Direct-member string selection. Nil kind means absent; null and other
    /// kinds remain distinguishable. A returned string owns 32+UTF8 logical bytes.
    /// No JSONKey hashing, second admission, cursor or ledger is created.
    package mutating func directStringMember(_ value: JSON, key: JSONKey,
                                             at path: [JSONLocationComponent]) throws
        -> (text: String?, kind: JSONTraversalKind?) {
        try perform(at: path) { state in
            try JSONAdmission.text(key.string, key: true, meter: &state.meter)
            try state.meter.work()
            guard case .object(let object) = value else { throw JSONFailure(.typeMismatch, code: .wrongKind) }
            guard let member = try object.lookup(key.string, meter: &state.meter) else { return (nil, nil) }
            guard case .string(let text) = member else { return (nil, JSONTraversalKind(member)) }
            try state.meter.retain(32)
            for _ in text.utf8 { try state.meter.work(); try state.meter.retain(1) }
            return (text, .string)
        }
    }
    /// Relinquish a directStringMember alias after its last owned use.
    package mutating func releaseStringAlias(_ text: String) throws {
        try perform { state in
            for _ in text.utf8 { try state.meter.work(); try state.meter.release(1) }
            try state.meter.release(32)
        }
    }
    package mutating func arrayCount(_ value: JSON, at path: [JSONLocationComponent]) throws -> Int {
        try perform(at: path) { state in
            try state.meter.work()
            guard case .array(let array) = value else { throw JSONFailure(.typeMismatch, code: .wrongKind) }
            return array.count
        }
    }
    /// Ephemeral canonical member in the owned reducer. The requested key was admitted
    /// by preparation; any retained string/output alias needs its own reservation.
    package mutating func member(_ value: JSON, key: JSONKey,
                                  at path: [JSONLocationComponent]) throws -> JSON? {
        try perform(at: path) { state in
            try state.meter.work()
            guard case .object(let object) = value else { throw JSONFailure(.typeMismatch, code: .wrongKind) }
            return try object.lookup(key.string, meter: &state.meter)
        }
    }

    /// Reserve an additional owned alias, not another text admission or key model.
    package mutating func retainKey(_ key: JSONKey, admittingCallerInput: Bool = false) throws {
        try perform { state in
            if admittingCallerInput { try JSONAdmission.text(key.string, key: true, meter: &state.meter) }
            for _ in key.string.utf8 { try state.meter.work(); try state.meter.retain(1) }
        }
    }
    package mutating func retainLocation(_ path: [JSONLocationComponent]) throws -> [JSONLocationComponent] {
        try perform(at: path) { state in
            for part in path {
                try state.meter.work(); try state.meter.retain(JSONLogicalWeights.indexSlot)
                if case .key(let key) = part {
                    for _ in key.string.utf8 { try state.meter.work(); try state.meter.retain(1) }
                }
            }
            return path
        }
    }
    package mutating func appending(_ part: JSONLocationComponent, to path: [JSONLocationComponent]) throws -> [JSONLocationComponent] {
        let handle = try perform(at: path) { state in
            try scope.append(part, to: path, state: state)
        }
        return try retainLocation(handle.components)
    }
    package mutating func sourceSpan(at path: [JSONLocationComponent]) throws -> JSONSourceSpan? {
        try perform(at: path) { state in
            try scope.document?.sourceMap?.span(at: path, kind: .value, meter: &state.meter)
        }
    }
    /// Transfer already-admitted input ownership, without exposing its scope.
    package mutating func transferDocumentOwnership() throws -> JSONDocument {
        try perform { _ in try scope.transferDocumentOwnership() }
    }
}
