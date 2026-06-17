// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MQUPEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MQUPEngine", targets: ["MQUPEngine"]),
        .executable(name: "MQUPEval", targets: ["MQUPEval"]),
    ],
    targets: [
        .target(
            name: "MQUPEngine",
            path: "Sources/MQUPEngine"
        ),
        .executableTarget(
            name: "MQUPEval",
            dependencies: ["MQUPEngine"],
            path: "Sources/MQUPEval"
        ),
        .testTarget(
            name: "MQUPEngineTests",
            dependencies: ["MQUPEngine"],
            path: "Tests/MQUPEngineTests",
            resources: [
                .copy("Resources"),
            ]
        ),
    ]
)
