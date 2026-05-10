// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TrueCaddieDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TrueCaddieDomain",
            targets: ["TrueCaddieDomain"]
        )
    ],
    targets: [
        .target(name: "TrueCaddieDomain"),
        .testTarget(
            name: "TrueCaddieDomainTests",
            dependencies: ["TrueCaddieDomain"]
        )
    ]
)
