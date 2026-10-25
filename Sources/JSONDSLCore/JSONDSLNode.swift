// SPDX-License-Identifier: Apache-2.0
import JSON

/// An ordered member in trusted, authored DSL staging.
///
/// Staging is not resource admission. The containing DSL finalizes the complete tree.
public struct JSONDSLMember: Sendable {
    /// The literal decoded-scalar member name; it is not a Pointer or dotted path.
    public let key: String
    /// The exact staged payload; admission occurs at finalization.
    public let value: JSONDSLNode
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init(_ key: String, _ value: JSONDSLNode) {
        self.key = key
        self.value = value
    }
}

/// A flat staging representation, without a recursive owned IR lifetime.
///
/// Factories are trusted authoring operations, outside the finalization budget.
/// They preserve literal containers, exact keys and numbers without interpretation.
public struct JSONDSLNode: Sendable {
    private enum Token: Sendable {
        case literal(JSON)
        case object, array
        case key(String)
        case endObject, endArray
    }
    private let tokens: [Token]
    private init(_ tokens: [Token]) { self.tokens = tokens }

    /// Stages an exact JSON payload without admitting it or flattening its containers.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func literal(_ value: JSON) -> Self { Self([.literal(value)]) }
    /// Combines ordered members into flat, unmetered staging; this factory does not finalize.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public static func object(_ members: [JSONDSLMember]) -> Self {
        var tokens: [Token] = [.object]
        for member in members {
            tokens.append(.key(member.key))
            tokens.append(contentsOf: member.value.tokens)
        }
        tokens.append(.endObject)
        return Self(tokens)
    }
    /// Combines ordered elements into flat, unmetered staging; literal arrays remain single values.
    ///
    /// - Parameters:
    ///   - elements: Typed siblings or array elements in their authored order.
    public static func array(_ elements: [Self]) -> Self {
        var tokens: [Token] = [.array]
        for element in elements { tokens.append(contentsOf: element.tokens) }
        tokens.append(.endArray)
        return Self(tokens)
    }

    /// Finalizes trusted staging through one finite invocation-owned ledger.
    ///
    /// This does not account for staging, caller callbacks, or process RSS.
    /// - Parameters:
    ///   - limits: Inclusive finite finalization capacities and work limits.
    /// - Throws: Exact duplicate keys, resource/configuration failure or cancellation.
    public func materialize(limits: JSONLimits = .balanced) throws -> JSON {
        try finalize(limits: limits, domain: .core) { value, _ in value }
    }

    private struct Frame {
        let object: Bool
        var members: [JSONMember] = []
        var values: [JSON] = []
        var index = JSONExactKeyIndex()
        var key: JSONKey?
    }

    /// The schema facade continues this exact ledger through document admission.
    package func finalize<Result>(
        limits: JSONLimits, domain: JSONOperationDomain,
        checkpointObserver: (@Sendable (UInt64) -> Void)? = nil,
        _ finish: (JSON, inout JSONWorkMeter) throws -> Result
    ) throws -> Result {
        var meter = try JSONWorkMeter(limits: limits, domain: domain)
        meter.checkpointObserver = checkpointObserver
        var frames: [Frame] = []
        var root: JSON?
        func requireSlot(_ frames: [Frame], meter: borrowing JSONWorkMeter) throws {
            if let parent = frames.last, !parent.object {
                try meter.require(.arrayItems, UInt64(parent.values.count) + 1)
            }
        }
        func append(_ value: JSON, frames: inout [Frame], root: inout JSON?, meter: inout JSONWorkMeter)
            throws
        {
            guard !frames.isEmpty else {
                guard root == nil else { throw JSONFailure(.configuration, code: .invalidOperation) }
                root = value
                return
            }
            let position = frames.count - 1
            if frames[position].object {
                guard let key = frames[position].key else {
                    throw JSONFailure(.configuration, code: .invalidOperation)
                }
                guard
                    try frames[position].index.insert(
                        key, position: frames[position].members.count, meter: &meter)
                else {
                    throw JSONFailure(.syntax, code: .duplicateKey)
                }
                try meter.retain(JSONLogicalWeights.member)
                frames[position].members.append(JSONMember(key, value: value))
                frames[position].key = nil
            } else {
                try meter.retain(JSONLogicalWeights.arraySlot)
                frames[position].values.append(value)
            }
        }
        for token in tokens {
            try meter.work()
            switch token {
            case .literal(let value):
                try requireSlot(frames, meter: meter)
                try JSONAdmission.value(value, meter: &meter, owned: true, depth: UInt64(frames.count))
                try append(value, frames: &frames, root: &root, meter: &meter)
            case .object, .array:
                try requireSlot(frames, meter: meter)
                try meter.require(.maxDepth, UInt64(frames.count) + 1)
                try meter.charge(.nodes)
                try meter.retain(JSONLogicalWeights.node)
                try meter.retain(JSONLogicalWeights.frame)
                if case .object = token {
                    frames.append(Frame(object: true))
                } else {
                    frames.append(Frame(object: false))
                }
            case .key(let spelling):
                guard let last = frames.last, last.object, last.key == nil else {
                    throw JSONFailure(.configuration, code: .invalidOperation)
                }
                try meter.require(.objectMembers, UInt64(last.members.count) + 1)
                try JSONAdmission.text(spelling, key: true, meter: &meter, owned: true)
                let key = try JSONKey(spelling, meter: &meter)
                guard try last.index.find(key, meter: &meter) == nil else {
                    throw JSONFailure(.syntax, code: .duplicateKey)
                }
                frames[frames.count - 1].key = key
            case .endObject, .endArray:
                guard let frame = frames.popLast(), frame.key == nil else {
                    throw JSONFailure(.configuration, code: .invalidOperation)
                }
                try meter.release(JSONLogicalWeights.frame)
                let value: JSON =
                    frame.object
                    ? .object(JSONObject(admitted: frame.members, index: frame.index)) : .array(frame.values)
                try append(value, frames: &frames, root: &root, meter: &meter)
            }
        }
        guard frames.isEmpty, let root else { throw JSONFailure(.configuration, code: .invalidOperation) }
        try meter.checkpoint()
        let result = try finish(root, &meter)
        try meter.checkpoint()
        return result
    }
}
