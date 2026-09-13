#!/usr/bin/env python3
"""Validate this frozen Arabic shared-message fragment without touching app files."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    'feature_validator', ROOT.parent / 'e7-fixes' / 'validate_arabic_features.py'
)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)
source_path = ROOT / 'messages_en-snapshot.json'
output_path = ROOT / 'messages_ar.json'
source = validator.load(source_path)
arabic = validator.load(output_path)
keys = {key for key in source if not key.startswith('@')}
assert len(keys) == 80
assert keys == set(arabic), (keys - set(arabic), set(arabic) - keys)
for key, value in arabic.items():
    assert isinstance(value, str) and re.search('[\u0600-\u06ff]', value), key
    assert not re.search('[\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]', value), key
    left, right = validator.Message(source[key]), validator.Message(value)
    assert left.arguments == right.arguments, (key, 'placeholder/type mismatch')
    assert left.selectors == right.selectors, (key, 'ICU alternatives changed')
    assert set(source.get('@' + key, {}).get('placeholders', {})) == set(left.arguments), key
    assert validator.urls(source[key]) == validator.urls(value), (key, 'URL changed')
    for literal in validator.TECHNICAL_LITERALS + (
        'Anthropic', 'OpenAI', 'SSH', 'opencode2 pair', 'opencode serve',
        'adb reverse', 'Model Context Protocol',
    ):
        if validator.literal_present(source[key], literal):
            assert validator.literal_present(value, literal), (key, literal)
result = {
    'status': 'passed',
    'message_count': len(arabic),
    'missing_keys': [],
    'extra_keys': [],
    'placeholder_mismatches': [],
    'directional_controls': 0,
    'source_sha256': hashlib.sha256(source_path.read_bytes()).hexdigest(),
    'translation_sha256': hashlib.sha256(output_path.read_bytes()).hexdigest(),
    'limits': 'Frozen 80-message corpus only; not a Flutter generation or rendered RTL gate.',
}
(ROOT / 'arabic-validation.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
