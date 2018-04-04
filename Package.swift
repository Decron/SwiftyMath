// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyMath",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SwiftyMath",
            targets: ["SwiftyMath"]),
        .library(
            name: "SwiftyTopology",
            targets: ["SwiftyTopology"]),
        .library(
            name: "SwiftyKnots",
            targets: ["SwiftyKnots"]),
        .library(
            name: "dSwiftyMath",
			type: .dynamic,
            targets: ["SwiftyMath", "SwiftyTopology", "SwiftyKnots"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SwiftyMath",
            dependencies: [],
			path: "Sources/SwiftyMath"),

        .testTarget(
            name: "SwiftyMathTests",
            dependencies: ["SwiftyMath"]),

        .target(
            name: "SwiftyTopology",
            dependencies: ["SwiftyMath"],
			path: "Sources/SwiftyTopology"),

        .testTarget(
            name: "SwiftyTopologyTests",
            dependencies: ["SwiftyTopology"]),

        .target(
            name: "SwiftyKnots",
            dependencies: ["SwiftyMath"],
			path: "Sources/SwiftyKnots"),

        .testTarget(
            name: "SwiftyKnotsTests",
            dependencies: ["SwiftyKnots"]),

    ]
)
