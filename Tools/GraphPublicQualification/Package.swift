// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "GraphPublicQualification", platforms: [.macOS("27.0"), .iOS("27.0")], dependencies: [.package(name: "Swift-JSON", path: "../..")], targets: [.executableTarget(name: "GraphPublicConsumer", dependencies: [.product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONNavigation", package: "Swift-JSON"), .product(name: "JSONInspection", package: "Swift-JSON")])], swiftLanguageModes: [.v6])
