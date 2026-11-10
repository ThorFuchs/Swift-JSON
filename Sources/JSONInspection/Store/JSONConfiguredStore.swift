// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

private final class JSONStoreOwner: Sendable {}
/// Unforgeable position bound to one immutable store instance, not a persistent ID.
public struct JSONStorePosition: Sendable, Equatable {
    fileprivate let owner: JSONStoreOwner
    /// Zero-based physical source collection position.
    public let collection: Int
    /// Zero-based physical row in that collection.
    public let row: Int
    /// Compares exact owner identity and fixed local ordinals; no JSON scan.
    /// - Parameters:
    ///   - lhs: First owner-bound position.
    ///   - rhs: Second owner-bound position.
    /// - Returns: True only for the same source instance and physical record.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.owner === rhs.owner && lhs.collection == rhs.collection && lhs.row == rhs.row
    }
}
/// A declared reference slot; missing and explicit null remain distinct.
public enum JSONStoreReferenceState: Sendable {
    /// Optional field absent from the original record.
    case absent
    /// Explicit JSON null accepted by the field policy.
    case null
    /// A validated existing target in this same store.
    /// - Parameter position: Exact owner-bound target position.
    case link(JSONStorePosition)
}
/// Immutable source metadata; value resolution is a separately metered operation.
public struct JSONStoreRecordMetadata: Sendable {
    /// Exact instance-bound physical position.
    public let position: JSONStorePosition
    /// Original decoded-scalar string ID.
    public let id: String
    /// Absolute physical path of the record.
    public let path: [JSONLocationComponent]
    /// Absolute path of its configured ID member.
    public let idPath: [JSONLocationComponent]
    /// Half-open range into the containing store references array.
    public let referenceRange: Range<Int>
}
/// Immutable configured-slot metadata in physical record and declaration order.
public struct JSONStoreReferenceMetadata: Sendable {
    /// Zero-based field declaration in the record collection profile.
    public let field: Int
    /// Exact absolute field path, including absent fields.
    public let path: [JSONLocationComponent]
    /// Absent, explicit null or a validated same-store link.
    public let state: JSONStoreReferenceState
}
internal struct StoreCollectionMetadata: Sendable {
    let profile: Int
    let path: [JSONLocationComponent]
    let start: Int
    let count: Int
}
/// Immutable completely admitted source, records and explicitly validated references.
/// Construct through JSONStoreBuilder. No mutable store, I/O or persistent identity.
public struct JSONConfiguredStore: Sendable {
    /// Original complete canonical source, optionally with coherent source mapping.
    public let document: JSONDocument
    /// Immutable explicit collection/reference interpretation.
    public let profile: JSONStoreProfile
    private let owner: JSONStoreOwner
    private let collections: [StoreCollectionMetadata]
    private let records: [JSONStoreRecordMetadata]
    /// All immutable configured slots, in physical record and field order.
    public let references: [JSONStoreReferenceMetadata]
    package let overlayLogicalBytes: UInt64
    package let identityAliasBytes: UInt64
    package let profileTextBytes: UInt64
    /// Number of complete physical collections.
    public var collectionCount: Int { collections.count }
    /// Total complete physical records.
    public var recordCount: Int { records.count }
    /// Fixed metadata access without a new owned operation.
    /// - Parameter collection: Zero-based physical collection position.
    /// - Returns: Complete record count in that collection.
    /// - Throws: Invalid local collection position.
    public func recordCount(in collection: Int) throws -> Int {
        guard collection >= 0, collection < collections.count else {
            throw JSONStoreFailure(.invalidPosition, phase: 0, domain: .operation)
        }
        return collections[collection].count
    }
    /// Reads a physical collection's exact name without scanning or opening a ledger.
    /// - Parameter collection: Zero-based physical source collection position.
    /// - Returns: Exact configured source name.
    /// - Throws: Invalid collection position.
    public func collectionName(at collection: Int) throws -> JSONKey {
        guard collection >= 0, collection < collections.count else {
            throw JSONStoreFailure(.invalidPosition, phase: 0, domain: .operation)
        }
        return profile.collections[collections[collection].profile].name
    }

    fileprivate init(document: JSONDocument, profile: JSONStoreProfile, owner: JSONStoreOwner,
                      collections: [StoreCollectionMetadata], records: [JSONStoreRecordMetadata],
                      references: [JSONStoreReferenceMetadata], overlay: UInt64, aliases: UInt64,
                      profileText: UInt64) {
        self.document = document; self.profile = profile; self.owner = owner
        self.collections = collections; self.records = records; self.references = references
        overlayLogicalBytes = overlay; identityAliasBytes = aliases
        profileTextBytes = profileText
    }
    /// Checked fixed metadata access; positions are bound to this exact owner instance.
    /// - Parameters:
    ///   - collection: Physical collection position.
    ///   - row: Physical row position.
    /// - Returns: Immutable metadata from this exact store.
    /// - Throws: Invalid local position.
    public func record(collection: Int, row: Int) throws -> JSONStoreRecordMetadata {
        guard collection >= 0, collection < collections.count, row >= 0,
              row < collections[collection].count else {
            throw JSONStoreFailure(.invalidPosition, phase: 0, domain: .operation)
        }
        return records[collections[collection].start + row]
    }
    /// Reads fixed metadata with exact owner validation, without scanning JSON.
    /// - Parameter position: Unforgeable position from this exact store instance.
    /// - Returns: Original immutable record metadata.
    /// - Throws: Foreign-owner or out-of-bounds position; never a null substitute.
    public func record(at position: JSONStorePosition) throws -> JSONStoreRecordMetadata {
        guard position.owner === owner else {
            throw JSONStoreFailure(.invalidPosition, phase: 0, domain: .operation)
        }
        return try record(collection: position.collection, row: position.row)
    }
}

/// Builds a complete immutable configured store using the original native ledger.
/// Profile preparation, admission, all construction phases and publication share it.
public struct JSONStoreBuilder: Sendable {
    /// Original canonical source; admitted once during build.
    public let document: JSONDocument
    /// Closed typed configuration checked before source admission.
    public let profile: JSONStoreProfile
    /// Native cumulative operation quotas.
    public let limits: JSONLimits
    /// Additional inclusive store construction policies.
    public let caps: JSONStoreCaps
    package var checkpointObserver: (@Sendable (UInt64) -> Void)?
    package var lifetimeObserver: (@Sendable (Bool, Bool) -> Void)?
    /// Qualification-only phase rendezvous; arbitrary observer work is not library work.
    package var phaseObserver: (@Sendable (Int) -> Void)?
    /// Captures trusted immutable inputs; validation occurs inside build.
    /// - Parameters:
    ///   - document: Complete canonical source, optionally with mapping.
    ///   - profile: Explicit exact collection/ID/reference declarations.
    ///   - limits: Finite cumulative native quotas.
    ///   - caps: Additional finite store policies, not physical capacity promises.
    public init(document: JSONDocument, profile: JSONStoreProfile,
                 limits: JSONLimits = .balanced, caps: JSONStoreCaps = .init()) {
        self.document = document; self.profile = profile; self.limits = limits; self.caps = caps
    }
    /// Completes all construction phases atomically or throws, with no partial store.
    /// - Returns: Immutable admitted store and the one original operation report.
    /// - Throws: Profile/source/capacity/core resource errors or cancellation.
    public func build() throws -> JSONOperationReport<JSONConfiguredStore> {
        try Task.checkCancellation()
        try limits.validate()
        try caps.validate()
        var reducer = StoreReducer(profile: profile, accounting: .init(caps: caps))
        reducer.phaseObserver = phaseObserver
        var traversal = JSONTraversal(document: document, limits: limits)
        traversal.checkpointObserver = checkpointObserver
        traversal.lifetimeObserver = lifetimeObserver
        do {
            return try traversal.inspectPreparedOwned(scope: .subtree(at: profile.collectionsAt),
                options: .init(depthLimit: 0), reducer: &reducer)
        } catch let error as JSONAccessFailure {
            // Selection happens before the reducer: preserve the real core cause/path/location.
            throw JSONStoreFailure(error.cause.category == .missingValue ? .selectionMissing : .selectionWrongKind,
                phase: 3, domain: .source, path: error.path, coreCause: error.cause)
        }
    }
}

private struct StorePendingReference {
    let metadata: Int
    let collection: String
    let id: String
    let aliasBytes: UInt64
}
private struct StoreReducer: JSONReadPreparation, JSONTraversalOwnedReducer {
    let profile: JSONStoreProfile
    var accounting: JSONStoreAccounting
    private var owner: JSONStoreOwner?
    private var collections: [StoreCollectionMetadata] = []
    private var records: [JSONStoreRecordMetadata] = []
    private var references: [JSONStoreReferenceMetadata] = []
    private var pending: [StorePendingReference] = []
    private var observed = false
    private var stagedLinks = 0
    private var resolvedLinks = 0
    var phaseObserver: (@Sendable (Int) -> Void)?
    init(profile: JSONStoreProfile, accounting: JSONStoreAccounting) {
        self.profile = profile; self.accounting = accounting
    }
    mutating func prepare(context: inout JSONReadPreparationContext) throws {
        phaseObserver?(1)
        try profile.prepare(accounting: &accounting, context: &context)
        owner = JSONStoreOwner() // fixed reservation was admitted before allocation
        phaseObserver?(2)
    }
    mutating func refuse(_ code: JSONStoreFailureCode, phase: Int, at path: [JSONLocationComponent],
                         missing: Bool = false, first: [JSONLocationComponent]? = nil,
                         context: inout JSONTraversalContext) throws -> Never {
        var anchor = path
        if missing {
            anchor = []
            for component in path.dropLast() {
                anchor = try accounting.path(component, after: anchor, context: &context)
            }
        }
        let span = try context.sourceSpan(at: anchor)
        throw JSONStoreFailure(code, phase: phase, domain: .source, path: path,
                               firstPath: first, sourceSpan: span)
    }
    mutating func path(_ component: JSONLocationComponent, after prefix: [JSONLocationComponent],
                       context: inout JSONTraversalContext) throws -> [JSONLocationComponent] {
        try accounting.path(component, after: prefix, context: &context)
    }
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work()
        guard !observed, hit.relativeDepth == 0 else { throw JSONFailure(.configuration, code: .invalidOperation) }
        observed = true
        phaseObserver?(3)
        guard case .object(let object) = value else {
            try refuse(.collectionsNotObject, phase: 3, at: hit.absoluteLocation, context: &context)
        }
        try headers(object, root: hit.absoluteLocation, context: &context)
        try identifiers(object, context: &context)
        try markers(object, context: &context)
        try targets(context: &context)
        return .skipDescendants
    }
    mutating func headers(_ object: JSONObject, root: [JSONLocationComponent],
                          context: inout JSONTraversalContext) throws {
        accounting.phase = 4
        phaseObserver?(4)
        try accounting.reserve(try JSONStoreAccounting.product(UInt64(profile.collections.count) + 1, 8), context: &context)
        var seen = Array(repeating: false, count: profile.collections.count)
        var total = 0
        for index in 0..<object.count {
            try context.work()
            try JSONStoreAccounting.check(index + 1, accounting.caps.collections, name: "collections", phase: 4)
            let member = object[index]
            let location = try path(.key(member.key), after: root, context: &context)
            var declaration: Int?
            for i in profile.collections.indices {
                try context.work()
                if try context.equalStrings(profile.collections[i].name.string, member.key.string) {
                    declaration = i; break
                }
            }
            guard let declaration else { try refuse(.unconfiguredCollection, phase: 4, at: location, context: &context) }
            guard case .array(let array) = member.value else { try refuse(.collectionNotArray, phase: 4, at: location, context: &context) }
            try JSONStoreAccounting.check(array.count, accounting.caps.recordsPerCollection,
                                          name: "recordsPerCollection", phase: 4, path: location)
            let sum = try JSONStoreAccounting.sum(UInt64(total), UInt64(array.count))
            let next = try JSONStoreAccounting.checkedCount(sum, phase: 4)
            try JSONStoreAccounting.check(next, accounting.caps.records, name: "records", phase: 4, path: location)
            collections.append(.init(profile: declaration, path: location, start: total, count: array.count))
            seen[declaration] = true; total = next
        }
        for index in profile.collections.indices {
            try context.work()
            if !seen[index] {
                let location = try path(.key(profile.collections[index].name), after: root, context: &context)
                try refuse(.missingConfiguredCollection, phase: 4, at: location, missing: true, context: &context)
            }
        }
        try accounting.reserve(try JSONStoreAccounting.product(UInt64(total) + 1, 8), context: &context)
    }
    mutating func identifiers(_ object: JSONObject, context: inout JSONTraversalContext) throws {
        accounting.phase = 5
        phaseObserver?(5)
        guard let owner else { throw JSONFailure(.configuration, code: .invalidOperation) }
        for ci in collections.indices {
            try context.work()
            let collection = collections[ci], declaration = profile.collections[collection.profile]
            guard case .array(let array) = object[ci].value else { throw JSONFailure(.configuration, code: .invalidOperation) }
            for row in array.indices {
                try context.work()
                let rowPath = try path(.index(row), after: collection.path, context: &context)
                guard case .object = array[row] else { try refuse(.recordWrongKind, phase: 5, at: rowPath, context: &context) }
                let idPath = try path(.key(declaration.idKey), after: rowPath, context: &context)
                guard let value = try context.member(array[row], key: declaration.idKey, at: rowPath) else {
                    try refuse(.recordIDMissing, phase: 5, at: idPath, missing: true, context: &context)
                }
                if case .null = value { try refuse(.recordIDNull, phase: 5, at: idPath, context: &context) }
                guard case .string(let id) = value else { try refuse(.recordIDWrongKind, phase: 5, at: idPath, context: &context) }
                _ = try accounting.alias(id, phase: 5, path: idPath, context: &context)
                for prior in collection.start..<records.count {
                    try context.work()
                    if try context.equalStrings(records[prior].id, id) {
                        try refuse(.duplicateRecordID, phase: 5, at: idPath,
                                   first: records[prior].idPath, context: &context)
                    }
                }
                try accounting.reserve(64, context: &context)
                let position = JSONStorePosition(owner: owner, collection: ci, row: row)
                records.append(.init(position: position, id: id, path: rowPath, idPath: idPath, referenceRange: 0..<0))
            }
        }
    }
    mutating func markers(_ object: JSONObject, context: inout JSONTraversalContext) throws {
        accounting.phase = 6
        phaseObserver?(6)
        for ci in collections.indices {
            try context.work()
            let collection = collections[ci], declaration = profile.collections[collection.profile]
            guard case .array(let array) = object[ci].value else { throw JSONFailure(.configuration, code: .invalidOperation) }
            for row in array.indices {
                try context.work()
                let ri = collection.start + row, record = records[ri], start = references.count
                for fi in declaration.referenceFields.indices {
                    try context.work()
                    try JSONStoreAccounting.check(references.count + 1, accounting.caps.referenceSlots,
                        name: "referenceSlots", phase: 6, path: record.path)
                    let field = declaration.referenceFields[fi]
                    let location = try path(.key(field.key), after: record.path, context: &context)
                    let marker = try context.member(array[row], key: field.key, at: record.path)
                    let state: JSONStoreReferenceState
                    if let marker {
                        if case .null = marker {
                            guard field.nullable else { try refuse(.referenceNull, phase: 6, at: location, context: &context) }
                            state = .null
                        } else {
                            try stageMarker(marker, location: location, context: &context)
                            // A staged placeholder is private and can never be published before targets finish.
                            state = .absent
                        }
                    } else {
                        guard field.presence == .optional else { try refuse(.referenceMissing, phase: 6, at: location, missing: true, context: &context) }
                        state = .absent
                    }
                    try accounting.reserve(64, context: &context)
                    references.append(.init(field: fi, path: location, state: state))
                }
                records[ri] = .init(position: record.position, id: record.id, path: record.path,
                                    idPath: record.idPath, referenceRange: start..<references.count)
            }
        }
    }
    mutating func stageMarker(_ value: JSON, location: [JSONLocationComponent],
                              context: inout JSONTraversalContext) throws {
        guard case .object(let object) = value else { try refuse(.referenceMarkerWrongKind, phase: 6, at: location, context: &context) }
        let collectionKey: JSONKey = "collection", idKey: JSONKey = "id"
        let collectionValue = try context.member(value, key: collectionKey, at: location)
        let idValue = try context.member(value, key: idKey, at: location)
        guard let collectionValue else {
            let missing = try path(.key(collectionKey), after: location, context: &context)
            try refuse(.referenceMarkerMissing, phase: 6, at: missing, missing: true, context: &context)
        }
        guard let idValue else {
            let missing = try path(.key(idKey), after: location, context: &context)
            try refuse(.referenceMarkerMissing, phase: 6, at: missing, missing: true, context: &context)
        }
        guard case .string(let collection) = collectionValue else {
            let failure = try path(.key(collectionKey), after: location, context: &context)
            try refuse(.referenceMarkerMemberWrongKind, phase: 6, at: failure, context: &context)
        }
        guard case .string(let id) = idValue else {
            let failure = try path(.key(idKey), after: location, context: &context)
            try refuse(.referenceMarkerMemberWrongKind, phase: 6, at: failure, context: &context)
        }
        for member in object {
            try context.work()
            if try !context.equalStrings(member.key.string, collectionKey.string),
               try !context.equalStrings(member.key.string, idKey.string) {
                let failure = try path(.key(member.key), after: location, context: &context)
                try refuse(.referenceMarkerExtra, phase: 6, at: failure, context: &context)
            }
        }
        try JSONStoreAccounting.check(pending.count + 1, accounting.caps.links, name: "links", phase: 6, path: location)
        let a = try accounting.alias(collection, phase: 6, path: location, context: &context)
        let b = try accounting.alias(id, phase: 6, path: location, context: &context)
        try accounting.reserve(32, context: &context)
        pending.append(.init(metadata: references.count, collection: collection, id: id,
                             aliasBytes: try JSONStoreAccounting.sum(a,b)))
        stagedLinks += 1 // the finite link cap was checked before staging
    }
    mutating func targets(context: inout JSONTraversalContext) throws {
        accounting.phase = 7
        phaseObserver?(7)
        for index in pending.indices {
            try context.work()
            let pending = pending[index], metadata = references[pending.metadata]
            var targetCollection: Int?
            for ci in collections.indices {
                try context.work()
                if try context.equalStrings(profile.collections[collections[ci].profile].name.string, pending.collection) {
                    targetCollection = ci; break
                }
            }
            guard let ci = targetCollection else {
                let failure = try path(.key("collection"), after: metadata.path, context: &context)
                try refuse(.referenceUnknownCollection, phase: 7, at: failure, context: &context)
            }
            let collection = collections[ci]
            var target: JSONStorePosition?
            for row in 0..<collection.count {
                try context.work()
                let record = records[collection.start + row]
                if try context.equalStrings(record.id, pending.id) { target = record.position; break }
            }
            guard let target else {
                let failure = try path(.key("id"), after: metadata.path, context: &context)
                try refuse(.referenceDanglingID, phase: 7, at: failure, context: &context)
            }
            references[pending.metadata] = .init(field: metadata.field, path: metadata.path, state: .link(target))
            resolvedLinks += 1
        }
        // All aliases remain live throughout the scan; release only after clearing staging.
        var bytes: UInt64 = 0
        for marker in pending { try context.work(); bytes = try JSONStoreAccounting.sum(bytes, marker.aliasBytes) }
        let count = UInt64(pending.count)
        pending = []
        try accounting.releaseAliases(bytes, count: try JSONStoreAccounting.product(count, 2), context: &context)
    }
    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONConfiguredStore {
        accounting.phase = 8
        phaseObserver?(8)
        try context.work()
        guard let owner, observed, pending.isEmpty, stagedLinks == resolvedLinks,
              summary.visitedCount == 1, summary.emittedCount == 1 else {
            throw JSONFailure(.configuration, code: .invalidOperation)
        }
        for record in records {
            try context.work()
            guard record.referenceRange.lowerBound >= 0, record.referenceRange.upperBound <= references.count else {
                throw JSONFailure(.configuration, code: .invalidOperation)
            }
        }
        for reference in references {
            try context.work()
            if case .link(let target) = reference.state {
                guard target.owner === owner, target.collection >= 0, target.collection < collections.count,
                      target.row >= 0, target.row < collections[target.collection].count else {
                    throw JSONFailure(.configuration, code: .invalidOperation)
                }
            }
        }
        try context.checkpoint()
        let source = try context.transferDocumentOwnership()
        phaseObserver?(8) // completion checkpoint after the one-shot transfer
        let result = JSONConfiguredStore(document: source, profile: profile, owner: owner,
            collections: collections, records: records, references: references,
            overlay: accounting.overlay, aliases: accounting.aliases, profileText: accounting.profileText)
        collections = []; records = []; references = []
        return result
    }
}
