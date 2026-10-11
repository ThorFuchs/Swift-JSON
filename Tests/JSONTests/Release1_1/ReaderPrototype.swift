// SPDX-License-Identifier: Apache-2.0
// Qualification prototype, compiled into tests or ReaderProbe, never into JSON.
@testable import JSON

public struct ProbeAccessFailure: Error, Sendable {
    public let cause: JSONFailure
    public let path: [JSONLocationComponent]
}

// Deliberately not Sendable: the synchronous invocation owns mutable state.
final class ProbeReadScope {
    var document: JSONDocument?
    var state: JSONCodingState?
    private var terminal: (any Error)?

    init(_ document: JSONDocument, limits: JSONLimits) throws {
        let state = JSONCodingState(options: .init(limits: limits),
                                    meter: try JSONWorkMeter(limits: limits, domain: .core))
        try JSONAdmission.value(document.root, meter: &state.meter, owned: true)
        self.document = document
        self.state = state
    }

    func invalidate() { document = nil; state = nil }

    func check() throws -> JSONCodingState {
        if let terminal { throw terminal }
        guard document != nil, let state else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        try state.check()
        return state
    }

    func run<T>(_ path: [JSONLocationComponent], _ body: (JSONCodingState) throws -> T) throws -> T {
        do { return try body(check()) }
        catch {
            if error is CancellationError || (error as? JSONFailure)?.category == .resource {
                if terminal == nil { terminal = error }
                throw error
            }
            if let failure = error as? JSONFailure,
               failure.category != .configuration || failure.code == .invalidIndex {
                throw ProbeAccessFailure(cause: failure, path: path)
            }
            throw error
        }
    }

    func select(_ path: [JSONLocationComponent], state: JSONCodingState) throws -> JSON {
        guard let document else { throw JSONFailure(.configuration, code: .invalidOperation) }
        var value = document.root
        for part in path {
            try state.meter.work()
            switch part {
            case .key(let key):
                guard case .object(let object) = value else { throw JSONFailure(.typeMismatch, code: .wrongKind) }
                guard let child = try object.lookup(key.string, meter: &state.meter) else {
                    throw JSONFailure(.missingValue, code: .missingMember)
                }
                value = child
            case .index(let index):
                guard case .array(let array) = value else { throw JSONFailure(.typeMismatch, code: .wrongKind) }
                guard index >= 0 else { throw JSONFailure(.configuration, code: .invalidIndex) }
                guard index < array.count else { throw JSONFailure(.missingValue, code: .missingTarget) }
                value = array[index]
            }
        }
        return value
    }

    func append(_ part: JSONLocationComponent, to path: [JSONLocationComponent], state: JSONCodingState) throws -> [JSONLocationComponent] {
        try state.meter.require(.pointerTokens, UInt64(path.count) + 1)
        var bytes: UInt64 = 0
        // Charge equivalent Pointer text, complete typed path copies and owned slots.
        for position in 0...path.count {
            let component = position == path.count ? part : path[position]
            bytes = try state.meter.adding(.pointerBytes, bytes, 1)
            let text: String
            switch component {
            case .key(let key): text = key.string
            case .index(let index): text = String(index)
            }
            try state.meter.work(); try state.meter.retain(JSONLogicalWeights.indexSlot)
            for byte in text.utf8 {
                try state.meter.work()
                bytes = try state.meter.adding(.pointerBytes, bytes, byte == 47 || byte == 126 ? 2 : 1)
                try state.meter.retain(1)
            }
        }
        try state.meter.require(.diagnosticBytes, bytes)
        var result: [JSONLocationComponent] = []
        for component in path { try state.meter.work(); result.append(component) }
        result.append(part)
        return result
    }
}

/// Experimental shape only. Handles own typed paths, never selected DOM payloads.
public struct ProbeReadCursor {
    let scope: ProbeReadScope
    let path: [JSONLocationComponent]

    public subscript(_ key: String) -> Self {
        get throws {
            try scope.run(path) { state in
                try JSONAdmission.text(key, key: true, meter: &state.meter)
                return try child(.key(JSONKey(key, meter: &state.meter)), state: state)
            }
        }
    }
    public subscript(_ key: JSONKey) -> Self {
        get throws {
            try scope.run(path) { state in
                try JSONAdmission.text(key.string, key: true, meter: &state.meter)
                return try child(.key(key), state: state)
            }
        }
    }
    public subscript(_ index: Int) -> Self {
        get throws { try scope.run(path) { try child(.index(index), state: $0) } }
    }
    private func child(_ part: JSONLocationComponent, state: JSONCodingState) throws -> Self {
        let attempted = try scope.append(part, to: path, state: state)
        // Failure includes the attempted hop. No cursor stores the selected value.
        return try scope.run(attempted) { state in
            _ = try scope.select(attempted, state: state)
            return Self(scope: scope, path: attempted)
        }
    }
    public func requiredString() throws -> String {
        try scope.run(path) { state in
            guard case .string(let text) = try scope.select(path, state: state) else {
                throw JSONFailure(.typeMismatch, code: .wrongKind)
            }
            try JSONAdmission.text(text, meter: &state.meter, owned: true)
            return text
        }
    }
    public func requiredInteger<T: FixedWidthInteger>(as type: T.Type) throws -> T {
        try scope.run(path) { state in
            guard case .number(let number) = try scope.select(path, state: state) else {
                throw JSONFailure(.typeMismatch, code: .wrongKind)
            }
            return try number.integer(as: type, meter: &state.meter)
        }
    }
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try scope.run(path) { state in
            let value = try scope.select(path, state: state)
            return try JSONNativeDecoder(value: value, state: state, codingPath: []).decode(type)
        }
    }
}

public func probeReadWithReport<Result>(_ value: JSON, limits: JSONLimits = .balanced,
                                       _ body: (ProbeReadCursor) throws -> Result) throws -> JSONOperationReport<Result> {
    let scope = try ProbeReadScope(JSONDocument(root: value), limits: limits)
    defer { scope.invalidate() }
    let result = try body(ProbeReadCursor(scope: scope, path: []))
    // Catching a resource or cancellation failure inside body cannot certify success.
    return try scope.run([]) { state in
        .init(result: result, statistics: state.meter.statistics())
    }
}
