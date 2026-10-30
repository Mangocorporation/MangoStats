// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MangoStats",
    platforms: [.macOS(.v26)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "MangoStatsKit"),
        .executableTarget(
            name: "MangoStats",
            dependencies: ["MangoStatsKit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)],
            // IOReport: CPU and GPU energy (Sampling/SensorReader.swift).
            linkerSettings: [.linkedLibrary("IOReport")]
        ),
        .testTarget(name: "MangoStatsKitTests", dependencies: ["MangoStatsKit"]),
    ]
)
