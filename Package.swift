// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "menote",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "NotchPadCore",
            path: "Sources/NotchPadCore",
            swiftSettings: [
                .unsafeFlags(["-swift-version", "5"])
            ]
        ),
        .executableTarget(
            name: "menote",
            dependencies: ["NotchPadCore"],
            path: "Sources/NotchPad",
            swiftSettings: [
                .unsafeFlags(["-swift-version", "5"])
            ]
        ),
        .testTarget(
            name: "NotchPadCoreTests",
            dependencies: ["NotchPadCore"],
            path: "Tests/NotchPadCoreTests"
        )
    ]
)
