// swift-tools-version:5.9
// Swift Package manifest for native iOS (Swift) consumers of the PrintLib SDK.
//
// MANAGED BY THE RELEASE PIPELINE — the url + checksum below are rewritten on every release
// and must match the XCFramework zip attached to this repository's GitHub Release of the
// same version. Do not edit them by hand.
import PackageDescription

let package = Package(
    name: "PrintLib",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "PrintLib", targets: ["PrintLib"])
    ],
    targets: [
        .binaryTarget(
            name: "PrintLib",
            url: "https://github.com/kotimadduluri/printlib-sdk/releases/download/v0.0.0-unreleased/PrintLib.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        )
    ]
)
