// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

// Declares exactly the package's deployment minimums so the compiler enforces
// availability of every public API a consumer reaches at that floor.
let package = Package(
    name: "PlatformFloorConsumer",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [.executable(name: "PlatformFloorConsumer", targets: ["PlatformFloorConsumer"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [
        .target(name: "FloorProbe", dependencies: [
            .product(name: "JSON", package: "Swift-JSON"),
            .product(name: "JSONSchema", package: "Swift-JSON"),
            .product(name: "JSONSchemaExamples", package: "Swift-JSON"),
            .product(name: "JSONStreaming", package: "Swift-JSON"),
            .product(name: "JSONPatch", package: "Swift-JSON"),
            .product(name: "JSONHTML", package: "Swift-JSON"),
            .product(name: "JSONBridges", package: "Swift-JSON"),
            .product(name: "JSONNavigation", package: "Swift-JSON"),
            .product(name: "JSONInspection", package: "Swift-JSON"),
            .product(name: "JSONTransform", package: "Swift-JSON"),
            .product(name: "JSONValueDSL", package: "Swift-JSON"),
            .product(name: "JSONSchemaDSL", package: "Swift-JSON"),
        ]),
        .executableTarget(name: "PlatformFloorConsumer", dependencies: ["FloorProbe"]),
    ],
    swiftLanguageModes: [.v6]
)
