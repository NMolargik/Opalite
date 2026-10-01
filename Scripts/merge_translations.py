#!/usr/bin/env python3
"""
merge_translations.py — merge a translations JSON into Opalite/Localizable.xcstrings.

Input: a JSON object mapping English keys to {"es": "...", "fr-CA": "...", "ja": "..."}.
Every key becomes a manual, non-symbol-generating catalog entry; existing entries are
updated in place. Keys with `%` specifiers are stored verbatim (Foundation handles them).

    python3 Scripts/merge_translations.py translations.json
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Opalite" / "Localizable.xcstrings"
LANGUAGES = ("es", "fr-CA", "ja")


def main(path: str) -> int:
    translations = json.loads(pathlib.Path(path).read_text())
    catalog = json.loads(CATALOG.read_text()) if CATALOG.exists() else {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
    strings = catalog.setdefault("strings", {})
    added = updated = 0
    for key, values in translations.items():
        entry = strings.get(key)
        if entry is None:
            entry = {}
            strings[key] = entry
            added += 1
        else:
            updated += 1
        entry["extractionState"] = "manual"
        entry["shouldGenerateSymbol"] = False
        localizations = entry.setdefault("localizations", {})
        for lang in LANGUAGES:
            value = values.get(lang)
            if value is None:
                continue
            localizations[lang] = {"stringUnit": {"state": "translated", "value": value}}
    catalog["sourceLanguage"] = "en"
    catalog["version"] = "1.0"
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : ")) + "\n")
    print(f"added {added}, updated {updated}; catalog now has {len(strings)} keys")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
