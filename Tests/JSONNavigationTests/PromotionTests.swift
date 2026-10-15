// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONNavigation

@Test func navigationPromotionDepthValidationPreservesAdmissionPrecedence() throws {
    for oversized in [false, true] {
        var limits = JSONLimits.balanced; limits[.nodes] = 1
        let value: JSON = oversized ? .array([.null]) : .null
        do {
            _ = try JSONTraversal(document: .init(root: value), limits: limits).visit(options: .init(depthLimit: -1)) { _, _ in
                Issue.record("Invalid invocation must not call visitor"); return .continue
            }
            Issue.record("Expected refusal")
        } catch let failure as JSONFailure {
            #expect(failure.category == (oversized ? .resource : .configuration))
            #expect(failure.code == (oversized ? .limitExceeded : .invalidLimits))
            #expect(failure.resource?.metric == (oversized ? .nodes : nil))
        }
    }
}

@Test func navigationPromotionRecordValidationPreservesAdmissionPrecedence() throws {
    for oversized in [false, true] {
        var limits = JSONLimits.balanced; limits[.nodes] = 1
        let value: JSON = oversized ? .array([.null]) : .null
        do {
            _ = try JSONTraversal(document: .init(root: value), limits: limits).collect(maximumRecords: -1)
            Issue.record("Expected refusal")
        } catch let failure as JSONFailure {
            #expect(failure.category == (oversized ? .resource : .configuration))
            #expect(failure.code == (oversized ? .limitExceeded : .invalidLimits))
            #expect(failure.resource?.metric == (oversized ? .nodes : nil))
        }
    }
}
