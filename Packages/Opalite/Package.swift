// swift-tools-version: 6.2
//
//  Package.swift
//  Opalite
//
//  The umbrella package holding the whole app: pure domain (Core), persistence (Data),
//  system-framework services (Services), the design system, one module per feature, and
//  the composition root. The app/extension/watch/TV targets are thin shells over these
//  products. Dependencies point inward — features depend on the design system and core;
//  data implements core's protocols; core depends on nothing but Foundation + SwiftData.
//

import PackageDescription

let isolation: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Opalite",
    defaultLocalization: "en",
    // Match the app targets' floors; macOS is the host `swift test` floor.
    platforms: [
        .iOS("18.4"), .macCatalyst("18.4"), .macOS("15.6"),
        .tvOS("18.4"), .watchOS("10.0"), .visionOS("26.2"),
    ],
    products: [
        .library(name: "OpaliteCore", targets: ["OpaliteCore"]),
        .library(name: "OpaliteData", targets: ["OpaliteData"]),
        .library(name: "OpaliteServices", targets: ["OpaliteServices"]),
        .library(name: "OpaliteDesignSystem", targets: ["OpaliteDesignSystem"]),
        .library(name: "OpaliteFeatureShared", targets: ["OpaliteFeatureShared"]),
        .library(name: "OpaliteFeatureColorEditor", targets: ["OpaliteFeatureColorEditor"]),
        .library(name: "OpaliteFeatureSharing", targets: ["OpaliteFeatureSharing"]),
        .library(name: "OpaliteFeaturePortfolio", targets: ["OpaliteFeaturePortfolio"]),
        .library(name: "OpaliteFeatureCommunity", targets: ["OpaliteFeatureCommunity"]),
        .library(name: "OpaliteFeatureCanvas", targets: ["OpaliteFeatureCanvas"]),
        .library(name: "OpaliteFeatureSearch", targets: ["OpaliteFeatureSearch"]),
        .library(name: "OpaliteFeatureSettings", targets: ["OpaliteFeatureSettings"]),
        .library(name: "OpaliteFeatureSwatchBar", targets: ["OpaliteFeatureSwatchBar"]),
        .library(name: "OpaliteFeatureOnboarding", targets: ["OpaliteFeatureOnboarding"]),
        .library(name: "OpaliteFeatureImmersive", targets: ["OpaliteFeatureImmersive"]),
        .library(name: "OpaliteFeatureTV", targets: ["OpaliteFeatureTV"]),
        .library(name: "OpaliteComposition", targets: ["OpaliteComposition"]),
    ],
    dependencies: [
        .package(url: "https://github.com/devicekit/DeviceKit.git", from: "5.7.0"),
    ],
    targets: [
        .target(name: "OpaliteCore", swiftSettings: isolation),
        .target(name: "OpaliteData", dependencies: ["OpaliteCore"], swiftSettings: isolation),
        .target(
            name: "OpaliteServices",
            dependencies: [
                "OpaliteCore",
                .product(name: "DeviceKit", package: "DeviceKit", condition: .when(platforms: [.iOS, .macCatalyst, .tvOS, .watchOS, .visionOS])),
            ],
            swiftSettings: isolation
        ),
        .target(name: "OpaliteDesignSystem", dependencies: ["OpaliteCore"], swiftSettings: isolation),
        .target(
            name: "OpaliteFeatureShared",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteServices"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureColorEditor",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteServices", "OpaliteFeatureShared"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureSharing",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteServices", "OpaliteFeatureShared"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeaturePortfolio",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteServices", "OpaliteFeatureShared", "OpaliteFeatureColorEditor", "OpaliteFeatureSharing"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureCommunity",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteServices", "OpaliteFeatureShared", "OpaliteFeatureSharing"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureCanvas",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteServices", "OpaliteFeatureShared", "OpaliteFeatureColorEditor"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureSearch",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteFeatureShared", "OpaliteFeaturePortfolio"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureSettings",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteServices", "OpaliteFeatureShared", "OpaliteFeatureSharing"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureSwatchBar",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteFeatureShared", "OpaliteFeatureColorEditor"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureOnboarding",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteFeatureShared"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureImmersive",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteFeatureShared"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteFeatureTV",
            dependencies: ["OpaliteCore", "OpaliteDesignSystem", "OpaliteFeatureShared"],
            swiftSettings: isolation
        ),
        .target(
            name: "OpaliteComposition",
            dependencies: [
                "OpaliteCore", "OpaliteData", "OpaliteServices", "OpaliteDesignSystem", "OpaliteFeatureShared",
                "OpaliteFeatureColorEditor", "OpaliteFeatureSharing", "OpaliteFeaturePortfolio", "OpaliteFeatureCommunity",
                "OpaliteFeatureCanvas", "OpaliteFeatureSearch", "OpaliteFeatureSettings", "OpaliteFeatureSwatchBar",
                "OpaliteFeatureOnboarding", "OpaliteFeatureImmersive", "OpaliteFeatureTV",
            ],
            swiftSettings: isolation
        ),
        .testTarget(name: "OpaliteCoreTests", dependencies: ["OpaliteCore"], swiftSettings: isolation),
        .testTarget(name: "OpaliteDataTests", dependencies: ["OpaliteData"], swiftSettings: isolation),
        .testTarget(name: "OpaliteServicesTests", dependencies: ["OpaliteServices"], swiftSettings: isolation),
        .testTarget(name: "OpaliteDesignSystemTests", dependencies: ["OpaliteDesignSystem"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureSharedTests", dependencies: ["OpaliteFeatureShared"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureColorEditorTests", dependencies: ["OpaliteFeatureColorEditor"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureSharingTests", dependencies: ["OpaliteFeatureSharing"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeaturePortfolioTests", dependencies: ["OpaliteFeaturePortfolio"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureCommunityTests", dependencies: ["OpaliteFeatureCommunity"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureCanvasTests", dependencies: ["OpaliteFeatureCanvas"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureSearchTests", dependencies: ["OpaliteFeatureSearch"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureSettingsTests", dependencies: ["OpaliteFeatureSettings"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureSwatchBarTests", dependencies: ["OpaliteFeatureSwatchBar"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureOnboardingTests", dependencies: ["OpaliteFeatureOnboarding"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureImmersiveTests", dependencies: ["OpaliteFeatureImmersive"], swiftSettings: isolation),
        .testTarget(name: "OpaliteFeatureTVTests", dependencies: ["OpaliteFeatureTV"], swiftSettings: isolation),
        .testTarget(name: "OpaliteCompositionTests", dependencies: ["OpaliteComposition"], swiftSettings: isolation),
    ]
)
