// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONTransform
func replaceScope(_ plan: JSONTransformProgram) throws {
    _ = try plan.withExecution(input: .null) { outer in
        _ = try plan.withExecution(input: .null) { inner in swap(&outer, &inner) }
    }
}
