// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "Swift-JSON",
    platforms: [.macOS("27.0"), .iOS("27.0")],
    products: [
        .library(name: "JSON", targets: ["JSON"]),
        .library(name: "JSONSchema", targets: ["JSONSchema"]),
        .library(name: "JSONStreaming", targets: ["JSONStreaming"]),
        .library(name: "JSONPatch", targets: ["JSONPatch"])
    ],
    targets: [
        .target(name: "JSON"),
        .target(name: "JSONRegexRuntime", dependencies: ["JSON"]),
        .target(name: "JSONSchema", dependencies: ["JSON", "JSONRegexRuntime"], resources: [.copy("Resources/Draft2020-12")]),
        .target(name: "JSONStreaming", dependencies: ["JSON"]),
        .target(name: "JSONPatch", dependencies: ["JSON"]),
        .testTarget(name: "JSONIntegrationTests", dependencies: ["JSON", "JSONSchema", "JSONStreaming", "JSONPatch"]),
        .testTarget(name: "JSONTests", dependencies: ["JSON"], exclude: ["ImplementationPlan.md"]),
        .testTarget(name: "JSONSchemaTests", dependencies: ["JSONSchema"], exclude: ["ImplementationPlan.md"]),
        .testTarget(name: "JSONStreamingTests", dependencies: ["JSONStreaming"], exclude: ["ImplementationPlan.md"]),
        .testTarget(name: "JSONPatchTests", dependencies: ["JSONPatch"], exclude: ["ImplementationPlan.md"]),
        .testTarget(name: "JSONRegexRuntimeTests", dependencies: ["JSONRegexRuntime"], exclude: ["ImplementationPlan.md"])
    ],
    swiftLanguageModes: [.v6]
)
