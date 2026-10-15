// SPDX-License-Identifier: Apache-2.0
import JSON

package struct FilterCompileFailure: Error, Sendable {
    package let code: String
    package let offset: Int
    package init(_ code: String, at offset: Int) { self.code = code; self.offset = offset }
}
package struct FilterLanguageFailure: Error, Sendable {
    package let code: String
    package let message: String
    package init(_ code: String, message: String? = nil) { self.code = code; self.message = message ?? code }
}
package struct FilterProgram: Sendable {
    package enum Node: Sendable {
        case pending, identity, literal(JSON), variable(String)
        case comma(Int, Int), pipe(Int, Int), fallback(Int, Int)
        case binary(String, Int, Int), unary(String, Int)
        case index(Int, Int), iterate(Int), slice(Int, Int?, Int?), optional(Int), recursive
        case array(Int), object([(Int, Int)]), bind(Int, String, Int)
        case conditional(Int, Int, Int), attempt(Int, Int?), call(String, [Int])
    }
    package let nodes: [Node]
    package let root: Int
    package let sourceRanges: [Range<Int>]
}
package struct FilterToken: Sendable {
    package enum Kind: Sendable { case symbol(String), name(String), variable(String), literal(JSON) }
    package let kind: Kind
    package let range: Range<Int>
    package var text: String? {
        switch kind { case .symbol(let s), .name(let s): s; default: nil }
    }
}
