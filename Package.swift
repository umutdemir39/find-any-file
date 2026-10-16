// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FindAnyFile",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FindAnyFile", targets: ["FindAnyFile"])
    ],
    targets: [
        .executableTarget(
            name: "FindAnyFile",
            path: "Sources/FindAnyFile"
        )
    ]
)

