// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "MobileQualification", platforms: [.macOS("27.0"), .iOS("27.0")],
    products: [.executable(name: "MobileQualification", targets: ["Runtime"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [
        .target(name: "ProbeCases", dependencies: [
            .product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONSchema", package: "Swift-JSON"),
            .product(name: "JSONPatch", package: "Swift-JSON"), .product(name: "JSONStreaming", package: "Swift-JSON")],
            resources: [.copy("Fixtures/version1.json")]),
        .executableTarget(name: "Runtime", dependencies: ["ProbeCases"]),
        .testTarget(name: "ProbeTests", dependencies: ["ProbeCases"])
    ], swiftLanguageModes: [.v6])
