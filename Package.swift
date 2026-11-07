// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PunchinoCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PunchinoCore", targets: ["PunchinoCore"])],
    targets: [
        .target(name: "PunchinoCore", path: "Shared", exclude: ["TimeStore.swift", "Theme.swift", "CloudSync.swift", "WatchSync.swift"]),
        .testTarget(name: "CoreTests", dependencies: ["PunchinoCore"], path: "Tests/CoreTests")
    ]
)
