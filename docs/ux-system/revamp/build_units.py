#!/usr/bin/env python3
"""Cuts the whole app revamp into agent-sized work units.

Output: docs/ux-system/revamp/work-units.json. Every unit has a disjoint
write set within its wave. Units that must share a file are chained
(`after`), never run side by side.

Inputs (all in the repo):
  test/kit_ratchet_baseline.json   raw framework widgets per file (G16)
  docs/ux-system/map/all.json      page records: file, module, proposal
  docs/ux-system/programmes.json   programme slices (P0-P10)
  docs/ux-system/kit-v2.json       kit parts to build or change

Run from the repo root: python3 docs/ux-system/revamp/build_units.py
"""

import collections
import json
import os

ROOT = os.getcwd()
OUT = 'docs/ux-system/revamp/work-units.json'
MAX_LINES = 3200  # one agent's reading budget per screen unit


def load(path):
    with open(path) as f:
        return json.load(f)


def lines(path):
    try:
        with open(path) as f:
            return sum(1 for _ in f)
    except OSError:
        return 0


baseline = load('test/kit_ratchet_baseline.json')['G16']
records = load('docs/ux-system/map/all.json')
if isinstance(records, dict):
    records = records.get('records', list(records.values()))
programmes = load('docs/ux-system/programmes.json')['programmes']

# ---------------------------------------------------------------- file facts
file_pages = collections.defaultdict(list)
file_module = {}
page_file = {}
for r in records:
    f = (r.get('file') or '')
    for ff in (f if isinstance(f, list) else [f]):
        ff = ff.split(':')[0]
        if not ff:
            continue
        file_pages[ff].append(r['pageId'])
        file_module.setdefault(ff, r.get('module', 'shell'))
        page_file.setdefault(r['pageId'], ff)


def guess_module(path):
    name = path.rsplit('/', 1)[-1]
    if '/chat/' in path or name.startswith('chat_'):
        return 'chat'
    if 'team' in path:
        return 'team'
    if 'terminal' in name:
        return 'terminal'
    for key, mod in [('preview', 'files'), ('quota', 'usage'), ('provider', 'usage'),
                     ('phone', 'phone'), ('local_server', 'phone'), ('builtin', 'phone'),
                     ('setup', 'phone'), ('managed', 'phone'), ('server', 'servers'),
                     ('perf', 'system'), ('desktop', 'shell')]:
        if key in path:
            return mod
    return 'shell'


def module_of(path):
    return file_module.get(path) or guess_module(path)


# ---------------------------------------------------------- single owners
# AGENTS.md: the chat library is one library with one editor at a time,
# so its units form one chain. main.dart and connection.dart are not UI
# files and stay out of the screen waves.
CHAT = [p for p in baseline if p == 'lib/ui/screens/chat_screen.dart'
        or p.startswith('lib/ui/screens/chat/')]
SHELL_FOUNDATION = {'lib/ui/app_theme.dart', 'lib/ui/app_iconography.dart'}

units = []


def unit(uid, wave, title, write, **kw):
    u = dict(id=uid, wave=wave, title=title, write=sorted(write), **kw)
    u.setdefault('after', [])
    u.setdefault('pages', sorted({p for f in write for p in file_pages.get(f, [])}))
    u.setdefault('raw', sum(sum(baseline.get(f, {}).values()) for f in write))
    u.setdefault('lines', sum(lines(f) for f in write))
    units.append(u)
    return u


# ------------------------------------------------------- wave 1: the kit
KIT_NEW = ['KitDialog', 'KitField', 'KitSearchField', 'KitSegmented', 'KitChoiceList',
           'KitDetailsFold', 'KitCodeBlock', 'KitLogPanel', 'KitChecklist',
           'KitProgressRow', 'KitViewer', 'KitDiffView', 'KitReceipt', 'KitUndo',
           'KitTopBar', 'KitJumpPill', 'KitTerm', 'KitNeedsYou',
           # kit-v2.md §9
           'KitIcon', 'KitSurface', 'KitTappable', 'KitDivider', 'KitScaffold',
           'KitPageRoute', 'KitDateTimePicker']
KIT_CHAT = ['KitTurn', 'KitMessage', 'KitMarkdown', 'KitToolRow', 'KitWorkLine',
            'KitComposer', 'KitQueuedMessage', 'KitAgentStrip']
KIT_SURFACES = ['KitTerminalView', 'KitScanner', 'KitWorkGraph', 'KitNavRail',
                'KitLevelMeter', 'KitBoardLane', 'KitTaskCard', 'KitSwatch', 'KitQr',
                'KitBreadcrumb']
KIT_CHANGED = {
    'KitRequestCard v2 (one answer card, answered state)': ['lib/ui/kit/kit_request_card.dart'],
    'KitStateView v2 (missing modes, 8 s escalation, error defaults)': ['lib/ui/kit/kit_state_view.dart'],
    'KitStatusLine v2 (Now line, escalation, replaces banners)': ['lib/ui/kit/kit_status_line.dart'],
    'KitNotice v2 (cost line, attention card)': ['lib/ui/kit/kit_notice.dart'],
    'KitRow v2 (unavailable, server label, swipe with Undo, risk switch)': ['lib/ui/kit/kit_row.dart', 'lib/ui/kit/kit_row_parts.dart'],
    'KitAction v2 (disabledReason, destructive stacking)': ['lib/ui/kit/kit_buttons.dart', 'lib/ui/kit/kit_action_stack.dart'],
    'KitProgress v2 (stages and estimate)': ['lib/ui/kit/kit_progress.dart'],
    'KitTabSwitcher v2 (strip)': ['lib/ui/kit/motion/kit_tab_switcher.dart'],
}
DEPENDS = {'KitStateView v2 (missing modes, 8 s escalation, error defaults)': ['kit-KitDetailsFold'],
           'KitLogPanel': ['kit-KitCodeBlock'], 'KitChecklist': ['kit-KitLogPanel'],
           'KitRequestCard v2 (one answer card, answered state)': ['kit-KitReceipt', 'kit-KitChoiceList', 'kit-KitField'],
           'KitDialog': ['kit-KitField'], 'KitViewer': ['kit-KitCodeBlock'],
           'KitComposer': ['kit-KitIcon', 'kit-KitSurface'], 'KitTopBar': ['kit-KitIcon'],
           'KitScaffold': ['kit-KitTopBar']}


def snake(name):
    return ''.join('_' + c.lower() if c.isupper() else c for c in name).lstrip('_')


for name in KIT_NEW + KIT_CHAT + KIT_SURFACES:
    sub = 'chat/' if name in KIT_CHAT else ''
    path = f'lib/ui/kit/{sub}{snake(name)}.dart'
    unit(f'kit-{name}', 1, f'Build {name}', [path, f'test/kit/{snake(name)}_test.dart'],
         kind='kit-part', after=DEPENDS.get(name, []), model='opus' if name in KIT_CHAT + ['KitDiffView', 'KitViewer'] else 'sonnet')
for title, paths in KIT_CHANGED.items():
    uid = 'kit-' + title.split(' ')[0] + '-v2'
    unit(uid, 1, title, paths, kind='kit-change', after=DEPENDS.get(title, []), model='opus')

# --------------------------------------------- wave 2: every screen file
# Shared widgets first (2a), then screens (2b), so a screen unit reads
# already-migrated shared widgets. Clusters stay inside one module and
# stop at MAX_LINES.
def clusters(paths, prefix, wave, kind):
    by_mod = collections.defaultdict(list)
    for p in sorted(paths):
        by_mod[module_of(p)].append(p)
    out = []
    for mod, files in sorted(by_mod.items()):
        files.sort(key=lambda p: -lines(p))
        bins = []
        for f in files:
            n = lines(f)
            for b in bins:
                if b[0] + n <= MAX_LINES:
                    b[0] += n
                    b[1].append(f)
                    break
            else:
                bins.append([n, [f]])
        for i, (_, fs) in enumerate(bins, 1):
            out.append(unit(f'{prefix}-{mod}-{i}', wave,
                            f'Revamp {mod} ({len(fs)} files)', fs, kind=kind, module=mod,
                            model='opus'))
    return out


widgets = [p for p in baseline if p.startswith('lib/ui/widgets/')]
screens = [p for p in baseline if p not in widgets and p not in CHAT
           and p not in SHELL_FOUNDATION and not p.startswith('lib/ui/kit/')]
clusters(widgets, 'shared', '2a', 'screen-revamp')
clusters(screens, 'screen', '2b', 'screen-revamp')

# The chat library: one chain, each link one editor, in this order.
chat_order = sorted(CHAT, key=lambda p: -lines(p))
chain, prev, bucket, size = [], None, [], 0
for f in chat_order:
    n = lines(f)
    if bucket and size + n > MAX_LINES:
        chain.append(bucket)
        bucket, size = [], 0
    bucket.append(f)
    size += n
if bucket:
    chain.append(bucket)
for i, fs in enumerate(chain, 1):
    u = unit(f'chat-{i}', '2c', f'Revamp the chat library, part {i}', fs,
             kind='screen-revamp', module='chat', model='opus',
             after=[prev] if prev else ['kit-KitComposer', 'kit-KitMessage', 'kit-KitTurn'])
    prev = u['id']

# ------------------------------------ wave 3: behaviour (the programmes)
# P9 is covered by waves 1 and 2 except search, accessibility and RTL.
DONE = {'P0.1', 'P0.2', 'P0.3', 'P0.4', 'P0.5', 'P0.6', 'P0.8', 'P9.1', 'P9.2', 'P9.3',
        'P9.7', 'P9.8', 'P9.9'}
DEFERRED = {'P2'}  # the owner chose "Not now"
for prog in programmes:
    if prog['id'] in DEFERRED:
        continue
    pages = prog.get('pages', {})
    for s in prog['slices']:
        if s['id'] in DONE:
            continue
        unit(f"slice-{s['id']}", 3, f"{s['id']} {s['title']}",
             [],  # the write set is fixed by the slice's own feasibility read
             kind='programme-slice', programme=prog['id'], finishLine=s['finishLine'],
             nonGoal=s.get('nonGoal', ''), effort=s.get('effort', 'M'),
             acceptance=s.get('acceptance', []), proof=s.get('proof', ''),
             after=[f"programme-{d}" for d in prog.get('dependsOn', [])], model='opus',
             pages=sorted({p for k in ('removed', 'merged', 'changed', 'new')
                           for p in pages.get(k, [])}))

summary = collections.Counter(str(u['wave']) for u in units)
with open(OUT, 'w') as f:
    json.dump({'generatedFrom': ['test/kit_ratchet_baseline.json', 'docs/ux-system/map/all.json',
                                 'docs/ux-system/programmes.json', 'docs/ux-system/kit-v2.json'],
               'maxLinesPerScreenUnit': MAX_LINES, 'waves': dict(summary), 'units': units},
              f, indent=1, ensure_ascii=False)
print(dict(summary), 'units:', len(units))
