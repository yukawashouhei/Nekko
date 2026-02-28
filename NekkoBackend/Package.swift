// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "NekkoBackend",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
    ],
    targets: [
        .executableTarget(
            name: "NekkoBackend",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources"
        ),
    ]
)
