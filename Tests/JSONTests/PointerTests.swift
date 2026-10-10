// SPDX-License-Identifier: Apache-2.0
import Testing
import Foundation
import JSON
@Test func pointerEscapingFragmentsAndRuntimeKinds() throws {
    let value = try JSONParser().parse(#"{"a/b":{"~":{"0":[10,20]}},"":3}"#)
    let pointer = try JSONPointer(tokens: ["a/b", "~", "0"]).appending(index: 1)
    #expect(pointer.string == "/a~1b/~0/0/1")
    #expect(try pointer.resolve(in: value) == 20)
    #expect(try JSONPointer.uriFragment("#/a~1b/~0/0/1").resolve(in: value) == 20)
    #expect(try JSONPointer(parsing: "/").resolve(in: value) == 3)
    #expect(try JSONPointer(parsing: "").resolve(in: value) == value)
    #expect(try JSONPointer.uriFragment("#/%7E1").tokens == [JSONKey("/")])
    #expect(try JSONPointer.uriFragment("#/%257E1").tokens == [JSONKey("%7E1")])
}
@Test(arguments: ["foo", "/~", "/~2", "/a~b"])
func invalidPointerEscapes(text: String) { #expect(throws: JSONFailure.self) { try JSONPointer(parsing: text) } }
@Test(arguments: ["/01", "/-1", "/-", "/2", "/18446744073709551616"])
func strictArrayIndexGrammar(text: String) throws {
    let pointer = try JSONPointer(parsing: text)
    #expect(throws: JSONFailure.self) { try pointer.resolve(in: .array([1, 2])) }
}
@Test func sourceSpansUseTypedPathsAndInvalidateOnEdit() throws {
    let document = try JSONParser().parseDocument(Data(#"{"0":[true]}"#.utf8))
    let candidate = try document.sourceMap?.span(at: [.key("0"), .index(0)])
    let span = try #require(candidate)
    #expect(span.start == 6 && span.end == 10)
    #expect(document.replacingRoot(.null).sourceMap == nil)
    #expect(document.replacingRoot(.null).sourceBytes == nil)
}
