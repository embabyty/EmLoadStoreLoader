// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EmLoadServer",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "emloadserver", targets: ["EmLoadServer"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/SideStore/SideSign",
            revision: "752d1ef602aa792a432ffa1e71646dc1ecf7363c"
        )
    ],
    targets: [
        .executableTarget(
            name: "EmLoadServer",
            dependencies: [.product(name: "SideSign", package: "SideSign")]
        ),
        .testTarget(name: "EmLoadServerTests", dependencies: ["EmLoadServer"])
    ]
)
