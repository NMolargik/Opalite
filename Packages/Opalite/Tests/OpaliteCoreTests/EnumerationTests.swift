//
//  EnumerationTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("OnyxGate")
struct OnyxGateTests {
    @Test func freeTierLimits() {
        let free = OnyxGate(hasOnyx: false)
        #expect(OnyxGate.freePaletteLimit == 5 && OnyxGate.freeCanvasLimit == 1)
        #expect(free.canCreatePalette(currentCount: 0))
        #expect(free.canCreatePalette(currentCount: 4))
        #expect(!free.canCreatePalette(currentCount: 5))
        #expect(!free.canCreatePalette(currentCount: 9))
        #expect(free.canCreateCanvas(currentCount: 0))
        #expect(!free.canCreateCanvas(currentCount: 1))
        #expect(!free.canSaveFromCommunity && !free.canExportProFormats)
    }

    @Test func freeTierOpensOnlyTheOldestCanvas() {
        let free = OnyxGate(hasOnyx: false)
        let oldest = UUID()
        #expect(free.canAccessCanvas(id: oldest, oldestCanvasID: oldest))
        #expect(!free.canAccessCanvas(id: UUID(), oldestCanvasID: oldest))
        #expect(!free.canAccessCanvas(id: UUID(), oldestCanvasID: nil))
    }

    @Test func onyxUnlocksEverything() {
        let onyx = OnyxGate(hasOnyx: true)
        #expect(onyx.canCreatePalette(currentCount: 500))
        #expect(onyx.canCreateCanvas(currentCount: 500))
        #expect(onyx.canAccessCanvas(id: UUID(), oldestCanvasID: nil))
        #expect(onyx.canSaveFromCommunity && onyx.canExportProFormats)
    }

    @Test func products() {
        #expect(OnyxSubscription.annual.rawValue == "onyx_1yr_4.99")
        #expect(OnyxSubscription.lifetime.rawValue == "onyx_lifetime_20")
        #expect(OnyxSubscription.annual.isSubscription && !OnyxSubscription.lifetime.isSubscription)
        #expect(OnyxSubscription.productIDs == ["onyx_1yr_4.99", "onyx_lifetime_20"])
        #expect(OnyxSubscription.purchasable == [.lifetime])
        #expect(OnyxSubscription.purchasableProductIDs == ["onyx_lifetime_20"])
        #expect(OnyxSubscription.allCases.allSatisfy { $0.id == $0.rawValue })
    }
}

@Suite("Appearance & picker enums")
struct AppearanceEnumTests {
    @Test func swatchSizeCycles() {
        #expect(SwatchSize.extraSmall.next == .small)
        #expect(SwatchSize.small.next == .medium)
        #expect(SwatchSize.medium.next == .large)
        #expect(SwatchSize.large.next == .extraSmall)
        #expect(SwatchSize.extraSmall.nextCompact == .small)
        #expect(SwatchSize.small.nextCompact == .medium)
        #expect(SwatchSize.medium.nextCompact == .extraSmall)
        #expect(SwatchSize.large.nextCompact == .extraSmall)
    }

    @Test func swatchSizeGeometry() {
        #expect(SwatchSize.allCases.map(\.side) == [40, 75, 150, 250])
        #expect(SwatchSize.extraSmall.cornerRadius == 8 && SwatchSize.large.cornerRadius == 16)
        #expect(SwatchSize.allCases.filter(\.showsOverlays) == [.medium, .large])
    }

    @Test func themeAndIconOptions() {
        #expect(AppThemeOption.allCases.map(\.rawValue) == ["system", "light", "dark"])
        #expect(AppIconOption.dark.iconName == nil)
        #expect(AppIconOption.light.iconName == "AppIcon-Light")
        #expect(AppStage.allStagesInOrder == [.splash, .onboarding, .main])
    }

    @Test func colorPickerTabKeys() {
        #expect(ColorPickerTab.allCases.map(\.keyboardShortcutKey) == ["1", "2", "3", "4", "5", "6"])
        for tab in ColorPickerTab.allCases {
            #expect(ColorPickerTab(fromKey: tab.keyboardShortcutKey) == tab)
        }
        #expect(ColorPickerTab(fromKey: "7") == nil)
        #expect(ColorPickerTab(fromKey: "a") == nil)
        #expect(Set(ColorPickerTab.allCases.map(\.systemImage)).count == 6)
    }

    @Test func canvasShapes() {
        #expect(CanvasShape.allCases.filter(\.supportsNonUniformScale) == [.rectangle])
        #expect(CanvasShape.square.constrainedAspectRatio == 1 && CanvasShape.circle.constrainedAspectRatio == 1)
        #expect(CanvasShape.triangle.constrainedAspectRatio.map { abs($0 - 1 / 0.866) < 0.001 } == true)
        #expect(CanvasShape.shirt.constrainedAspectRatio == 1.26)
        #expect(CanvasShape.rectangle.constrainedAspectRatio == nil && CanvasShape.line.constrainedAspectRatio == nil && CanvasShape.arrow.constrainedAspectRatio == nil)
        let numbers = CanvasShape.allCases.compactMap(\.keyboardNumber)
        #expect(numbers == [1, 2, 3, 4, 5].sorted() || Set(numbers) == Set(1...5))
        #expect(CanvasShape.rectangle.keyboardNumber == nil && CanvasShape.shirt.keyboardNumber == nil)
    }

    @Test func onboardingSteps() {
        #expect(OnboardingStep.welcome.isFirst && !OnboardingStep.welcome.isLast)
        #expect(OnboardingStep.profile.isLast && !OnboardingStep.profile.isFirst)
        #expect(OnboardingStep.welcome.previous == nil)
        #expect(OnboardingStep.profile.next == nil)
        #expect(OnboardingStep.welcome.next == .portfolio)
        #expect(OnboardingStep.community.previous == .canvas)
        #expect(OnboardingStep.welcome.progress.isClose(to: 0.2))
        #expect(OnboardingStep.profile.progress == 1)
        var step: OnboardingStep? = .welcome
        var visited: [OnboardingStep] = []
        while let current = step { visited.append(current); step = current.next }
        #expect(visited == OnboardingStep.allCases)
    }

    @Test func previewBackgrounds() {
        #expect(PreviewBackground.defaultFor(isDark: true) == .black)
        #expect(PreviewBackground.defaultFor(isDark: false) == .white)
        #expect(PreviewBackground.allCases.count == 8)
        for background in PreviewBackground.allCases {
            #expect(background.prefersDarkText == background.rgba.prefersDarkText, "\(background) text preference matches its luminance")
            #expect(!background.systemImage.isEmpty)
        }
        #expect(PreviewBackground.white.rgba == .white && PreviewBackground.black.rgba == .black)
    }

    @Test("DeviceKind classification", arguments: [
        ("iPhone 17 Pro", DeviceKind.iPhone), ("iPad Pro", .iPad), ("Apple Watch Ultra", .appleWatch), ("Apple Vision Pro", .visionPro),
        ("iMac", .iMac), ("Mac Studio", .macStudio), ("MacStudio", .macStudio), ("Mac mini", .macMini), ("Mac Pro", .macPro),
        ("MacBook Air", .macBook), ("Apple TV 4K", .appleTV), ("Toaster", .unknown), ("", .unknown), ("   ", .unknown), ("IPHONE", .iPhone),
    ])
    func deviceKind(name: String, expected: DeviceKind) {
        #expect(DeviceKind.from(name) == expected)
    }

    @Test func deviceKindNilAndSymbols() {
        #expect(DeviceKind.from(nil) == .unknown)
        #expect(DeviceKind.unknown.systemImage == "ipad.and.iphone")
        #expect(DeviceKind.visionPro.systemImage == "vision.pro")
    }
}

extension AppStage {
    static var allStagesInOrder: [AppStage] { [.splash, .onboarding, .main] }
}
