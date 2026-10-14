// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "JSONHTMLExport", platforms: [.macOS("27.0"), .iOS("27.0")],
    products: [.executable(name: "ExportConsumer", targets: ["ExportConsumer"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "ExportConsumer", dependencies:
        ["JSON", "JSONSchema", "JSONStreaming", "JSONPatch", "JSONHTML"].map {
            .product(name: $0, package: "Swift-JSON")
        }, resources: [.copy("Fixtures")])], swiftLanguageModes: [.v6])
