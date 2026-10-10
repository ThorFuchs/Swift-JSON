// SPDX-License-Identifier: Apache-2.0
import Foundation
import MCPReadinessKit
let receipt = try runReadiness()
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(receipt)
if CommandLine.arguments.count == 2 { try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1])) }
else { FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data([10])) }
