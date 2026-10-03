"""G13 fail-on-violation proof: writes violating copies of the real map and kit.

Run from the repo root: python3 docs/qa/gate-G13-2026-09-26/make_violation.py <out dir>
The committed docs are only read, never edited. Each numbered change is one
violation the gate must report, including the review's evasions of 2026-09-26.
"""
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
kit = json.load(open('docs/ux-system/kit-v2.json'))
pages = json.load(open('docs/ux-system/map/all.json'))
chat = next(p for p in pages if p['pageId'] == 'chat')
worktrees = next(p for p in pages if p['pageId'] == 'worktrees')

# 1. A kit-v2 replaces entry that points at an element the map does not list.
kit['new'][0]['replaces'].append({'page': 'chat', 'element': 'chat-element-that-does-not-exist'})
# 2. A new hand-built element (kit "none") on chat.
chat['elements'].append({'id': 'g13-throwaway', 'kind': 'row', 'kit': 'none', 'kitGap': '', 'couldBeAutomatic': '', 'note': ''})
# 3. Hand-built elements that dodge the "none" spelling: "custom", "", "None", no kit key.
for i, kit_value in enumerate(['custom', '', 'None', None]):
    element = {'id': f'g13-dodge-{i}', 'kind': 'row'}
    if kit_value is not None:
        element['kit'] = kit_value
    chat['elements'].append(element)
# 4. Hidden text that does not start with "hidden", on a capability with an enable flow.
chat['whenMissing']['server.any'] = 'the retry row is hidden (evasion)'
# 5. A non-string whenMissing value.
chat['whenMissing']['team.on'] = ['hidden']
# 6. A new dead row.
chat['whenMissing']['project.open'] = 'disabled (rows dim)'
# 7. Deleting a baselined kit-none element from a keep/fix page instead of re-kitting it
#    (one no kit-v2 replaces entry names, so only the kit-none check can catch it).
replaced = {(r['page'], r['element']) for s in ('new', 'changed') for part in kit[s] for r in part.get('replaces', [])}
removed = next(e for e in worktrees['elements'] if e.get('kit') == 'none' and ('worktrees', e['id']) not in replaced)
worktrees['elements'].remove(removed)

(out / 'kit-v2.json').write_text(json.dumps(kit))
(out / 'all.json').write_text(json.dumps(pages))
print(f"wrote {out}/kit-v2.json and {out}/all.json; removed worktrees#{removed['id']} (proposal {worktrees.get('proposal')})")
