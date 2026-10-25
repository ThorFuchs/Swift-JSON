// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "Consumer",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "Consumer", targets: ["Consumer"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "Consumer", dependencies: [
        .product(name: "JSONValueDSL", package: "Swift-JSON"),
            .product(name: "JSONSchemaDSL", package: "Swift-JSON"),
            .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON"),
        .product(name: "JSONSchemaExamples", package: "Swift-JSON"),
        .product(name: "JSONStreaming", package: "Swift-JSON"),
        .product(name: "JSONPatch", package: "Swift-JSON"),
        .product(name: "JSONHTML", package: "Swift-JSON"),
        .product(name: "JSONBridges", package: "Swift-JSON"),
        .product(name: "JSONInspection", package: "Swift-JSON")
    ])],
    swiftLanguageModes: [.v6]
)
