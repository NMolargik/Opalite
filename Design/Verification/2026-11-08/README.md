# Extract Palette verification (2026-11-08)

Run on iPhone 18 Pro Max and iPad Air 13-inch (M4) simulators (ad hoc signed debug build), with a wallpaper image added through `simctl addmedia`.

- `ios-extract-source-picker.png`, `ipad-extract-source-picker.png`: the sheet opened from Portfolio, Create (+), Extract Palette. Photo source with the Photos button and drop zone.
- `ios-extract-photo-result.png`, `ipad-extract-photo-result.png`: swatches extracted from a photo, selection count, color-count stepper, Save To card (new palette named "Photo Palette").
- `ios-extract-website-result.png`, `ipad-extract-website-result.png`: Website source, address typed, swatches extracted from the live page (stripe.com on iPhone, wikipedia.org on iPad). The palette name defaults to the host. Saving on iPhone created a "stripe.com" palette with 5 colors.

Not captured: the camera (no camera in the simulator) and Mac Catalyst (build only, never launched).


## Verification, November 8, 2026: canvas on the iPhone Duo and iPad

Simulator, Debug build of main.

| File | What it shows |
|---|---|
| `duo-closed-canvas-before.png` | Closed iPhone Duo before: ink stops at the vertical bar's safe area, the swatch strip shares the bottom with the collapsed pen. |
| `duo-closed-canvas-after.png` | After: ink runs under the vertical bar to the screen edge, the swatch strip sits under the floating toolbar and fades at its trailing end instead of cutting a swatch. |
| `ipad-canvas-before.png` | iPad Air 11-inch before (unchanged main): no swatch strip at all; it sat behind PencilKit's floating palette, which never reported its frame. |
| `ipad-canvas-after.png` | After: the strip under the toolbar, capped at the readable width (empty portfolio, so it shows the Add Color prompt). |


## Design-token exports, automatic backups, sync health (2026-11-08)

Verified on iPhone 18 Pro and iPad Pro 11-inch (M5) simulators from an unsigned debug build
(`CODE_SIGNING_ALLOWED=NO`, run with `--no-cloudkit`, a DEBUG-only launch flag that skips CloudKit
because an unsigned build has no iCloud entitlement). Because of that flag, Settings shows
"Not Signed In" and "This Device Only", which is the real local-only path.

Other DEBUG-only launch flags used to reach screens without tapping: `--seed-sample-data`,
`--open-first-palette`, `--show-export-sheet`, `--scroll-to-tokens`, `--simulate-onyx`,
`--open-settings`, `--open-backups`.

## Screenshots

| File | Shows |
| --- | --- |
| `iphone-export-list-locked.png`, `ipad-export-list-locked.png` | Share Palette, general formats (Onyx simulated on, so the original list is selectable) |
| `iphone-export-tokens-locked.png`, `ipad-export-tokens-locked.png` | The new "Design Tokens" section with Onyx badges (no Onyx) and the existing Onyx footer |
| `ipad-export-tokens-onyx.png` | The same section unlocked |
| `iphone-backups.png`, `ipad-backups.png` | Settings > Backups after one automatic backup (28 colors, 4 palettes) |
| `iphone-settings.png`, `ipad-settings.png` | Settings with the sync-health rows and the Backups row |
| `exported-file-*.png` | Contents of exported files, **rendered from the files by a script** (the simulator has no file viewer reachable without taps) |

## Exported samples (`exports/`)

Produced by the production encoders from a fixture palette ("Summer Sunset") that exercises name
collisions, an unnamed color, a diacritic name, a non-Latin name, a wide-gamut color, alpha, and a
paired dark palette. `SummerSunset.xcassets.zip` was unzipped with the system `unzip` and compiled
with `xcrun actool` without warnings; `SummerSunset.xcassets/` is the same tree extracted.

## What was not exercised on a device

Tapping Back Up Now, Restore, Share, Import, and picking a format in the sheet (no screen control
was allowed). Those paths are covered by the host tests (`BackupManagerTests`, `LibraryBackupTests`,
the token goldens), not by a UI run.
