// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "MCPReadiness",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "MCPReadiness", targets: ["MCPReadiness"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [
        .target(name: "MCPReadinessKit", dependencies: [
            .product(name: "JSON", package: "Swift-JSON"),
            .product(name: "JSONSchema", package: "Swift-JSON")
        ], resources: [.copy("Resources")]),
        .executableTarget(name: "MCPReadiness", dependencies: ["MCPReadinessKit"]),
        .testTarget(name: "MCPReadinessTests", dependencies: ["MCPReadinessKit"])
    ], swiftLanguageModes: [.v6]
)
