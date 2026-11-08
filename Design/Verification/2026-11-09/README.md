# Palette accessibility tools (2026-11-09)

Simulators: iPhone 18 Pro and iPad Pro 13-inch (M5), ad hoc signed Debug build, run with
`--no-cloudkit --skip-onboarding --seed-sample-data --simulate-onyx --seed-confusable-palette --open-first-palette --expand-accessibility`
(`--accessibility-tool=scale|vision` picks the tool, `--palette-index=N` picks another sample palette, `--scroll-to-accessibility` scrolls the palette screen to the new row; `--expand-accessibility` also opens the iPhone sheet at its large detent). All are DEBUG-only flags.
The "Confusable" palette is seeded by `--seed-confusable-palette` because the sample palettes have no pairs that collapse under simulation.

| File | What it shows |
|---|---|
| `iphone-contrast-matrix.png`, `ipad-contrast-matrix.png` | Accessibility view, Contrast tab (WCAG): every ordered pair, ratio, AA/AAA levels for normal and large text. One quiet result badge per cell (gray Fail, amber AA Large, green AA/AAA), a WCAG/APCA menu on the summary line, a trailing fade where columns scroll off. iPhone scrolls sideways; iPad sizes to content. |
| `iphone-lightness-scale.png`, `ipad-lightness-scale.png` | Scale tab: base chooser, hex field, 11-step ramp, selected step detail (with a Display P3 value where the sRGB step is chroma reduced), Add as Palette. |
| `iphone-color-vision.png`, `ipad-color-vision.png` | Color Vision tab: score tile per deficiency and the problem pairs with designed vs simulated swatches. |
| `iphone-palette-detail.png`, `ipad-palette-detail.png` | The palette screen scrolled so the single new "Accessibility" row is visible between Colors and Notes. |

Not captured: Mac Catalyst (build only, never launched), tvOS (build only; the tools are iOS/visionOS views).


## Export sheet and Settings iCloud: before and after (2026-11-09)

Captured on iPhone 18 Pro and iPad Pro 13-inch (M5) simulators, iOS 27.2, light mode, `--no-cloudkit --seed-sample-data` debug builds.
Palette "Grayscale" (13 colors). Filenames end in `-iphone` or `-ipad`.

## Export sheet (Share Palette)
- `export-before-locked-*`, `export-before-owned-*`: old flat list of 16 formats, two-line descriptions, Onyx badge on every locked row.
- `export-after-locked-*`: Image, PDF, Opalite File, then one Onyx note ("Files and code need Onyx" / Get Onyx) heading the three groups (Design Apps 3, Code 6, Design Tokens 4).
- `export-after-owned-*`: same without the Onyx note.
- `export-after-sublist-code-locked-*`: pushed Code list, not signed in to Onyx (note repeated on top, no per-row locks; tapping a row opens the paywall).
- `export-after-sublist-tokens-owned-*`: pushed Design Tokens list with Onyx owned.

## Settings iCloud section
- `settings-before-signedout-*`, `settings-before-synced-*`: old stack (iCloud Sync, iCloud Account, Library Storage, Last Synced, three footers).
- `settings-after-signedout-*`: one "iCloud: Not Signed In" row, "Sync Details" disclosure, one short footer.
- `settings-after-synced-*`: "iCloud: Up to Date", no footer.
- `settings-after-error-*`: "iCloud: Error" with the short footer.

Simulated sync states use the DEBUG flag `--simulate-icloud=signedout|synced|syncing|error|offline|local`. Export sheet: `--show-export-sheet[=color]`, `--export-group=designApps|code|designTokens`, `--simulate-no-onyx`.
