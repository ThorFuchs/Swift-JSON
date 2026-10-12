// SPDX-License-Identifier: Apache-2.0
// Controlled index candidates for qualification. No production publication path.
@testable import JSON

struct ProbeKey {
    let bytes: [UInt8]
    let fingerprint: UInt64
    let position: Int
    init(_ text: String, position: Int, collision: Bool = false, meter: inout JSONWorkMeter) throws {
        var bytes: [UInt8] = [], fingerprint: UInt64 = 14695981039346656037
        for byte in text.utf8 {
            try meter.work(); try meter.require(.keyBytes, UInt64(bytes.count) + 1)
            try meter.retain(1); bytes.append(byte)
            fingerprint = (fingerprint ^ UInt64(byte)) &* 1099511628211
        }
        self.bytes = bytes; self.fingerprint = collision ? 0 : fingerprint; self.position = position
    }
    func compare(_ other: Self, meter: inout JSONWorkMeter) throws -> Int {
        try meter.work()
        if fingerprint != other.fingerprint { return fingerprint < other.fingerprint ? -1 : 1 }
        return try compareBytes(other, meter: &meter)
    }
    func compareBytes(_ other: Self, meter: inout JSONWorkMeter) throws -> Int {
        for index in 0..<min(bytes.count, other.bytes.count) {
            try meter.work()
            if bytes[index] != other.bytes[index] { return bytes[index] < other.bytes[index] ? -1 : 1 }
        }
        try meter.work()
        return bytes.count == other.bytes.count ? 0 : bytes.count < other.bytes.count ? -1 : 1
    }
}

struct ProbeScalarIndex: ProbeIndex {
    private var keys: [ProbeKey] = []
    init() {}
    mutating func insert(_ key: ProbeKey, meter: inout JSONWorkMeter) throws {
        guard try find(key, meter: &meter) == nil else { throw JSONFailure(.syntax, code: .duplicateKey) }
        try meter.require(.objectMembers, UInt64(keys.count) + 1)
        try meter.retain(JSONLogicalWeights.indexSlot); keys.append(key)
    }
    func find(_ key: ProbeKey, meter: inout JSONWorkMeter) throws -> Int? {
        for previous in keys {
            try meter.work()
            if try previous.compareBytes(key, meter: &meter) == 0 { return previous.position }
        }
        return nil
    }
}

protocol ProbeIndex {
    init()
    mutating func insert(_ key: ProbeKey, meter: inout JSONWorkMeter) throws
    func find(_ key: ProbeKey, meter: inout JSONWorkMeter) throws -> Int?
}

struct ProbeLinearIndex: ProbeIndex {
    private var keys: [ProbeKey] = []
    init() {}
    mutating func insert(_ key: ProbeKey, meter: inout JSONWorkMeter) throws {
        guard try find(key, meter: &meter) == nil else { throw JSONFailure(.syntax, code: .duplicateKey) }
        try meter.require(.objectMembers, UInt64(keys.count) + 1)
        try meter.retain(JSONLogicalWeights.indexSlot); keys.append(key)
    }
    func find(_ key: ProbeKey, meter: inout JSONWorkMeter) throws -> Int? {
        for previous in keys {
            try meter.work()
            if try previous.compare(key, meter: &meter) == 0 { return previous.position }
        }
        return nil
    }
}

struct ProbeAVLIndex: ProbeIndex {
    private struct Node { let key: ProbeKey; var left = -1; var right = -1; var height = 1 }
    private var nodes: [Node] = []
    private var root = -1
    private var slots = 0
    init() {}
    private func height(_ index: Int) -> Int { index < 0 ? 0 : nodes[index].height }
    private mutating func update(_ index: Int) { nodes[index].height = 1 + max(height(nodes[index].left), height(nodes[index].right)) }
    private mutating func rotateRight(_ index: Int, meter: inout JSONWorkMeter) throws -> Int {
        try meter.work(4)
        let child = nodes[index].left
        nodes[index].left = nodes[child].right; nodes[child].right = index
        update(index); update(child); return child
    }
    private mutating func rotateLeft(_ index: Int, meter: inout JSONWorkMeter) throws -> Int {
        try meter.work(4)
        let child = nodes[index].right
        nodes[index].right = nodes[child].left; nodes[child].left = index
        update(index); update(child); return child
    }
    private mutating func append(_ key: ProbeKey, meter: inout JSONWorkMeter) throws -> Int {
        try meter.require(.objectMembers, UInt64(nodes.count) + 1)
        if nodes.count == slots {
            let (doubled, overflow) = slots.multipliedReportingOverflow(by: 2)
            guard !overflow else { throw JSONFailure(.resource, code: .counterOverflow) }
            let next = min(Int(meter.limits[.objectMembers]), max(1, doubled))
            let (bytes, byteOverflow) = UInt64(next).multipliedReportingOverflow(by: JSONLogicalWeights.indexSlot)
            guard !byteOverflow else { throw JSONFailure(.resource, code: .counterOverflow) }
            // Admit the new allocation while the old capacity still coexists.
            try meter.retain(bytes); try meter.work(UInt64(nodes.count)); nodes.reserveCapacity(next)
            try meter.release(UInt64(slots) * JSONLogicalWeights.indexSlot); slots = next
        }
        try meter.work(); nodes.append(Node(key: key)); return nodes.count - 1
    }
    private mutating func insert(_ key: ProbeKey, at index: Int, meter: inout JSONWorkMeter) throws -> Int {
        if index < 0 { return try append(key, meter: &meter) }
        try meter.retain(JSONLogicalWeights.frame)
        let comparison = try key.compare(nodes[index].key, meter: &meter)
        if comparison == 0 { throw JSONFailure(.syntax, code: .duplicateKey) }
        if comparison < 0 { nodes[index].left = try insert(key, at: nodes[index].left, meter: &meter) }
        else { nodes[index].right = try insert(key, at: nodes[index].right, meter: &meter) }
        try meter.work(); update(index)
        let balance = height(nodes[index].left) - height(nodes[index].right)
        var result = index
        if balance > 1 {
            let left = nodes[index].left
            if height(nodes[left].left) < height(nodes[left].right) { nodes[index].left = try rotateLeft(left, meter: &meter) }
            result = try rotateRight(index, meter: &meter)
        } else if balance < -1 {
            let right = nodes[index].right
            if height(nodes[right].right) < height(nodes[right].left) { nodes[index].right = try rotateRight(right, meter: &meter) }
            result = try rotateLeft(index, meter: &meter)
        }
        try meter.release(JSONLogicalWeights.frame)
        return result
    }
    mutating func insert(_ key: ProbeKey, meter: inout JSONWorkMeter) throws { root = try insert(key, at: root, meter: &meter) }
    func find(_ key: ProbeKey, meter: inout JSONWorkMeter) throws -> Int? {
        var index = root
        while index >= 0 {
            try meter.work()
            let comparison = try key.compare(nodes[index].key, meter: &meter)
            if comparison == 0 { return nodes[index].key.position }
            index = comparison < 0 ? nodes[index].left : nodes[index].right
        }
        return nil
    }
}

struct ProbeHashIndex: ProbeIndex {
    private var slots: [ProbeKey?] = []
    private var count = 0
    init() {}
    private func position(_ key: ProbeKey, in table: [ProbeKey?], meter: inout JSONWorkMeter) throws -> (Int, Bool) {
        var position = Int(key.fingerprint & UInt64(table.count - 1))
        for _ in table.indices {
            try meter.work()
            guard let previous = table[position] else { return (position, false) }
            if try previous.compare(key, meter: &meter) == 0 { return (position, true) }
            position = (position + 1) & (table.count - 1)
        }
        throw JSONFailure(.configuration, code: .invalidOperation)
    }
    private mutating func grow(meter: inout JSONWorkMeter) throws {
        let (capacity, overflow) = max(1, slots.count).multipliedReportingOverflow(by: 2)
        guard !overflow else { throw JSONFailure(.resource, code: .counterOverflow) }
        let (bytes, byteOverflow) = UInt64(capacity).multipliedReportingOverflow(by: JSONLogicalWeights.indexSlot)
        guard !byteOverflow else { throw JSONFailure(.resource, code: .counterOverflow) }
        try meter.retain(bytes)
        var replacement: [ProbeKey?] = []
        replacement.reserveCapacity(capacity)
        for _ in 0..<capacity { try meter.work(); replacement.append(nil) }
        for previous in slots {
            try meter.work()
            if let previous {
                let (index, _) = try position(previous, in: replacement, meter: &meter)
                replacement[index] = previous
            }
        }
        try meter.release(UInt64(slots.count) * JSONLogicalWeights.indexSlot)
        slots = replacement
    }
    mutating func insert(_ key: ProbeKey, meter: inout JSONWorkMeter) throws {
        guard try find(key, meter: &meter) == nil else { throw JSONFailure(.syntax, code: .duplicateKey) }
        try meter.require(.objectMembers, UInt64(count) + 1)
        if count >= slots.count / 2 { try grow(meter: &meter) }
        let (index, found) = try position(key, in: slots, meter: &meter)
        guard !found else { throw JSONFailure(.syntax, code: .duplicateKey) }
        slots[index] = key; count += 1
    }
    func find(_ key: ProbeKey, meter: inout JSONWorkMeter) throws -> Int? {
        guard !slots.isEmpty else { return nil }
        let (index, found) = try position(key, in: slots, meter: &meter)
        return found ? slots[index]?.position : nil
    }
}
