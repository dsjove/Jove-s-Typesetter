// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Jove's Typesetter",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Jove's Typesetter",
            targets: ["Jove_s_Typesetter"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Jove_s_Typesetter",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "Jove_s_TypesetterTests",
            dependencies: ["Jove_s_Typesetter"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
