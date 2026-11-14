// SPDX-License-Identifier: Apache-2.0
// Original bounded structural difference shared by JSONPatch and JSONHTML.

/// One step of a merged walk over two values, in display order.
///
/// A value event (`same`, `added`, `removed`, `replaced`, `beginObject`,
/// `beginArray`) follows a `member` or `element` event, except at the root.
package enum JSONDifferenceEvent: Sendable {
    /// The value is equal on both sides (exact model equality).
    case same(JSON)
    /// The value exists only in the target.
    case added(JSON)
    /// The value exists only in the source.
    case removed(JSON)
    /// Different kinds or unequal scalars: the source value is replaced.
    case replaced(source: JSON, target: JSON)
    /// Both sides are unequal objects; member events follow until `endObject`.
    case beginObject
    case endObject
    /// Both sides are unequal arrays; element events follow until `endArray`.
    case beginArray
    case endArray
    /// The next value event belongs to this object member.
    case member(JSONKey)
    /// The next value event belongs to this element; the position is nil on the side that lacks it.
    case element(source: Int?, target: Int?)
    /// A run of equal array elements, kept as one event.
    case sameElements(ArraySlice<JSON>, sourceStart: Int, targetStart: Int)
}

/// A neutral RFC 6902 operation produced from the shared difference.
package struct JSONDifferenceOperation: Sendable {
    package enum Kind: Sendable { case add, remove, replace }
    package let kind: Kind
    package let path: [JSONKey]
    package let value: JSON?
}

/// Walks two admitted values and yields ``JSONDifferenceEvent``s on the caller's meter.
///
/// Objects list source members in source order (compared or removed), then target-only
/// members in target order. Arrays keep the longest equal prefix and suffix, compare
/// the remaining elements by position, then list surplus source elements (removed)
/// and surplus target elements (added) in ascending order.
package struct JSONDifferenceWalker {
    private enum Frame {
        case compare(JSON, JSON)
        case object(JSONObject, JSONObject, phase: Int, index: Int)
        case array([JSON], [JSON], prefix: Int, suffix: Int, step: Int)
    }
    private var frames: [Frame]
    private var queued: [JSONDifferenceEvent] = []
    private var started = false

    package init(source: JSON, target: JSON) { frames = [.compare(source, target)] }

    package mutating func next(meter: inout JSONWorkMeter) throws -> JSONDifferenceEvent? {
        if !started { try meter.retain(JSONLogicalWeights.frame); started = true }
        while true {
            try meter.work()
            if !queued.isEmpty { return queued.removeFirst() }
            guard let frame = frames.popLast() else { return nil }
            try meter.release(JSONLogicalWeights.frame)
            switch frame {
            case .compare(let a, let b):
                if try JSONComparison.equals(a, b, meter: &meter) { return .same(b) }
                switch (a, b) {
                case (.object(let x), .object(let y)):
                    try push(.object(x, y, phase: 0, index: 0), meter: &meter); return .beginObject
                case (.array(let x), .array(let y)):
                    let shared = min(x.count, y.count)
                    var prefix = 0
                    while prefix < shared, try JSONComparison.equals(x[prefix], y[prefix], meter: &meter) { prefix += 1 }
                    var suffix = 0
                    while suffix < shared - prefix,
                          try JSONComparison.equals(x[x.count - 1 - suffix], y[y.count - 1 - suffix], meter: &meter) { suffix += 1 }
                    try push(.array(x, y, prefix: prefix, suffix: suffix, step: 0), meter: &meter); return .beginArray
                default:
                    return .replaced(source: a, target: b)
                }
            case .object(let a, let b, let phase, let index):
                if phase == 0, index < a.count {
                    let member = a[index]
                    try push(.object(a, b, phase: 0, index: index + 1), meter: &meter)
                    if let counterpart = try b.lookup(member.key.string, meter: &meter) {
                        try push(.compare(member.value, counterpart), meter: &meter)
                    } else {
                        queued.append(.removed(member.value))
                    }
                    return .member(member.key)
                }
                var position = phase == 0 ? 0 : index
                while position < b.count {
                    try meter.work()
                    let member = b[position]; position += 1
                    if try a.lookup(member.key.string, meter: &meter) == nil {
                        try push(.object(a, b, phase: 1, index: position), meter: &meter)
                        queued.append(.added(member.value))
                        return .member(member.key)
                    }
                }
                return .endObject
            case .array(let a, let b, let prefix, let suffix, let step):
                let middleA = a.count - prefix - suffix, middleB = b.count - prefix - suffix
                let paired = min(middleA, middleB)
                // Steps: 0 prefix run, then pairs, removals, additions, suffix run, end.
                var next = step
                if next == 0 {
                    next = 1
                    if prefix > 0 {
                        try push(.array(a, b, prefix: prefix, suffix: suffix, step: next), meter: &meter)
                        return .sameElements(b[0..<prefix], sourceStart: 0, targetStart: 0)
                    }
                }
                let pairedEnd = 1 + paired, removedEnd = pairedEnd + middleA - paired, addedEnd = removedEnd + middleB - paired
                if next < pairedEnd {
                    let position = prefix + next - 1
                    try push(.array(a, b, prefix: prefix, suffix: suffix, step: next + 1), meter: &meter)
                    try push(.compare(a[position], b[position]), meter: &meter)
                    return .element(source: position, target: position)
                }
                if next < removedEnd {
                    let position = prefix + paired + (next - pairedEnd)
                    try push(.array(a, b, prefix: prefix, suffix: suffix, step: next + 1), meter: &meter)
                    queued.append(.removed(a[position]))
                    return .element(source: position, target: nil)
                }
                if next < addedEnd {
                    let position = prefix + paired + (next - removedEnd)
                    try push(.array(a, b, prefix: prefix, suffix: suffix, step: next + 1), meter: &meter)
                    queued.append(.added(b[position]))
                    return .element(source: nil, target: position)
                }
                if next == addedEnd, suffix > 0 {
                    try push(.array(a, b, prefix: prefix, suffix: suffix, step: next + 1), meter: &meter)
                    return .sameElements(b[(b.count - suffix)...], sourceStart: a.count - suffix, targetStart: b.count - suffix)
                }
                return .endArray
            }
        }
    }
    private mutating func push(_ frame: Frame, meter: inout JSONWorkMeter) throws {
        try meter.retain(JSONLogicalWeights.frame); frames.append(frame)
    }

    /// RFC 6902 operations for the same difference, in an order that applies cleanly:
    /// within an array, paired changes first, then removals from the highest index
    /// down, then additions in ascending order.
    package static func operations(from source: JSON, to target: JSON, meter: inout JSONWorkMeter) throws -> [JSONDifferenceOperation] {
        struct Level { var removals: [JSONDifferenceOperation] = []; var additions: [JSONDifferenceOperation] = [] }
        var walker = JSONDifferenceWalker(source: source, target: target)
        var operations: [JSONDifferenceOperation] = []
        var path: [JSONKey] = [], levels: [Level?] = []
        var pendingKey: JSONKey? = nil, pendingElement = false
        func emit(_ operation: JSONDifferenceOperation, meter: inout JSONWorkMeter) throws {
            try meter.require(.operations, UInt64(operations.count) + 1)
            try meter.retain(JSONLogicalWeights.frame); operations.append(operation)
        }
        func childPath(meter: inout JSONWorkMeter) throws -> [JSONKey] {
            guard let pendingKey else { return path }
            try meter.require(.pointerTokens, UInt64(path.count) + 1)
            for _ in path { try meter.work() }
            try meter.retain(16)
            return path + [pendingKey]
        }
        func deferred(_ operation: JSONDifferenceOperation, removal: Bool, meter: inout JSONWorkMeter) throws {
            guard pendingElement, let last = levels.indices.last, levels[last] != nil else { return try emit(operation, meter: &meter) }
            try meter.retain(JSONLogicalWeights.frame)
            if removal { levels[last]!.removals.append(operation) } else { levels[last]!.additions.append(operation) }
        }
        while let event = try walker.next(meter: &meter) {
            switch event {
            case .member(let key): pendingKey = key; pendingElement = false
            case .element(let s, let t):
                pendingKey = try JSONKey(String(s ?? t ?? 0), meter: &meter); pendingElement = s == nil || t == nil
            case .same, .sameElements: pendingKey = nil; pendingElement = false
            case .replaced(_, let value):
                try emit(.init(kind: .replace, path: childPath(meter: &meter), value: value), meter: &meter)
                pendingKey = nil; pendingElement = false
            case .removed:
                try deferred(.init(kind: .remove, path: childPath(meter: &meter), value: nil), removal: true, meter: &meter)
                pendingKey = nil; pendingElement = false
            case .added(let value):
                try deferred(.init(kind: .add, path: childPath(meter: &meter), value: value), removal: false, meter: &meter)
                pendingKey = nil; pendingElement = false
            case .beginObject, .beginArray:
                path = try childPath(meter: &meter); pendingKey = nil; pendingElement = false
                try meter.retain(JSONLogicalWeights.frame)
                if case .beginArray = event { levels.append(Level()) } else { levels.append(nil) }
            case .endObject, .endArray:
                if let level = levels.removeLast() {
                    for operation in level.removals.reversed() { try emit(operation, meter: &meter) }
                    for operation in level.additions { try emit(operation, meter: &meter) }
                }
                try meter.release(JSONLogicalWeights.frame)
                if !path.isEmpty { path.removeLast() }
            }
        }
        return operations
    }
}
