// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONNavigation

private func navigationFixture(_ name: String) throws -> JSON {
    let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
    return try JSONParser().parse(Data(contentsOf: folder.appendingPathComponent(name)))
}

@Test func navigationPinnedPacketPathsAndUnevenDFS() throws {
    let root = try navigationFixture("paths.json")
    var witnessed = 0
    _ = try JSONTraversal(document: .init(root: root)).visit { hit, value in
        let tokens = hit.absoluteLocation.map { p in
            switch p { case .key(let k): return k.string; case .index(let i): return String(i) }
        }
        let resolved = try JSONPointer(tokens: tokens).resolve(in: root)
        #expect(resolved == value)
        witnessed += 1
        return .continue
    }
    #expect(witnessed == 12)
    let tree = try navigationFixture("structures.json")
    let paths = try JSONTraversal(document: .init(root: tree)).collect(scope: .subtree(at: [.key("tree")])).result.nodes.map(\.absoluteLocation)
    #expect(paths == [[.key("tree")], [.key("tree"), .key("left")], [.key("tree"), .key("left"), .key("leaf")], [.key("tree"), .key("right")], [.key("tree"), .key("right"), .index(0)], [.key("tree"), .key("right"), .index(1)], [.key("tree"), .key("right"), .index(1), .key("leaf")]])
}

@Test func navigationCapturedRevisionNeverRebinds() throws {
    let revisions = try navigationFixture("source-revisions.json")
    let old = try revisions.requiredMember("rev1"), new = try revisions.requiredMember("rev2")
    let oldTraversal = JSONTraversal(document: .init(root: old))
    let newTraversal = JSONTraversal(document: oldTraversal.document.replacingRoot(new))
    var oldTail = JSON.null, newTail = JSON.null
    _ = try oldTraversal.visit { hit, value in if hit.absoluteLocation == [.key("rows"), .index(2)] { oldTail = value }; return .continue }
    _ = try newTraversal.visit { hit, value in if hit.absoluteLocation == [.key("rows"), .index(2)] { newTail = value }; return .continue }
    #expect(oldTail == 3 && newTail == 4 && oldTraversal.document.root != newTraversal.document.root)
}
