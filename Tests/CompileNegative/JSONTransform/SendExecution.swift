// SPDX-License-Identifier: Apache-2.0
import JSONTransform
func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {}
func sendExecution(_ execution: borrowing JSONTransformExecution) { requireSendable(execution) }
