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
                "Core/Helpers/OverseerrAuthContextProvider.swift",
                "Core/Helpers/OverseerrPlexSSODelegate.swift",
                "Core/Helpers/Shimmer.swift",
                "Core/Helpers/WebView.swift",
                // Exclude SwiftUI and UI-related resources not used by SwiftPM
                "App",
                "Views",
                "Navigation",
                "Persistence",
                "Assets.xcassets",
                "Cantinarr.xcdatamodeld",
                "LaunchScreen.storyboard",
                "Features/Shared",
                "Features/Shell/RootShellView.swift",
                "Features/Shell/UI/SideMenuView.swift",
                "Features/Settings",
                "Features/OverseerrUsers/UI",
                "Features/OverseerrUsers/MediaDetail/UI",
                "Features/OverseerrUsers/MediaDetail/Logic",
                "Features/Radarr/UI",
                "Features/Radarr/Logic"
            ],
            sources: [
                "Core/Models",
                "Core/Helpers",
                "Core/Stores",
                "Core/Auth",
                "Core/Configuration",
                "Features/Radarr/Models",
                "Features/OverseerrUsers/Models",
                "Features/OverseerrUsers/MediaDetail/Models",
                "Features/OverseerrUsers/Networking/OverseerrServiceType.swift",
                "Features/OverseerrUsers/Logic/FilterManager.swift",
                "Features/OverseerrUsers/Logic/SearchController.swift",
                "Features/OverseerrUsers/Networking/OverseerrUsersService.swift",
                "Features/Shell/SideMenuGestureManager.swift"
            ]
        ),
        .testTarget(
            name: "CantinarrModelTests",
            dependencies: ["CantinarrModels"],
            path: "Tests"
        )
    ]
)
