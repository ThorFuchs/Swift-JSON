// SPDX-License-Identifier: Apache-2.0
@testable import JSONSchemaExamples
func move(_ state: consuming SchemaExampleRandom) { let moved = state; _ = consume moved }
func share<T: Sendable>(_ value: T) {}
func sharePrepared(_ value: JSONSchemaExampleGenerator) { share(value) }
