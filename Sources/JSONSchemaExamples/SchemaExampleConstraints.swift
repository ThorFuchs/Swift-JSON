// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

struct SchemaExampleConstraint {
    let node: JSONSchemaQualifiedNode
    let view: JSONSchemaQualifiedNode.Declaration
    func value(_ key: JSONSchemaPlan.Keyword, meter: inout JSONWorkMeter) throws -> JSON? {
        guard view.vocabulary.applies(key) else { return nil }
        return try view.raw.objectValue?.lookup(key.rawValue, meter: &meter)
    }
    func children(_ keyword: JSONSchemaPlan.Keyword, token: String? = nil,
                  meter: inout JSONWorkMeter) throws -> [JSONSchemaQualifiedNode] {
        guard view.vocabulary.applies(keyword) else { return [] }
        var result: [JSONSchemaQualifiedNode] = []
        for i in 0..<node.childCount {
            let child = try node.child(at: i, meter: &meter)
            guard child.keyword == keyword else { continue }
            if let token {
                guard let spelling = child.token?.string, try JSONComparison.textEquals(spelling, token, meter: &meter) else { continue }
            }
            try meter.retain(JSONLogicalWeights.indexSlot); result.append(child.target)
        }
        return result
    }
}

enum SchemaExampleConjunction {
    private enum Step { case enter(JSONSchemaQualifiedNode), exit(Int) }
    static func gather(_ nodes: [JSONSchemaQualifiedNode], meter: inout JSONWorkMeter) throws -> [SchemaExampleConstraint] {
        var pending: [Step] = [], active: [Int] = [], seen: [Int] = [], result: [SchemaExampleConstraint] = []
        func push(_ step: Step, meter: inout JSONWorkMeter) throws {
            try meter.require(.evaluationFrames, UInt64(pending.count) + 1)
            try meter.retain(JSONLogicalWeights.frame); pending.append(step)
        }
        for node in nodes.reversed() { try push(.enter(node), meter: &meter) }
        while let step = pending.popLast() {
            try meter.work(); try meter.release(JSONLogicalWeights.frame)
            switch step {
            case .exit(let identity):
                guard active.last == identity else { throw JSONFailure(.configuration, code: .invalidOperation) }
                active.removeLast(); try meter.release(JSONLogicalWeights.indexSlot)
            case .enter(let node):
                for id in active {
                    try meter.work()
                    if id == node.identity { throw JSONSchemaExampleFailure.unsupportedFeature(.cyclicReference) }
                }
                var visited = false
                for id in seen { try meter.work(); if id == node.identity { visited = true; break } }
                if visited { continue }
                try meter.charge(.schemaNodes); try meter.retain(JSONLogicalWeights.indexSlot * 2 + 64)
                seen.append(node.identity); active.append(node.identity)
                let view = try node.declaration(meter: &meter), constraint = SchemaExampleConstraint(node: node, view: view)
                result.append(constraint)
                try push(.exit(node.identity), meter: &meter)
                // AllOf is conjunction; no alternative branch or conditional is flattened.
                let children = try constraint.children(.allOf, meter: &meter)
                for child in children.reversed() { try push(.enter(child), meter: &meter) }
                for kind in SchemaExampleVersion.referencePushOrder {
                    for i in 0..<node.referenceCount {
                        let edge = try node.reference(at: i, meter: &meter)
                        if edge.requiresDynamicScope { throw JSONSchemaExampleFailure.unsupportedFeature(.dynamicReference) }
                        if edge.keyword == kind { try meter.charge(.referenceEdges); try push(.enter(edge.target), meter: &meter) }
                    }
                }
            }
        }
        return result
    }
}
