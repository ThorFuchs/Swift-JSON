// SPDX-License-Identifier: Apache-2.0
import JSON

package enum JSONStoreProfileVersion: String, Sendable { case v1 = "nav12.store-profile/1" }
package enum JSONStoreMarkerVersion: String, Sendable { case v1 = "collection-id/1" }
package enum JSONStoreFieldPresence: String, Sendable { case required, optional }
package enum JSONStoreReferences: Sendable {
    case disabled
    case strict(marker: JSONStoreMarkerVersion, validateTargets: Bool)
}
package struct JSONStoreReferenceField: Sendable {
    package let key: JSONKey
    package let presence: JSONStoreFieldPresence
    package let nullable: Bool
    package init(key: JSONKey, presence: JSONStoreFieldPresence, nullable: Bool) {
        self.key = key; self.presence = presence; self.nullable = nullable
    }
}
package struct JSONStoreCollectionProfile: Sendable {
    package let name: JSONKey
    package let recordsAt: [JSONLocationComponent]
    package let idKey: JSONKey
    package let referenceFields: [JSONStoreReferenceField]
    package init(name: JSONKey, recordsAt: [JSONLocationComponent], idKey: JSONKey,
                 referenceFields: [JSONStoreReferenceField]) {
        self.name = name; self.recordsAt = recordsAt; self.idKey = idKey
        self.referenceFields = referenceFields
    }
}
/// Closed native input, not a new JSON wire decoder or public configuration API.
package struct JSONStoreProfile: Sendable {
    package let version: JSONStoreProfileVersion
    package let collectionsAt: [JSONLocationComponent]
    package let collections: [JSONStoreCollectionProfile]
    package let references: JSONStoreReferences
    package init(version: JSONStoreProfileVersion, collectionsAt: [JSONLocationComponent],
                 collections: [JSONStoreCollectionProfile], references: JSONStoreReferences) {
        self.version = version; self.collectionsAt = collectionsAt
        self.collections = collections; self.references = references
    }
}

/// Finite prototype policy only. All maxima inclusive, inside unchanged core limits.
package struct JSONStoreCaps: Sendable {
    package var collections = 256
    package var recordsPerCollection = 10_000
    package var records = 10_000
    package var referenceFieldsPerCollection = 16
    package var referenceFields = 4_096
    package var referenceSlots = 100_000
    package var links = 100_000
    package var identityBytes = 4_096
    package var profileTextBytes = 1_048_576
    package var aliasBytes = 16_777_216
    package var pathComponents = 128
    package var overlayBytes = 33_554_432
    package init() {}
    internal func validate() throws {
        // Fixed bootstrap size; no source/profile text scanned before native health.
        for value in [collections, recordsPerCollection, records, referenceFieldsPerCollection,
                      referenceFields, referenceSlots, links, identityBytes, profileTextBytes,
                      aliasBytes, pathComponents, overlayBytes] {
            guard value >= 0, value < Int.max else { throw JSONFailure(.configuration, code: .invalidLimits) }
        }
    }
}

package enum JSONStoreFailureCode: String, Sendable {
    case invalidTypedComponent, duplicateCollectionDeclaration, invalidRecordsAt
    case duplicateReferenceField, idReferenceFieldCollision, disabledReferencesConflict
    case invalidReferenceMode, collectionsNotObject, unconfiguredCollection, collectionNotArray
    case missingConfiguredCollection, recordWrongKind, recordIDMissing, recordIDNull, recordIDWrongKind
    case duplicateRecordID, referenceMissing, referenceNull, referenceMarkerWrongKind
    case referenceMarkerMissing, referenceMarkerMemberWrongKind, referenceMarkerExtra
    case referenceUnknownCollection, referenceDanglingID, selectionMissing, selectionWrongKind
    case capacityExceeded, counterOverflow, invalidPosition
}
package enum JSONStoreFailureDomain: String, Sendable { case profile, source, operation }
/// Source path and core cause are separate; missing targets have no invented span.
package struct JSONStoreFailure: Error, Sendable {
    package let code: JSONStoreFailureCode
    package let phase: Int
    package let domain: JSONStoreFailureDomain
    package let path: [JSONLocationComponent]
    package let firstPath: [JSONLocationComponent]?
    package let sourceSpan: JSONSourceSpan?
    package let coreCause: JSONFailure?
    package let capacity: String?
    package let limit: Int?
    internal init(_ code: JSONStoreFailureCode, phase: Int, domain: JSONStoreFailureDomain,
                  path: [JSONLocationComponent] = [], firstPath: [JSONLocationComponent]? = nil,
                  sourceSpan: JSONSourceSpan? = nil, coreCause: JSONFailure? = nil,
                  capacity: String? = nil, limit: Int? = nil) {
        self.code = code; self.phase = phase; self.domain = domain; self.path = path
        self.firstPath = firstPath; self.sourceSpan = sourceSpan; self.coreCause = coreCause
        self.capacity = capacity; self.limit = limit
    }
}
