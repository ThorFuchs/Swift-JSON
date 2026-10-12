// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "MobileConsumer", platforms: [.macOS("27.0"), .iOS("27.0")],
    products: [.library(name: "MobileConsumer", targets: ["MobileConsumer"])],
    dependencies: [.package(name: "Swift-JSON", path: "../../..")],
    targets: [.target(name: "MobileConsumer", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONSchema", package: "Swift-JSON"),
        .product(name: "JSONStreaming", package: "Swift-JSON"), .product(name: "JSONPatch", package: "Swift-JSON")
    ])], swiftLanguageModes: [.v6])
