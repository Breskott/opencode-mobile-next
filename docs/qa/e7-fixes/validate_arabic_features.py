#!/usr/bin/env python3
"""Validate the E7 feature corpus without generating or editing app localization."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'arabic_features-source.json'
TRANSLATION = ROOT / 'arabic_features.json'
ARABIC_CATEGORIES = {'zero', 'one', 'two', 'few', 'many', 'other'}
TECHNICAL_ONLY = {
    'quotaCodex', 'quotaClaude', 'pluginsSourceSdk', 'quotaMiniMax',
    'managedHealthVersion', 'quotaGlm', 'monitorRequestSummary',
    'monitorLabeledTime', 'openCodeConnectionLabel', 'termuxGuideEnterKey',
    'setupRuntimeOne', 'projectFolderNameHint', 'projectFolderPathHint',
    'reviewNoteDescription', 'oc2DiscoveryEditorTitle',
}
TECHNICAL_LITERALS = (
    'OpenCode', 'Codex', 'Claude', 'MiniMax', 'GLM', 'Coding Plan',
    'Pro/Max', 'ChatGPT', 'Termux', 'Ubuntu', 'Android', 'iOS', 'Keychain',
    'Tailscale', 'Serve', 'Funnel', 'tailnet', 'Wi-Fi', 'VPN', 'DNS',
    'POSIX', 'OPENCODE_SERVER_PASSWORD', 'HTTP', 'HTTPS', 'OAuth',
    'API', 'SDK', 'MCP', 'JSON-RPC', 'A2A', 'Linux', 'musl', 'localhost',
    'PNG', 'JPEG', 'GIF', 'WebP', 'SVG', 'PDF', 'Git',
    'bridge-unlocked', 'tool/quota/README.md', 'my-app', 'GiB', 'MB', 'KB',
)


def load(path: Path) -> dict:
    def unique(pairs: list[tuple]) -> dict:
        result = {}
        for key, value in pairs:
            assert key not in result, f'{path.name}: duplicate key {key}'
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique)


class Message:
    """Parse the simple arguments and plural/select syntax used by this source."""

    def __init__(self, value: str):
        self.value = value
        self.pos = 0
        self.arguments: dict[str, str | None] = {}
        self.selectors: dict[tuple[str, str], set[str]] = {}
        self.sequence(False)
        assert self.pos == len(value), 'unconsumed ICU text'

    def space(self):
        while self.pos < len(self.value) and self.value[self.pos].isspace():
            self.pos += 1

    def expect(self, char: str):
        self.space()
        assert self.pos < len(self.value) and self.value[self.pos] == char, (
            f'expected {char!r} at {self.pos}'
        )
        self.pos += 1

    def token(self, pattern: str) -> str:
        self.space()
        match = re.match(pattern, self.value[self.pos:])
        assert match, f'expected ICU token at {self.pos}'
        self.pos += len(match[0])
        return match[0]

    def sequence(self, nested: bool):
        while self.pos < len(self.value):
            char = self.value[self.pos]
            if char == '{':
                self.argument()
            elif char == '}':
                assert nested, f'unexpected closing brace at {self.pos}'
                self.pos += 1
                return
            else:
                self.pos += 1
        assert not nested, 'unclosed ICU branch'

    def argument(self):
        self.expect('{')
        name = self.token(r'[A-Za-z_]\w*')
        self.space()
        assert self.pos < len(self.value), 'unclosed ICU argument'
        if self.value[self.pos] == '}':
            self.pos += 1
            self.arguments.setdefault(name, None)
            return
        self.expect(',')
        kind = self.token(r'[A-Za-z]+')
        assert kind in {'plural', 'select', 'selectordinal'}, kind
        previous = self.arguments.get(name)
        assert previous in (None, kind), f'conflicting kind for {name}'
        self.arguments[name] = kind
        self.expect(',')
        selectors = set()
        while True:
            self.space()
            assert self.pos < len(self.value), 'unclosed ICU expression'
            if self.value[self.pos] == '}':
                self.pos += 1
                break
            selector = self.token(r'=[0-9]+|[A-Za-z_]\w*')
            assert selector not in selectors, f'duplicate ICU selector {selector}'
            selectors.add(selector)
            self.expect('{')
            self.sequence(True)
        assert 'other' in selectors, f'{name}: missing other branch'
        self.selectors[(name, kind)] = selectors


def literal_present(value: str, literal: str) -> bool:
    return bool(re.search(r'(?<![A-Za-z0-9_])' + re.escape(literal)
                          + r'(?![A-Za-z0-9_])', value))


def urls(value: str) -> set[str]:
    return {url.rstrip('.,;') for url in re.findall(r'(?:https?|wss?)://[^\s]+', value)}


def main():
    source = load(SOURCE)
    arabic = load(TRANSLATION)
    source_keys = {key for key in source if not key.startswith('@')}
    assert len(source_keys) == 727
    assert source_keys == set(arabic), {
        'missing': sorted(source_keys - set(arabic)),
        'extra': sorted(set(arabic) - source_keys),
    }
    plural_keys = []
    for key, translated in arabic.items():
        assert isinstance(translated, str) and translated.strip(), key
        assert not re.search('[\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]', translated), (
            key, 'directional control character'
        )
        assert re.search('[\u0600-\u06ff]', translated) or key in TECHNICAL_ONLY, (
            key, 'missing Arabic prose'
        )
        left, right = Message(source[key]), Message(translated)
        assert left.arguments == right.arguments, (key, left.arguments, right.arguments)
        assert left.selectors.keys() == right.selectors.keys(), (key, 'ICU identity')
        metadata = source.get('@' + key, {}).get('placeholders', {})
        assert set(metadata) == set(left.arguments), (key, 'source metadata mismatch')
        for identity, old_selectors in left.selectors.items():
            new_selectors = right.selectors[identity]
            kind = identity[1]
            if kind in {'plural', 'selectordinal'}:
                assert ARABIC_CATEGORIES <= new_selectors, (key, 'Arabic category missing')
                assert {v for v in old_selectors if v.startswith('=')} <= new_selectors
                assert all(v.startswith('=') or v in ARABIC_CATEGORIES for v in new_selectors)
                assert metadata[identity[0]]['type'] in {'int', 'num', 'double'}
                plural_keys.append(key)
            else:
                assert old_selectors == new_selectors, (key, 'select alternatives changed')
        for literal in TECHNICAL_LITERALS:
            if literal_present(source[key], literal):
                assert literal_present(translated, literal), (key, 'missing literal', literal)
        if key in {'termuxGuideEnterTitle', 'termuxGuideEnterDescription', 'termuxGuideEnterKey'}:
            assert 'Enter' in translated, (key, 'keyboard label changed')
        assert urls(source[key]) == urls(translated), (key, 'URL changed')
    result = {
        'status': 'passed',
        'message_count': len(arabic),
        'missing_keys': [],
        'extra_keys': [],
        'placeholder_mismatches': [],
        'icu_plural_messages': plural_keys,
        'arabic_plural_categories': sorted(ARABIC_CATEGORIES),
        'technical_only_keys': sorted(TECHNICAL_ONLY),
        'directional_controls': 0,
        'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'translation_sha256': hashlib.sha256(TRANSLATION.read_bytes()).hexdigest(),
        'limits': 'Corpus validation only. Flutter generation, UI reachability and RTL visual checks belong to integration.',
    }
    (ROOT / 'arabic_features-validation.json').write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
