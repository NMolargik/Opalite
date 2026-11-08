# UX round 4: floating background button, title menu (2026-11-09)

Simulators: iPhone 18 Pro and iPad Pro 13-inch (M5), iOS 27.2, sample data plus the 5-color "Confusable" palette, `--no-cloudkit`, no Onyx.
Palettes: 3 colors (Sunrise), 5 (Confusable), 13 (Grayscale). `before-*` are the ux3 "after" shots (main); `after-*` are this branch.

- The board header row is gone at rest. The preview-background button (30pt circle, label "Preview background" with its value) floats over the card's top-trailing corner, inset 4pt. The grid gets 10pt extra top inset so a long name badge in the trailing swatch never sits under the button; it saves about 38pt versus before.
- While renaming, the inline name field still appears above the board (with trailing space reserved for the button).
- The navigation title now has a title menu (`toolbarTitleMenu`, chevron next to the name) with "Rename…", the same flow as More > Rename….
- Not run: tapping the title menu (simctl has no tap), Mac Catalyst (build only). No new strings.

- `after-iphone-5-menu-background.png`: final version: preview background moved into More, no corner button (Nov 8).
