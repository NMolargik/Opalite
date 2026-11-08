# Verification, November 8, 2026: canvas on the iPhone Duo and iPad

Simulator, Debug build of main.

| File | What it shows |
|---|---|
| `duo-closed-canvas-before.png` | Closed iPhone Duo before: ink stops at the vertical bar's safe area, the swatch strip shares the bottom with the collapsed pen. |
| `duo-closed-canvas-after.png` | After: ink runs under the vertical bar to the screen edge, the swatch strip sits under the floating toolbar and fades at its trailing end instead of cutting a swatch. |
| `ipad-canvas-before.png` | iPad Air 11-inch before (unchanged main): no swatch strip at all; it sat behind PencilKit's floating palette, which never reported its frame. |
| `ipad-canvas-after.png` | After: the strip under the toolbar, capped at the readable width (empty portfolio, so it shows the Add Color prompt). |
