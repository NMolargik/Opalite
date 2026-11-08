# UX round 3: board column count and header (2026-11-09)

Simulators: iPhone 18 Pro and iPad Pro 13-inch (M5), iOS 27.2, sample data plus the 5-color "Confusable" palette, `--no-cloudkit`, no Onyx.
Palettes: 3 colors (Sunrise), 5 (Confusable), 13 (Grayscale, the largest sample palette).

Files: `before-<iphone|ipad>-<3|5|13>.png` and `after-<iphone|ipad>-<3|5|13>.png`.

- `GridColumns.count(... items:)` avoids a lone "+" tile on the last row: one more column if tiles can shrink to 80% of the minimum (even steps on a fold), else one fewer when that divides the tiles evenly.
- The board header no longer shows the palette name; only the preview-background button remains (label "Preview background"). Rename stays in More > Rename..., which shows the inline name field while editing.
- Not run: the Duo fold (logic unit-tested), Mac Catalyst (build only).
