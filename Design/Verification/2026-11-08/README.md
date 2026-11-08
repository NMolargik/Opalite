# Extract Palette verification (2026-11-08)

Run on iPhone 18 Pro Max and iPad Air 13-inch (M4) simulators (ad hoc signed debug build), with a wallpaper image added through `simctl addmedia`.

- `ios-extract-source-picker.png`, `ipad-extract-source-picker.png`: the sheet opened from Portfolio, Create (+), Extract Palette. Photo source with the Photos button and drop zone.
- `ios-extract-photo-result.png`, `ipad-extract-photo-result.png`: swatches extracted from a photo, selection count, color-count stepper, Save To card (new palette named "Photo Palette").
- `ios-extract-website-result.png`, `ipad-extract-website-result.png`: Website source, address typed, swatches extracted from the live page (stripe.com on iPhone, wikipedia.org on iPad). The palette name defaults to the host. Saving on iPhone created a "stripe.com" palette with 5 colors.

Not captured: the camera (no camera in the simulator) and Mac Catalyst (build only, never launched).
