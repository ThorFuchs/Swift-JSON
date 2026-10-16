// SPDX-License-Identifier: Apache-2.0
@testable import JSONSchemaExamples
func send<T: Sendable & ~Copyable>(_ value: borrowing T) {}
func transfer(_ state: borrowing SchemaExampleTransport) { send(state) }
