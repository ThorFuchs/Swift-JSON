// SPDX-License-Identifier: Apache-2.0
import JSON

/// Closed version of the typed configured-store construction contract.
public enum JSONStoreProfileVersion: String, Sendable {
    /// Exact collection arrays, explicit typed identifiers and declared reference slots.
    case v1 = "nav12.store-profile/1"
}
/// Closed reference-marker interpretation, independent of JSON Schema $ref.
public enum JSONStoreMarkerVersion: String, Sendable {
    /// An object containing exactly a string collection member and an id member
    /// whose kind matches the target collection's ``JSONStoreIDKind``.
    case v1 = "collection-id/1"
}
/// The JSON kind a collection's ID member must have; nothing is converted or inferred.
public enum JSONStoreIDKind: String, Sendable {
    /// A JSON string, compared by exact decoded Unicode scalars.
    case string
    /// A JSON number with no fractional part, compared by exact mathematical value.
    /// Equivalent spellings such as `7`, `7.0` and `7e0` are the same ID; fractions,
    /// strings such as `"7"` and other kinds are refused. No Double conversion occurs.
    case integer
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
    /// Target validation is always on; an unvalidated store cannot be built.
    /// - Parameter marker: Closed version of the two-member marker grammar.
    case strict(marker: JSONStoreMarkerVersion)
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
/// A named direct array collection with an explicit exact, typed ID field.
public struct JSONStoreCollectionProfile: Sendable {
    /// Exact collection name; canonical Unicode equivalence does not merge it.
    public let name: JSONKey
    /// Must be exactly one key component matching name inside collectionsAt.
    public let recordsAt: [JSONLocationComponent]
    /// Exact direct record member holding its ID; no id/_id fallback.
    public let idKey: JSONKey
    /// Required JSON kind of every ID in this collection.
    public let idKind: JSONStoreIDKind
    /// Declared reference slots, interpreted in this order.
    public let referenceFields: [JSONStoreReferenceField]
    /// Captures an explicit collection declaration without scanning source data.
    /// - Parameters:
    ///   - name: Exact direct collection name.
    ///   - recordsAt: One direct key equal to name; checked during preparation.
    ///   - idKey: Required exact identifier member.
    ///   - idKind: Required ID kind; string by default.
    ///   - referenceFields: Ordered explicit reference declarations, or [].
    public init(name: JSONKey, recordsAt: [JSONLocationComponent], idKey: JSONKey,
                idKind: JSONStoreIDKind = .string, referenceFields: [JSONStoreReferenceField]) {
        self.name = name; self.recordsAt = recordsAt; self.idKey = idKey
        self.idKind = idKind; self.referenceFields = referenceFields
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
    /// The ID is present with a kind other than the collection's ``JSONStoreIDKind``,
    /// including a fractional number for an integer-ID collection.
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
    /// The marker collection is not a string, or its id is neither a string nor an
    /// integral number.
    case referenceMarkerMemberWrongKind
    /// A marker has an undeclared extra member.
    case referenceMarkerExtra
    /// A marker names an unknown exact collection.
    case referenceUnknownCollection
    /// A marker names a missing ID in an existing collection. IDs of a different
    /// kind never match, so `"7"` does not reach the integer ID `7`.
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
/// Where a store refusal happened: a construction phase, metadata access or a query.
public enum JSONStoreFailurePhase: Int, Sendable {
    /// Fixed metadata access on a built store, which opens no ledger.
    case metadata = 0
    /// Typed profile validation and preparation, before source admission.
    case profile = 1
    /// Owner allocation after the profile was admitted.
    case ownership = 2
    /// Selection of the configured collections object.
    case selection = 3
    /// Collection headers: declared, present and array-shaped collections.
    case collections = 4
    /// Record shapes, typed IDs and duplicate detection.
    case identifiers = 5
    /// Declared reference slots and marker grammar.
    case references = 6
    /// Marker target resolution.
    case targets = 7
    /// Final checks and publication of the immutable store.
    case publication = 8
    /// An owned lookup, value read or follow on a built store.
    case query = 9
}
/// A named finite policy that a ``JSONStoreFailureCode/capacityExceeded`` refusal hit.
public enum JSONStoreCapacity: String, Sendable {
    /// ``JSONStoreCaps/collections``.
    case collections
    /// ``JSONStoreCaps/recordsPerCollection``.
    case recordsPerCollection
    /// ``JSONStoreCaps/records``.
    case records
    /// ``JSONStoreCaps/referenceFieldsPerCollection``.
    case referenceFieldsPerCollection
    /// ``JSONStoreCaps/referenceFields``.
    case referenceFields
    /// ``JSONStoreCaps/referenceSlots``.
    case referenceSlots
    /// ``JSONStoreCaps/links``.
    case links
    /// ``JSONStoreCaps/identityBytes``.
    case identityBytes
    /// ``JSONStoreCaps/profileTextBytes``.
    case profileTextBytes
    /// ``JSONStoreCaps/aliasBytes``.
    case aliasBytes
    /// ``JSONStoreCaps/pathComponents``.
    case pathComponents
    /// ``JSONStoreCaps/overlayBytes``.
    case overlayBytes
    /// ``JSONStoreFollowLimits/maximumDepth``.
    case maximumDepth
    /// ``JSONStoreFollowLimits/maximumFrontier``.
    case maximumFrontier
    /// ``JSONStoreFollowLimits/maximumVisited``.
    case maximumVisited
    /// ``JSONStoreFollowLimits/maximumResults``.
    case maximumResults
}
/// Precise checked refusal; no partial store or null substitute is published.
public struct JSONStoreFailure: Error, Sendable, Equatable {
    /// Stable refusal identity.
    public let code: JSONStoreFailureCode
    /// Construction phase, metadata access or owned query that refused.
    public let phase: JSONStoreFailurePhase
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
    public let capacity: JSONStoreCapacity?
    /// Inclusive configured capacity, distinct from physical memory.
    public let limit: Int?
    internal init(_ code: JSONStoreFailureCode, phase: JSONStoreFailurePhase, domain: JSONStoreFailureDomain,
                  path: [JSONLocationComponent] = [], firstPath: [JSONLocationComponent]? = nil,
                  sourceSpan: JSONSourceSpan? = nil, coreCause: JSONFailure? = nil,
                  capacity: JSONStoreCapacity? = nil, limit: Int? = nil) {
        self.code = code; self.phase = phase; self.domain = domain; self.path = path
        self.firstPath = firstPath; self.sourceSpan = sourceSpan; self.coreCause = coreCause
        self.capacity = capacity; self.limit = limit
    }
}
