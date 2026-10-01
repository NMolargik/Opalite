#!/usr/bin/env python3
"""
pin_package_strings.py — keep package-rendered strings safe in the app's String Catalog.

Opalite's UI lives in Swift package modules, but SwiftUI's key-based initializers
(`Text("…")`, `Button("…")`, `Label("…", systemImage:)`, …) and `String(localized:)`
resolve against `Bundle.main` at runtime. Translations therefore live in the *app
target's* `Opalite/Localizable.xcstrings` — by design. Xcode's automatic extraction,
however, only scans app-target sources, so every key whose literal moved into the
package gets flagged "stale" and is one careless click away from deletion.

This script pins every catalog entry whose literal appears anywhere in
`Packages/Opalite/Sources` to `extractionState: "manual"` (rescuing already-stale ones),
and reports package string literals that are missing from the catalog entirely.

    python3 Scripts/pin_package_strings.py            # pin + report
    python3 Scripts/pin_package_strings.py --missing  # only print missing literals (one per line)
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Opalite" / "Localizable.xcstrings"
PACKAGE_SOURCES = ROOT / "Packages" / "Opalite" / "Sources"
EXTRA_SOURCES = [ROOT / "Opalite", ROOT / "OpaliteTV", ROOT / "OpaliteWatch Watch App", ROOT / "OpaliteWidgets", ROOT / "OpaliteWatchWidgets", ROOT / "OpaliteMessages", ROOT / "OpaliteShareExtension", ROOT / "OpaliteQuickLook", ROOT / "OpaliteThumbnail"]

SPECIFIER = re.compile(r"%(?:\d+\$)?(?:l?l?[du]|[@fgeasxX]|\.\d+f)")

LITERAL_PATTERNS = [
    re.compile(p)
    for p in (
        r'Text\("((?:[^"\\]|\\.)+)"[,)]',
        r'Label\("((?:[^"\\]|\\.)+)",',
        r'Button\("((?:[^"\\]|\\.)+)"[,)]',
        r'Toggle\("((?:[^"\\]|\\.)+)",',
        r'Picker\("((?:[^"\\]|\\.)+)",',
        r'TextField\("((?:[^"\\]|\\.)+)",',
        r'SecureField\("((?:[^"\\]|\\.)+)",',
        r'Section\("((?:[^"\\]|\\.)+)"\)',
        r'Section\(header: Text\("((?:[^"\\]|\\.)+)"\)',
        r'ContentUnavailableView\("((?:[^"\\]|\\.)+)",',
        r'LabeledContent\("((?:[^"\\]|\\.)+)"[,)]',
        r'Link\("((?:[^"\\]|\\.)+)",',
        r'Menu\("((?:[^"\\]|\\.)+)"[,)]',
        r'Stepper\("((?:[^"\\]|\\.)+)",',
        r'DatePicker\("((?:[^"\\]|\\.)+)",',
        r'ProgressView\("((?:[^"\\]|\\.)+)"\)',
        r'Tab\("((?:[^"\\]|\\.)+)",',
        r'EmptyStateView\("((?:[^"\\]|\\.)+)",',
        r'SectionCard\("((?:[^"\\]|\\.)+)",',
        r'DetailRow\("((?:[^"\\]|\\.)+)",',
        r'\.navigationTitle\("((?:[^"\\]|\\.)+)"\)',
        r'\.accessibilityLabel\("((?:[^"\\]|\\.)+)"\)',
        r'\.accessibilityHint\("((?:[^"\\]|\\.)+)"\)',
        r'\.accessibilityValue\("((?:[^"\\]|\\.)+)"\)',
        r'\.alert\("((?:[^"\\]|\\.)+)",',
        r'\.confirmationDialog\("((?:[^"\\]|\\.)+)",',
        r'\.configurationDisplayName\("((?:[^"\\]|\\.)+)"\)',
        r'\.description\("((?:[^"\\]|\\.)+)"\)',
        r'String\(localized: "((?:[^"\\]|\\.)+)"[,)]',
        r'LocalizedStringResource\("((?:[^"\\]|\\.)+)"\)',
        r'LocalizedStringResource = "((?:[^"\\]|\\.)+)"',
        r'IntentDescription\("((?:[^"\\]|\\.)+)"\)',
        r'TypeDisplayRepresentation\(name: "((?:[^"\\]|\\.)+)"\)',
        r'@Parameter\(title: "((?:[^"\\]|\\.)+)"',
        r'shortTitle: "((?:[^"\\]|\\.)+)"',
        r'dialog: "((?:[^"\\]|\\.)+)"\)',
        r'Summary\("((?:[^"\\]|\\.)+)"',
    )
]


def source_blob(paths):
    parts = []
    for base in paths:
        for path in sorted(base.rglob("*.swift")):
            if "/.build/" in str(path) or "/Tests/" in str(path):
                continue
            parts.append(path.read_text())
    return "\n".join(parts)


def normalize(literal: str) -> str:
    literal = re.sub(r"\\\((?:[^()]|\([^()]*\))*\)", "%", literal)
    return literal.replace('\\"', '"').replace("\\n", "\n")


def key_matches(key: str, blob: str) -> bool:
    escaped = key.replace('"', '\\"').replace("\n", "\\n")
    if key in blob or escaped in blob:
        return True
    fragments = [f for f in SPECIFIER.split(key) if f.strip()]
    if not fragments or fragments == [key]:
        return False
    return all(f in blob or f.replace('"', '\\"') in blob for f in fragments)


def literals(blob: str) -> set[str]:
    found: set[str] = set()
    for pattern in LITERAL_PATTERNS:
        for match in pattern.finditer(blob):
            found.add(normalize(match.group(1)))
    return found


def catalog_covers(literal: str, keys: list[str]) -> bool:
    if literal in keys:
        return True
    if "%" in literal:
        fragments = [f for f in literal.split("%") if f.strip()]
        return any(all(f in key for f in fragments) for key in keys)
    return False


def main() -> int:
    missing_only = "--missing" in sys.argv
    catalog = json.loads(CATALOG.read_text()) if CATALOG.exists() else {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    blob = source_blob([PACKAGE_SOURCES])
    strings = catalog["strings"]

    pinned, rescued = [], []
    for key, entry in strings.items():
        if not key_matches(key, blob):
            continue
        state = entry.get("extractionState", "automatic")
        if state == "stale":
            rescued.append(key)
        elif state != "manual":
            pinned.append(key)
        entry["extractionState"] = "manual"
        entry["shouldGenerateSymbol"] = False

    if not missing_only:
        CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : ")) + "\n")
        print(f"pinned {len(pinned)} entries to manual; rescued {len(rescued)} stale entries")
        for key in rescued:
            print(f"  rescued: {key!r}")

    keys = list(strings.keys())
    all_literals = literals(source_blob([PACKAGE_SOURCES] + EXTRA_SOURCES))
    missing = sorted(l for l in all_literals if not catalog_covers(l, keys))
    if missing_only:
        for literal in missing:
            print(literal)
        return 0
    if missing:
        print(f"\n{len(missing)} literals missing from the catalog:")
        for literal in missing:
            print(f"  MISSING: {literal!r}")
    else:
        print("\nno literals missing from the catalog")
    return 0


if __name__ == "__main__":
    sys.exit(main())
