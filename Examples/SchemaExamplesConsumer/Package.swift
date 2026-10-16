// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "SchemaExamplesConsumer",
    platforms: [.macOS("27.0"), .iOS("27.0")],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "SchemaExamplesConsumer", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON"),
        .product(name: "JSONSchemaExamples", package: "Swift-JSON")
    ])],
    swiftLanguageModes: [.v6]
)
