// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "TransformBindingQualification", platforms: [.macOS("27.0"), .iOS("27.0")],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "TransformBindingConsumer", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONTransform", package: "Swift-JSON")
    ])], swiftLanguageModes: [.v6])
