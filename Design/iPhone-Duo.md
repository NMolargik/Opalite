# Opalite on iPhone Duo

Reviewed November 7, 2026 against Apple's "Designing for iPhone Duo" guideline, the "Prepare your app for iPhone Duo" checklist, and the four Tech Talks (Prepare, Design, Strike a Pose, Raise the Bar, Leverage Multiple Displays). Opalite was run in the Xcode 27.2 iPhone Duo simulator in the closed, open-landscape, partially-open and open-portrait poses.

## What Apple asks for

**Two size classes, not poses.** Design a compact-width layout for the outer display and a regular-width layout for the inner display. Don't build a layout per pose, don't branch on idiom, and don't treat regular width as "iPad."

| Display | Points | Size classes | Bars |
|---|---|---|---|
| Outer (closed), portrait | 466 × 678 | compact w, regular h | vertical, right edge |
| Outer, landscape | 678 × 466 | compact w, compact h | vertical |
| Inner (open), landscape | 951 × 669 | regular w, regular h | vertical, right edge |
| Inner, portrait | 669 × 951 | regular w, regular h | horizontal (the only pose that keeps them) |

The inner display ignores the app's supported orientations; the outer display follows normal iPhone rules, and Apple recommends supporting landscape there for the tent pose.

**Keep the experience consistent across displays.** Same functionality and element state in every pose. The inner display may show one extra level of hierarchy (list and detail together), and Apple lists three patterns for it: split views, a vertically stacked layout that becomes two columns when width allows, or the tab bar as a sidebar.

**Reserved regions and displacement.** The fold is a "division region" that is active only when partially folded; the cameras are "occlusion regions." System containers, sheets, alerts, menus and popovers move around them automatically. Custom UI should query `GeometryProxy.reservedRegions(kind:)`, prefer an even number of grid columns whenever a division region exists, and move or resize elements rather than rearrange them. Continuous scrolling content does not need to avoid the fold.

**Arrangements (iOS 27.1).** `ArrangementView { primary } secondary: { … }` with `.split` divides space along the longer axis and follows the fold; `.overlay` stacks and goes side by side when folded. Keep navigation containers outside it. In propped-up poses, interactive controls belong in the bottom half and viewed content in the top half.

**Vertical bars.** With the iOS 27.1 SDK or later, `NavigationStack`/`NavigationSplitView` toolbars and `TabView` lay out vertically on their own. Every toolbar item needs both a symbol and a title; text-only items stay horizontal; use `visibilityPriority` for the actions that must stay visible and the system overflow menu for the rest.

**Checklist items.** No `UIScreen.main`, no orientation checks, size from `GeometryReader`/`onGeometryChange`, safe areas handled per edge (they are asymmetric), test Split View on both sides, `ConcentricRectangle` for edge-hugging corners.

**App Store.** Duo screenshots (outer 1398 × 2034, inner 2007 × 2853, plus landscape) earn a "made for iPhone Duo" badge on the product page and become required in April 2027 for apps built with the 27.1 SDK. Featuring nominations can state "optimized for iPhone Duo, including all device poses."

## What Opalite already does right

- No `UIScreen.main`, orientation or idiom checks anywhere in the package. Layout decisions use `horizontalSizeClass` and `onGeometryChange`.
- Standard containers throughout: `TabView` with `.sidebarAdaptable`, one `NavigationStack` per tab, `.toolbar` items with symbols and titles. Built with Xcode 27.2, so on the Duo the toolbar and tab bar already move into the vertical strip, content respects the camera and status bar, and sheets get vertical close buttons. Confirmed in the simulator on the outer display and in open landscape; open portrait keeps horizontal bars.
- Grids use `.adaptive` columns; the detail screens cap width at 760 points; every interactive element lives in the safe area.
- The 1.7.1 build being uploaded today is compiled with the 27.2 SDK, so Duo owners get the edge-to-edge, vertical-bar version without any of the work below.

## Gaps found in the simulator

1. **Inner display is the iPhone layout stretched.** Portfolio stays one column with horizontal palette rows, and the color detail stacks its cards in one 760-point column with a 730-point hero. The two-column palette grid never engages because `PortfolioLayout.wideWindowThreshold` is 900 and the open display minus the bar insets is about 890.
2. **Partially folded, nothing reacts.** Rows and cards straddle the hinge; nothing queries reserved regions, and column counts are not kept even.
3. **Outer display is portrait only.** iPhone orientations are `Portrait` only, so the tent pose is unsupported on the closed device.
4. **Canvas ignores the pose.** The canvas and its tool picker are one surface in every pose; the laptop pose has no use of the bottom half.
5. **No Duo screenshots in App Store Connect**, so no badge.

## Plan

### 1.7.2, about two days: look right in every pose

- Portfolio: on regular width, lower the palette grid threshold so the open display gets two palette columns, and keep column counts even whenever a division region exists (query `reservedRegions(kind: .division, options: .includeInactive)`).
- Color detail: on regular width wider than about 800 points, a two-column layout: hero, tiles, codes and notes on the left; palette, harmonies, tones and contrast on the right. Plain `HStack` keyed on size class; `ArrangementView(.split)` once we take the 27.1 dependency, which also handles the fold for free.
- Palette detail and Community grids: even columns on regular width.
- Add landscape to the iPhone orientations and check the compact-height layouts for the editor sheets and the contrast checker.
- Capture Duo screenshots for both displays and submit them with the release for the badge.

### 1.8: use the fold

- **Canvas in laptop pose.** `ArrangementView` with the canvas as primary and the tool picker plus palette strip as secondary, `.split` restricted to the vertical axis. Propped on a table, the canvas sits on the top half and the tools on the stable bottom half, which is Apple's own example of a pose-aware layout. Flat, it collapses back to today's single surface.
- **Fold to preview light and dark.** With a dark-variant palette paired (new in 1.7.1), partially folding the device shows the light palette on one half and the dark palette on the other. Same `ArrangementView` pattern with `.overlay`, no new data model.
- **Contrast checker and harmony wheel** in the bottom half when propped up, driven by the same split.
- **Hinge-driven touch:** `onHingeChange` to run the blend between light and dark variants as the hinge angle changes. Effect only; layout never depends on the angle.
- Nominate for featuring with the "optimized for all poses" line once the above ships.

### Not worth doing

- Tab bar as sidebar on the inner display. The system's vertical tab bar costs 60 points; a sidebar costs 200 and Opalite has five tabs. Revisit if the Community tab grows sections.
- `UIRequiresFullScreen` or opting out of vertical bars. Nothing in Opalite is a bottom-heavy single-page layout.
- Multiple windows. Only available on the inner display and not a natural fit for a portfolio app.

## Verification

Device Hub → iPhone Duo → pose buttons (Closed, Partially Open, Open, Rotate). Split View: drag the app by the home indicator to either side and test both. The resizable iOS simulator and iPhone Mirroring on macOS 27 cover the in-between sizes.
