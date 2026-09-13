#!/usr/bin/env python3
"""Assemble lib/l10n/app_ar.arb from the E7 Arabic fragments in docs/qa.

Fragments are unioned (first definition wins, in the order below) and emitted
in the template's key order so reviewers can diff en/ar side by side.
"""
import collections, glob, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EN = ROOT / 'lib/l10n/app_en.arb'
AR = ROOT / 'lib/l10n/app_ar.arb'
FRAGMENTS = [
    *sorted(glob.glob(str(ROOT / 'docs/qa/e7-*/messages_ar*.json'))),
    # Every other slice keeps its fragment beside its notes; E7 fragments
    # (listed first) win on any duplicate key.
    *sorted(glob.glob(str(ROOT / 'docs/qa/*/messages_ar*.json'))),
    str(ROOT / 'docs/qa/e7-fixes/arabic_core.json'),
    str(ROOT / 'docs/qa/e7-fixes/arabic_features.json'),
    str(ROOT / 'docs/qa/e7-fixes/arabic_chat.json'),
]
PLACEHOLDER = re.compile(r'\{([A-Za-z_][A-Za-z0-9_]*)\s*[,}]', re.ASCII)

def main() -> int:
    en = json.loads(EN.read_text(encoding='utf-8'), object_pairs_hook=collections.OrderedDict)
    ar = {}
    for fragment in FRAGMENTS:
        for key, value in json.loads(Path(fragment).read_text(encoding='utf-8')).items():
            if not key.startswith('@'):
                ar.setdefault(key, value)
    out = collections.OrderedDict([('@@locale', 'ar')])
    missing, mismatched = [], []
    for key, value in en.items():
        if key.startswith('@'):
            continue
        if key not in ar:
            missing.append(key)
            continue
        declared = set((en.get('@' + key) or {}).get('placeholders') or {})
        expected = declared or set(PLACEHOLDER.findall(value))
        if expected - set(PLACEHOLDER.findall(ar[key])):
            mismatched.append(key)
        out[key] = ar[key]
    AR.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'wrote {len(out) - 1} Arabic strings; missing {len(missing)}; placeholder mismatches {len(mismatched)}')
    for key in missing: print('  missing', key)
    for key in mismatched: print('  mismatch', key)
    return 1 if missing or mismatched else 0

if __name__ == '__main__':
    sys.exit(main())
