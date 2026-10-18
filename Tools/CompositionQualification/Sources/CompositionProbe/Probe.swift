// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema

/// Minimal ordinary public consumer, also compiled for supported Apple SDKs.
public func compositionProbe(_ data: Data) throws -> JSONOperationReport<JSON> {
    try JSON.withComposition { (scope: borrowing JSONCompositionScope) in
        let document = try scope.parseDocument(data)
        try adapterStep(scope)
        let path = try scope.pointer(tokens: ["count"])
        let uri = try scope.uri("https://example.invalid/schema.json#/$defs/count")
        _ = try scope.removingFragment(uri)
        return try scope.resolve(path, in: document.root)
    }
}

private func adapterStep(_ scope: borrowing JSONCompositionScope) throws {
    try scope.reserveExternalLogicalBytes(1, count: 32, overhead: 32)
    try scope.chargeExternalWork(1)
}
