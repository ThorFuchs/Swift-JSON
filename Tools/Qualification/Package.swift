// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "Qualification",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "Qualification", targets: ["Qualification"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "Qualification", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON"),
        .product(name: "JSONStreaming", package: "Swift-JSON"),
        .product(name: "JSONPatch", package: "Swift-JSON")
    ]), .testTarget(name: "LimitQualificationTests", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON"),
        .product(name: "JSONStreaming", package: "Swift-JSON"),
        .product(name: "JSONPatch", package: "Swift-JSON")
    ])],
    swiftLanguageModes: [.v6]
)
