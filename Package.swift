// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "jswitcher",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "jswitcher", targets: ["jswitcher"]),
    ],
    targets: [
        .target(name: "JswitcherCore"),
        .executableTarget(name: "jswitcher", dependencies: ["JswitcherCore"]),
        .executableTarget(name: "build-dicts", dependencies: ["JswitcherCore"], path: "Tools/build-dicts"),
        .testTarget(name: "JswitcherCoreTests", dependencies: ["JswitcherCore"]),
    ],
    swiftLanguageModes: [.v6]
)
