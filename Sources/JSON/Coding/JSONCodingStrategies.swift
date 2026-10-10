// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct JSONCodingOptions: Sendable {
    public enum DateStrategy: Sendable { case deferredToDate, secondsSince1970, iso8601 }
    public enum DataStrategy: Sendable { case base64, deferredToData }
    public var limits: JSONLimits
    public var dateStrategy: DateStrategy
    public var dataStrategy: DataStrategy
    public var userInfo: [CodingUserInfoKey: any Sendable]
    public init(limits: JSONLimits = .balanced, dateStrategy: DateStrategy = .deferredToDate,
                dataStrategy: DataStrategy = .base64, userInfo: [CodingUserInfoKey: any Sendable] = [:]) {
        self.limits = limits; self.dateStrategy = dateStrategy; self.dataStrategy = dataStrategy; self.userInfo = userInfo
    }
}
package final class JSONCodingState {
    package var meter: JSONWorkMeter
    package let options: JSONCodingOptions
    package var failure: (any Error)?
    package private(set) var bridgedUserInfo: [CodingUserInfoKey: Any] = [:]
    private var prepared = false
    package init(options: JSONCodingOptions, meter: consuming JSONWorkMeter) {
        self.options = options; self.meter = meter
    }
    package func check() throws {
        if let failure { throw failure }; try meter.checkpoint()
        if !prepared {
            try meter.require(.objectMembers, UInt64(options.userInfo.count))
            for (key, value) in options.userInfo {
                try JSONAdmission.text(key.rawValue, key: true, meter: &meter, owned: true)
                try meter.work(); try meter.retain(JSONLogicalWeights.member)
                bridgedUserInfo[key] = value
            }
            prepared = true
        }
    }
    package func latch(_ action: () throws -> Void) { do { try action() } catch { if failure == nil { failure = error } } }
    package func path(_ path: [any CodingKey], appending key: any CodingKey) throws -> [any CodingKey] {
        try check(); try meter.require(.maxDepth, UInt64(path.count) + 1)
        var result: [any CodingKey] = []
        for part in path { try meter.work(); try meter.retain(16); result.append(part) }
        try JSONAdmission.text(key.stringValue, key: true, meter: &meter, owned: true)
        try meter.retain(16); result.append(key); return result
    }
}
package struct JSONCodingKey: CodingKey {
    package let stringValue: String
    package let intValue: Int?
    package init(_ string: String) { stringValue = string; intValue = nil }
    package init(index: Int) { stringValue = String(index); intValue = index }
    package init?(stringValue: String) { self.init(stringValue) }
    package init?(intValue: Int) { self.init(index: intValue) }
}
