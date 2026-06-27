// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-playable-kit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PlayableKit", targets: ["PlayableKit"]),
    ],
    targets: [
        .target(name: "PlayableKit"),
    ]
)
