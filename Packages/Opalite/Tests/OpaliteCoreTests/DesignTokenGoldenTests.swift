//
//  DesignTokenEncodersTests.swift
//  OpaliteCoreTests
//
//  Golden-output tests for the design-token exporters, plus naming, ZIP, and JSON-validity checks.
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("Design token goldens")
struct DesignTokenGoldenTests {
    private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }
    private var full: TokenSet { DesignTokenFixtures.set(dark: true) }
    private var compact: TokenSet { DesignTokenFixtures.compact }

    @Test func tailwindWithDark() {
        #expect(text(DesignTokenEncoders.tailwind(full)) == #"""
/* Summer Sunset - Tailwind CSS v4 theme, exported from Opalite */
@theme {
  --color-summer-sunset-dusty-rose: oklch(68.2% 0.096 9.09);
  --color-summer-sunset-dusty-rose-2: oklch(49.9% 0.099 250.43);
  --color-summer-sunset-ff5733: oklch(68.0% 0.210 33.62);
  --color-summer-sunset-neon-lime: oklch(86.6% 0.293 143.16); /* outside sRGB, fallback #00FE24 */
  --color-summer-sunset-default: oklch(21.6% 0.000 0.00);
  --color-summer-sunset-creme-brulee: oklch(89.1% 0.086 88.67);
  --color-summer-sunset-e66633: oklch(66.0% 0.171 40.78);
  --color-summer-sunset-glass: oklch(31.4% 0.056 250.03 / 0.5);
}

/* Dark appearance: overrides the theme variables above. */
@media (prefers-color-scheme: dark) {
  :root {
    --color-summer-sunset-dusty-rose: oklch(39.1% 0.074 5.18);
    --color-summer-sunset-dusty-rose-2: oklch(31.4% 0.056 250.03);
    --color-summer-sunset-ff5733: oklch(41.3% 0.120 33.67);
  }
}
"""# + "\n")
    }

    @Test func androidWithDark() {
        #expect(text(DesignTokenEncoders.androidColorsXML(full)) == #"""
<?xml version="1.0" encoding="utf-8"?>
<!-- Summer Sunset - Exported from Opalite -->
<resources>
    <color name="summer_sunset_dusty_rose">#CC808C</color>
    <color name="summer_sunset_dusty_rose_2">#336699</color>
    <color name="summer_sunset_ff5733">#FF5733</color>
    <color name="summer_sunset_neon_lime">#00FE24</color> <!-- sRGB approximation of a wide-gamut color -->
    <color name="summer_sunset_default">#1A1A1A</color>
    <color name="summer_sunset_creme_brulee">#F2D999</color>
    <color name="summer_sunset_e66633">#E66633</color>
    <color name="summer_sunset_glass">#801A334D</color>
    <!-- Dark appearance: copy these into res/values-night/colors.xml and drop the _dark suffix. -->
    <color name="summer_sunset_dusty_rose_dark">#663340</color>
    <color name="summer_sunset_dusty_rose_2_dark">#1A334D</color>
    <color name="summer_sunset_ff5733_dark">#802B1A</color>
</resources>
"""# + "\n")
    }

    @Test func flutterWithDark() {
        #expect(text(DesignTokenEncoders.flutter(full)) == #"""
// Summer Sunset - Exported from Opalite
import 'dart:ui' show Color, ColorSpace;

abstract final class SummerSunsetColors {
  static const Color summerSunsetDustyRose = Color(0xFFCC808C);
  static const Color summerSunsetDustyRoseDark = Color(0xFF663340);
  static const Color summerSunsetDustyRose2 = Color(0xFF336699);
  static const Color summerSunsetDustyRose2Dark = Color(0xFF1A334D);
  static const Color summerSunsetFf5733 = Color(0xFFFF5733);
  static const Color summerSunsetFf5733Dark = Color(0xFF802B1A);
  static const Color summerSunsetNeonLime = Color.from(alpha: 1, red: 0.4483, green: 0.9851, blue: 0.3159, colorSpace: ColorSpace.displayP3);
  static const Color summerSunsetDefault = Color(0xFF1A1A1A);
  static const Color summerSunsetCremeBrulee = Color(0xFFF2D999);
  static const Color summerSunsetE66633 = Color(0xFFE66633);
  static const Color summerSunsetGlass = Color(0x801A334D);
}
"""# + "\n")
    }

    @Test func scssWithDark() {
        #expect(text(DesignTokenEncoders.scss(full)) == #"""
// Summer Sunset - Exported from Opalite
$summer-sunset-dusty-rose: #CC808C;
$summer-sunset-dusty-rose-dark: #663340;
$summer-sunset-dusty-rose-2: #336699;
$summer-sunset-dusty-rose-2-dark: #1A334D;
$summer-sunset-ff5733: #FF5733;
$summer-sunset-ff5733-dark: #802B1A;
$summer-sunset-neon-lime: #00FE24; // sRGB approximation of color(display-p3 0.4483 0.9851 0.3159)
$summer-sunset-default: #1A1A1A;
$summer-sunset-creme-brulee: #F2D999;
$summer-sunset-e66633: #E66633;
$summer-sunset-glass: rgba(26, 51, 77, 0.50);
"""# + "\n")
    }

    @Test func dtcgCompact() {
        #expect(text(DesignTokenEncoders.dtcg(compact)) == #"""
{
  "summer-sunset": {
    "dusty-rose": {
      "$type": "color",
      "$value": {
        "colorSpace": "srgb",
        "components": [0.8, 0.5, 0.55],
        "hex": "#cc808c"
      },
      "$extensions": {
        "mode": {
          "dark": {
            "colorSpace": "srgb",
            "components": [0.4, 0.2, 0.25],
            "hex": "#663340"
          }
        }
      }
    },
    "neon-lime": {
      "$type": "color",
      "$value": {
        "colorSpace": "display-p3",
        "components": [0.4483, 0.9851, 0.3159],
        "hex": "#00fe24"
      },
      "$description": "Wide-gamut color. The hex value is an sRGB approximation."
    }
  }
}
"""# + "\n")
    }

    @Test func jsonCompact() {
        #expect(text(DesignTokenEncoders.json(compact)) == #"""
{
  "name": "Summer Sunset",
  "generator": "Opalite",
  "colors": [
    {
      "key": "dusty-rose",
      "name": "Dusty Rose",
      "hex": "#CC808C",
      "rgb": {
        "red": 204,
        "green": 128,
        "blue": 140
      },
      "alpha": 1,
      "oklch": {
        "lightness": 0.6818,
        "chroma": 0.0958,
        "hue": 9.09
      },
      "displayP3": {
        "red": 0.7577,
        "green": 0.5137,
        "blue": 0.5522
      },
      "inSRGBGamut": true,
      "dark": {
        "hex": "#663340",
        "rgb": {
          "red": 102,
          "green": 51,
          "blue": 64
        },
        "alpha": 1,
        "oklch": {
          "lightness": 0.3912,
          "chroma": 0.0744,
          "hue": 5.18
        },
        "displayP3": {
          "red": 0.3737,
          "green": 0.2103,
          "blue": 0.2503
        },
        "inSRGBGamut": true
      }
    },
    {
      "key": "neon-lime",
      "name": "Neon Lime",
      "hex": "#00FE24",
      "rgb": {
        "red": 0,
        "green": 254,
        "blue": 36
      },
      "alpha": 1,
      "oklch": {
        "lightness": 0.8657,
        "chroma": 0.293,
        "hue": 143.16
      },
      "displayP3": {
        "red": 0.4483,
        "green": 0.9851,
        "blue": 0.3159
      },
      "inSRGBGamut": false
    }
  ]
}
"""# + "\n")
    }

    @Test func figmaCompact() {
        #expect(text(DesignTokenEncoders.figmaVariables(compact)) == #"""
{
  "collection": "Summer Sunset",
  "note": "Colors are sRGB. Figma variables do not support OKLCH or Display P3, so wide-gamut colors are gamut-mapped and keep their Display P3 value in the description.",
  "modes": [
    "Light",
    "Dark"
  ],
  "variables": [
    {
      "name": "summer-sunset/dusty-rose",
      "type": "COLOR",
      "values": {
        "Light": {
          "hex": "#CC808C",
          "r": 0.8,
          "g": 0.5,
          "b": 0.55,
          "a": 1
        },
        "Dark": {
          "hex": "#663340",
          "r": 0.4,
          "g": 0.2,
          "b": 0.25,
          "a": 1
        }
      }
    },
    {
      "name": "summer-sunset/neon-lime",
      "type": "COLOR",
      "values": {
        "Light": {
          "hex": "#00FE24",
          "r": 0,
          "g": 0.9977,
          "b": 0.1427,
          "a": 1
        }
      },
      "description": "Display P3 original: color(display-p3 0.4483 0.9851 0.3159). Figma variables hold the sRGB approximation."
    }
  ]
}
"""# + "\n")
    }

    @Test func xcassetsCompact() {
        let files = DesignTokenEncoders.xcassetsFiles(compact)
        #expect(files.map(\.path) == ["Contents.json", "Summer Sunset Dusty Rose.colorset/Contents.json", "Summer Sunset Neon Lime.colorset/Contents.json"])
        #expect(text(files[0].data) == #"""
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""# + "\n")
        #expect(text(files[1].data) == #"""
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.550",
          "green" : "0.500",
          "red" : "0.800"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.250",
          "green" : "0.200",
          "red" : "0.400"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""# + "\n")
        #expect(text(files[2].data) == #"""
{
  "colors" : [
    {
      "color" : {
        "color-space" : "display-p3",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.316",
          "green" : "0.985",
          "red" : "0.448"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""# + "\n")
    }
}
