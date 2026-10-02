// swift-tools-version: 6.0

import PackageDescription

// A package that uses DMVariableBlurView the way an app does. It exists to be compiled:
// when a public declaration it uses changes shape, it stops building.
let package = Package(
    name: "Consumer",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "Consumer", targets: ["Consumer"])
    ],
    dependencies: [
        .package(name: "DMVariableBlurView", path: "../..")
    ],
    targets: [
        .target(
            name: "Consumer",
            dependencies: [
                .product(name: "DMVariableBlurView", package: "DMVariableBlurView")
            ]
        )
    ]
)
