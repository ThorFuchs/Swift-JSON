// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "CompositionQualification",
    platforms: [.macOS("27.0")],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.target(name: "CompositionFixtures", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON")
    ]), .testTarget(name: "CompositionScaleTests", dependencies: [
        "CompositionFixtures", .product(name: "JSON", package: "Swift-JSON")
    ]), .executableTarget(name: "CompositionScaleProbe", dependencies: [
        "CompositionFixtures", .product(name: "JSON", package: "Swift-JSON")
    ]), .executableTarget(name: "CompositionConsumer", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON")
    ]), .executableTarget(name: "CompositionRegression", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON")
    ])],
    swiftLanguageModes: [.v6]
)
