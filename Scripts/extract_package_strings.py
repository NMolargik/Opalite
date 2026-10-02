#!/usr/bin/env python3
"""
extract_package_strings.py — list every user-facing literal in the package and app sources
as a String Catalog key, with Swift interpolations turned into Foundation specifiers.

Xcode only extracts app-target sources into `Opalite/Localizable.xcstrings`, but the UI
lives in `Packages/Opalite`. This script produces the keys Xcode would have extracted
(`%lld` for integers, `%lf` for doubles, `%@` for everything else) so translations can be
authored and merged with `merge_translations.py`.

    python3 Scripts/extract_package_strings.py            # JSON: {key: {"files": [...], "args": [...]}}
    python3 Scripts/extract_package_strings.py --keys     # one key per line
    python3 Scripts/extract_package_strings.py --missing  # keys not yet in the catalog
"""

import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pin_package_strings import CATALOG, EXTRA_SOURCES, LITERAL_PATTERNS, PACKAGE_SOURCES  # noqa: E402

INTERPOLATION = re.compile(r"\\\(((?:[^()]|\([^()]*(?:\([^()]*\)[^()]*)*\))*)\)")
SPECIFIER_ARG = re.compile(r'specifier:\s*"([^"]+)"')
FORMAT_ARG = re.compile(r"format:\s*\.(number|percent|currency)")

INT_HINTS = re.compile(
    r"(\.count\b|\bcount\b|\bindex\b|\bnumber\b|\btotal\b|\bremaining\b|\blimit\b|Limit\b|\bInt\(|\bmax\b|\bmin\b|\bpage\b|"
    r"\bdays?\b|\bhours?\b|\bminutes?\b|\bseconds?\b|\bpercent\b|\bstep\b|\bposition\b|\bordinal\b|\bsize\b|\bwidth\b|\bheight\b|\+ 1\b|- 1\b|\bcolorCount\b|\bpaletteCount\b|\bcanvasCount\b)"
)
DOUBLE_HINTS = re.compile(r"(\bratio\b|\bDouble\(|\bopacity\b|\balpha\b|\bluminance\b|\bcontrast\b|\bhue\b|\bsaturation\b|\bbrightness\b|\blightness\b|\bvalue\b)")
STRING_HINTS = re.compile(
    r"(String\(|\.name\b|\.title\b|hexString|displayName|\.formatted\(|\.rawValue|\.description\b|\.joined\(|\blabel\b|\btext\b|\btitle\b|\bname\b|"
    r"\bhex\b|\.uppercased\(|\.lowercased\(|\.capitalized|\.localized|\.message\b|\.summary\b|\bdeviceName\b|\bversion\b|\bbuild\b|\bformat\b)"
)

DECL_LINE = re.compile(r"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*([A-Za-z0-9_?.<>\[\]]+))?\s*(?:=\s*(.+))?$")
COMPUTED_DECL = re.compile(r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z0-9_?.<>\[\]]+)\s*\{")
PARAM_DECL = re.compile(r"[(,]\s*(?:_\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z0-9_?.<>\[\]]+)")

INT_TYPES = {"Int", "Int64", "Int32", "UInt", "Int?", "Int64?"}
DOUBLE_TYPES = {"Double", "CGFloat", "TimeInterval", "Float", "Double?", "CGFloat?"}
STRING_TYPES = {"String", "String?", "Substring", "LocalizedStringResource", "LocalizedStringKey"}


def category(declared_type, rhs):
    """'int' / 'double' / 'string' / None for a declaration's explicit type or initializer."""
    if declared_type:
        if declared_type in INT_TYPES:
            return "int"
        if declared_type in DOUBLE_TYPES:
            return "double"
        if declared_type in STRING_TYPES or declared_type.endswith("String"):
            return "string"
        return "other"
    if rhs is None:
        return None
    rhs = rhs.strip().rstrip("{").strip()
    if re.fullmatch(r"-?\d+", rhs) or rhs.startswith("Int(") or rhs.endswith(".count") or re.search(r"\.count\s*[-+*/]|[-+*/]\s*\d+$", rhs) and ".count" in rhs:
        return "int"
    if re.fullmatch(r"-?\d+\.\d+", rhs) or rhs.startswith(("Double(", "CGFloat(")):
        return "double"
    if rhs.startswith(("String(", '"')) or ".formatted(" in rhs or rhs.endswith((".uppercased()", ".lowercased()", ".hexString", ".displayName", ".name", ".title")):
        return "string"
    return None


def symbol_table(source: str) -> dict[str, set[str]]:
    table: dict[str, set[str]] = {}
    for line in source.splitlines():
        line = line.strip()
        if match := COMPUTED_DECL.search(line):
            name, declared = match.groups()
            if cat := category(declared, None):
                table.setdefault(name, set()).add(cat)
        elif match := DECL_LINE.search(line):
            name, declared, rhs = match.groups()
            if cat := category(declared, rhs):
                table.setdefault(name, set()).add(cat)
        for name, declared in PARAM_DECL.findall(line):
            if cat := category(declared, None):
                table.setdefault(name, set()).add(cat)
    return table


GLOBAL_TABLE: dict[str, set[str]] = {}


def resolve(name: str, local: dict[str, set[str]]):
    for table in (local, GLOBAL_TABLE):
        cats = (table.get(name) or set()) - {"other"}
        if len(cats) == 1:
            return next(iter(cats))
    return None


SPEC = {"int": "%lld", "double": "%lf", "string": "%@", "other": "%@"}


def specifier_for(expression: str, local: dict[str, set[str]]) -> str:
    expression = expression.strip()
    if match := re.fullmatch(r"\\\.\$([A-Za-z_][A-Za-z0-9_]*)", expression):
        return "${" + match.group(1) + "}"
    if match := SPECIFIER_ARG.search(expression):
        return match.group(1)
    if FORMAT_ARG.search(expression) or ".formatted(" in expression:
        return "%@"
    head = expression.split(",")[0].strip()
    if head.startswith("Int("):
        return "%lld"
    if head.startswith(("String(", "\"")) or head.endswith((".uppercased()", ".lowercased()", ".capitalized")):
        return "%@"
    # `a ?? b`: both sides share a type; classify the left side.
    head = head.split("??")[0].strip()
    # A bare identifier or a member path: look up the last component.
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.$]*", head):
        last = head.split(".")[-1]
        if cat := resolve(last, local):
            return SPEC[cat]
    # Arithmetic on a resolved integer (`index + 1`, `tags.count - limit`).
    if match := re.fullmatch(r"([A-Za-z_][A-Za-z0-9_.]*)\s*[-+*/]\s*.+", head):
        last = match.group(1).split(".")[-1]
        if last == "count" or resolve(last, local) == "int":
            return "%lld"
    if STRING_HINTS.search(head):
        return "%@"
    if INT_HINTS.search(head):
        return "%lld"
    if DOUBLE_HINTS.search(head):
        return "%lf"
    return "%@"


def catalog_key(literal: str, local: dict[str, set[str]]):
    args = []

    def replace(match):
        spec = specifier_for(match.group(1), local)
        args.append((match.group(1).strip(), spec))
        return spec

    key = INTERPOLATION.sub(replace, literal)
    key = key.replace('\\"', '"').replace("\\n", "\n")
    return key, args


def source_files():
    bases = [PACKAGE_SOURCES] + EXTRA_SOURCES
    for base in bases:
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.swift")):
            text = str(path)
            if "/.build/" in text or "/Tests/" in text or path.parts[-2].endswith("Tests"):
                continue
            yield path


def collect():
    results: dict[str, dict] = {}
    for path in source_files():
        for name, cats in symbol_table(path.read_text()).items():
            GLOBAL_TABLE.setdefault(name, set()).update(cats)
    for path in source_files():
        if True:
            source = path.read_text()
            local = symbol_table(source)
            for pattern in LITERAL_PATTERNS:
                for match in pattern.finditer(source):
                    key, args = catalog_key(match.group(1), local)
                    if not key.strip():
                        continue
                    entry = results.setdefault(key, {"files": [], "args": []})
                    rel = str(path.relative_to(CATALOG.parent.parent))
                    if rel not in entry["files"]:
                        entry["files"].append(rel)
                    for arg in args:
                        if list(arg) not in entry["args"]:
                            entry["args"].append(list(arg))
    return results


def main() -> int:
    results = collect()
    if "--missing" in sys.argv:
        catalog = json.loads(CATALOG.read_text()) if CATALOG.exists() else {"strings": {}}
        results = {k: v for k, v in results.items() if k not in catalog["strings"]}
    if "--keys" in sys.argv or "--missing" in sys.argv:
        for key in sorted(results):
            print(key.replace("\n", "\\n"))
        return 0
    print(json.dumps(results, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
