// SPDX-License-Identifier: Apache-2.0
@testable import JSONSchemaExamples
func duplicate(_ state: consuming SchemaExampleRandom) { let other = state; _ = consume state; _ = consume other }
