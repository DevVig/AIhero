// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIhero",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AIhero",
            path: "Sources/AIhero",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "AIheroTests",
            dependencies: ["AIhero"],
            path: "Tests/AIheroTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
