// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "CompositionQualification",
    platforms: [.macOS("27.0"), .iOS("27.0")],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "CompositionBenchmark", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONSchema", package: "Swift-JSON")
    ]), .target(name: "CompositionProbe", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONSchema", package: "Swift-JSON")
    ]), .testTarget(name: "CompositionPublicTests", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONSchema", package: "Swift-JSON")
    ], resources: [.copy("Fixtures")]), .target(name: "CompositionFixtures", dependencies: [
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
