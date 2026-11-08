# Export sheet and Settings iCloud: before and after (2026-11-09)

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
