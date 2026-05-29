// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacSerial",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacSerial", targets: ["MacSerial"])
    ],
    targets: [
        .executableTarget(
            name: "MacSerial",
            path: "Sources/MacSerial"
        )
    ]
)
