// SPDX-License-Identifier: Apache-2.0
import JSON
/// Declaration values, separate from evaluation annotations. Defaults never mutate an instance.
public struct JSONDeclaredAnnotations: Sendable {
    public let values: JSONObject
    public func presence(of key: JSONKey) -> JSONPresence<JSON> { values.presence(of: key) }
    package init(values: JSONObject) { self.values = values }
}
