// SPDX-License-Identifier: Apache-2.0
import JSONTransform
func duplicate(_ execution: consuming JSONTransformExecution) {
    let first = consume execution
    let second = consume execution
    _ = consume first
    _ = consume second
}
