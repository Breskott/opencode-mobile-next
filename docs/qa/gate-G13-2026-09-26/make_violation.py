"""G13 fail-on-violation proof: writes violating copies of the real map and kit.

Run from the repo root: python3 docs/qa/gate-G13-2026-09-26/make_violation.py <out dir>
The committed docs are only read, never edited.
"""
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
kit = json.load(open('docs/ux-system/kit-v2.json'))
pages = json.load(open('docs/ux-system/map/all.json'))

# 1. A kit-v2 replaces entry that points at an element the map does not list.
kit['new'][0]['replaces'].append({'page': 'chat', 'element': 'chat-element-that-does-not-exist'})
# 2. One more hand-built element (kit "none").
chat = next(p for p in pages if p['pageId'] == 'chat')
chat['elements'].append({'id': 'g13-throwaway', 'kind': 'row', 'kit': 'none', 'kitGap': '', 'couldBeAutomatic': '', 'note': ''})
# 3. A capability with an enable flow (server.any) hidden on a page that explains it today.
chat['whenMissing']['server.any'] = 'hidden (throwaway G13 violation)'

(out / 'kit-v2.json').write_text(json.dumps(kit))
(out / 'all.json').write_text(json.dumps(pages))
