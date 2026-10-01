# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Opalite is a native color management and digital design app for Apple platforms built with SwiftUI and SwiftData. It provides six color picking modes, palette management, WCAG contrast checking, color blindness simulation, a PencilKit-based drawing canvas (1 free, unlimited with Onyx), multi-format palette export (Procreate, Adobe ASE, SwiftUI, CSS, GIMP, PDF), and a CloudKit-powered community for sharing colors and palettes.

**Platforms**: iOS 18.4+, macOS 15.6+ (native), macOS (Catalyst), tvOS, watchOS, visionOS
**Dependencies**: DeviceKit (SPM, v5.7.0) - the only external dependency

## Build Commands

```bash
# Build iOS app
xcodebuild -project Opalite/Opalite.xcodeproj -scheme Opalite build

# Build native macOS app
xcodebuild -project Opalite/Opalite.xcodeproj -scheme "Opalite Mac" build

# Build tvOS app
xcodebuild -project Opalite/Opalite.xcodeproj -scheme OpaliteTV build

# Run tests (iOS)
xcodebuild -project Opalite/Opalite.xcodeproj -scheme Opalite test

# Clean build
xcodebuild -project Opalite/Opalite.xcodeproj -scheme Opalite clean build
```

Available schemes: `Opalite`, `Opalite Mac`, `OpaliteTV`, `OpaliteWatch Watch App`, `OpaliteWidgetsExtension`, `OpaliteShareExtension`, `OpaliteQuickLook`, `OpaliteThumbnail`, `OpaliteMessages`.

## Architecture

### Two macOS Strategies

The project has **two separate macOS implementations**:
1. **Mac Catalyst** — the main `Opalite` target runs on macOS via Catalyst with UIKit adaptations (AppDelegate handles window/menu management)
2. **Native macOS** — the `Opalite Mac` target (`Opalite macOS/Opalite_macOSApp.swift`) is a pure SwiftUI app with `Window`, `MenuBarExtra`, and no AppDelegate

Both share ~90% of source files via Xcode file membership. Use `#if` guards when adding platform-specific code:
```swift
#if os(iOS)                                    // iOS + Catalyst
#if os(macOS)                                  // Native macOS only
#if targetEnvironment(macCatalyst)             // Catalyst only
#if os(iOS) && !targetEnvironment(macCatalyst) // True iOS only
#if os(visionOS)                               // visionOS only
```

### Data Layer (SwiftData + CloudKit)
- **OpaliteColor**: Single color (sRGB components, metadata, timestamps)
- **OpalitePalette**: Color collection with bi-directional color relationships
- **CanvasFile**: PencilKit drawing with external data storage
- CloudKit container: `iCloud.com.molargiksoftware.Opalite`
- App Group: `group.com.molargiksoftware.Opalite` (widgets, share extension)

### Manager Layer (`@Observable`)
All managers use `@Observable` (not ObservableObject) and inject via `.environment()`:

| Manager | Responsibility |
|---------|---------------|
| **ColorManager** | Color/palette CRUD, caching, relationship management |
| **CanvasManager** | Canvas file operations and persistence |
| **CommunityManager** | CloudKit public database, pagination, search |
| **SubscriptionManager** | StoreKit 2, Onyx entitlement checks |
| **ToastManager** | In-app notification toasts |
| **HexCopyManager** | Clipboard operations for color hex codes |
| **HapticsManager** | Tactile feedback (iOS) |
| **ReviewRequestManager** | App Store review prompts |
| **PhoneSessionManager** | WatchConnectivity sync (iOS only, singleton) |

### Navigation
Three parallel navigation systems:
- **Tabs** enum: Main app tabs (portfolio, community, canvas, search, swatchBar, settings) with dynamic `canvasBody(CanvasFile?)` tabs on iPad
- **PortfolioNavigationNode**: NavigationStack drill-down for palettes and colors
- **CommunityNavigationNode**: Color detail, palette detail, publisher profile

Deep linking via `IntentNavigationManager.shared` and URL schemes (`opalite://color/<uuid>`, `opalite://createColor`, `opalite://swatchBar`, `opalite://sharedImage`).

### StoreKit (Onyx)
- Lifetime purchase (`onyx_lifetime_20`, $19.99)
- Monthly subscription (`onyx_1m_0.99`)
- Annual subscription (`onyx_1yr_4.99`)
- Gates: unlimited canvases (1 free), unlimited palettes (5 free), save from Community, export

## Key Patterns

- **MVVM**: ViewModels as nested classes (e.g., `ColorEditorView.ViewModel`)
- **App lifecycle**: `AppStage` enum in ContentView's ViewModel (`.splash` → `.onboarding` → `.main`)
- **Size-class adaptive layouts**: iPad/Mac show additional tabs and split views
- **Sample data**: Models provide sample data for SwiftUI previews
- **File sharing**: Code shared across targets via Xcode file membership (not Swift packages)
- **Tests**: Swift Testing framework (`@Test`, `#expect`), not XCTest

## Extension Targets

- **OpaliteWidgetsExtension**: Home screen widgets
- **OpaliteShareExtension**: Share sheet for importing images
- **OpaliteQuickLook**: File preview for .opalitecolor/.opalitepalette
- **OpaliteThumbnail**: File thumbnail provider
- **OpaliteMessages**: iMessage extension

## SwiftUI Conventions

- Use `@Observable` (Swift 5.9+) instead of ObservableObject
- Inject managers via `.environment()` at app root
- ViewModels are nested classes within their view files
- Use MARK comments for code organization within files
