// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "JF42Consumer",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../Swift-JSON")],
    targets: [
        .executableTarget(name: "JF42Consumer", dependencies: [
            .product(name: "JSON", package: "Swift-JSON"),
            .product(name: "JSONSchema", package: "Swift-JSON"),
            .product(name: "JSONSchemaDSL", package: "Swift-JSON"),
            .product(name: "JSONFoundationModels", package: "Swift-JSON")
        ])
    ],
    swiftLanguageModes: [.v6]
)
