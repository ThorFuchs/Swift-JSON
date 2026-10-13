// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "WasmAudit", platforms: [.macOS("27.0")],
    products: [.executable(name: "WasmAudit", targets: ["WasmAudit"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [
        .target(name: "WasmAuditKit", dependencies: [
            .product(name: "JSON", package: "Swift-JSON"),
            .product(name: "JSONSchema", package: "Swift-JSON"),
            .product(name: "JSONStreaming", package: "Swift-JSON"),
            .product(name: "JSONPatch", package: "Swift-JSON")]),
        .executableTarget(name: "WasmAudit", dependencies: ["WasmAuditKit"]),
        .testTarget(name: "WasmAuditTests", dependencies: ["WasmAuditKit"])
    ], swiftLanguageModes: [.v6])
