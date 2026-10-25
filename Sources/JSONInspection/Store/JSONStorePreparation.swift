// SPDX-License-Identifier: Apache-2.0
import JSON

internal extension JSONStoreProfile {
    func prepare(accounting a: inout JSONStoreAccounting,
                 context: inout JSONReadPreparationContext) throws {
        try a.reserve(512, context: &context)
        try a.profile(version.rawValue, key: false, context: &context)
        try JSONStoreAccounting.check(collectionsAt.count, a.caps.pathComponents,
                                      name: "pathComponents", phase: 1)
        for (index, part) in collectionsAt.enumerated() {
            try context.work(); try a.reserve(JSONLogicalWeights.indexSlot, context: &context)
            switch part {
            case .key(let key): try a.profile(key.string, key: true, context: &context)
            case .index(let indexValue):
                guard indexValue >= 0 else {
                    throw JSONStoreFailure(.invalidTypedComponent, phase: 1, domain: .profile,
                        path: [.key("collectionsAt"), .index(index), .key("index")])
                }
            }
        }
        switch references {
        case .disabled: try a.profile("disabled", key: false, context: &context)
        case .strict(let marker, let validateTargets):
            try a.profile("strict", key: false, context: &context)
            try a.profile(marker.rawValue, key: false, context: &context)
            guard validateTargets else {
                throw JSONStoreFailure(.invalidReferenceMode, phase: 1, domain: .profile,
                                       path: [.key("references"), .key("validateTargets")])
            }
            try a.profile("collection", key: true, context: &context)
            try a.profile("id", key: true, context: &context)
        }
        var fields = 0
        for (i, collection) in collections.enumerated() {
            try context.work()
            try JSONStoreAccounting.check(i + 1, a.caps.collections, name: "collections", phase: 1)
            try a.reserve(128, context: &context)
            try a.profile(collection.name.string, key: true, identity: true, context: &context)
            for prior in 0..<i {
                try context.work()
                if try context.equalStrings(collections[prior].name.string, collection.name.string) {
                    throw JSONStoreFailure(.duplicateCollectionDeclaration, phase: 1, domain: .profile,
                                          path: [.key("collections"), .index(i), .key("name")])
                }
            }
            guard collection.recordsAt.count == 1, case .key(let selected) = collection.recordsAt[0],
                  try context.equalStrings(selected.string, collection.name.string) else {
                throw JSONStoreFailure(.invalidRecordsAt, phase: 1, domain: .profile,
                                       path: [.key("collections"), .index(i), .key("recordsAt")])
            }
            try a.reserve(JSONLogicalWeights.indexSlot, context: &context)
            try a.profile(selected.string, key: true, identity: true, context: &context)
            try a.profile(collection.idKey.string, key: true, context: &context)
            for (j, field) in collection.referenceFields.enumerated() {
                try context.work()
                try JSONStoreAccounting.check(j + 1, a.caps.referenceFieldsPerCollection,
                                              name: "referenceFieldsPerCollection", phase: 1)
                let nextFields = try JSONStoreAccounting.sum(UInt64(fields), 1)
                guard let checkedFields = Int(exactly: nextFields) else {
                    throw JSONStoreFailure(.counterOverflow, phase: 1, domain: .operation)
                }
                fields = checkedFields
                try JSONStoreAccounting.check(fields, a.caps.referenceFields, name: "referenceFields", phase: 1)
                try a.reserve(64, context: &context)
                try a.profile(field.key.string, key: true, context: &context)
                try a.profile(field.presence.rawValue, key: false, context: &context)
                for prior in 0..<j {
                    try context.work()
                    if try context.equalStrings(collection.referenceFields[prior].key.string, field.key.string) {
                        throw JSONStoreFailure(.duplicateReferenceField, phase: 1, domain: .profile,
                            path: [.key("collections"), .index(i), .key("referenceFields"), .index(j), .key("key")])
                    }
                }
                if try context.equalStrings(collection.idKey.string, field.key.string) {
                    throw JSONStoreFailure(.idReferenceFieldCollision, phase: 1, domain: .profile,
                        path: [.key("collections"), .index(i), .key("referenceFields"), .index(j), .key("key")])
                }
            }
        }
        if case .disabled = references, fields != 0 {
            throw JSONStoreFailure(.disabledReferencesConflict, phase: 1, domain: .profile,
                                   path: [.key("references"), .key("mode")])
        }
    }
}
