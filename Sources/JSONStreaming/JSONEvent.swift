// SPDX-License-Identifier: Apache-2.0
import JSON
public struct JSONStreamSummary: Sendable {
    public let records: UInt64
    public let statistics: JSONOperationStatistics
    public init(records: UInt64, statistics: JSONOperationStatistics) { self.records = records; self.statistics = statistics }
}
/// Token events are provisional. Completion follows framing validation, including EOF for a document.
public enum JSONEvent: Sendable {
    case startObject, endObject, startArray, endArray, key(String), scalar(JSON)
    case recordCompleted(JSONStreamSummary), documentCompleted(JSONStreamSummary)
    init(_ event: JSONMachineEvent) {
        switch event.kind {
        case .startObject: self = .startObject
        case .endObject: self = .endObject
        case .startArray: self = .startArray
        case .endArray: self = .endArray
        case .key(let text): self = .key(text)
        case .scalar(let value): self = .scalar(value)
        }
    }
}
