// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "SwiftJSONKitRecipes",
    platforms: [.macOS(.v15), .iOS(.v18)],
    dependencies: [.package(url: "https://github.com/ThorFuchs/Swift-JSON.git", exact: "1.9.0")],
    targets: [.executableTarget(name: "Consumer", dependencies: [
        .product(name: "JSON", package: "swift-json"),
        .product(name: "JSONBridges", package: "swift-json"),
        .product(name: "JSONSchema", package: "swift-json"),
        .product(name: "JSONSchemaExamples", package: "swift-json"),
        .product(name: "JSONStreaming", package: "swift-json"),
        .product(name: "JSONNavigation", package: "swift-json"),
        .product(name: "JSONPatch", package: "swift-json"),
        .product(name: "JSONHTML", package: "swift-json"),
        .product(name: "JSONInspection", package: "swift-json"),
        .product(name: "JSONTransform", package: "swift-json"),
        .product(name: "JSONValueDSL", package: "swift-json"),
        .product(name: "JSONSchemaDSL", package: "swift-json")
    ])],
    swiftLanguageModes: [.v6]
)
