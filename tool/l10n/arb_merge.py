#!/usr/bin/env python3
"""Git merge driver for ARB files: a 3-way union of keys (revamp rule R04).

Registered in .gitattributes as `lib/l10n/*.arb merge=arbunion`, with the
repo-local config (docs/ux-system/revamp/PLAN.md §8):

    git config merge.arbunion.name "ARB 3-way key union"
    git config merge.arbunion.driver "python3 tool/l10n/arb_merge.py %O %A %B %P"

Git calls it with the ancestor (%O), ours (%A, also the output) and theirs
(%B). Every key either side added is kept; a key one side changed takes that
side's value; a key one side deleted and the other left alone is deleted.
@metadata entries ("@key", "@@locale") merge the same way, field by field, so
a placeholder added on one side survives. The merge fails (exit 1) only when
one key ends up with two different values, or one side deletes a key the
other side changed. On failure %A keeps ours for those keys and the conflicts
are printed, so the integrator resolves them by hand.

Key order: ours first, in its order (never re-sorted, so a merge adds no
churn); keys only theirs added follow in theirs' order. The output is written the way
the repo stores ARB files: JSON, two-space indent, UTF-8, trailing newline.

Test it without git:  python3 tool/l10n/arb_merge.py --self-test
"""

import json
import sys
from collections import OrderedDict

MISSING = object()


class Conflict(Exception):
    pass


def merge_value(key, base, ours, theirs, conflicts):
    """3-way merge of one value; recurses into objects (the @metadata)."""
    if ours == theirs:
        return ours
    if ours == base:
        return theirs
    if theirs == base:
        return ours
    if isinstance(ours, dict) and isinstance(theirs, dict):
        b = base if isinstance(base, dict) else {}
        return merge_objects(b, ours, theirs, conflicts, prefix=key + '.')
    conflicts.append(key)
    return ours


def merge_objects(base, ours, theirs, conflicts, prefix=''):
    out = OrderedDict()
    order = list(ours.keys()) + [k for k in theirs.keys() if k not in ours]
    for k in order:
        b = base.get(k, MISSING)
        o = ours.get(k, MISSING)
        t = theirs.get(k, MISSING)
        v = merge_value(prefix + k, b, o, t, conflicts)
        if v is not MISSING:
            out[k] = v
    return out


def merge(base, ours, theirs):
    conflicts = []
    merged = merge_objects(base, ours, theirs, conflicts)
    return merged, conflicts


def read(path):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    return json.loads(text, object_pairs_hook=OrderedDict) if text.strip() else OrderedDict()


def write(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(json.dumps(data, indent=2, ensure_ascii=False) + '\n')


def self_test():
    base = OrderedDict([('a', 'A'), ('@a', {'description': 'x'}), ('b', 'B'), ('c', 'C')])
    ours = OrderedDict([('a', 'A'), ('@a', {'description': 'x', 'placeholders': {'n': {}}}), ('b', 'B2'),
                        ('c', 'C'), ('kitChipNew', 'Chip')])
    theirs = OrderedDict([('a', 'A'), ('@a', {'description': 'y'}), ('c', 'C'), ('screenNew', 'Screen'),
                          ('@screenNew', {'description': 'z'})])
    merged, conflicts = merge(base, ours, theirs)
    # b: ours changed, theirs deleted -> conflict; @a merges field by field.
    assert conflicts == ['b'], conflicts
    assert merged['@a'] == {'description': 'y', 'placeholders': {'n': {}}}, merged['@a']
    assert list(merged) == ['a', '@a', 'b', 'c', 'kitChipNew', 'screenNew', '@screenNew'], list(merged)
    theirs2 = OrderedDict([('a', 'A'), ('@a', {'description': 'x'}), ('c', 'C'), ('screenNew', 'Screen')])
    ours2 = OrderedDict([('a', 'A'), ('@a', {'description': 'x'}), ('b', 'B'), ('c', 'C'), ('kitChipNew', 'Chip')])
    merged, conflicts = merge(base, ours2, theirs2)
    assert conflicts == [] and 'b' not in merged and merged['screenNew'] == 'Screen', (conflicts, merged)
    _, conflicts = merge(base, OrderedDict(base, d='one'), OrderedDict(base, d='two'))
    assert conflicts == ['d'], conflicts
    print('arb_merge self-test: ok')


def main(argv):
    if argv[1:] == ['--self-test']:
        self_test()
        return 0
    if len(argv) < 4:
        print('usage: arb_merge.py BASE OURS THEIRS [PATH]  (git merge driver: %O %A %B %P)', file=sys.stderr)
        return 2
    base_p, ours_p, theirs_p = argv[1:4]
    label = argv[4] if len(argv) > 4 else ours_p
    try:
        base, ours, theirs = read(base_p), read(ours_p), read(theirs_p)
    except ValueError as e:
        print(f'arb_merge: {label}: not valid JSON ({e}); resolve by hand', file=sys.stderr)
        return 1
    merged, conflicts = merge(base, ours, theirs)
    write(ours_p, merged)
    if conflicts:
        print(f'arb_merge: {label}: {len(conflicts)} key(s) got two different values; ours kept, resolve by hand:',
              file=sys.stderr)
        for k in conflicts:
            print(f'  {k}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
