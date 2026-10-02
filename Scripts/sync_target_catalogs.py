#!/usr/bin/env python3
"""
sync_target_catalogs.py — derive the per-target String Catalogs from the app's master catalog.

Package strings resolve in `Bundle.main` at runtime, so every *process* that renders them
needs its own catalog: the iOS app (`Opalite/Localizable.xcstrings`, the master), the TV
app, the watch app, the widgets, the iMessage app, and the extensions. This script copies
each key the target's sources (its own folder plus the package modules it links) can render
from the master into that target's `Localizable.xcstrings`, so translations are authored
once and never drift.

    python3 Scripts/sync_target_catalogs.py          # rewrite every derived catalog
    python3 Scripts/sync_target_catalogs.py --check  # exit 1 if any derived catalog is stale
"""

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from extract_package_strings import collect  # noqa: E402
from pin_package_strings import CATALOG, ROOT  # noqa: E402

# Target folder → the source roots (relative to the repo) whose strings it renders.
TARGETS = {
    "OpaliteTV": [
        "OpaliteTV",
        "Packages/Opalite/Sources/OpaliteCore",
        "Packages/Opalite/Sources/OpaliteDesignSystem",
        "Packages/Opalite/Sources/OpaliteServices",
        "Packages/Opalite/Sources/OpaliteFeatureShared",
        "Packages/Opalite/Sources/OpaliteFeatureTV",
        "Packages/Opalite/Sources/OpaliteComposition",
    ],
    "OpaliteWatch Watch App": ["OpaliteWatch Watch App", "Packages/Opalite/Sources/OpaliteCore", "Packages/Opalite/Sources/OpaliteDesignSystem"],
    "OpaliteWatchWidgets": ["OpaliteWatchWidgets", "Packages/Opalite/Sources/OpaliteCore", "Packages/Opalite/Sources/OpaliteDesignSystem"],
    "OpaliteWidgets": ["OpaliteWidgets", "Packages/Opalite/Sources/OpaliteCore", "Packages/Opalite/Sources/OpaliteDesignSystem"],
    "OpaliteMessages": ["OpaliteMessages", "Packages/Opalite/Sources/OpaliteCore", "Packages/Opalite/Sources/OpaliteDesignSystem"],
    "OpaliteShareExtension": ["OpaliteShareExtension", "Packages/Opalite/Sources/OpaliteCore"],
    "OpaliteQuickLook": ["OpaliteQuickLook", "Packages/Opalite/Sources/OpaliteCore"],
    "OpaliteThumbnail": ["OpaliteThumbnail", "Packages/Opalite/Sources/OpaliteCore"],
}


def render(catalog: dict) -> str:
    return json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : ")) + "\n"


def main() -> int:
    check = "--check" in sys.argv
    master = json.loads(CATALOG.read_text())
    strings = master["strings"]
    extracted = collect()
    stale = []
    for target, roots in TARGETS.items():
        keys = {
            key for key, info in extracted.items()
            if any(file.startswith(root + "/") for file in info["files"] for root in roots)
        }
        derived = {
            "sourceLanguage": master.get("sourceLanguage", "en"),
            "strings": {key: strings[key] for key in sorted(keys) if key in strings},
            "version": master.get("version", "1.0"),
        }
        path = ROOT / target / "Localizable.xcstrings"
        text = render(derived)
        if check:
            if not path.exists() or path.read_text() != text:
                stale.append(target)
            continue
        path.write_text(text)
        print(f"{target}: {len(derived['strings'])} keys")
    if check and stale:
        print("stale catalogs: " + ", ".join(stale))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
