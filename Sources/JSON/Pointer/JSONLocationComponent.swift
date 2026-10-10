// SPDX-License-Identifier: Apache-2.0
public enum JSONLocationComponent: Sendable, Hashable, Codable {
    case key(JSONKey), index(Int)
}
