// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodableRPC",
    platforms: [
      .macOS(.v14),
      .iOS(.v13)
    ],
    products: [
      .library(
        name: "CodableRPC",
        targets: ["CodableRPC"]),
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "CodableRPC",
            dependencies: [
              .product(name: "NIOCore", package: "swift-nio"),
              .product(name: "NIOPosix", package: "swift-nio"),
              .product(name: "NIOFoundationCompat", package: "swift-nio")
            ]
        ),
        .testTarget(
            name: "CodableRPCTests",
            dependencies: ["CodableRPC"]),
    ]
)
