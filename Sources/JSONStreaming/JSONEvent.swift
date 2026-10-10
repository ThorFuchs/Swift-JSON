// SPDX-License-Identifier: Apache-2.0
import JSON
/// A cumulative completion receipt for the enclosing stream iterator.
public struct JSONStreamSummary: Sendable {
    /// The cumulative completed record count for the iterator.
    public let records: UInt64
    /// Versioned accounting for the completed operation or cumulative stream lifetime.
    public let statistics: JSONOperationStatistics
    /// Pairs a cumulative completed record count with iterator-lifetime accounting.
    ///
    /// - Parameters:
    ///   - records: The cumulative completed record count.
    ///   - statistics: Already recorded successful operation accounting.
    public init(records: UInt64, statistics: JSONOperationStatistics) { self.records = records; self.statistics = statistics }
}
/// Provisional syntax events and explicit framing completion receipts.
public enum JSONEvent: Sendable {
    /// An opening object delimiter; the enclosing document remains provisional.
    case startObject
    /// A closing object delimiter; trailing data or EOF may still fail.
    case endObject
    /// An opening array delimiter; the enclosing document remains provisional.
    case startArray
    /// A closing array delimiter; this does not certify document completion.
    case endArray
    /// A complete decoded exact-key token.
    case key(String)
    /// A complete scalar token; framing completion is still required.
    case scalar(JSON)
    /// A value framing boundary has been certified; later records may still fail.
    case recordCompleted(JSONStreamSummary)
    /// Closing syntax, trailing whitespace and EOF have certified the single document.
    case documentCompleted(JSONStreamSummary)
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
