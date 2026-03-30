// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PromptZen",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "PromptZen", targets: ["PromptZen"])
    ],
    dependencies: [
        .package(url: "https://github.com/swhitty/FlyingFox.git", from: "0.24.0"),
    ],
    targets: [
        .executableTarget(
            name: "PromptZen",
            dependencies: [
                .product(name: "FlyingFox", package: "FlyingFox"),
            ],
            path: "Sources/PromptZen"
        )
    ]
)
