// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PromptZen",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "PromptZen", targets: ["PromptZen"])
    ],
    targets: [
        .executableTarget(
            name: "PromptZen",
            path: "Sources/PromptZen"
        )
    ]
)
