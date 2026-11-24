#!/usr/bin/env python3
"""Audit app copy keys and interpolation placeholders. No network or provider dependency."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
translations = json.loads((root / "INVERTER/Resources/English.json").read_text())
for key, value in translations.items():
    assert isinstance(value, str) and value.strip(), f"Empty translation: {key}"
    assert sorted(re.findall(r"\{\d+\}", key)) == sorted(re.findall(r"\{\d+\}", value)), f"Placeholder mismatch: {key}"

# Literal-only L() and service errors; interpolated copy is validated by its template above.
missing = set()
for path in (root / "INVERTER").rglob("*.swift"):
    source = path.read_text()
    for match in re.finditer(r'(?:\bL|localizedServiceError)\("((?:[^"\\]|\\[ntr"\\])*)"\)', source):
        key = json.loads('"' + match.group(1) + '"')
        if re.search(r"[\u4e00-\u9fff]", key) and key not in translations:
            missing.add(key)
assert not missing, f"Missing translations: {sorted(missing)}"
print(f"Validated {len(translations)} translations and interpolation templates.")
