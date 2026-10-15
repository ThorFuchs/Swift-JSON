// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "IndependentCompositionQualification",
    platforms: [.macOS("27.0"), .iOS("27.0")],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "CompositionBenchmark", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON")
    ]), .target(name: "CompositionProbe", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON")
    ]), .testTarget(name: "CompositionPublicTests", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON")
    ])],
    swiftLanguageModes: [.v6]
)
