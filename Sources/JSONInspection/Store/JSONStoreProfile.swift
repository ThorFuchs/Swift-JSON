// SPDX-License-Identifier: Apache-2.0
import JSON

/// Closed version of the typed configured-store construction contract.
public enum JSONStoreProfileVersion: String, Sendable {
    /// Exact collection arrays, explicit string identifiers and declared reference slots.
    case v1 = "nav12.store-profile/1"
}
/// Closed reference-marker interpretation, independent of JSON Schema $ref.
public enum JSONStoreMarkerVersion: String, Sendable {
    /// An object containing exactly the string members collection and id.
    case v1 = "collection-id/1"
}
/// Requiredness of one explicitly declared reference field.
public enum JSONStoreFieldPresence: String, Sendable {
    /// A missing member is a construction error.
    case required
    /// A missing member is retained as an absent slot.
    case optional
}
/// Explicit reference interpretation; undeclared fields always remain ordinary JSON.
public enum JSONStoreReferences: Sendable {
    /// Interpret no fields as references.
    case disabled
    /// Validate exact markers and their existing targets before publishing a store.
    /// - Parameters:
    ///   - marker: Closed version of the two-member marker grammar.
    ///   - validateTargets: Must be true; false is a typed profile refusal.
    case strict(marker: JSONStoreMarkerVersion, validateTargets: Bool)
}
/// One configured direct reference field; no name or null policy is inferred.
public struct JSONStoreReferenceField: Sendable {
    /// Exact decoded-scalar field name.
    public let key: JSONKey
    /// Whether a missing member is accepted as an absent slot.
    public let presence: JSONStoreFieldPresence
    /// Whether explicit JSON null is accepted as a null slot.
    public let nullable: Bool
    /// Captures trusted typed configuration, checked on construction's one ledger.
    /// - Parameters:
    ///   - key: Literal exact member name.
    ///   - presence: Required or optional field policy.
    ///   - nullable: Explicit null policy, independent of absence.
    public init(key: JSONKey, presence: JSONStoreFieldPresence, nullable: Bool) {
        self.key = key; self.presence = presence; self.nullable = nullable
    }
}
/// A named direct array collection with an explicit exact string-ID field.
public struct JSONStoreCollectionProfile: Sendable {
    /// Exact collection name; canonical Unicode equivalence does not merge it.
    public let name: JSONKey
    /// Must be exactly one key component matching name inside collectionsAt.
    public let recordsAt: [JSONLocationComponent]
    /// Exact direct record member holding its string ID; no id/_id fallback.
    public let idKey: JSONKey
    /// Declared reference slots, interpreted in this order.
    public let referenceFields: [JSONStoreReferenceField]
    /// Captures an explicit collection declaration without scanning source data.
    /// - Parameters:
    ///   - name: Exact direct collection name.
    ///   - recordsAt: One direct key equal to name; checked during preparation.
    ///   - idKey: Required exact string identifier member.
    ///   - referenceFields: Ordered explicit reference declarations, or [].
    public init(name: JSONKey, recordsAt: [JSONLocationComponent], idKey: JSONKey,
                referenceFields: [JSONStoreReferenceField]) {
        self.name = name; self.recordsAt = recordsAt; self.idKey = idKey
        self.referenceFields = referenceFields
    }
}
/// Closed native configuration, checked before source admission on the same ledger.
/// It is neither a JSON wire-profile decoder nor an online resource resolver.
public struct JSONStoreProfile: Sendable {
    /// Closed construction contract version.
    public let version: JSONStoreProfileVersion
    /// Absolute exact typed selection of the collections object.
    public let collectionsAt: [JSONLocationComponent]
    /// Explicit collection declarations; unconfigured source collections are refused.
    public let collections: [JSONStoreCollectionProfile]
    /// Disabled or strict reference interpretation; no ambient reference behavior.
    public let references: JSONStoreReferences
    /// Captures immutable typed policy; construction performs bounded validation.
    /// - Parameters:
    ///   - version: Explicit closed profile version.
    ///   - collectionsAt: Absolute collections-object selection, including [].
    ///   - collections: Exact declared direct collections.
    ///   - references: Explicit reference mode.
    public init(version: JSONStoreProfileVersion, collectionsAt: [JSONLocationComponent],
                collections: [JSONStoreCollectionProfile], references: JSONStoreReferences) {
        self.version = version; self.collectionsAt = collectionsAt
        self.collections = collections; self.references = references
    }
}

/// Finite inclusive construction policies within unchanged native limits.
/// Maxima are not jointly achievable capacity or RSS/throughput guarantees.
public struct JSONStoreCaps: Sendable {
    /// Maximum configured/source collections.
    public var collections = 256
    /// Maximum records in each complete collection.
    public var recordsPerCollection = 10_000
    /// Maximum records across all collections.
    public var records = 10_000
    /// Maximum configured reference fields in each collection.
    public var referenceFieldsPerCollection = 16
    /// Maximum configured fields across all collections.
    public var referenceFields = 4_096
    /// Maximum interpreted slots, including absent and null slots.
    public var referenceSlots = 100_000
    /// Maximum staged links; repeated targets remain distinct slots.
    public var links = 100_000
    /// Maximum UTF-8 bytes in a collection or record identity.
    public var identityBytes = 4_096
    /// Maximum cumulative profile UTF-8 text bytes.
    public var profileTextBytes = 1_048_576
    /// Maximum live logical ID/marker text-alias bytes.
    public var aliasBytes = 16_777_216
    /// Maximum typed components in generated/configured paths.
    public var pathComponents = 128
    /// Maximum conservative logical metadata/scratch overlay bytes.
    public var overlayBytes = 33_554_432
    /// Uses finite policy defaults; zero is finite, negatives and Int.max invalid.
    public init() {}
    internal func validate() throws {
        for value in [collections, recordsPerCollection, records, referenceFieldsPerCollection,
                      referenceFields, referenceSlots, links, identityBytes, profileTextBytes,
                      aliasBytes, pathComponents, overlayBytes] {
            guard value >= 0, value < Int.max else { throw JSONFailure(.configuration, code: .invalidLimits) }
        }
    }
}

/// Stable typed construction/selection refusals, separate from native quota errors.
public enum JSONStoreFailureCode: String, Sendable {
    /// A configured typed index is negative.
    case invalidTypedComponent
    /// Two profile collection names have identical decoded scalars.
    case duplicateCollectionDeclaration
    /// A collection selector is not its one exact direct name.
    case invalidRecordsAt
    /// Two configured fields have identical decoded scalars.
    case duplicateReferenceField
    /// An ID member is also declared as a reference.
    case idReferenceFieldCollision
    /// Reference declarations conflict with disabled references.
    case disabledReferencesConflict
    /// Strict mode attempted to disable target validation.
    case invalidReferenceMode
    /// The selected collections value is not an object.
    case collectionsNotObject
    /// A source collection has no explicit declaration.
    case unconfiguredCollection
    /// A declared collection value is not an array.
    case collectionNotArray
    /// A declared collection is absent from the source.
    case missingConfiguredCollection
    /// A physical record is not an object.
    case recordWrongKind
    /// The required ID member is absent.
    case recordIDMissing
    /// The required ID is explicit null.
    case recordIDNull
    /// The ID is present with a non-string kind.
    case recordIDWrongKind
    /// The second exact duplicate ID retains its first ID path.
    case duplicateRecordID
    /// A required declared reference field is absent.
    case referenceMissing
    /// A declared reference field forbids explicit null.
    case referenceNull
    /// A non-null marker is not an object.
    case referenceMarkerWrongKind
    /// An exact collection/id marker member is missing.
    case referenceMarkerMissing
    /// A marker member has a non-string kind.
    case referenceMarkerMemberWrongKind
    /// A marker has an undeclared extra member.
    case referenceMarkerExtra
    /// A marker names an unknown exact collection.
    case referenceUnknownCollection
    /// A marker names a missing ID in an existing collection.
    case referenceDanglingID
    /// The collections selection is missing; coreCause retains the original error.
    case selectionMissing
    /// The collections selection crosses a wrong kind.
    case selectionWrongKind
    /// A finite store construction or follow policy was exceeded.
    case capacityExceeded
    /// Checked size/counter arithmetic overflowed.
    case counterOverflow
    /// A local position is out of bounds or belongs to another store instance.
    case invalidPosition
    /// A lookup request names no declared physical collection.
    case unknownCollection
}
/// The authority that refused construction or a read-only operation.
public enum JSONStoreFailureDomain: String, Sendable {
    /// Invalid typed configuration, before source admission.
    case profile
    /// Invalid source structure or declared references.
    case source
    /// Invalid local position, query policy or checked capacity.
    case operation
}
/// Precise checked refusal; no partial store or null substitute is published.
public struct JSONStoreFailure: Error, Sendable {
    /// Stable refusal identity.
    public let code: JSONStoreFailureCode
    /// Construction phases1...8; ordinary metadata0 and owned queries9.
    public let phase: Int
    /// Profile, source or operation authority.
    public let domain: JSONStoreFailureDomain
    /// Exact source/request path, empty when no location applies.
    public let path: [JSONLocationComponent]
    /// First occurrence for a duplicate ID; never a normalized key.
    public let firstPath: [JSONLocationComponent]?
    /// Coherent original span, or nil when unavailable.
    public let sourceSpan: JSONSourceSpan?
    /// Original core selection failure without loss of its resource/location metadata.
    public let coreCause: JSONFailure?
    /// Named construction/follow capacity for a capacity refusal.
    public let capacity: String?
    /// Inclusive configured capacity, distinct from physical memory.
    public let limit: Int?
    internal init(_ code: JSONStoreFailureCode, phase: Int, domain: JSONStoreFailureDomain,
                  path: [JSONLocationComponent] = [], firstPath: [JSONLocationComponent]? = nil,
                  sourceSpan: JSONSourceSpan? = nil, coreCause: JSONFailure? = nil,
                  capacity: String? = nil, limit: Int? = nil) {
        self.code = code; self.phase = phase; self.domain = domain; self.path = path
        self.firstPath = firstPath; self.sourceSpan = sourceSpan; self.coreCause = coreCause
        self.capacity = capacity; self.limit = limit
    }
}
