// SPDX-License-Identifier: Apache-2.0
public struct JSONSourceSpan: Sendable, Equatable {
    public let start: UInt64
    public let end: UInt64
    package init(start: UInt64, end: UInt64) { self.start = start; self.end = end }
}
public struct JSONSourceMap: Sendable {
    public struct Entry: Sendable {
        public enum Kind: Sendable { case value, memberKey }
        public let path: [JSONLocationComponent]
        public let kind: Kind
        public let span: JSONSourceSpan
    }
    public let entries: [Entry]
    package init(entries: [Entry]) { self.entries = entries }
    public func span(at path: [JSONLocationComponent], kind: Entry.Kind = .value, limits: JSONLimits = .balanced) throws -> JSONSourceSpan? {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        for entry in entries {
            try meter.work()
            if entry.kind != kind || entry.path.count != path.count { continue }
            var equal = true
            for (a, b) in zip(entry.path, path) {
                try meter.work()
                switch (a, b) {
                case (.index(let l), .index(let r)): equal = l == r
                case (.key(let l), .key(let r)): equal = try JSONComparison.textEquals(l.string, r.string, meter: &meter)
                default: equal = false
                }
                if !equal { break }
            }
            if equal { return entry.span }
        }
        return nil
    }
}

package struct JSONSourceMapBuilder {
    private struct Frame { let path: [JSONLocationComponent]; let start: UInt64; var nextIndex = 0; var key: JSONKey?; let object: Bool }
    private var stack: [Frame] = []
    private var entries: [JSONSourceMap.Entry] = []
    private mutating func path(meter: inout JSONWorkMeter) throws -> [JSONLocationComponent] {
        guard !stack.isEmpty else { return [] }
        let index = stack.count - 1
        var path: [JSONLocationComponent] = []
        for component in stack[index].path { try meter.work(); try meter.retain(16); path.append(component) }
        try meter.retain(16)
        if stack[index].object {
            guard let key = stack[index].key else { throw JSONFailure(.syntax, code: .invalidOperation) }
            path.append(.key(key)); stack[index].key = nil
        } else { path.append(.index(stack[index].nextIndex)); stack[index].nextIndex += 1 }
        return path
    }
    private mutating func add(path: [JSONLocationComponent], kind: JSONSourceMap.Entry.Kind, start: UInt64, end: UInt64, meter: inout JSONWorkMeter) throws {
        try meter.charge(.sourceMapEntries); try meter.retain(JSONLogicalWeights.sourceMapEntry)
        entries.append(.init(path: path, kind: kind, span: .init(start: start, end: end)))
    }
    package mutating func consume(_ event: JSONMachineEvent, meter: inout JSONWorkMeter) throws {
        try meter.work()
        switch event.kind {
        case .key(let text):
            stack[stack.count - 1].key = try JSONKey(text, meter: &meter)
            var keyPath: [JSONLocationComponent] = []
            for part in stack.last!.path { try meter.work(); try meter.retain(16); keyPath.append(part) }
            try meter.retain(16); keyPath.append(.key(try JSONKey(text, meter: &meter)))
            try add(path: keyPath, kind: .memberKey, start: event.start, end: event.end, meter: &meter)
        case .startObject, .startArray:
            let path = try path(meter: &meter)
            let object: Bool
            if case .startObject = event.kind { object = true } else { object = false }
            try meter.retain(JSONLogicalWeights.frame); stack.append(.init(path: path, start: event.start, object: object))
        case .endObject, .endArray:
            let frame = stack.removeLast(); try meter.release(JSONLogicalWeights.frame)
            try add(path: frame.path, kind: .value, start: frame.start, end: event.end, meter: &meter)
        case .scalar:
            try add(path: path(meter: &meter), kind: .value, start: event.start, end: event.end, meter: &meter)
        }
    }
    package func finish() -> JSONSourceMap { .init(entries: entries) }
}
