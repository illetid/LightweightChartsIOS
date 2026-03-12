// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LightweightCharts",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "LightweightCharts",
            targets: ["LightweightCharts"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LightweightCharts",
            dependencies: [],
            exclude: [
                "Extensions/Bundle+Resources.swift",
                "Assets/lightweight-charts.js.backup"
            ],
            resources: [
                .process("Assets/content-setup.js"),
                .process("Assets/lightweight-charts.js"),
                .process("Assets/wrapper_functions.js")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
            ])
    ]
)
