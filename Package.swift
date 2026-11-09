// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MiniAquarium",
    platforms: [.macOS(.v13)],
    targets: [
        // 순수 로직 (UI 의존 없음) — 테스트 대상
        .target(name: "MiniAquariumCore"),
        // AppKit + SwiftUI 앱
        .executableTarget(name: "MiniAquarium", dependencies: ["MiniAquariumCore"]),
        .testTarget(name: "MiniAquariumCoreTests", dependencies: ["MiniAquariumCore"]),
    ]
)
