#!/usr/bin/env python3
"""Validate the bounded Arabic corpus without a Flutter or network process."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import unicodedata

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "arabic_core-source.json"
TARGET = ROOT / "arabic_core.json"
IDENTIFIER = re.compile(r"[a-zA-Z_][a-zA-Z_0-9]*")
SELECTOR = re.compile(r"(?:=-?\d+(?:\.\d+)?|[a-zA-Z_][a-zA-Z_0-9]*)")
UNCHANGED_ALLOWED = {
    "appTitle", "libraryMcpTitle", "aboutBuildVersion", "workStatusElapsed",
    "usagePeriod", "activeContextTypeCount", "activeContextPartHeading",
    "quotaSourceTitle",
}
# Product names, executable example, and placeholders only; no English prose.
LATIN_PHRASES_ALLOWED = {"OpenCode Mobile", "npm run dev", "Tailscale Serve", "Tailscale Funnel"}


def read_unique(path: Path) -> dict:
    def unique(pairs):
        result = {}
        for key, value in pairs:
            assert key not in result, f"Duplicate JSON key: {key}"
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique)


def parse_icu(text: str):
    """Parse the simple/ICU plural constructs used by this baseline slice.

    This is a structural check, not a replacement for Flutter gen-l10n. Both
    catalogs are parsed, argument names and ICU kinds are compared, and Arabic
    plural additions are checked explicitly. Literal English contractions are
    plain text; translated messages contain no ASCII ICU-quoting apostrophes.
    """
    index = 0
    names = set()
    choices = []

    def space():
        nonlocal index
        while index < len(text) and text[index].isspace():
            index += 1

    def token(pattern):
        nonlocal index
        space()
        match = pattern.match(text, index)
        assert match, f"Expected token at {index}"
        index = match.end()
        return match.group()

    def expect(value):
        nonlocal index
        space()
        assert text.startswith(value, index), f"Expected {value!r} at {index}"
        index += len(value)

    def argument():
        nonlocal index
        expect("{")
        name = token(IDENTIFIER)
        names.add(name)
        space()
        if index < len(text) and text[index] == "}":
            index += 1
            return
        expect(",")
        kind = token(IDENTIFIER)
        assert kind in {"plural", "select", "selectordinal"}, kind
        expect(",")
        branches = set()
        while True:
            space()
            assert index < len(text), "Unclosed ICU argument"
            if text[index] == "}":
                index += 1
                break
            selector = token(SELECTOR)
            assert selector not in branches, "Duplicate ICU branch"
            branches.add(selector)
            expect("{")
            sequence(nested=True)
        assert "other" in branches, "Missing ICU other branch"
        choices.append((name, kind, branches))

    def sequence(nested=False):
        nonlocal index
        while index < len(text):
            if text[index] == "{":
                argument()
            elif text[index] == "}":
                assert nested, "Unmatched closing brace"
                index += 1
                return
            else:
                index += 1
        assert not nested, "Unclosed ICU branch"

    sequence()
    return names, choices


def main():
    source = read_unique(SOURCE)
    target = read_unique(TARGET)
    messages = {k: v for k, v in source.items() if not k.startswith("@")}
    assert len(messages) == 730
    assert set(messages) == set(target), {
        "missing": sorted(set(messages) - set(target)),
        "extra": sorted(set(target) - set(messages)),
    }
    plural_keys = []
    unchanged = []
    metadata_checks = 0
    for key, translated in target.items():
        assert isinstance(translated, str) and translated.strip(), key
        assert translated == translated.strip(), f"Whitespace: {key}"
        assert not any(unicodedata.category(c) == "Cf" for c in translated), f"Bidi/control marker: {key}"
        assert not any(ord(c) < 32 and c not in "\n\t" for c in translated), f"Control character: {key}"
        assert "'" not in translated, f"Review ICU apostrophe quoting: {key}"
        source_names, source_choices = parse_icu(messages[key])
        target_names, target_choices = parse_icu(translated)
        assert source_names == target_names, f"Placeholder mismatch: {key}"
        meta = source.get("@" + key, {}).get("placeholders")
        if meta is not None:
            assert source_names == set(meta), f"Source metadata mismatch: {key}"
            metadata_checks += 1
        assert len(source_choices) == len(target_choices), f"ICU construct mismatch: {key}"
        for (s_name, s_kind, s_branches), (t_name, t_kind, t_branches) in zip(source_choices, target_choices):
            assert (s_name, s_kind) == (t_name, t_kind), f"ICU kind/argument mismatch: {key}"
            assert s_branches <= t_branches, f"Original ICU selector missing: {key}"
            if s_kind in {"plural", "selectordinal"}:
                assert {"two", "few", "many", "other"} <= t_branches, f"Arabic plural coverage: {key}"
                assert "zero" in t_branches or "=0" in t_branches, f"Arabic zero coverage: {key}"
                assert "one" in t_branches or "=1" in t_branches, f"Arabic one coverage: {key}"
            else:
                assert s_branches == t_branches, f"Select identity changed: {key}"
        if source_choices:
            plural_keys.append(key)
        if translated == messages[key]:
            unchanged.append(key)
            assert key in UNCHANGED_ALLOWED, f"Untranslated prose: {key}"
        elif not re.search(r"[\u0600-\u06ff]", translated):
            raise AssertionError(f"Missing Arabic: {key}")
        for phrase in re.findall(r"[a-zA-Z]+(?: [a-zA-Z]+)+", translated):
            assert phrase in LATIN_PHRASES_ALLOWED, f"Review Latin prose: {key}: {phrase}"
    assert set(unchanged) == UNCHANGED_ALLOWED
    report = {
        "status": "passed",
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "translation_sha256": hashlib.sha256(TARGET.read_bytes()).hexdigest(),
        "source_message_count": len(messages),
        "translated_message_count": len(target),
        "missing_keys": [],
        "extra_keys": [],
        "placeholder_parity": "passed for every source and translated message",
        "source_placeholder_metadata_verified": metadata_checks,
        "metadata_policy": "Source file retains types; target contains messages only for root merge with unchanged English metadata.",
        "icu_structure": "balanced and parsed; kind, argument and existing selectors preserved",
        "arabic_plural_message_count": len(plural_keys),
        "arabic_plural_messages": plural_keys,
        "arabic_plural_forms": "zero (or =0), one (or =1), two, few, many, other in every plural",
        "unchanged_name_or_template_keys": unchanged,
        "english_prose_left_untranslated": [],
        "direction_control_characters": [],
        "ascii_icu_quoting_apostrophes": [],
        "boundary": "Corpus-only structural verification. Flutter generation, rendered RTL layouts and activation are integration checks.",
    }
    (ROOT / "arabic_core-validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "messages": len(target), "plural_messages": len(plural_keys), "metadata_checked": metadata_checks}))


if __name__ == "__main__":
    main()
