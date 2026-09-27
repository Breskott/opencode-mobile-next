#!/usr/bin/env python3
"""Resolve a merge conflict in test/kit_ratchet_baseline.json.

The baseline may only go down: for each gate/file/pattern, keep the lower
count of the two sides; an entry either side removed (relative to the merge
base) stays removed. Run from the repo root during a conflicted merge.
"""
import json
import subprocess

PATH = 'test/kit_ratchet_baseline.json'


def stage(n):
    try:
        return json.loads(subprocess.check_output(['git', 'show', f':{n}:{PATH}']))
    except subprocess.CalledProcessError:
        return {}


base, ours, theirs = stage(1), stage(2), stage(3)
out = {}
for gate in sorted(set(ours) | set(theirs)):
    files = {}
    for f in sorted(set(ours.get(gate, {})) | set(theirs.get(gate, {}))):
        pats = {}
        b = base.get(gate, {}).get(f, {})
        o = ours.get(gate, {}).get(f)
        t = theirs.get(gate, {}).get(f)
        for p in sorted(set((o or {})) | set((t or {}))):
            in_base = p in b
            ov, tv = (o or {}).get(p), (t or {}).get(p)
            if in_base and (ov is None or tv is None):
                continue  # removed on one side
            vals = [v for v in (ov, tv) if v is not None]
            pats[p] = min(vals)
        if pats:
            files[f] = pats
    if files:
        out[gate] = files
with open(PATH, 'w') as fh:
    json.dump(out, fh, indent=2, sort_keys=True)
    fh.write('\n')
print('merged', PATH)
