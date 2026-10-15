// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "DistributionAcceptance", platforms: [.macOS("27.0"), .iOS("27.0")],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "DistributionAcceptance", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON"),
        .product(name: "JSONStreaming", package: "Swift-JSON"),
        .product(name: "JSONPatch", package: "Swift-JSON")])],
    swiftLanguageModes: [.v6])
