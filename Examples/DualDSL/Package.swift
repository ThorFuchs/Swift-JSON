// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "DualDSLConsumer",
    platforms: [.macOS("27.0"), .iOS("27.0")],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "DualDSLConsumer", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON"),
        .product(name: "JSONValueDSL", package: "Swift-JSON"),
        .product(name: "JSONSchemaDSL", package: "Swift-JSON")
    ])],
    swiftLanguageModes: [.v6]
)
