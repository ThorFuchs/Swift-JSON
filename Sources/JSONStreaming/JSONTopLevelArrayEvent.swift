// SPDX-License-Identifier: Apache-2.0
import JSON
public enum JSONTopLevelArrayEvent: Sendable {
    case element(index: UInt64, value: JSON)
    case documentCompleted(JSONStreamSummary)
}
