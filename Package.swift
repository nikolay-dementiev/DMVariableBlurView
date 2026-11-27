// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DMVariableBlurView",
    platforms: [
        .iOS(.v17),
        //.watchOS(.v7),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DMVariableBlurView",
            targets: ["DMVariableBlurView"]
        ),
    ],
    dependencies: [
        // The tracing port the views report their work to, and its spy for the tests.
        .package(url: "https://github.com/nikolay-dementiev/DMCore.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DMVariableBlurView",
            dependencies: [.product(name: "DMCore", package: "DMCore")],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .testTarget(
            name: "DMVariableBlurViewTests",
            dependencies: [
                "DMVariableBlurView",
                .product(name: "DMCore", package: "DMCore"),
                .product(name: "DMCoreTesting", package: "DMCore"),
            ],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        )
    ],
    swiftLanguageModes: [.v6]
)
