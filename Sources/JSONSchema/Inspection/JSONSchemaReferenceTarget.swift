// SPDX-License-Identifier: Apache-2.0
import JSON

/// Initial indexed target in an immutable compiled snapshot. Dynamic scope may replace it during evaluation.
public struct JSONSchemaReferenceTarget: Sendable {
    public let keyword: JSONKey
    public let resourceURI: JSONSchemaURI
    public let pointer: JSONPointer
    public let requiresDynamicScope: Bool
    package init(keyword: JSONKey, resourceURI: JSONSchemaURI, pointer: JSONPointer, requiresDynamicScope: Bool) {
        self.keyword = keyword; self.resourceURI = resourceURI; self.pointer = pointer; self.requiresDynamicScope = requiresDynamicScope
    }
}
