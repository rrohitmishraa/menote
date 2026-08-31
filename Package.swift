// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "menote",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "MenoteCore",
            path: "Sources/MenoteCore",
            swiftSettings: [
                .unsafeFlags(["-swift-version", "5"])
            ]
        ),
        .executableTarget(
            name: "menote",
            dependencies: ["MenoteCore"],
            path: "Sources/Menote",
            swiftSettings: [
                .unsafeFlags(["-swift-version", "5"])
            ]
        ),
        .testTarget(
            name: "MenoteCoreTests",
            dependencies: ["MenoteCore"],
            path: "Tests/MenoteCoreTests"
        )
    ]
)
