// SPDX-License-Identifier: Apache-2.0
@testable import JSONSchemaExamples
func duplicate(_ state: consuming SchemaExampleTrace) { let other = state; _ = consume state; _ = consume other }
