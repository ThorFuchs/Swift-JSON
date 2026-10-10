// SPDX-License-Identifier: Apache-2.0
import Foundation
import Darwin

@main struct Qualification {
    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        var registry: String?, output: String?, all = false
        while !arguments.isEmpty {
            let argument = arguments.removeFirst()
            if argument == "--all" { all = true }
            else if (argument == "--registry" || argument == "--output"), !arguments.isEmpty {
                let value = arguments.removeFirst()
                if argument == "--registry" { registry = value } else { output = value }
            } else { print("Usage: Qualification --all --registry PATH --output PATH"); exit(2) }
        }
        guard all, let registry, let output else { print("Usage: Qualification --all --registry PATH --output PATH"); exit(2) }
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        var report = QualificationReport(command: CommandLine.arguments.dropFirst().joined(separator: " "))
        do {
            guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 else { throw HarnessFailure("macOS 27 native baseline required") }
            let suites = try loadValue(root.appendingPathComponent(registry))["suites"].array()
            guard !suites.isEmpty else { throw HarnessFailure("No registered suites") }
            for suite in suites {
                let input = try VerifiedSuite(suite, root: root)
                switch input.repository {
                case "nst/JSONTestSuite": report.suites.append(try qualifySyntax(input))
                case "json-schema-org/JSON-Schema-Test-Suite": report.suites.append(try qualifySchema(input, root: root))
                default: throw HarnessFailure("Unimplemented registered suite: " + input.repository)
                }
                let receipt = report.suites.last!
                print("\(receipt.repository): observed=\(receipt.observed_cases) passed=\(receipt.passed_cases) policy=\(receipt.policy_cases) failed=\(receipt.failed_cases)")
            }
            report.authored = try await qualifyAuthored(root: root)
            report.status = report.suites.allSatisfy { $0.failed_cases == 0 && $0.observed_cases == $0.expected_cases && $0.unexpected_skips == 0 } && report.authored.allSatisfy { $0.failed == 0 && $0.observed > 0 } ? "passed" : "failed"
        } catch { report.errors.append(errorCode(error)); report.status = "failed" }
        do {
            // Infrastructure serialization only. Every exercised operation uses the public engines.
            let encoder = Foundation.JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let destination = root.appendingPathComponent(output)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(report).write(to: destination, options: .atomic)
        } catch { print("Could not save qualification receipt: \(errorCode(error))"); exit(1) }
        print("Qualification \(report.status)"); exit(report.status == "passed" ? 0 : 1)
    }
}
