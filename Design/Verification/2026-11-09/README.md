# Palette accessibility tools (2026-11-09)

Simulators: iPhone 18 Pro and iPad Pro 13-inch (M5), ad hoc signed Debug build, run with
`--no-cloudkit --skip-onboarding --seed-sample-data --simulate-onyx --seed-confusable-palette --open-first-palette --expand-accessibility`
(`--accessibility-tool=scale|vision` picks the tool, `--palette-index=N` picks another sample palette). All are DEBUG-only flags.
The "Confusable" palette is seeded by `--seed-confusable-palette` because the sample palettes have no pairs that collapse under simulation.

| File | What it shows |
|---|---|
| `iphone-contrast-matrix.png`, `ipad-contrast-matrix.png` | Accessibility view, Contrast tab (WCAG): every ordered pair, ratio, AA/AAA levels for normal and large text. iPhone scrolls sideways; iPad fills the page. |
| `iphone-lightness-scale.png`, `ipad-lightness-scale.png` | Scale tab: base chooser, hex field, 11-step ramp, selected step detail (with a Display P3 value where the sRGB step is chroma reduced), Add as Palette. |
| `iphone-color-vision.png`, `ipad-color-vision.png` | Color Vision tab: score tile per deficiency and the problem pairs with designed vs simulated swatches. |
| `iphone-palette-detail.png` | The palette screen with its single new "Accessibility" row (below the swatch board and info tiles; may be off screen at the top scroll position). |

Not captured: Mac Catalyst (build only, never launched), tvOS (build only; the tools are iOS/visionOS views).
