// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONTransform
func escapeScope(_ plan: JSONTransformProgram) throws {
    var saved: (() throws -> JSONTransformOutput?)?
    _ = try plan.withExecution(input: .null) { execution in saved = { try execution.next() } }
    _ = try saved?()
}
