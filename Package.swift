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
                "Core/Helpers/WebView.swift",
                "Features/OverseerrUsers/Networking/OverseerrAPIService.swift",
                "Features/OverseerrUsers/Networking/OverseerrAPIService+Authentication.swift",
                "Features/OverseerrUsers/Networking/OverseerrAPIService+MediaDetail.swift",
                "Features/OverseerrUsers/Networking/OverseerrAPIService+Discover.swift",
                "Features/OverseerrUsers/Networking/OverseerrUsersService.swift"
            ],
            sources: [
                "Core/Models",
                "Core/Helpers",
                "Core/Stores",
                "Core/Auth",
                "Features/Radarr/Models",
                "Features/OverseerrUsers/Models",
                "Features/OverseerrUsers/MediaDetail/Models",
                "Features/OverseerrUsers/Networking"
            ]
        ),
        .testTarget(
            name: "CantinarrModelTests",
            dependencies: ["CantinarrModels"],
            path: "Tests"
        )
    ]
)
