// swift-tools-version:5.9
// Builds the platform-independent rules engine so it can be unit-tested with `swift test`
// on macOS or Linux. The iOS app itself is built from ColorLink.xcodeproj.
import PackageDescription

let package = Package(
    name: "ColorLinkCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ColorLinkCore", targets: ["ColorLinkCore"]),
    ],
    targets: [
        .target(name: "ColorLinkCore", path: "ColorLink/Core"),
        .testTarget(name: "ColorLinkCoreTests", dependencies: ["ColorLinkCore"], path: "Tests/ColorLinkCoreTests"),
    ]
)
