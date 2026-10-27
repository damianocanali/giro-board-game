// swift-tools-version:5.9
// Builds only the platform-independent game rules (Giro/Core) so they can be tested
// with `swift test` on macOS or Linux. The iOS app itself is built from Giro.xcodeproj.
import PackageDescription

let package = Package(
    name: "GiroCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "GiroCore", targets: ["GiroCore"])],
    targets: [
        .target(name: "GiroCore", path: "Giro/Core"),
        .testTarget(name: "GiroCoreTests", dependencies: ["GiroCore"], path: "Tests/GiroCoreTests"),
    ]
)
