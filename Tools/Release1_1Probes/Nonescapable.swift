// SPDX-License-Identifier: Apache-2.0
final class Owner {}
public struct Cursor: ~Escapable {
    let value: Int
    init(owner: borrowing Owner) { value = 42 }
    public subscript(_ key: String) -> Cursor { get throws { self } }
}
func read<Result>(_ body: (borrowing Cursor) throws -> Result) rethrows -> Result {
    let owner = Owner()
    let cursor = Cursor(owner: owner)
    return try body(cursor)
}
