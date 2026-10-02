# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Opalite is a native color-management and digital-design app for Apple platforms: six color-picking modes, palettes with drag-and-drop, WCAG contrast checking, color-vision simulation, a PencilKit canvas (1 free, unlimited with Onyx), multi-format export (Procreate, Adobe ASE, SwiftUI, CSS, GIMP, PDF), and a CloudKit-backed Community for sharing colors and palettes. It ships an iOS/iPadOS app (also on Mac via Catalyst and on visionOS), a tvOS app, an Apple Watch companion with a complication, home-screen widgets, an iMessage app, a Share Extension, and Quick Look preview/thumbnail extensions.

The app is a **thin set of targets on top of an SPM umbrella package** (`Packages/Opalite`) of layered, single-responsibility modules — the same clean architecture as Stork/Waffle/SetDeck/Mygra. Dependencies point **inward**: features depend on the design system and core; data implements core's protocols; **core depends on nothing** (Foundation + SwiftData only).

## Build & Run

**Open `Opalite.xcworkspace`** (not the bare `.xcodeproj`) — it resolves the local package. The only external dependency is DeviceKit (device marketing names), consumed by `OpaliteServices` behind the `DeviceDescribing` seam. Xcode 27 / Swift 6.4.

**Swift 6 language mode**, MainActor default isolation everywhere: app/extension/watch/TV targets set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; package targets use `swiftSettings: [.defaultIsolation(MainActor.self)]`. `#MemberImportVisibility` is on: every file must import the module defining any member it uses (`import os` for `Log`). Deployment floors: **iOS/iPadOS 18.4 (Catalyst 18.4), tvOS 18.4, watchOS 10, visionOS 26.2**; macOS 15.6 is the host-test floor only (there is no native macOS app — Mac is Catalyst, so `os(iOS)` is true there and `targetEnvironment(macCatalyst)` distinguishes it). iOS 26/27-only APIs (`glassEffect`, glass button styles, `tabViewBottomAccessory`, `reorderable`, FoundationModels) stay behind the `…IfAvailable` helpers in `OpaliteDesignSystem`.

Fast iteration — the package builds and tests on the macOS host, simulator-free:
```
cd Packages/Opalite && swift build && swift test
```
Verify a feature's UI compiles (feature view files are gated `#if os(iOS) || os(visionOS)`, TV `#if os(tvOS)`):
```
cd Packages/Opalite && xcodebuild -scheme OpaliteFeaturePortfolio -destination 'generic/platform=iOS Simulator' build
```
Build the whole product (app + extensions + watch app) or the TV app:
```
xcodebuild -workspace Opalite.xcworkspace -scheme Opalite -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
xcodebuild -workspace Opalite.xcworkspace -scheme OpaliteTV -destination 'generic/platform=tvOS Simulator' build
```
Package products only resolve through **scheme** builds (`-workspace … -scheme`); `xcodebuild -project … -target X` cannot see them.

**Requirements:** iCloud container `iCloud.com.molargiksoftware.Opalite` (private DB for sync, public DB for Community); App Group `group.com.molargiksoftware.Opalite` (widgets, iMessage, Share Extension hand-off, intent hand-off); watch App Group `group.com.molargiksoftware.OpaliteWatch`; StoreKit products `onyx_1yr_4.99` and `onyx_lifetime_20` (`Opalite/Configuration.storekit` for local testing).

## Architecture — `Packages/Opalite`

```
   ┌──────────── Opalite (app target — thin) ──────────────────┐
   │ OpaliteApp (@main) builds SessionController · Intents/    │
   │ (entities as IndexedEntity, intents, shortcuts, seams) ·  │
   │ QuickActions · OpaliteCommands · SwatchBar WindowGroup ·  │
   │ visionOS ImmersiveSpace                                   │
   ├─ OpaliteTV (thin) · OpaliteWatch (Core + DS) · widgets ───┤
   │  iMessage · Share · QuickLook · Thumbnail (Core [+ DS])   │
   └──────────────────────────┬────────────────────────────────┘
                              │ hosts RootView / TVRootHost
   ┌──────────────────────────▼────────────────────────────────┐
   │ OpaliteComposition — SessionController (composition root) │
   │ + RootView (stage machine) + MainView (adaptive tabs,     │
   │ typed NavigationStacks, global sheets) + SwatchBarScene   │
   └──┬──────────────────────────────────┬─────────────────────┘
 ┌────▼──────────────┐  ┌──────────────┐ ┌▼───────────────────┐
 │ OpaliteFeature*   │  │ Opalite-     │ │ OpaliteData        │
 │ Portfolio · Search│  │ Services     │ │ Default*Repository │
 │ ColorEditor ·     │  │ CloudSync ·  │ │ · OpaliteStore     │
 │ Sharing · Commun- │  │ CloudKit     │ │ (CloudKit → local  │
 │ ity · Canvas ·    │  │ Community ·  │ │ → in-memory) ·     │
 │ Settings (+Paywall│  │ StoreKit ·   │ │ SamplePortfolio-   │
 │ ) · SwatchBar ·   │  │ watch relay ·│ │ Data (DEBUG)       │
 │ Onboarding ·      │  │ export/PDF · │ └─────────┬──────────┘
 │ Immersive · TV    │  │ Foundation-  │           │ implements
 ├───────────────────┤  │ Models naming│           │
 │ OpaliteFeature-   │  │ · screen     │           │
 │ Shared            │  │ sampler      │           │
 │ PortfolioModel ·  │  └──────┬───────┘           │
 │ CanvasModel ·     │         │                   │
 │ CommunityModel ·  │         │                   │
 │ HexCopyModel ·    │         │                   │
 │ ImportModel ·     │         │                   │
 │ SwatchView/Row ·  │         │                   │
 │ PreviewEnvironment│         │                   │
 └───┬──────────┬────┘         │                   │
     │ uses     │ uses         │                   │
 ┌───▼──────┐ ┌─▼─────────────▼───────────────────▼───────────┐
 │ Opalite- │ │ OpaliteCore (pure)                             │
 │ Design-  │ │ @Model types · RGBA/ColorMath/Harmony/CVD sim  │
 │ System   │ │ · classifier · exporters · file codec · enums  │
 │ brand ·  │ │ · DeepLink/AppRouter · repository & use-case   │
 │ tokens · │ │ PROTOCOLS · PortfolioChangeCenter · seams ·    │
 │ toast ·  │ │ CommunityService protocol · watch wire types · │
 │ glass ·  │ │ widget snapshot · PortfolioStatusSync · Log    │
 │ components│└────────────────────────────────────────────────┘
 └──────────┘
```

### OpaliteCore (pure — Foundation + SwiftData only, host-tested)
- **Models** (`@Model`): `OpaliteColor` (sRGB components + authorship), `OpalitePalette` (colors, tags, preview background, archived, linked canvas), `CanvasFile` (external-storage drawing/placed-images/thumbnail blobs, canvas size). CloudKit rules: defaults on every attribute, optional relationships, no unique constraints; new properties must be additive. Core is SwiftUI-free: `Color` faces live in the design system (`color.swiftUIColor`, `rgba.color`).
- **Color math** (`nonisolated`, `Sendable`): `RGBA`/`HSL`/`HSV`/`CMYK` + `ColorMath` (hex parse incl. #RGB/#RRGGBBAA, formatting, WCAG luminance/contrast, `WCAGConformance`), `ColorHarmony` (complementary/analogous/triadic/tetradic/split, tints/shades/tones, mix), `ColorBlindnessSimulator` (Brettel/Viénot/Mollon in linear RGB), `ColorClassifier` (family/search terms/description), `ColorNamePrompt` (the Apple Intelligence prompt + parser).
- **Domain**: `PaletteOrder` (persisted `[UUID]` order with `onMove` semantics), `PalettePreviewLayout`, `PortfolioSearch` (+ Siri's ranked name matches), `HexFormat` (the "#" preference), `ExportFormat` enums + `ExportEncoders` (ASE, Procreate ZIP, GPL, CSS, SwiftUI) + `ZipArchive`, `OpaliteFileCodec` (native `.opalitecolor`/`.opalitepalette` JSON, import previews), `OnyxGate` (free tier: 5 palettes, 1 canvas, no Community saves/pro exports), `ReviewMilestone`, `PortfolioStatusSync` (one change-stream observer that pushes the widget snapshot, the watch snapshot, Spotlight, and Siri vocabulary, debounced + fingerprinted).
- **Enumerations**: `AppTab` (+`available` per platform, `keyboardNumber`), `AppStage`, `OnboardingStep` (every page skippable per the HIG), `ColorPickerTab` (+ keys 1–6), `ColorBlindnessMode`, `AppThemeOption`, `AppIconOption`, `SwatchSize`, `CanvasShape`, `PreviewBackground`, `DeviceKind`, `OnyxSubscription`, Community enums.
- **Navigation**: `AppRouter` (`@MainActor @Observable`): `selectedTab`, `pendingDeepLink`, `pendingPresentation` (paywall with context, color editor, photo sampler, shared image, SwatchBar info); `open(_:)` jumps to the link's `destinationTab` and stages it, `open(url:)` parses. Widgets, quick actions, Siri, iMessage, the menu bar, and `onOpenURL` all go through it; `MainView` consumes. `DeepLink` (`opalite://portfolio|community|search|canvases|settings|onyx|createColor|createPalette|samplePhoto|swatchBar|sharedImage`, `color/<uuid>`, `palette/<uuid>`, `canvas/<uuid>`) with App Group hand-off for `openAppWhenRun` intents. Typed destinations: `PortfolioDestination`, `CommunityDestination`, `SettingsDestination`, `CanvasDestination`.
- **Services (protocols only)**: `ColorRepository`/`PaletteRepository`/`CanvasRepository` + single-verb use-cases (`LoadColors`, `FindColor`, `CreateColor`, `InsertColor`, `UpdateColor`, `DeleteColor`, `MoveColorToPalette`, `LoadPalettes`, `FindPalette`, `CreatePalette`/`InsertPalette` (Onyx-gated, `throws(PaletteCreationError)`), `UpdatePalette`, `DeletePalette`, `LinkCanvasToPalette`, `LoadCanvases`, `FindCanvas`, `CreateCanvas` (gated), `UpdateCanvas`, `DeleteCanvas`, `ObservePortfolioChanges`, DEBUG `GenerateSampleData`) — each a `protocol` + `…UseCase` struct with `callAsFunction`. `CommunityService` (CloudKit-free: `CommunityRecordID`, opaque `CommunityCursor` pages). Nothing outside the composition root touches a repository directly (even App Intents).
- **Typed errors**: the persistence boundary declares `throws(PersistenceError)`; `OpaliteError` covers import/export, subscriptions, Community, and tier limits (`requiresOnyx`).
- **Change stream**: `PortfolioChangeCenter` yields `PortfolioChange` payloads (`colorCreated(id)`, `…Updated`, `…Deleted`, palette/canvas equivalents, `bulk`). Repositories notify on every successful write and `CloudSyncManager` notifies `.bulk` on CloudKit imports; the shared models and `PortfolioStatusSync` observe the one multicast `AsyncStream`. Never add per-screen refresh callbacks or NotificationCenter posts.
- **Seams**: `KeyValueStoring`, `EntitlementProviding` (+`FixedEntitlement`), `DeviceDescribing`, `WidgetTimelineReloading`, `WatchPortfolioPushing`, `Pasteboarding`, `PortfolioIndexing` (Spotlight — impl app-side), `IntentDonating` (app-side), `EntityActivityAnnotating` (Siri on-screen awareness — app-side), `ShortcutVocabularyUpdating` (app-side), `ReviewRequesting` (app-side), `ColorNaming`.
- **Wire types**: `WatchColor`/`WatchPalette`/`WatchPortfolioSnapshot` + `WatchMessageKey`/`WatchAction`/`WatchReply` (one definition linked by the phone relay, the watch app, and the watch widget), `WatchSnapshotCache`, `WatchWidgetStore`; `WidgetColor`/`WidgetColorStorage`/`WidgetKind` (home-screen widgets + iMessage); `SharedImageStore` (Share Extension hand-off).
- `Log` — `os.Logger` per category. **Never `print`.**

### OpaliteData (persistence impl, depends on Core)
`DefaultColorRepository` (stamps authorship/device, keeps both sides of the palette relationship consistent), `DefaultPaletteRepository`, `DefaultCanvasRepository` (folds duplicate records from sync races), `OpaliteStore.makeContainer(inMemory:)` — **CloudKit → local → in-memory graceful degradation** — plus `makeTemporaryContainer()` for tests/previews. `SamplePortfolioData` (DEBUG): four themed palettes, loose colors, three canvases.

### OpaliteServices (system frameworks, depend on Core)
`CloudSyncManager` (NSPersistentCloudKitContainer events + remote-change pings → change center; `isOnline` is the app's reachability source; `triggerSync()`), `CloudKitCommunityService` (public DB; record mapping lives here), `SubscriptionManager` (StoreKit 2; conforms to `EntitlementProviding`), `PhoneConnectivityManager` (iOS: `WatchPortfolioPushing`; services `requestSync`/`copyHex`/`copyColorFile`, queues a notification when backgrounded; delegate callbacks are `nonisolated` and parse Sendable snapshots before hopping), `ExportService` + `PortfolioPDFRenderer` (UIKit), `CanvasThumbnailRenderer`, `ColorNameSuggestionService` (FoundationModels behind `ColorNaming`), `SystemColorSampler` (Catalyst eyedropper via the ObjC runtime), `DeviceInfo` (DeviceKit), `SystemPasteboard`, `WidgetCenterReloader`.

### OpaliteDesignSystem (depends on Core)
Brand colors **in code** (`Color.opaliteBlue/.opalitePurple/.opaliteTan/.onyx/.opaliteInverse`, `LinearGradient.opalite/.opaliteWash/.opaliteHorizontal/.onyx`, `AngularGradient.hueWheel/.appleIntelligence`), `Brand.Space`/`Brand.Radius`/`readableWidth`/`detailMaxWidth`, `Color(hex:)`/`Color(RGBA)`/`toHex()`, color bridging for every Core color type, localized titles/tints for Core enums (`CoreStyling`), `Haptics` (no-op off-UIKit), toast stack (`ToastStyle`/`ToastItem` with optional action/`ToastManager`/`.toastContainer()`), surface modifiers (`adaptiveGlass`, `adaptiveGlassCapsule`, `materialSurface`, `cardSurface`/`cardStyle`, `glassActionButton`, `primaryActionButton`/`secondaryActionButton`, `hoverHighlight`/`hoverLift`, `statPillBackground`, `toolbarButtonTint`, `.if`), **OS-gated chrome helpers** that keep `#available` out of feature code (`tabViewBottomAccessoryIfAvailable`, `minimizeTabBarOnScrollIfAvailable`, `minimizingSearchIfAvailable`, `softScrollEdgesIfAvailable`, `backgroundExtensionIfAvailable`, `navigationSubtitleIfAvailable`, `reorderableIfAvailable` (iOS 27), `ToolbarSpacerIfAvailable`), label styles (`.alignedIcon`, `.settingsIcon(tint)`), components (`SectionCard`, `DetailRow`, `InfoTile`, `HexBadge`, `Checkerboard`, `OnyxBadge`, `EmptyStateView`, `FlowLayout`, `ColorChip`), `ImageRendering` (SwiftUI → PNG). **Do not** hand-roll tinted glass; use `glassActionButton` and reserve `prominent` for the single primary action per context.

### OpaliteFeatureShared (depends on Core + DesignSystem + Services)
- **`PortfolioModel`** — the environment-injected portfolio surface (successor to ColorManager): cached `colors`/`palettes`, the user's `PaletteOrder` (`orderedPalettes`), `authorName`/`authorship`, `activeColorID`/`activePaletteID` + `pendingCommand` (menu-bar context), and verbs that each go through a use-case, refresh the cache, and surface failures as toasts (never `try?`-swallowed); tier limits toast with a "Get Onyx" action that routes to the paywall. The change stream refreshes it for writes made elsewhere (CloudKit, intents, watch).
- **`CanvasModel`** (canvases, `pendingCanvasID`, `pendingShape`, `selectedInkColor`, tier gate + `requestOpen`), **`CommunityModel`** (paged feed, local search, rate-limited publishing, reporting with auto-hide at 5, Onyx-gated saves), **`HexCopyModel`** (first-run "#" question, copy + toast + donation), **`ImportModel`** (file previews and confirmation).
- **Shared views**: `SwatchView` (generic menus, editable name badge with AI suggestions, drag, CVD simulation, checkerboard), `SwatchRow` (drop target that moves/imports), `ColorDragDrop`/`DraggedColor`.
- **`PreviewEnvironment`**: in-memory repositories + `FakeCommunityService` + fakes behind the production use-cases; `.previewEnvironment()` is how feature previews and tests get their graph. `\.onyxEntitlement` environment value.

### OpaliteFeature* (one per screen, depend on Core + DesignSystem + FeatureShared [+ Services])
`Portfolio` (root, color/palette detail, `PortfolioDestinationView`; depends on ColorEditor + Sharing), `Search` (depends on Portfolio), `ColorEditor` (`ColorEditorView(mode:onCancel:onSave:)`, `PhotoSamplerSheet`), `Sharing` (export/import/publish/report sheets, export image views), `Community`, `Canvas` (`CanvasListView`, `CanvasView(canvasID:)`), `Settings` (+ `PaywallView(context:)`, `OnyxInfoSheet`, admin, watch info), `SwatchBar` (`SwatchBarView`, `SwatchBarInfoSheet`), `Onboarding` (`SplashView`, `OnboardingView`), `Immersive` (visionOS `ColorConstellationView` + `ImmersiveColorModel`), `TV` (`TVRootView`). Views are `#if os(iOS) || os(visionOS)`-gated (TV `#if os(tvOS)`) and read `@Environment(PortfolioModel.self)` etc.; `RootView` injects everything (including `AppRouter`, `CloudSyncManager`, `SubscriptionManager`, `ColorNameSuggestionService`, and on iOS `PhoneConnectivityManager`).

### OpaliteComposition (top of graph — the composition root)
`SessionController` (`@MainActor @Observable`) builds the whole graph in `init` (container → change center → repositories → use-cases → shared models → managers → `PortfolioStatusSync`), owns the `router`, `handle(url:)` (deep links, then Opalite files), `becameActive()` (entitlements, queued watch copy), `annotateViewingColor/Palette` for Siri's on-screen awareness, and `start()`. `RootView` = stage machine (splash → onboarding → main) + theme + environment injection + `.toastContainer()` (honors `--reset-onboarding`/`--skip-onboarding` for UI tests); `MainView` = `TabView` + `Tab` + `.sidebarAdaptable`, one `NavigationStack` per tab with typed destinations, the **tab-bar bottom accessory** (live color/palette count + New Color), the globally presented sheets (color editor, photo sampler, shared image, paywall, imports, hex-prefix question), and all deep-link / presentation routing. `SwatchBarRootView` hosts the secondary window; `TVRootHost` the tvOS UI.

### App target (`Opalite/`) — thin
`OpaliteApp` (builds `SessionController` with the app-side seams, registers it with `AppDependencyManager`, hosts the main `WindowGroup(id: "main")`, the `WindowGroup(id: "swatchBar")`, and the visionOS `ImmersiveSpace`; under the test host it uses one process-wide temp-store container). `QuickActions.swift` = Home Screen quick actions: static items in `Info.plist` whose `type` is an `opalite://` URL, bridged from the UIKit delegates through `QuickActionRelay` into `session.handle(url:)`; the scene delegate also configures the Catalyst title bar and docks the SwatchBar window. `OpaliteCommands` (menu bar: ⌘N/⇧⌘N/⌥⌘N new color/palette/canvas, ⇧⌘P sample photo, ⇧⌘S SwatchBar, ⌘R refresh, ⌘1–5 tabs, Color menu bound to the active detail screen, Canvas shapes ⇧⌘1–5) drives the same router/models. `Intents/`: `ColorEntity`/`PaletteEntity` (`IndexedEntity` + `EntityStringQuery` via `@Dependency var session`), intents (`OpenOpaliteIntent`, `ShowColorIntent`, `ShowPaletteIntent`, `CreateColorIntent`, `CreatePaletteIntent`, `CopyColorHexIntent`, `RandomColorIntent`, `PaletteColorsIntent`, `PortfolioSummaryIntent`), `OpaliteShortcuts` (phrases localized in `AppShortcuts.xcstrings`), and the app-side seams (`SpotlightIndexer`, `IntentDonor`, `EntityActivityAnnotator`, `ShortcutVocabularyUpdater`, `AppStoreReviewRequester`).

### Extensions, watch, TV
- `OpaliteWidgetsExtension` (random color), `OpaliteMessages` (send a swatch), `OpaliteShareExtension` (image → sampler), `OpaliteQuickLook`/`OpaliteThumbnail` (native files) link `OpaliteCore` (+ `OpaliteDesignSystem` where they render). The old `membershipExceptions` file-sharing is gone.
- `OpaliteWatch Watch App` + `OpaliteWatchWidgetsExtension` link `OpaliteCore` + `OpaliteDesignSystem`; `WatchSessionManager` is the relay over the Core wire types and the phone is the source of truth.
- `OpaliteTV` hosts `TVRootHost` over a `SessionController` (no canvas/community on TV).
- If a target needs another package module, add it to that target's `packageProductDependencies` in `project.pbxproj` (deterministic `DEC0DE…` IDs).

## Testing
- Swift Testing (`@Suite`, `@Test`, `#expect`). The real suite is in `Packages/Opalite/Tests` (`swift test`, host, simulator-free): `OpaliteCoreTests` (color math, harmony, CVD, classifier, order, layout, search, encoders, codec, deep links, router, status sync, use-cases), `OpaliteDataTests` (repositories over on-disk temp stores), `OpaliteServicesTests`, `OpaliteDesignSystemTests`, `OpaliteFeatureSharedTests` (models over the preview graph), per-feature view-model suites, `OpaliteCompositionTests`.
- **Suites that create SwiftData containers are `.serialized` with a unique on-disk temp store per test** (`OpaliteStore.makeTemporaryContainer()`) — parallel in-memory containers share a /dev/null SQLite identity and crash the host.
- `OpaliteTests` (hosted) covers app glue only — hosted tests must not create SwiftData containers. `OpaliteUITests` are smoke tests over the shell's accessibility identifiers.
- New logic goes into Core (pure) first with tests, then a repository/use-case in Data, then feature behavior over `PreviewEnvironment`.

## Localization
- Languages: en (source), es, fr-CA, ja via `Opalite/Localizable.xcstrings` (the **master**) + `InfoPlist.xcstrings` + `AppShortcuts.xcstrings`.
- **Policy for package strings:** SwiftUI's key-based initializers and `String(localized:)` resolve in `Bundle.main`, so translations for package-rendered strings live in the **app target's** catalog, pinned `extractionState: "manual"` + `shouldGenerateSymbol: false`. `STRING_CATALOG_GENERATE_SYMBOLS = NO` everywhere. Xcode's extractor never sees package sources, so the catalog is maintained by the scripts below, not by the Xcode "Localize" button.
- **After adding user-facing strings to package code:** `python3 Scripts/extract_package_strings.py --missing` lists the new keys exactly as the runtime looks them up (interpolations become Foundation specifiers: `Int` → `%lld`, `Double` → `%lf`, everything else `%@`; App Intents parameters become `${name}`). Translate them into a JSON `{key: {"es", "fr-CA", "ja"}}`, merge with `python3 Scripts/merge_translations.py <json>`, pin with `python3 Scripts/pin_package_strings.py`, then regenerate the per-process catalogs with `python3 Scripts/sync_target_catalogs.py`. **Don't reword existing keys** — the English literal *is* the key.
- Every process that renders package strings carries its own derived catalog (TV app, watch app, both widget extensions, iMessage, Share, Quick Look, Thumbnail): `sync_target_catalogs.py` copies the keys each target's sources can render out of the master, so never hand-edit those; `--check` fails when they drift.

## Key Patterns & Gotchas
- `@ContentBuilder` (SwiftUI's name for `ViewBuilder`) is the house spelling in package code; `@ToolbarContentBuilder` is unchanged. OS-gated modifiers are wrapped once in `OpaliteDesignSystem` as `…IfAvailable` helpers — don't sprinkle `#available` through feature views.
- Adaptive layout is driven by `horizontalSizeClass` and `onGeometryChange`, never `UIDevice.userInterfaceIdiom` — iPad windows are freely resizable.
- Drag & drop uses `DraggedColor` (`Transferable`) with the legacy `UTType.opaliteColor`/`.opaliteColorID` providers for cross-device drops; `SwatchRow` is the drop target.
- Swift 6 concurrency: non-Sendable values crossing isolation use `UncheckedSendableBox`; system-framework delegate callbacks are `nonisolated` and extract Sendable values before hopping to `@MainActor`; `NSItemProvider` loads go through `ColorDragDrop`'s main-actor helper.
- Default-argument isolation: a MainActor-protocol conformer used as a default argument needs a `nonisolated init() {}` (see `WidgetCenterReloader`).
- Shipping identifiers (`com.molargiksoftware.Opalite`, the App Groups, the CloudKit container, the UTIs, the StoreKit product IDs, the `AppStorageKeys` strings) must not change.
- App icon assets (`AppIcon.icon`, `AppIcon-Light.icon`, `Icons/`) are off-limits.
- Verify new API names against the installed SDK's `.swiftinterface` by compiling — never adopt from memory.
