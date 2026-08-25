// swift-tools-version:5.9
// Swift Package manifest for native iOS (Swift) consumers of the PrintBeam SDK.
//
// MANAGED BY THE RELEASE PIPELINE — the url + checksum below are rewritten on every release
// and must match the XCFramework zip attached to this repository's GitHub Release of the
// same version. Do not edit them by hand.
import PackageDescription

let package = Package(
    name: "PrintBeam",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "PrintBeam", targets: ["PrintBeam"])
    ],
    targets: [
        .binaryTarget(
            name: "PrintBeam",
            url: "https://github.com/kotimadduluri/printbeam-sdk/releases/download/v0.1.0-alpha01/PrintBeam.xcframework.zip",
            checksum: "f9312ef82a43537be8a9ecfdaeccf6863cb12b78e324fb81a585f1915dd9b23a"
        )
    ]
)
