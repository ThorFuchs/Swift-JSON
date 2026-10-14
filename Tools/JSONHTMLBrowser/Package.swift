// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "JSONHTMLBrowser", platforms: [.macOS("27.0")],
    products: [.executable(name: "BrowserFixtures", targets: ["BrowserFixtures"])],
    dependencies: [.package(name: "Swift-JSON", path: "../..")],
    targets: [.executableTarget(name: "BrowserFixtures", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONHTML", package: "Swift-JSON")])], swiftLanguageModes: [.v6])
