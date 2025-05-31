// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CantinarrModels",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CantinarrModels", targets: ["CantinarrModels"]),
    ],
    targets: [
        .target(
            name: "CantinarrModels",
            path: "Cantinarr",
            exclude: [
                "Core/Models/UserSession.swift",
                "Core/Helpers/OverseerrAuthContextProvider.swift",
                "Core/Helpers/OverseerrPlexSSODelegate.swift",
                "Core/Helpers/Shimmer.swift",
                "Core/Helpers/WebView.swift"
            ],
            sources: [
                "Core/Models",
                "Core/Helpers",
                "Core/Stores",
                "Features/Radarr/Models",
                "Features/OverseerrUsers/Models"
            ]
        ),
        .testTarget(
            name: "CantinarrModelTests",
            dependencies: ["CantinarrModels"],
            path: "Tests"
        )
    ]
)
