// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Additional capacity bookkeeping, never a work meter or independent health.
internal struct JSONStoreAccounting {
    let caps: JSONStoreCaps
    var overlay: UInt64 = 0
    var profileText: UInt64 = 0
    var aliases: UInt64 = 0
    var phase = 1
    static func sum(_ lhs: UInt64, _ rhs: UInt64) throws -> UInt64 {
        let (next, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw JSONStoreFailure(.counterOverflow, phase: 0, domain: .operation) }
        return next
    }
    static func product(_ lhs: UInt64, _ rhs: UInt64) throws -> UInt64 {
        let (next, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        guard !overflow else { throw JSONStoreFailure(.counterOverflow, phase: 0, domain: .operation) }
        return next
    }
    static func checkedCount(_ value: UInt64, phase: Int) throws -> Int {
        guard let result = Int(exactly: value) else {
            throw JSONStoreFailure(.counterOverflow, phase: phase, domain: .operation)
        }
        return result
    }
    static func check(_ count: Int, _ limit: Int, name: String, phase: Int,
                      path: [JSONLocationComponent] = []) throws {
        guard count <= limit else {
            throw JSONStoreFailure(.capacityExceeded, phase: phase, domain: .operation,
                                   path: path, capacity: name, limit: limit)
        }
    }
    mutating func track(_ bytes: UInt64) throws {
        let next = try Self.sum(overlay, bytes)
        guard next <= UInt64(caps.overlayBytes) else {
            throw JSONStoreFailure(.capacityExceeded, phase: phase, domain: .operation,
                                   capacity: "overlayBytes", limit: caps.overlayBytes)
        }
        overlay = next
    }
    mutating func reserve(_ bytes: UInt64, context: inout JSONReadPreparationContext) throws {
        try track(bytes); try context.retain(bytes)
    }
    mutating func reserve(_ bytes: UInt64, context: inout JSONTraversalContext) throws {
        try track(bytes); try context.retain(bytes)
    }
    mutating func profile(_ text: String, key: Bool, identity: Bool = false,
                          context: inout JSONReadPreparationContext) throws {
        var size: UInt64 = 0
        for _ in text.utf8 {
            try context.work(); size = try Self.sum(size, 1)
            let next = try Self.sum(profileText, 1)
            guard next <= UInt64(caps.profileTextBytes),
                  !identity || size <= UInt64(caps.identityBytes) else {
                throw JSONStoreFailure(.capacityExceeded, phase: 1, domain: .operation,
                    capacity: identity && size > UInt64(caps.identityBytes) ? "identityBytes" : "profileTextBytes",
                    limit: identity && size > UInt64(caps.identityBytes) ? caps.identityBytes : caps.profileTextBytes)
            }
            profileText = next
        }
        // Native admission owns the text reservation. Track, do not reserve twice.
        try track(size); try context.admitText(text, key: key)
    }
    mutating func alias(_ text: String, phase: Int, path: [JSONLocationComponent],
                        context: inout JSONTraversalContext) throws -> UInt64 {
        try reserve(32, context: &context)
        var size: UInt64 = 0
        for _ in text.utf8 {
            try context.work(); size = try Self.sum(size, 1)
            let next = try Self.sum(aliases, 1)
            guard size <= UInt64(caps.identityBytes), next <= UInt64(caps.aliasBytes) else {
                throw JSONStoreFailure(.capacityExceeded, phase: phase, domain: .operation, path: path,
                    capacity: size > UInt64(caps.identityBytes) ? "identityBytes" : "aliasBytes",
                    limit: size > UInt64(caps.identityBytes) ? caps.identityBytes : caps.aliasBytes)
            }
            aliases = next; try reserve(1, context: &context)
        }
        return size
    }
    mutating func releaseAliases(_ textBytes: UInt64, count: UInt64,
                                context: inout JSONTraversalContext) throws {
        let bytes = try Self.sum(textBytes, Self.product(count, 32))
        guard aliases >= textBytes, overlay >= bytes else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        try context.release(bytes); aliases -= textBytes; overlay -= bytes
    }
    mutating func path(_ component: JSONLocationComponent, after prefix: [JSONLocationComponent],
                       context: inout JSONTraversalContext) throws -> [JSONLocationComponent] {
        let count = try Self.sum(UInt64(prefix.count), 1)
        guard count <= UInt64(caps.pathComponents) else {
            throw JSONStoreFailure(.capacityExceeded, phase: phase, domain: .operation,
                                   capacity: "pathComponents", limit: caps.pathComponents)
        }
        var bytes = try Self.product(count, JSONLogicalWeights.indexSlot)
        for part in prefix {
            try context.work()
            if case .key(let key) = part {
                for _ in key.string.utf8 { try context.work(); bytes = try Self.sum(bytes, 1) }
            }
        }
        if case .key(let key) = component {
            for _ in key.string.utf8 { try context.work(); bytes = try Self.sum(bytes, 1) }
        }
        try track(bytes)
        return try context.appending(component, to: prefix)
    }
}
