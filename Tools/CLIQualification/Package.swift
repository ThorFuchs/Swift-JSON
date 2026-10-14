// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "CLIQualification", platforms: [.macOS("27.0"), .iOS("27.0")],
    products: [.executable(name: "CLIExactCompare", targets: ["CLIExactCompare"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.target(name: "CLIMobileConsumer", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONSchema", package: "Swift-JSON"),
        .product(name: "JSONStreaming", package: "Swift-JSON"), .product(name: "JSONPatch", package: "Swift-JSON"),
        .product(name: "JSONHTML", package: "Swift-JSON")]), .executableTarget(name: "CLIExactCompare", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONStreaming", package: "Swift-JSON")])],
    swiftLanguageModes: [.v6])
