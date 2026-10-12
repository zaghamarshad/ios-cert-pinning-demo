// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CertPinningDemo",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "CertPinningDemo", targets: ["CertPinningDemo"]),
    ],
    targets: [
        .target(name: "CertPinningDemo"),
    ]
)
