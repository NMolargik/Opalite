# Design-token exports, automatic backups, sync health (2026-11-08)

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
