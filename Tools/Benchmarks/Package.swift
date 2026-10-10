// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "Benchmarks", targets: ["Benchmarks"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "Benchmarks", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON"),
        .product(name: "JSONStreaming", package: "Swift-JSON"),
        .product(name: "JSONPatch", package: "Swift-JSON")
    ])],
    swiftLanguageModes: [.v6]
)
