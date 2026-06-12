// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "A2UIJSONBowtie",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(name: "A2UISwiftCore", path: "../../../../")
    ],
    targets: [
        .executableTarget(
            name: "A2UIJSONBowtie",
            dependencies: [
                .product(name: "A2UISwiftCore", package: "A2UISwiftCore")
            ],
            path: "Sources"
        )
    ]
)
