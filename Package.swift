// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MangoStats",
    platforms: [.macOS(.v26)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "MangoStatsKit"),
        // SMC access and the fan helper's XPC interface, shared by the app and the helper.
        .target(name: "MangoStatsSMC"),
        // The root helper that sets the fan (S-024). build.sh puts it in the app bundle.
        .executableTarget(name: "MangoStatsHelper", dependencies: ["MangoStatsKit", "MangoStatsSMC"]),
        .executableTarget(
            name: "MangoStats",
            dependencies: ["MangoStatsKit", "MangoStatsSMC"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)],
            // IOReport: CPU and GPU energy (Sampling/SensorReader.swift).
            linkerSettings: [.linkedLibrary("IOReport")]
        ),
        .testTarget(name: "MangoStatsKitTests", dependencies: ["MangoStatsKit"]),
    ]
)
