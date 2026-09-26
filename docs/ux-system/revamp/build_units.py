#!/usr/bin/env python3
"""Cuts the whole app revamp into agent-sized work units (cut v2).

Output: docs/ux-system/revamp/work-units.json. The script reads the current
tree, builds every unit, and ends with ASSERTIONS (cut v2 C51). It exits
non-zero and prints every failed assertion when one fails, so a regenerated
cut can never silently overlap, dangle or drop a file.

Inputs (all in the repo):
  every lib/**.dart outside lib/ui/kit and lib/l10n that declares a widget
  test/kit_ratchet_baseline.json   G1/G15/G16 per file
  test/kit_ratchet_test.dart       the _allowed map (files the gate skips)
  docs/ux-system/map/all.json      page records: file, module, proposal
  docs/ux-system/programmes.json   programme slices (P0-P10)
  docs/ux-system/programme-decisions-2026-09-26.json  owner order, P2 deferred
  docs/ux-system/kit-v2.json       element -> part assignment
  docs/ux-system/kit-api/*.md      frozen API blocks (C02); may not exist yet
  test/**/*.dart                   imports, for the tests write sets (R08)

Waves:
  1   the kit, in tiers (tier = 1 + max tier of after; R02)
  2a  shared widgets        2b  screens (+ screen-voice-1, screen-system-2,
  2c  the chat chain         coord-main run by the coordinator)
  2d  kit-hygiene           3   programme slices (45), packed at run time

Run from the repo root: python3 docs/ux-system/revamp/build_units.py
"""

import collections
import fnmatch
import json
import math
import os
import re
import subprocess
import sys

OUT = 'docs/ux-system/revamp/work-units.json'
MAX_LINES = 3200  # one agent's reading budget per screen unit
MAX_RAW = 150     # raw framework widgets per unit (C35); a single-file bin may exceed it, flagged
SLOTS = 6         # min(16, CPUs - 2) on the 8-CPU PC
PKG = 'package:opencode_mobile/'
VL_TIP = '510f601d'  # feat/visual-language-v1: 76095bd3, f5370bd3, 510f601d
VL_TOUCHED_FALLBACK = [
    'lib/ui/app_theme.dart', 'lib/ui/kit/glass/kit_glass.dart', 'lib/ui/kit/kit.dart',
    'lib/ui/kit/kit_buttons.dart', 'lib/ui/kit/kit_confirm_sheet.dart', 'lib/ui/kit/kit_notice.dart',
    'lib/ui/kit/kit_panel.dart', 'lib/ui/kit/kit_request_card.dart', 'lib/ui/kit/kit_row.dart',
    'lib/ui/kit/kit_row_parts.dart', 'lib/ui/kit/kit_status_line.dart', 'lib/ui/kit/kit_text.dart',
    'lib/ui/kit/kit_tokens.dart', 'lib/ui/screens/home_screen.dart', 'lib/ui/screens/running_work_sheet.dart',
    'lib/ui/theme_packs.dart', 'lib/ui/theme_roles.dart', 'lib/ui/widgets/builtin_team_section.dart',
    'lib/ui/widgets/glass_surface.dart', 'lib/ui/widgets/markdown.dart', 'lib/ui/widgets/product_states.dart',
    'lib/ui/widgets/team_host_form.dart', 'lib/ui/widgets/terminal_view.dart']


def load(path):
    with open(path) as f:
        return json.load(f)


def read(path):
    try:
        with open(path, encoding='utf-8') as f:
            return f.read()
    except OSError:
        return ''


def lines(path):
    t = read(path)
    return t.count('\n') + (1 if t and not t.endswith('\n') else 0)


def git(*a):
    try:
        return subprocess.run(['git', *a], capture_output=True, text=True, check=False).stdout
    except OSError:
        return ''


def snake(name):
    return ''.join('_' + c.lower() if c.isupper() else c for c in name).lstrip('_')


ratchet = load('test/kit_ratchet_baseline.json')
G1, G15, G16 = ratchet.get('G1', {}), ratchet.get('G15', {}), ratchet.get('G16', {})
records = load('docs/ux-system/map/all.json')
if isinstance(records, dict):
    records = records.get('records', list(records.values()))
programmes = load('docs/ux-system/programmes.json')['programmes']
decisions = load('docs/ux-system/programme-decisions-2026-09-26.json')
assignment = load('docs/ux-system/kit-v2.json').get('assignment', {})
ALLOWED_NOW = set(re.findall(r"'([^']+\.dart)'\s*:", (re.search(
    r'const _allowed = <String, String>\{(.*?)\};', read('test/kit_ratchet_test.dart'), re.S) or [None, ''])[1]))
# kit-gates-ratchet adds app_theme.dart to _allowed (C21 g): ThemeData
# component themes are theme data, not UI.
ALLOWED_PLANNED = {'lib/ui/app_theme.dart': 'kit-gates-ratchet (C21 g)'}

VL_MERGED = subprocess.run(['git', 'merge-base', '--is-ancestor', VL_TIP, 'HEAD'],
                           capture_output=True).returncode == 0 if git('rev-parse', '--git-dir') else False
VL_TOUCHED = set(VL_TOUCHED_FALLBACK)
if git('cat-file', '-t', VL_TIP).strip() == 'commit':
    base = git('merge-base', 'HEAD', VL_TIP).strip()
    if base:
        VL_TOUCHED = {p for p in git('diff', '--name-only', base, VL_TIP, '--', 'lib').split() if p}

# ---------------------------------------------------------------- file facts
# R21 / C28: split map `file` fields on ' + ' as well as ':'.
file_pages = collections.defaultdict(list)
page_proposal, file_module = {}, {}
map_files, map_files_missing = set(), set()
for r in records:
    f = r.get('file') or ''
    page_proposal[r['pageId']] = str(r.get('proposal') or '')
    for ff in (f if isinstance(f, list) else [f]):
        for part in re.split(r'\s\+\s', ff):
            p = part.split(':')[0].strip()
            if not p:
                continue
            file_pages[p].append(r['pageId'])
            file_module.setdefault(p, r.get('module', 'shell'))
            (map_files if os.path.exists(p) else map_files_missing).add(p)

WIDGET_RX = re.compile(r'class\s+\w+(?:<[^{]*?>)?\s+extends\s+(?:StatelessWidget|StatefulWidget|CustomPainter)\b')
GENERATED = ('.g.dart', '.freezed.dart', '.mocks.dart')


def dart_files(root):
    for dp, _, fns in os.walk(root):
        for fn in fns:
            p = os.path.join(dp, fn).replace(os.sep, '/')
            if p.endswith('.dart') and not p.endswith(GENERATED):
                yield p


widget_files = {p for p in dart_files('lib') if not p.startswith(('lib/ui/kit/', 'lib/l10n/'))
                and WIDGET_RX.search(read(p))}
CANDIDATES = (widget_files | set(G1) | set(G16) | set(G15) | map_files)
CANDIDATES = {p for p in CANDIDATES if os.path.exists(p) and not p.startswith(('lib/ui/kit/', 'lib/l10n/'))}
KIT_EXISTING = sorted(p for p in dart_files('lib/ui/kit'))


def raw(path):
    return sum(G16.get(path, {}).values())


def g1(path):
    return sum(G1.get(path, {}).values())


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
                     ('perf', 'system'), ('desktop', 'shell'), ('voice', 'voice')]:
        if key in path:
            return mod
    return 'shell'


# Module pins keep moved files next to the units the cut review names
# (C29, C34); everything else follows the map's module.
MODULE_PIN = {
    'lib/ui/search/search_index.dart': 'shell', 'lib/ui/desktop/file_drop.dart': 'shell',
    'lib/ui/desktop/desktop_interaction.dart': 'shell',
    'lib/ui/widgets/run_command_dialog.dart': 'system', 'lib/ui/widgets/external_link.dart': 'system',
    'lib/ui/widgets/product_states.dart': 'system',
    'lib/ui/widgets/safety_confirms.dart': 'shell', 'lib/ui/widgets/work_status_line.dart': 'shell',
    'lib/ui/widgets/confirm_sheet.dart': 'shell',
    'lib/ui/widgets/local_agent_server_entry.dart': 'servers',
    'lib/ui/widgets/termux_running_server_entry.dart': 'servers',
    'lib/ui/widgets/termux_phone_tools.dart': 'servers',
    'lib/ui/screens/phone_setup/phone_setup_welcome_entry.dart': 'phone',
    'lib/ui/widgets/grace_timer.dart': 'work',
    'lib/ui/screens/team/team_needs_you.dart': 'team',
}


def module_of(path):
    return MODULE_PIN.get(path) or file_module.get(path) or guess_module(path)


units = []
by_id = {}


def unit(uid, wave, title, write, **kw):
    assert uid not in by_id, f'duplicate unit id {uid}'
    write = sorted(set(write))
    u = dict(id=uid, wave=wave, title=title, write=write, **kw)
    u.setdefault('after', [])
    u.setdefault('acceptance', [])
    u.setdefault('pages', sorted({p for f in write for p in file_pages.get(f, [])}))
    u.setdefault('raw', sum(raw(f) for f in write))
    u.setdefault('g1', sum(g1(f) for f in write))
    u.setdefault('lines', sum(lines(f) for f in write))
    units.append(u)
    by_id[uid] = u
    return u


# ======================================================= wave 1: the kit
# One row per unit: (name, kind, extra files, after, spec source, model, acceptance)
# Every unit writes lib/ui/kit/<snake>.dart (or the named files), its test
# file, and its gallery test. `spec` points at the frozen API block (C02, R16).
K = 'lib/ui/kit/'
W = 'lib/ui/widgets/'
KIT = [
    # ---- tier 1a (no dependencies)
    ('KitIcon', 'kit-part', [K + 'kit_icon.dart', 'lib/ui/app_iconography.dart'], [], '§9.2', 'sonnet',
     ['sizes s/m/l = 20/22/24 only (VL §7, settled in the C02 freeze)',
      'AppGlyph and AppBrandMark become KitIcon or re-exports of it; the 34 importers keep compiling (R11)',
      'lib/ui/app_iconography.dart reaches G16 zero']),
    ('KitIconButton-v2', 'kit-change', [K + 'kit_icon_button.dart'], [], '§1.10', 'sonnet',
     ["KitIconButton.copy({required String Function() text}): check crossfade, 'Copied' announced once, no SnackBar (G9 copy contract)",
      'destructive, working and selected; §8.2 hover tooltip that shows the shortcut',
      "the current `label` parameter keeps compiling; §1.10's `tooltip` vs `label` is settled in the C02 freeze (either §1.10 is amended, or `tooltip` is added and `label` becomes a @Deprecated alias)",
      'ten wave-1 units build on it: Field, DetailsFold, CodeBlock, LogPanel, DiffView, Viewer, StateView-v2, TopBar, QueuedMessage, Composer']),
    ('KitStatusMark-v2', 'kit-change', [K + 'kit_status_mark.dart', K + 'kit_task_mark.dart'], [], '§2.9', 'sonnet',
     ['KitMarkState.paused', 'an optional word next to every mark: no state by colour alone (from P9.5)',
      'the G8 reduced-motion test and 200 % goldens (KitMotion.reduced is already used; do not redo it)']),
    ('KitMenu', 'kit-part', [K + 'kit_menu.dart'], [], 'cut v2 C07; §2.5 (KitRowMenu)', 'sonnet',
     ['showKitMenu(context, {anchor | position}) and KitMenuItem v2: icon, checked, group divider, destructive sorted last after a divider, enabled with a reason',
      'does not edit kit_row_parts.dart (kit-KitRowParts-v2 rebuilds KitRowMenu on it)',
      'replaces PopupMenuButton, PopupMenuItem, CheckedPopupMenuItem and PopupMenuDivider']),
    ('KitChip', 'kit-part', [K + 'kit_chip.dart'], [], 'cut v2 C09; VL §4-§5', 'sonnet',
     ["variants plain, action, removable, count ('Tasks · n') and summary ('Read 3 files · edited 1')",
      'radius 999, 48 dp hit area, a word and never colour alone; replaces Chip, ActionChip, InputChip, FilterChip (ChoiceChip stays with KitSegmented)']),
    ('KitText-v2', 'kit-change', [K + 'kit_text.dart'], [], '§9.2 KitText; cut v2 C10', 'sonnet',
     ['KitText.selectable and a KitSelectable region wrapper (replace SelectionArea, SelectionContainer, SelectableText)',
      'KitText.mono isolates LTR (replaces Directionality outside the kit)',
      'builds on the kit_text.dart that feat/visual-language-v1 creates: runs only after that merge']),
    ('KitMotionParts', 'kit-part', [K + 'motion/kit_motion_parts.dart'], [], 'cut v2 C11; §4.11', 'sonnet',
     ['KitSwap, KitSpin, KitAnimatedBox, KitDim; still under reduced motion (G8); no fade-scale (VL §7)',
      'Transform, ScaleTransition, FadeTransition, ShaderMask, Opacity, AnimatedContainer/Size/Rotation, RotatedBox and TweenAnimationBuilder map onto these']),
    ('KitSince', 'kit-part', [K + 'kit_since.dart'], [], '§4.9; cut v2 C12', 'sonnet',
     ["a KitSince builder that escalates by itself after 8 s, fake-clock-testable, copy 'Still waiting after 8 s', reduced-motion-safe tick",
      "absorbs P7.6's 'tests use a fake clock'"]),
    ('KitImage', 'kit-part', [K + 'kit_image.dart'], [], 'cut v2 C13; VL §7', 'sonnet',
     ['KitImage decodes at the device pixel ratio (cacheWidth), FilterQuality.high, semantic label, loading and error states',
      'KitAvatar (initials with a word) and KitZoom (replaces InteractiveViewer)']),
    ('KitSheet-v2', 'kit-change', [K + 'kit_sheet.dart'], [], '§1.1; VL §5 Sheets', 'sonnet',
     ['grabber, icon tile, left-aligned title, consequences in a surface1 panel, buttons stacked on phones and right-aligned in a row on PC',
      'KitDraft unchanged']),
    ('KitAskLine-look', 'kit-change', [K + 'kit_ask_line.dart', K + 'kit_skeleton_transcript.dart'], [], 'VL §7 (look only)', 'sonnet',
     ['ThemeRoles and KitText only; icon sizes 20/22/24 only']),
    ('KitScenes-v2', 'kit-change', [K + 'kit_illustration.dart'] + sorted(p for p in KIT_EXISTING if p.startswith(K + 'scenes/')),
     [], 'VL §2 (roles only); cut v2 C19', 'sonnet',
     ['colours from ThemeRoles; recount BorderRadius/Radius.circular and colorScheme uses before writing the acceptance (the review counted 39 and 1)',
      'radius literals inside scene drawing geometry are exempt from the look ratchet (C21 e)']),
    ('gates-ratchet', 'kit-gate', ['test/kit_ratchet_test.dart', 'test/kit_ratchet_baseline.json'], [],
     '§7, §9.1, §9.3; cut v2 C21', 'opus',
     ['(a) G16 scans lib/** minus lib/ui/kit, lib/l10n and generated files; the coordinator amends kit-v2.md §9.3 to match',
      '(b) the §9.1 allowlist gains SingleChildScrollView, NotificationListener, Form, IntrinsicHeight, IntrinsicWidth, FractionallySizedBox, OverflowBox, ClipRect, ExcludeFocus, TickerMode, FocusableActionDetector, ScrollConfiguration',
      '(c) G2 patterns: Clipboard.setData except KitIconButton.copy, HapticFeedback., launchUrl outside external_link.dart, literal Duration(milliseconds:), AnimatedSize',
      '(d) G7: EdgeInsets.only(left:/right:), asymmetric fromLTRB, Alignment.centerLeft/Right, TextAlign.left/right, Positioned(left:/right:)',
      '(e) look patterns: Color(0x…), Colors.*, withOpacity/withValues(alpha:) on text colours, literal TextStyle(/fontSize:/fontWeight:, Icon sizes other than 20/22/24, BorderRadius/Radius.circular literals; excluding app_theme.dart, theme_packs*.dart, theme_roles.dart and scene geometry',
      '(f) ban a disabled KitAction with a spinner (from P7.6)',
      "(g) lib/ui/app_theme.dart joins _allowed: 'ThemeData component themes (AppBarTheme, InputDecorationTheme, NavigationBarThemeData) are theme data, not UI'",
      'G7 and the look patterns start as a ratchet inside lib/ui/kit too (27 parallel kit branches); kit-gates-manifest switches the kit to zero',
      'the only unit besides the integrator that commits test/kit_ratchet_baseline.json (R05)']),
    ('KitUndo', 'kit-part', [K + 'kit_undo.dart', K + 'kit_bottom_inset.dart'], [], '§1.17', 'sonnet',
     ['owns lib/ui/kit/kit_bottom_inset.dart (KitScreen-v2 publishes the inset through it)']),
    ('KitSegmented', 'kit-part', [K + 'kit_segmented.dart'], [], '§1.6', 'sonnet', []),
    ('KitSurface', 'kit-part', [K + 'kit_surface.dart', K + 'kit_panel.dart'], [], '§9.2', 'sonnet',
     ['KitPanel = KitSurface.raised (icon 18 -> 20); KitGlass stays and KitSurface.glass delegates to it']),
    ('KitDivider', 'kit-part', [K + 'kit_divider.dart'], [], '§9.2', 'sonnet', ['hairline 1 physical px']),
    ('KitPageRoute', 'kit-part', [K + 'kit_page_route.dart', K + 'motion/kit_page_transitions.dart'], [], '§9.2', 'sonnet', []),
    ('KitDateTimePicker', 'kit-part', [K + 'kit_date_time_picker.dart'], [], '§9.2', 'sonnet', []),
    ('KitTerm', 'kit-part', [K + 'kit_term.dart', W + 'info_label.dart'], [], '§1.20', 'sonnet',
     ['info_label.dart becomes a @Deprecated wrapper over KitTerm (R12); slice-P3.1 deletes it']),
    ('KitProgress-v2', 'kit-change', [K + 'kit_progress.dart'], [], '§2.8', 'sonnet', []),
    ('KitNotice-v2', 'kit-change', [K + 'kit_notice.dart', W + 'nudge_card.dart'], [], '§2.4; cut v2 C26', 'opus',
     ['KitNotice.cost (the KitCostLine); absorbs NudgeCard (nudge_card.dart becomes a @Deprecated wrapper), _Notice, _FileStatusNotice and the first-run tips; a turn-on notice',
      'the attention card is already KitNotice.card (visual language branch): do not rebuild it',
      "defines KitReportHook (a static handler the app registers); an error tone shows Copy details always and 'Report this' when KitReportHook.handler != null",
      'a classifier maps SocketException and TimeoutException to Retry / Switch server; a test reaches Report within 2 taps (from P8.3)']),
    ('KitAction-v2', 'kit-change', [K + 'kit_buttons.dart', K + 'kit_action_stack.dart'], [], '§2.7', 'sonnet',
     ['disabledReason is required when onPressed is null (from P7.6); destructive stacking']),
    ('KitTerminalView', 'kit-part', [K + 'kit_terminal_view.dart', K + 'terminal_key_bar.dart', W + 'terminal_view.dart'], [], '§9.2', 'opus',
     ['terminal_view.dart becomes a @Deprecated wrapper or is git mv-ed with a re-export (R12)']),
    ('KitScanner', 'kit-part', [K + 'kit_scanner.dart'], [], '§9.2', 'sonnet', []),
    ('KitLevelMeter', 'kit-part', [K + 'kit_level_meter.dart'], [], '§9.2', 'sonnet', []),
    ('KitSwatch', 'kit-part', [K + 'kit_swatch.dart'], [], '§9.2; cut v2 C26', 'sonnet',
     ['KitSwatch + KitThemePreview (accent-only packs after the visual language)']),
    ('KitQr', 'kit-part', [K + 'kit_qr.dart'], [], '§9.2', 'sonnet', []),
    # ---- tier 1b
    ('KitField', 'kit-part', [K + 'kit_field.dart', K + 'kit_secret_field.dart'], ['KitSince', 'KitIconButton-v2'], '§1.4', 'opus',
     ['KitField.secret; KitSecretField becomes a @Deprecated wrapper (R12)']),
    ('KitReceipt', 'kit-part', [K + 'kit_receipt.dart', W + 'team_receipt.dart'], ['KitSince'], '§1.16', 'opus',
     ["carries the automation vertical's KitAutoLine", 'team_receipt.dart becomes a @Deprecated wrapper; slice-P4.1c deletes it']),
    ('KitNeedsYou', 'kit-part', [K + 'kit_needs_you.dart'], ['KitStatusMark-v2'], '§1.21', 'sonnet', []),
    ('KitTappable', 'kit-part', [K + 'kit_tappable.dart'], ['KitMenu'], '§9.2', 'sonnet',
     ['48 dp minimum, focus ring, hover, the same menu on right-click or long-press; `tooltip:` is one of the three Tooltip routes (R23)']),
    ('KitDetailsFold', 'kit-part', [K + 'kit_details_fold.dart', K + 'kit_confirm_sheet.dart', K + 'kit_technical_value.dart'],
     ['KitIconButton-v2'], '§1.8', 'opus', ['the private _KitDetailsFold in kit_confirm_sheet.dart is replaced by the public part']),
    ('KitCodeBlock', 'kit-part', [K + 'kit_code_block.dart', W + 'code_highlight.dart'], ['KitIconButton-v2'], '§1.9', 'sonnet',
     ['code_highlight.dart moves into the kit (wrapper or git mv with re-export, R12)']),
    ('KitJumpPill', 'kit-part', [K + 'kit_jump_pill.dart'], ['KitUndo'], '§1.19', 'sonnet', []),
    ('KitProgressRow', 'kit-part', [K + 'kit_progress_row.dart'], ['KitProgress-v2'], '§1.13; cut v2 C26', 'sonnet',
     ['KitProgressRow.segments: a stacked bar with a worded legend; takes session-context#session-context-makeup']),
    ('KitStatusLine-v2', 'kit-change', [K + 'kit_status_line.dart'], ['KitSince'], '§2.3', 'opus',
     ["the Now line (`next`, the KitNowLine) and escalation; replaces banners and the update/release snackbars",
      "since/onSlow with a fake clock and 'Retry / Restart / Leave it running' (from P7.6)"]),
    ('KitWorkLine', 'kit-part', [K + 'chat/kit_work_line.dart'], ['KitChip'], '§9.2 (chat parts)', 'opus', []),
    ('KitComposerChips', 'kit-part', [K + 'chat/kit_composer_chips.dart'], ['KitChip', 'KitMenu', 'KitImage'], 'cut v2 C16; §5 composer group', 'opus',
     ['the model chip, context badge, attachment preview and inline command row']),
    ('KitWorkGraph', 'kit-part', [K + 'kit_work_graph.dart', 'lib/ui/screens/team/work_graph.dart'], ['KitStatusMark-v2'], '§9.2', 'sonnet',
     ['screens/team/work_graph.dart becomes a @Deprecated wrapper or moves with a re-export (R12)']),
    # ---- tier 1c
    ('KitSearchField', 'kit-part', [K + 'kit_search_field.dart'], ['KitField', 'KitChip'], '§1.5', 'sonnet', []),
    ('KitChoiceList', 'kit-part', [K + 'kit_choice_list.dart', W + 'question_options.dart'], ['KitField', 'KitReceipt'], '§1.7', 'opus',
     ['question_options.dart becomes a @Deprecated wrapper (R12)']),
    ('KitLogPanel', 'kit-part', [K + 'kit_log_panel.dart'], ['KitDetailsFold', 'KitJumpPill', 'KitIconButton-v2'], '§1.11', 'sonnet',
     ['mono LTR, folded (does not compose KitCodeBlock)']),
    ('KitDialog', 'kit-part', [K + 'kit_dialog.dart'], ['KitField', 'KitDetailsFold'], '§1.3', 'sonnet', []),
    ('KitMarkdown', 'kit-part', [K + 'chat/kit_markdown.dart', W + 'markdown.dart'], ['KitCodeBlock'], '§9.2 (chat parts)', 'opus',
     ['KitMarkdown takes a block builder and a highlighter as parameters, so the kit imports neither agent_blocks.dart nor transcript_highlight.dart',
      'markdown.dart becomes a @Deprecated wrapper (R12)']),
    ('KitStateView-v2', 'kit-change', [K + 'kit_state_view.dart'], ['KitDetailsFold', 'KitNotice-v2', 'KitIconButton-v2', 'KitSince'], '§2.2', 'opus',
     ["the whenMissing modes; since/onSlow with a fake clock and 'Retry / Restart / Leave it running' (from P7.6)",
      "an error tone shows Copy details always and 'Report this' when KitReportHook.handler != null; Report within 2 taps (from P8.3)",
      'product_states.dart stays in wave 2a (8 classes); its Product* states become wrappers there']),
    ('KitRowParts-v2', 'kit-change', [K + 'kit_row_parts.dart'], ['KitMenu', 'KitStatusLine-v2', 'KitSegmented'], '§2.5, §2.6, §2.11', 'opus',
     ['KitRowMenu rebuilt on showKitMenu', "KitSwitchRow risk (KitRisk scope and until; while on, the screen's KitStatusLine says so) and locked",
      'a controlled KitExpandRow (expanded, onExpansionChanged)']),
    ('KitTabSwitcher-v2', 'kit-change', [K + 'motion/kit_tab_switcher.dart', W + 'team_board_tabs.dart'], ['KitNeedsYou'], '§2.10', 'sonnet',
     ['the strip; team_board_tabs.dart becomes a @Deprecated wrapper (R12)']),
    ('KitTopBar', 'kit-part', [K + 'kit_top_bar.dart'], ['KitIcon', 'KitIconButton-v2', 'KitNeedsYou', 'KitMenu', 'KitStatusMark-v2'], '§1.18; cut v2 C26', 'opus',
     ['KitTopBar.shell: a glass server pill with a status word and a glass search button (VL §6)']),
    ('KitNav', 'kit-part', [K + 'kit_nav.dart', W + 'glass_surface.dart'], ['KitNeedsYou', 'KitStatusMark-v2', 'KitIcon'], '§8.1; VL §4, §6; cut v2 C08', 'opus',
     ['one KitNavDestination list builds KitNavBar (floating 60 dp glass dock, lens tab, KitNeedsYou badge) and KitNavRail (from medium, extended from expanded) plus the PC sidebar header',
      'glass_surface.dart becomes a @Deprecated wrapper (home_screen.dart and tool/capture import it)',
      'no KitGlass change: the visual language branch ships the rim and dim']),
    ('KitBreadcrumb', 'kit-part', [K + 'kit_breadcrumb.dart'], ['KitTappable'], '§9.2', 'sonnet', []),
    ('KitTaskCard', 'kit-part', [K + 'kit_task_card.dart', W + 'team_board_card.dart'], ['KitNeedsYou', 'KitReceipt', 'KitStatusMark-v2'], '§9.2', 'sonnet',
     ['team_board_card.dart becomes a @Deprecated wrapper (R12)']),
    ('KitQueuedMessage', 'kit-part', [K + 'chat/kit_queued_message.dart'], ['KitReceipt', 'KitIconButton-v2'], '§9.2 (chat parts)', 'opus', []),
    ('KitAgentStrip', 'kit-part', [K + 'chat/kit_agent_strip.dart', W + 'agent_color.dart'], ['KitStatusMark-v2', 'KitNeedsYou'], '§9.2 (chat parts)', 'opus',
     ['agent_color.dart (14 Colors literals) moves onto theme roles inside the kit']),
    ('KitComposer', 'kit-part', [K + 'chat/kit_composer.dart'], ['KitField', 'KitIconButton-v2', 'KitLevelMeter'], '§9.2 (chat parts); cut v2 C16', 'opus',
     ['the glass pill frame (KitGlass with dim), the multiline KitField slot, send (accent) and stop (text1 with a ground square) circles at least 8 dp apart and 48 dp',
      "attach and voice slots; voice mode with KitLevelMeter (P10.3's UI half; embedded-voice-conversation-controls lands here)",
      'no 200 % regressions (from P9.5)']),
    # ---- tier 1d
    ('KitChecklist', 'kit-part', [K + 'kit_checklist.dart', W + 'setup_progress_view.dart'],
     ['KitLogPanel', 'KitProgress-v2', 'KitNotice-v2', 'KitStatusMark-v2', 'KitNeedsYou', 'KitAction-v2', 'KitSince'], '§1.12', 'opus',
     ['the person-step row with its button; waiting/done/failed goldens in dark, light and 200 % (from P1.1)',
      'setup_progress_view.dart becomes a @Deprecated wrapper (R12)']),
    ('KitDiffView', 'kit-part', [K + 'kit_diff_view.dart', W + 'diff_view.dart'], ['KitChoiceList', 'KitIconButton-v2', 'KitAction-v2'], '§1.15', 'opus',
     ['diff_view.dart becomes a @Deprecated wrapper; slice-P3.7a deletes it']),
    ('KitViewer', 'kit-part', [K + 'kit_viewer.dart'], ['KitCodeBlock', 'KitMarkdown', 'KitSearchField', 'KitIconButton-v2', 'KitImage', 'KitMenu'], '§1.14', 'opus', []),
    ('KitScreen-v2', 'kit-change', [K + 'kit_screen.dart', K + 'kit_scaffold.dart', K + 'kit_layout.dart'],
     ['KitTopBar', 'KitSearchField', 'KitStatusLine-v2', 'KitUndo', 'KitJumpPill'], '§2.12, §8.2; cut v2 C06', 'opus',
     ['topBar, search and status slots (KitStatusLineSlot shows the highest-priority status); the bottom inset through kit_bottom_inset.dart',
      'the bottom block lifts above the keyboard; KitScreen.twoPane (§8.2) and a threePane variant for the large class, widths from the C02 freeze (VL: list 296 · conversation 700 · changes 340)',
      "KitScaffold = KitScreen + KitTopBar; the debug-only 'one visible primary per screen' check (§2.7)",
      'FloatingActionButton becomes the KitScreen bottom primary (R23)']),
    ('KitRow-v2', 'kit-change', [K + 'kit_row.dart', K + 'kit_swipe_action.dart'], ['KitUndo', 'KitTappable', 'KitDivider', 'KitRowParts-v2'], '§2.5, §4.1', 'opus',
     ['KitRow.unavailable, the server label, KitSwipeAction (always Undo, never a confirm), destructive rows last after a divider',
      '§8.2 hover, focus and right-click open KitRowMenu']),
    ('KitRequestCard-v2', 'kit-change', [K + 'kit_request_card.dart'],
     ['KitReceipt', 'KitChoiceList', 'KitField', 'KitNeedsYou', 'KitSince', 'KitAction-v2'], '§2.1', 'opus',
     ['kinds {permission, question, form, choice, gate, reply} and the five phases; no change variant (P2 is deferred)',
      'the answered collapse to a row with its receipt; the common answers in place; since escalation; §8.2 A/D/1-9 shortcuts; VL attention roles (attentionSurface, attentionLine, radius 22)',
      "from P4.1a: goldens for every kind in dark, light, RTL and 200 %; 48 dp targets; the receipt announced once; Allow once / Reject in place; an option sends with Undo; 'Something else' opens a KitField with a draft"]),
    ('KitBoardLane', 'kit-part', [K + 'kit_board_lane.dart'], ['KitTaskCard', 'KitTabSwitcher-v2'], '§9.2', 'sonnet', []),
    ('KitMessage', 'kit-part', [K + 'chat/kit_message.dart'], ['KitMarkdown'], '§9.2 (chat parts)', 'opus', []),
    # ---- tier 1e
    ('KitCapabilityExplainer', 'kit-part', [K + 'kit_capability_explainer.dart'], ['KitRow-v2', 'KitStateView-v2'], 'cut v2 C20; capabilities.json', 'opus',
     ['a registry mapping a capability id to why, which host can, and an enable-flow id; the app registers the handlers (coord-main), so the kit imports no screens',
      'KitRow.unavailable and KitStateView.missing look it up by capability id; tests cover the 21 capabilities.json enable flows, plus goldens (replaces slice-P7.3)']),
    ('KitRequestSheet', 'kit-part', [K + 'kit_request_sheet.dart'], ['KitRequestCard-v2', 'KitRowParts-v2', 'KitDiffView'], '§2.1; cut v2 C15', 'opus',
     ["showKitRequestSheet with RequestRoutes; the permission, question, form and gate variants; 'Always allow' as a risk KitSwitchRow"]),
    ('KitToolRow', 'kit-part', [K + 'chat/kit_tool_row.dart'], ['KitCodeBlock', 'KitDiffView', 'KitRowParts-v2', 'KitStatusMark-v2'], '§9.2 (chat parts)', 'opus', []),
    # ---- tier 1f
    ('KitTurn', 'kit-part', [K + 'chat/kit_turn.dart'], ['KitMessage', 'KitWorkLine', 'KitToolRow', 'KitRequestCard-v2'], '§9.2 (chat parts)', 'opus', []),
]
KIT_CHAT_PARTS = {'KitTurn', 'KitMessage', 'KitMarkdown', 'KitToolRow', 'KitWorkLine', 'KitComposer',
                  'KitComposerChips', 'KitQueuedMessage', 'KitAgentStrip'}
# The planned part names (R13): no unit may create a file or class with one of these names.
PLANNED_PARTS = sorted({n.split('-')[0] for n, *_ in KIT if n.startswith('Kit')})
# Names in the contracts that are variants of a wave-1 part.
ALIASES = {'KitNowLine': 'KitStatusLine-v2', 'KitCostLine': 'KitNotice-v2', 'KitAutoLine': 'KitReceipt',
           'KitReportHook': 'KitNotice-v2', 'KitScaffold': 'KitScreen-v2', 'KitStatusLineSlot': 'KitScreen-v2',
           'KitNavRail': 'KitNav', 'KitNavBar': 'KitNav', 'KitSwitchRow': 'KitRowParts-v2', 'KitRowMenu': 'KitRowParts-v2',
           'KitExpandRow': 'KitRowParts-v2', 'KitRisk': 'KitRowParts-v2', 'KitMenuItem': 'KitMenu',
           'KitActionBlock': 'KitAction-v2', 'KitActionStack': 'KitAction-v2', 'KitPanel': 'KitSurface',
           'KitConfirmSheet': 'KitDetailsFold', 'KitTechnicalValue': 'KitDetailsFold', 'KitChoiceRow': 'KitChoiceList',
           'KitPickerRow': 'KitChoiceList', 'KitLoadingBar': 'KitProgress-v2', 'KitThemePreview': 'KitSwatch',
           'KitAvatar': 'KitImage', 'KitZoom': 'KitImage', 'KitSwap': 'KitMotionParts', 'KitSpin': 'KitMotionParts',
           'KitAnimatedBox': 'KitMotionParts', 'KitDim': 'KitMotionParts', 'KitSelectable': 'KitText-v2',
           'KitBottomInset': 'KitUndo', 'KitSwipeAction': 'KitRow-v2', 'KitMarkState': 'KitStatusMark-v2',
           'KitTaskState': 'KitStatusMark-v2', 'KitTaskMark': 'KitStatusMark-v2', 'KitSecretField': 'KitField',
           'KitTerminalKeyBar': 'KitTerminalView', 'KitSheet': 'KitSheet-v2', 'KitText': 'KitText-v2', 'KitIconButton': 'KitIconButton-v2',
           'KitStatusMark': 'KitStatusMark-v2', 'KitScreen': 'KitScreen-v2', 'KitRow': 'KitRow-v2',
           'KitRequestCard': 'KitRequestCard-v2', 'KitStateView': 'KitStateView-v2', 'KitStatusLine': 'KitStatusLine-v2',
           'KitNotice': 'KitNotice-v2', 'KitAction': 'KitAction-v2', 'KitProgress': 'KitProgress-v2',
           'KitTabSwitcher': 'KitTabSwitcher-v2'}


def part_of(name):
    """kit-v2 name -> wave-1 unit id, or None."""
    base = ALIASES.get(name, name)
    uid = f'kit-{base}' if base.startswith('Kit') else f'kit-{base}'
    return uid if uid in by_id else None


for name, kind, files, deps, section, model, acc in KIT:
    part = name.split('-')[0] if name.startswith('Kit') else name
    stem = snake(part) if part.startswith('Kit') else part.replace('-', '_')
    tests = [f'test/kit/{stem}_test.dart']
    if kind != 'kit-gate':
        tests.append(f'test/goldens/kit/{stem}_golden_test.dart')
    spec_name = part if part.startswith('Kit') else part
    spec = f'docs/ux-system/kit-api/{spec_name}.md'
    title = {'kit-part': f'Build {part}', 'kit-change': f'{part} v2', 'kit-gate': f'Kit gates: {part}'}[kind]
    if name == 'KitNotice-v2':
        title = 'KitNotice v2 (cost line; absorbs NudgeCard, _Notice, _FileStatusNotice, first-run tips; turn-on notice)'
    elif name == 'KitAskLine-look':
        title = 'Kit ask line and skeleton transcript take the look'
    elif name == 'KitScenes-v2':
        title = 'Kit scenes and illustration on theme roles'
    elif name == 'KitSwatch':
        title = 'Build KitSwatch + KitThemePreview'
    write = [f for f in files if not f.startswith('test/')] + [f for f in files if f.startswith('test/')]
    if kind == 'kit-gate':
        write = files
        tests = []
    write = write + tests
    touched_vl = sorted(set(files) & VL_TOUCHED)
    unit(f'kit-{name}', 1, title, write, kind=kind, part=part, spec=spec, specSource=f'kit-v2.md {section}',
         specFrozen=os.path.exists(spec), after=[f'kit-{d}' for d in deps], model=model, acceptance=list(acc),
         **({'provisional': True, 'provisionalReason': 'feat/visual-language-v1 is not merged yet and touches '
             + ', '.join(touched_vl) + '; drop from the title and acceptance what it delivered and regenerate (R22)'}
            if touched_vl and not VL_MERGED else {}))

# kit-gates-manifest runs last (tier 1g): after every other wave-1 unit.
unit('kit-gates-manifest', 1, 'Kit gates: manifest, redaction, map check, drafts, glossary',
     ['test/kit_manifest_test.dart', 'test/redaction_test.dart', 'tool/ux/check_map.py',
      'test/kit/kit_draft_manifest_test.dart', 'test/ui_glossary_test.dart'],
     kind='kit-gate', part='gates-manifest', spec='docs/ux-system/kit-api/gates-manifest.md',
     specSource='kit-v2.md §7 (G4, G10, G11, G12, G13); cut v2 C22',
     specFrozen=os.path.exists('docs/ux-system/kit-api/gates-manifest.md'),
     after=sorted(u['id'] for u in units if u['wave'] == 1), model='opus',
     acceptance=['G4: every kit.dart export has a gallery and a doc-table row; starts from a checked-in list of missing galleries that may only shrink (kit.dart has 33 exports and only kit_confirm_sheet has galleries today)',
                 'G12: fake provider keys through KitLogPanel, KitDetailsFold, KitCodeBlock, KitIconButton.copy and the diagnostics preview never render (absorbs P7.1 harness)',
                 'G13 tool/ux/check_map.py; G10 every showKitSheet with a multiline KitField has a KitDraft; G11 contradiction pairs in test/ui_glossary_test.dart (from P7.5)',
                 'switches G7 and the look patterns inside lib/ui/kit to zero now that every kit unit has merged (C21 correction)'])

# ============================================== wave 2: every screen file
# Files that leave wave 2 (moved into kit units, the chat chain, explicit
# units or wave-3 slices) are removed before clustering.
CHAT_LIB = sorted({'lib/ui/screens/chat_screen.dart'} |
                  {p for p in dart_files('lib/ui/screens/chat') if p.count('/') == 4})
S = 'lib/ui/screens/'

# C33: remove/merge-only files go to the wave-3 slice that deletes them
# (seeded write sets, C51 correction).
SLICE_SEEDS = {
    'P1.3': [S + 'termux_setup_screen.dart'],
    'P1.5': [S + 'termux_setup_screen.dart'],
    'P1.6b': [W + 'local_agent_onboarding.dart'],
    'P1.7': [W + 'team_phone_onboarding.dart'],
    'P3.1': [S + 'context_capsule_screen.dart', W + 'session_inventory_footer.dart', W + 'team_card.dart',
             S + 'settings/server_plugins_section.dart', W + 'info_label.dart'],
    'P3.2': [S + 'legacy_drafts_screen.dart'],
    'P3.5': [S + 'team/run_screen.dart'],
    'P3.6': [S + 'team/agent_output_screen.dart'],
    'P3.7a': [W + 'diff_view.dart', S + 'files_screen.dart', S + 'team/merge_section.dart', W + 'run_result_view.dart'],
    'P3.9': [S + 'agent_choice_screen.dart', S + 'connection_help_screen.dart'],
    'P3.11a': [S + 'manage_project_screen.dart', W + 'session_handoff.dart', S + 'library/command_auth_sheet.dart',
               S + 'library/credential_sheet.dart', S + 'library/pending_auth_recovery.dart',
               S + 'library/skill_activation.dart', S + 'library/skills_screen.dart', S + 'provider_quota_screen.dart',
               S + 'project_hub_screen.dart', S + 'workspace_screen.dart', S + 'activity_screen.dart'],
    'P4.1c': [W + 'team_controls.dart', W + 'team_receipt.dart', S + 'team/gate_sheet.dart'],
    'P4.2a': [S + 'attention_overview_screen.dart'],
    'P4.2b': [W + 'completion_digest.dart'],
    'P9.4': ['lib/ui/search/search_index.dart'],
    'P9.10': ['test/kit_ratchet_test.dart'],
}
# Files that leave wave 2 for a wave-3 slice (only the C33 moves; the other
# seeds above are files wave 2 also restyles first).
WAVE3_ONLY = {
    S + 'context_capsule_screen.dart', W + 'session_inventory_footer.dart', W + 'team_card.dart',
    S + 'settings/server_plugins_section.dart', S + 'legacy_drafts_screen.dart', S + 'team/run_screen.dart',
    S + 'team/agent_output_screen.dart', S + 'agent_choice_screen.dart', S + 'connection_help_screen.dart',
    S + 'manage_project_screen.dart', W + 'session_handoff.dart', S + 'attention_overview_screen.dart',
    W + 'completion_digest.dart', W + 'team_phone_onboarding.dart', W + 'local_agent_onboarding.dart',
    S + 'termux_setup_screen.dart'}

# C38 (with the skeptic's corrections): the chat chain, parts first and
# the host last; chat_screen.dart is cut into three regions.
cs = 'lib/ui/screens/chat_screen.dart'
cs_text = read(cs).split('\n')
state_line = next((i + 1 for i, t in enumerate(cs_text) if t.startswith('class _ChatScreenState')), 379)
build_line = next((i + 1 for i, t in enumerate(cs_text) if t.startswith('  Widget build(BuildContext context)')), 6913)
METHOD_RX = re.compile(r'^  (?:@override\s*)?(?:static\s+)?[A-Za-z_][\w<>?, ]*\s+_?\w+\(')
mid_target = (state_line + build_line) // 2
split_line = next((i + 1 for i in range(mid_target - 1, build_line - 1)
                   if METHOD_RX.match(cs_text[i]) and not cs_text[i - 1].strip()), mid_target)
cs_end = len(cs_text) - (1 if cs_text and cs_text[-1] == '' else 0)
KC = K + 'chat/'
CHAIN = [
    ('chat-1', 'Chat parts: messages, markdown and the work line',
     [S + 'chat/message_view.dart', KC + 'kit_turn.dart', KC + 'kit_message.dart', KC + 'kit_markdown.dart', KC + 'kit_work_line.dart'],
     ["from P4.3: the 'Waiting to send · N' bubble (embedded-pending-sends-strip)",
      "from P7.5: 'Waiting for you', never 'Running tools'", 'from P8.3: chat error details can be copied']),
    ('chat-2', 'Chat parts: tool rows and the task view',
     [W + 'tool_card.dart', W + 'mobile_task_view.dart', W + 'transcript_highlight.dart', KC + 'kit_tool_row.dart'],
     ['additive API only (R11): run_result_view.dart and tool/capture import tool_card.dart']),
    ('chat-3', 'Chat parts: the composer',
     [S + 'chat/composer.dart', W + 'model_shortcuts.dart', S + 'chat/prompt_editor.dart', S + 'chat/prompt_history.dart',
      S + 'chat/prompt_stash.dart', KC + 'kit_composer.dart', KC + 'kit_composer_chips.dart', KC + 'kit_queued_message.dart'],
     ["from P4.3: withdrawing a queued message returns its text to the draft with Undo",
      "from P7.7: a 'Sign in to a model' chip before the first send",
      'from P6.6: Queue is the default over Steer (composer.dart:52)',
      "from P7.5: never 'Choose model' while a model answers",
      'draft carry (P7.1): type, swipe, reopen, text kept; the profile sweep removes it']),
    ('chat-4', 'Chat parts: command launcher and the team conversation',
     [S + 'chat/command_launcher.dart', S + 'chat/team_conversation_view.dart',
      S + 'team_conversation/team_conversation.dart', KC + 'kit_agent_strip.dart'], []),
    ('chat-5', 'Chat requests on the one card',
     [S + 'chat/approvals_sheet.dart', S + 'chat/attention_card.dart', S + 'chat/empty_chat.dart',
      S + 'chat/permission_sheet.dart', S + 'chat/voice_conversation.dart', S + 'chat/form_flow.dart'],
     ['from P4.1b: all three cards on KitRequestCard with receipts; Details = showKitRequestSheet; OC1 question = OC2 form',
      'draft carry (P7.1): form answers survive swipe and reopen']),
    ('chat-6', 'Chat sheets, states and small merges',
     [S + 'chat/chat_states.dart', S + 'chat/read_aloud.dart', S + 'chat/session_sheets.dart', S + 'chat/timeline_sheet.dart',
      S + 'chat/transcript_find.dart', S + 'chat/watching.dart', S + 'chat/nudge_slot.dart'],
     ["from P3.11: the todos sheet merges into the transcript checklist; shell-stop uses showKitConfirm; one error-details path through showKitTechnicalDetails",
      'nudge_slot.dart (embedded-chat-nudge-slot, fix) is revamped here']),
    ('chat-7', f'Chat screen, first half ({cs}:1-{split_line - 1})', [cs],
     [f'edits only {cs}:1-{split_line - 1} of the host (plus call sites anywhere in the chat library, R03)',
      'SnackBar -> KitUndo/KitStatusLine, AlertDialog -> KitDialog, _showMessageActions ListTiles -> KitRowMenu, within this region']),
    ('chat-8', f'Chat screen, second half ({cs}:{split_line}-{build_line - 1})', [cs],
     [f'edits only {cs}:{split_line}-{build_line - 1} of the host (plus call sites anywhere in the chat library, R03)',
      'SnackBar -> KitUndo/KitStatusLine, AlertDialog -> KitDialog within this region; from P7.4: the gate near :5070 explains and offers the enable flow']),
    ('chat-9', f'Chat screen build ({cs}:{build_line}-{cs_end})', [cs],
     [f'edits only {cs}:{build_line}-{cs_end} (build) of the host',
      'KitScaffold, KitTopBar, KitJumpPill, the glass composer layer and the §8 panes']),
]
CHAIN_FILES = {f for _, _, fs, _ in CHAIN for f in fs if not f.startswith(K)}
chain_region = {'chat-7': (1, split_line - 1), 'chat-8': (split_line, build_line - 1), 'chat-9': (build_line, cs_end)}
missing_chat = sorted(set(CHAT_LIB) - CHAIN_FILES)

EXPLICIT_2B = {
    'screen-voice-1': ('Voice setup and notices', ['lib/voice/voice_ui.dart', 'lib/voice/notices.dart'],
                       ['kit-KitLevelMeter', 'kit-KitDialog', 'kit-KitSheet-v2'],
                       ['voice-composer-sheet is only restyled: slice-P10.3 deletes it',
                        'G1 reaches 0: showModalBottomSheet becomes showKitSheet']),
    'screen-system-2': ('Update and feedback notices',
                        ['lib/update/shorebird_update_notice.dart', 'lib/update/desktop_release_check.dart',
                         'lib/feedback/bug_report.dart'],
                        ['kit-KitStatusLine-v2', 'kit-KitUndo'],
                        ['the update and release snackbars become KitStatusLine (§2.3); bug_report snackbar becomes showKitUndo or a KitNotice; G1 reaches 0']),
}
COORD_MAIN = ['lib/main.dart', W + 'saved_server_connection_card.dart', W + 'connection_failure.dart',
              'lib/ui/capability_flows.dart']

MOVED_TO_KIT = {f for u in units for f in u['write'] if u['wave'] == 1 and not f.startswith(('test/', K, 'tool/'))}
EXCLUDED_FROM_CLUSTERS = (set(CHAT_LIB) | CHAIN_FILES | MOVED_TO_KIT | WAVE3_ONLY | set(COORD_MAIN)
                          | {f for _, fs, _, _ in EXPLICIT_2B.values() for f in fs}
                          | set(ALLOWED_NOW) | set(ALLOWED_PLANNED))
# C29 corrections: these declare no widget, carry no map page and no gate
# entry, so they are in no unit on purpose.
NOT_UI = {W + 'thermal_notice.dart', W + 'app_exit_notice.dart', 'lib/diagnostics/app_diagnostics.dart'}


def clusters(paths, prefix, wave):
    by_mod = collections.defaultdict(list)
    for p in sorted(paths):
        by_mod[module_of(p)].append(p)
    out = []
    for mod, files in sorted(by_mod.items()):
        files.sort(key=lambda p: (-lines(p), p))
        bins = []
        for f in files:
            n, r = lines(f), raw(f)
            for b in bins:
                if b[0] + n <= MAX_LINES and b[1] + r <= MAX_RAW:
                    b[0] += n
                    b[1] += r
                    b[2].append(f)
                    break
            else:
                bins.append([n, r, [f]])
        for i, (n, r, fs) in enumerate(bins, 1):
            extra = {}
            if len(fs) == 1 and (r > MAX_RAW or n > MAX_LINES):
                extra = {'overBudget': True, 'overBudgetReason': f'single file: {r} raw, {n} lines (C35 correction: allowed and flagged, not split)'}
            out.append(unit(f'{prefix}-{mod}-{i}', wave, f'Revamp {mod} ({len(fs)} files)', fs,
                            kind='screen-revamp', module=mod, model='opus', **extra))
    return out


wave2_files = {p for p in CANDIDATES if p not in EXCLUDED_FROM_CLUSTERS and p not in NOT_UI
               and not p.startswith(K)}
widgets = sorted(p for p in wave2_files if p.startswith(W))
screens = sorted(p for p in wave2_files if not p.startswith(W))
clusters(widgets, 'shared', '2a')
clusters(screens, 'screen', '2b')
for uid, (title, fs, deps, acc) in EXPLICIT_2B.items():
    unit(uid, '2b', title, fs, kind='screen-revamp', module=uid.split('-')[1], model='opus', after=list(deps), acceptance=list(acc))


def owner_of(path, wave):
    for u in units:
        if str(u['wave']) == str(wave) and path in u['write']:
            return u['id']
    return None


# C36: wave-2 `after` from kit-v2.json assignment joined with the unit's
# pages, plus the file -> part map for parts with no assignment.
FILE_PARTS = {
    S + 'pairing_scanner_screen.dart': ['KitScanner'], S + 'home_screen.dart': ['KitNav', 'KitScreen-v2'],
    W + 'appearance_picker.dart': ['KitSwatch'], W + 'session_handoff_sheets.dart': ['KitQr'],
    S + 'files_screen.dart': ['KitBreadcrumb'], S + 'team/team_board_screen.dart': ['KitBoardLane'],
    W + 'file_preview.dart': ['KitViewer'], W + 'run_result_view.dart': ['KitDiffView', 'KitLogPanel'],
}
page_parts = collections.defaultdict(set)
for key, part in assignment.items():
    pid = key.split('#')[0]
    uid = part_of(part) if part.startswith('Kit') else None
    if uid:
        page_parts[pid].add(uid)
for u in units:
    if u['wave'] in ('2a', '2b'):
        deps = set(u['after'])
        for p in u['pages']:
            deps |= page_parts.get(p, set())
        for f in u['write']:
            deps |= {f'kit-{x}' for x in FILE_PARTS.get(f, [])}
        u['after'] = sorted(deps)

# C37 / C42 / C43 / C29 carries, anchored to a file so a re-cut keeps them.
CARRIES = [
    (S + 'home_screen.dart', 'P7.4', 'home_screen.dart:120-132 says why a tab is gated on Codex or Paseo and offers the enable flow'),
    (S + 'home_screen.dart', 'P9.2', 'the rail and dock move onto KitLayout classes via KitNav; the 760/1040 width literals go'),
    (S + 'activity_screen.dart', 'C37', 'Inbox (activity_screen.dart) uses KitScreen.twoPane from expanded'),
    (S + 'workspace_screen.dart', 'C37', 'Work uses KitScreen.twoPane from expanded'),
    (S + 'settings_screen.dart', 'C37', 'Settings uses KitScreen.twoPane from expanded'),
    (S + 'project_hub_screen.dart', 'P7.4', 'project_hub_screen.dart:301 offers the chooser instead of vanishing'),
    (S + 'files_screen.dart', 'P3.8', 'files-file-viewer-sheet is deleted: Files opens showKitViewer, and row actions sit in a KitRowMenu'),
    (W + 'file_preview.dart', 'P3.8', 'the viewer has Close, one labelled action and an overflow'),
    (S + 'workspace_screen.dart', 'P3.12', 'archive from swipe and from the menu is one path with showKitUndo; workspace-archive-session-sheet and workspace-archived-sheet are deleted'),
    (S + 'global_sessions_screen.dart', 'P3.12', 'Archived is a filter of All conversations'),
    (S + 'review_workspace.dart', 'P3.7a', "review_workspace renders KitDiffView with one 'Change 1 of N' navigator"),
    (W + 'team_now.dart', 'P9.6', 'l10n_coverage_test is green for team_now.dart'),
    (W + 'language_picker.dart', 'P9.6', "the language sheet says 'partly translated (N %)'"),
    (W + 'team_controls.dart', 'C37', 'TeamReceiptChip and TeamTechnicalValue become @Deprecated wrappers over KitReceipt and KitTechnicalValue; TeamComposerField becomes KitField'),
    (S + 'team/start_run_sheet.dart', 'P7.1', 'draft carry: the team objective survives type, swipe and reopen; the profile sweep removes it'),
    (S + 'review_workspace.dart', 'P7.1', 'draft carry: the review comment survives type, swipe and reopen'),
    (S + 'team/agent_screen.dart', 'P7.1', 'draft carry: the agent message survives type, swipe and reopen'),
    (S + 'development_services_screen.dart', 'P7.1', 'draft carry: the dev-service editor survives type, swipe and reopen'),
    (W + 'form_renderer.dart', 'P7.1', 'draft carry: form answers survive type, swipe and reopen'),
    (S + 'terminal_screen.dart', 'P7.4', 'explain the gate instead of vanishing, with the enable flow'),
    (S + 'team/agent_screen.dart', 'P7.4', 'explain the gate instead of vanishing, with the enable flow'),
    (S + 'usage_screen.dart', 'P7.4', 'explain the gate instead of vanishing, with the enable flow'),
    (S + 'library/integrations_screen.dart', 'P7.4', 'explain the gate instead of vanishing, with the enable flow'),
    (S + 'capabilities_screen.dart', 'P7.4', 'explain the gate instead of vanishing, with the enable flow'),
    ('lib/ui/search/search_index.dart', 'P7.4', 'Claude Code in search explains its gate'),
    (W + 'confirm_sheet.dart', 'C37', 'SwipeDeleteBackground becomes a wrapper over KitSwipeAction'),
    (W + 'agent_blocks.dart', 'P4.1b', '```choices``` (AgentChoicesBlock) renders KitChoiceList inside KitRequestCard(kind: choice)'),
    (S + 'library/integration_tiles.dart', 'P3.11', 'the two OAuth-code dialogs become one KitDialog'),
    (W + 'product_states.dart', 'C24', 'the Product* states become wrappers over KitStateView; GatedRow and SectionLabel become wrappers over KitRow'),
]
carry_misses = []
for anchor, src, text in CARRIES:
    uid = next((u['id'] for u in units if u['wave'] in ('2a', '2b') and anchor in u['write']), None)
    if uid:
        by_id[uid]['acceptance'].append(f'{text} (from {src})')
    else:
        carry_misses.append((anchor, src))

for u in units:
    if u['wave'] in ('2a', '2b'):
        u['acceptance'].append("G1, G16, G7 and the look patterns for this unit's files reach 0 (showConfirmSheet -> showKitConfirm) (R14, C40)")

# C42 correction: the Archived filter builds on the single archive path.
w1, w2 = owner_of(S + 'workspace_screen.dart', '2b'), owner_of(S + 'global_sessions_screen.dart', '2b')
if w1 and w2 and w1 != w2:
    by_id[w2]['after'] = sorted(set(by_id[w2]['after']) | {w1})

# coord-main (C32): run by the coordinator after the 2b integration.
screen_2b = sorted(u['id'] for u in units if u['wave'] == '2b')
unit('coord-main', '2b', 'App root: main.dart, the saved-server card and the app-level registrations',
     COORD_MAIN, kind='coordinator', module='shell', model='opus',
     after=sorted(set(screen_2b) | {'kit-KitStatusLine-v2', 'kit-KitUndo', 'kit-KitScreen-v2',
                                   'kit-KitCapabilityExplainer', 'kit-KitNotice-v2'}),
     acceptance=['SnackBar x6 -> showKitUndo or KitStatusLine; MaterialBanner x2 -> KitStatusLine; G1 and G16 reach 0',
                 'pages bootstrap-gate, root-connecting, share-session-failed-banner (fix); session-link-server-missing-banner is restyled only (P3.9)',
                 'registers KitReportHook.handler = openReportProblem; report within 2 taps (from P8.3, C26)',
                 'registers all 21 capabilities.json enable-flow handlers (lib/ui/capability_flows.dart); every enableFlows id resolves at runtime (C20)',
                 'connection_failure.dart rides along as the card helper'])

# 2c: the chain starts after the 2a integration (C39) and runs alongside 2b.
shared_2a = sorted(u['id'] for u in units if u['wave'] == '2a')
prev = None
for i, (uid, title, fs, acc) in enumerate(CHAIN, 1):
    kit_deps = sorted({f'kit-{n}' for n in KIT_CHAT_PARTS if f'{KC}{snake(n)}.dart' in fs})
    after = ([prev] if prev else shared_2a) + kit_deps
    if uid == 'chat-5':
        after.append('kit-KitRequestSheet')
    extra = {}
    if uid in chain_region:
        a, b = chain_region[uid]
        extra = dict(region=f'{cs}:{a}-{b}', lines=b - a + 1)
    u = unit(uid, '2c', title, fs, kind='screen-revamp', module='chat', model='opus', lane='CHAT',
             after=sorted(set(after)), acceptance=list(acc), **extra)
    u['acceptance'].append("G1, G16, G7 and the look patterns for this link's files (or region) reach 0 (R14)")
    prev = uid
CHAIN_LAST = prev

# 2d: kit-hygiene closes wave 2 (C40).
WRAPPERS = sorted({W + 'product_states.dart', W + 'nudge_card.dart', W + 'confirm_sheet.dart', W + 'info_label.dart',
                   W + 'setup_progress_view.dart', W + 'question_options.dart', W + 'team_board_tabs.dart',
                   W + 'team_board_card.dart', W + 'terminal_view.dart', W + 'glass_surface.dart', W + 'code_highlight.dart',
                   W + 'agent_color.dart', W + 'markdown.dart', S + 'team/work_graph.dart', K + 'kit_secret_field.dart'})
unit('kit-hygiene', '2d', 'Kit hygiene: drop dead wrappers, complete kit.dart', [K + 'kit.dart'] + WRAPPERS + ['tool/capture/**'],
     kind='kit-hygiene', model='opus',
     after=sorted(u['id'] for u in units if u['wave'] in ('2a', '2b', '2c')),
     acceptance=['kit.dart: drop the product_states re-export and complete the doc table',
                 'deletes every @Deprecated wrapper from C23/C24 that has no callers left, and re-points tool/capture call sites',
                 'confirm_sheet.dart and product_states.dart are deleted only when no callers remain; otherwise listed with the wave-3 slice that clears them',
                 'wrappers still in use wait for their slice and are listed: diff_view -> P3.7a, TeamReceiptChip -> P4.1c, InfoLabel -> P3.1',
                 'runs the G4 manifest test', 'then the integrator runs a dead-key ARB sweep (R04)'])

# ================================ wave 3: behaviour (the programme slices)
DONE = {'P0.1', 'P0.2', 'P0.3', 'P0.4', 'P0.5', 'P0.6', 'P0.8', 'P9.1', 'P9.2', 'P9.3', 'P9.7', 'P9.8', 'P9.9', 'P4.1a'}
DEFERRED = {pid for pid, d in decisions['decisions'].items() if d.get('verdict') == 'later'}  # P2
ABSORBED = {
    'P1.1': 'kit-KitChecklist (app-resume re-check -> slice-P1.2)', 'P4.1a': 'kit-KitRequestCard-v2 + kit-KitRequestSheet',
    'P7.1': 'wave-2 draft carries, kit-gates-manifest G10/G12, voice transcript -> slice-P10.3',
    'P7.3': 'kit-KitCapabilityExplainer', 'P7.4': 'wave-2 carries and chat-8',
    'P7.5': 'chat-1, chat-3, kit-gates-manifest G11; row 19 -> slice-P5.2; row 22 -> slice-P4.4',
    'P7.6': 'kit-KitSince, kit-KitStateView-v2, kit-KitStatusLine-v2, kit-KitAction-v2, kit-gates-ratchet',
    'P8.3': 'kit-KitStateView-v2, kit-KitNotice-v2 (KitReportHook), coord-main, chat-1',
    'P9.5': 'kit-KitStatusMark-v2, kit-KitComposer, per-unit 200 % goldens; TalkBack walk -> PLAN §7',
    'P9.6': 'kit-gates-ratchet G7, shared team_now owner, shared language_picker owner',
    'P3.8': 'the files_screen and file_preview owners (2b/2a)', 'P3.12': 'the workspace and global_sessions owners (2b)',
    'P4.1b': 'chat-5 and the agent_blocks owner (2a)', 'P4.3': 'chat-1 and chat-3', 'P7.7': 'chat-3',
    'P1.6a': 'gate-P1.6a (coordinator, on device)', 'P3.11': 'slice-P3.11a + chat-6', 'P6.6': 'slice-P6.6a + chat-3 + slice-P10.4',
}
RESCOPE = {
    'P3.7a': dict(effort='S', finishLine="widgets/diff_view.dart (the @Deprecated wrapper over KitDiffView since wave 1) and files-changes-sheet in files_screen.dart are deleted; merge_section.dart, run_result_view.dart and the request 'See the change' render KitDiffView directly."),
    'P4.1c': dict(effort='S', finishLine="Both TeamReceiptChip wrappers (team_controls.dart:52, team_receipt.dart:101) and gate_sheet's _Receipt are deleted; gate-sheet is the Details variant only; team gates use the wave-1 KitRequestCard and KitReceipt."),
    'P9.4': dict(finishLine='The search index upgrade (lib/ui/search/search_index.dart) plus adoption: typo tolerance, rows inside pages, arrival with a highlight, dead aliases fixed, and effects, keep running and crash indexed. kit_search_field.dart is read-only.'),
    'P3.11a': dict(title='Small merges (outside the chat library)',
                   finishLine='The remaining non-chat pairs become one: the handoff dialog becomes continue-on-computer; one forget-auth sheet; the auth confirm merges into the auth sheet; skills preview merges into activation; quota enrol merges into provider-quota; the directory and session detail dialogs merge into the context sheets; manage-project merges into project-hub (deleted); question-sheet-dismiss-dialog (activity_screen.dart) uses showKitConfirm.'),
    'P6.6a': dict(title='Defaults instead of questions (pickers, project, model, review scope)',
                  finishLine="The app skips any picker with one option, uses the only or last-used project ('my-app' on first run), picks the server's default model by name after the first sign-in, and picks the review scope that has changes."),
}
DROP_ACCEPT = {'P3.10': 'search aliases', 'P6.3': 'measured:'}
DROP_FINISH = {'P3.9': ', and profile-monitor folds into server rows'}
ADD_ACCEPT = {
    'P1.2': ['person steps are re-checked on app resume (from P1.1)'],
    'P4.4': ['uses KitStatusLineSlot and the priority order (connection > app killed > heat > update) over what coord-main and screen-system-2 converted',
             "ledger row 22 closed ('Connecting…' forever; from P7.5)"],
    'P5.2': ['ledger row 19 closed (from P7.5)'],
    'P10.3': ['the voice transcript lands in the draft and survives swipe and reopen (from P7.1)'],
    'P10.4': ['the voice pack is picked by total RAM and the voice by locale (from P6.6)'],
    'P3.1': ['info_label.dart (the wrapper over KitTerm) is deleted', 'each moved file is deleted, or G16 for it is 0'],
    'P6.3': ["the '< 5 s on the emulator / owner's phone' measurement is coordinator work at the PLAN §7 checkpoint (R20)"],
}
GATED = {
    'P0.7': 'Can projects be kept when This phone is removed? Read lib/builtin/builtin_folders.dart; if not, the sheet offers Export projects first.',
    'P6.3': "Does lib/orchestration's Gas City client expose a dispatch trigger?",
}
# C46 slice edges, on top of the programme floor (C46 correction).
EDGES = {
    'P1.3': ['P1.2'], 'P1.5': ['P1.2', 'P1.3', 'P0.7'], 'P1.4': ['P1.5', 'P0.7'],
    'P1.6b': ['gate-P1.6a:go', 'P1.2', 'P1.5'], 'P1.7': ['P1.2'], 'P3.4': ['P1.7'], 'P3.5': ['P3.4', 'P4.1c'],
    'P3.6': ['P3.5'], 'P3.10': ['P3.1'], 'P4.2b': ['P4.2a'], 'P5.1': ['P3.5'], 'P5.2': ['P3.4'],
    'P5.3': ['P1.5'], 'P5.4': ['P3.11a'], 'P5.5': ['P4.4', 'P4.2b'], 'P6.2': ['P6.1', 'P4.2a'], 'P6.3': ['P5.1'],
    'P6.4': ['P6.1', 'P3.5'], 'P6.5': ['P4.4'], 'P6.6a': ['P3.3', 'P4.5'], 'P6.7': ['P6.1'], 'P7.2': ['P3.2'],
    'P8.2': ['P8.1'], 'P8.4': ['P8.2'], 'P9.4': ['P3.1', 'P3.10', 'P3.11a', 'P1.3'], 'P10.1': ['P3.1'],
    'P10.2': ['P3.11a'], 'P10.3': ['P10.4'],
}
# Earlier-wave edges, by anchor file where the owning unit id is computed.
EDGES_FILE = {'P3.7a': [(S + 'review_workspace.dart', '2b'), (S + 'files_screen.dart', '2b')],
              'P4.1c': [(S + 'team/gate_sheet.dart', '2b')]}
EDGES_UNIT = {'P4.1c': ['chat-4'], 'P4.4': ['kit-KitScreen-v2', 'coord-main']}
# Owner order (programme-decisions): P5 after P3; P6 after P4+P5; P10 after
# P4; P1 and P3 after P0 (only P0.7 remains).
FLOOR = {'P1': ['P0'], 'P3': ['P0'], 'P5': ['P3'], 'P6': ['P4', 'P5'], 'P10': ['P4']}
CHAT_LANE = ['P3.7b', 'P3.2', 'P3.3', 'P4.1c', 'P3.5', 'P3.6', 'P5.1', 'P4.4', 'P10.2', 'P10.1', 'P10.3']
# Slices that name a wave-1 part in their title or finish line only as a
# user of it (assertion 4): the part's files are read-only for them.
ADOPTS = {'P1.5': ['KitLogPanel'], 'P3.7a': ['KitDiffView'], 'P4.1c': ['KitRequestCard', 'KitReceipt'],
          'P5.1': ['KitNowLine'], 'P6.2': ['KitAutoLine'], 'P8.4': ['KitLogPanel'], 'P9.4': ['KitSearchField'],
          'P9.10': ['KitPageRoute'], 'P10.2': ['KitRow']}
PROG_ORDER = ['P0', 'P9', 'P7', 'P8', 'P4', 'P1', 'P3', 'P10', 'P5', 'P6']

page_ids = set(page_proposal)
target_ia = read('docs/ux-system/target-ia.md')
ia14 = target_ia.split('### 1.4', 1)[1].split('\n## ', 1)[0] if '### 1.4' in target_ia else ''


def slice_pages(sid, texts):
    """C49: only page ids named in the slice's own text, plus §1.4 rows tagged with its id."""
    blob = ' '.join(texts)
    # Hyphenated ids only: one-word ids ('files', 'settings') are ordinary words in prose.
    found = {p for p in re.findall(r'[a-z0-9]+(?:-[a-z0-9]+)+', blob) if p in page_ids}
    for row in ia14.split('\n'):
        if re.search(rf'\b{re.escape(sid)}\b', row):
            found |= {p for p in re.findall(r'`([a-z0-9-]+)`', row) if p in page_ids}
    return sorted(found)


slice_src = {}
for prog in programmes:
    for s in prog['slices']:
        slice_src[s['id']] = (prog, s)
WAVE3_IDS = []
for prog in programmes:
    if prog['id'] in DEFERRED:
        continue
    for s in prog['slices']:
        sid = s['id']
        if sid in DONE or sid in ABSORBED and sid not in ('P3.11', 'P6.6'):
            continue
        if sid in ('P3.11', 'P6.6'):
            sid = sid + 'a'
        s = dict(s, **RESCOPE.get(sid, {}))
        acc = [a for a in s.get('acceptance', []) if not (sid in DROP_ACCEPT and DROP_ACCEPT[sid] in a)]
        acc += ADD_ACCEPT.get(sid, [])
        fl = s['finishLine'].replace(DROP_FINISH.get(sid, '\0'), '')
        seeds = SLICE_SEEDS.get(sid, [])
        extra = {}
        if sid in GATED:
            extra['gate'] = GATED[sid]
        if sid == 'P1.6b':
            extra['onGateNoGo'] = {'gate': 'gate-P1.6a', 'moveWrite': {W + 'local_agent_onboarding.dart': 'slice-P1.5'},
                                   'note': 'on no-go P1.6b is skipped and local_agent_onboarding.dart gets a kit-only restyle in slice-P1.5 (C33 correction)'}
        after = [e if e.startswith('gate-') else f'slice-{e}' for e in EDGES.get(sid, [])]
        after += EDGES_UNIT.get(sid, [])
        after += [f'programme-{p}' for p in FLOOR.get(prog['id'], [])]
        after.append('CHAIN_LAST')
        unit(f'slice-{sid}', 3, f"{sid} {s['title']}", seeds, kind='programme-slice', programme=prog['id'],
             finishLine=fl, nonGoal=s.get('nonGoal', ''), effort=s.get('effort', 'M'), acceptance=acc,
             proof=s.get('proof', ''), model='opus', seeded=bool(seeds),
             kitReadOnly=sorted(ADOPTS.get(sid, [])), lane='CHAT' if sid in CHAT_LANE else None,
             pages=slice_pages(sid, [s['title'], fl] + acc), after=after, **extra)
        WAVE3_IDS.append(f'slice-{sid}')
for sid in WAVE3_IDS:
    u = by_id[sid]
    u['after'] = [CHAIN_LAST if a == 'CHAIN_LAST' else a for a in u['after']]
    for f, wave in EDGES_FILE.get(sid[6:], []):
        o = owner_of(f, wave)
        if o:
            u['after'].append(o)
    if sid == 'slice-P9.10':  # C45: after every unit in waves 1-2d and every other slice
        u['after'] = sorted(x['id'] for x in units if x['id'] != sid and x['kind'] != 'coordinator') + ['coord-main']
        u['afterMode'] = 'settled'  # a blocked (no-go, not feasible) slice only has to settle, not merge
    u['after'] = sorted(set(u['after']))
    if u['lane'] is None:
        del u['lane']

# ------------------------------------------------------ lock groups (C47)
CHANNEL_RX = re.compile(r'(?<![\w])(?:Method|Event)Channel\(')
DART_CHANNEL_FILES = sorted(p for p in dart_files('lib') if CHANNEL_RX.search(read(p)))
LOCK_GROUPS = {
    'CHAT': {'exact': ['lib/ui/screens/chat_screen.dart'], 'prefix': ['lib/ui/screens/chat/', 'lib/ui/kit/chat/']},
    'NATIVE': {'exact': DART_CHANNEL_FILES, 'prefixSuffix': [['android/', '.kt']]},
    'API2': {'prefix': ['lib/api2/']},
}
SINGLE_LOCKS = ['lib/main.dart', 'lib/state/connection.dart', 'lib/domain/server_gateway.dart', 'lib/api/product_repository.dart']
HOTSPOTS = {'exact': ['lib/ui/kit/kit.dart', 'test/kit_ratchet_baseline.json', 'test/l10n_coverage_test.dart',
                      'test/design_standard_test.dart', 'docs/design/ui-ledger/ledger.json',
                      'docs/design/ui-ledger/pages.md', 'docs/design/ui-ledger/navigation.md'],
            'prefix': ['lib/l10n/', 'test/goldens/', 'docs/qa/'],
            'newUnder': ['lib/ui/kit/']}
KIT_EXISTING_SET = set(KIT_EXISTING)


def is_hotspot(p):
    return (p in HOTSPOTS['exact'] or p.startswith(tuple(HOTSPOTS['prefix']))
            or (p.startswith('lib/ui/kit/') and p not in KIT_EXISTING_SET))


def locks_of(paths, hints=()):
    out = set(hints)
    for p in paths:
        if is_hotspot(p):
            continue
        g = None
        for name, rule in LOCK_GROUPS.items():
            if (p in rule.get('exact', []) or p.startswith(tuple(rule.get('prefix', [])))
                    or any(p.startswith(a) and p.endswith(b) for a, b in rule.get('prefixSuffix', []))):
                out.add(name)
                g = name
        if p in SINGLE_LOCKS or g is None:
            out.add(p)
    return sorted(out)


for sid in WAVE3_IDS:
    u = by_id[sid]
    u['locks'] = locks_of(u['write'], ['CHAT'] if u.get('lane') == 'CHAT' else [])

# ------------------------------------------- tiers (R02) and wave-3 preview
def expand(u, pool):
    out = set()
    for a in u['after']:
        if a.startswith('programme-'):
            out |= {x for x in pool if by_id[x].get('programme') == a[10:] and x != u['id']}
        elif a in by_id:
            out.add(a)
    return out


def tiers(ids):
    pool, tier = set(ids), {}
    changed = True
    while changed:
        changed = False
        for i in sorted(ids):
            deps = expand(by_id[i], pool) & pool
            if all(d in tier for d in deps):
                t = 1 + max([tier[d] for d in deps] or [0])
                if tier.get(i) != t:
                    tier[i] = t
                    changed = True
    return tier


for wave in (1, '2a', '2b', '2c', '2d', 3):
    ids = [u['id'] for u in units if u['wave'] == wave]
    for i, t in tiers(ids).items():
        by_id[i]['tier'] = t

LANE_INDEX = {f'slice-{s}': n for n, s in enumerate(CHAT_LANE)}


def pack_wave3(slices):
    """Mirror of revamp.workflow.js packWave3 (C47, R17) over the seeded
    write sets: batches plus one serial CHAT lane, dependency-aware."""
    pool = set(slices)
    lane = sorted([s for s in slices if 'CHAT' in by_id[s]['locks']], key=lambda s: (LANE_INDEX.get(s, 99), s))
    deps = {s: expand(by_id[s], pool) & pool for s in slices}
    for a, b in zip(lane, lane[1:]):
        deps[b].add(a)
    order, done = [], set()
    prio = {s: (PROG_ORDER.index(by_id[s]['programme']), LANE_INDEX.get(s, 99), s) for s in slices}
    while len(done) < len(slices):
        ready = sorted((s for s in slices if s not in done and deps[s] <= done), key=lambda s: prio[s])
        if not ready:
            raise SystemExit('wave-3 dependency cycle among: ' + ', '.join(sorted(set(slices) - done)))
        order.append(ready[0])
        done.add(ready[0])
    batches, where, ready_at = [], {}, {}
    for s in order:
        need = max([where.get(d, ready_at.get(d, -1)) for d in deps[s]] or [-1])
        if s in lane:
            ready_at[s] = need
            continue
        locks = set(by_id[s]['locks'])
        native = 'NATIVE' in locks
        i = need + 1
        while i < len(batches):
            b = batches[i]
            if not (locks & b['locks']) and not (native and b['native']):
                break
            i += 1
        if i == len(batches):
            batches.append({'ids': [], 'locks': set(), 'native': False})
        batches[i]['ids'].append(s)
        batches[i]['locks'] |= locks
        batches[i]['native'] |= native
        where[s] = i
    return [b['ids'] for b in batches], lane


preview_batches, preview_lane = pack_wave3(WAVE3_IDS)

# ------------------------------------------------ tests write sets (R08)
IMPORT_RX = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)


def resolve(src, spec):
    if spec.startswith(PKG):
        return 'lib/' + spec[len(PKG):]
    if spec.startswith(('package:', 'dart:')):
        return None
    return os.path.normpath(os.path.join(os.path.dirname(src), spec)).replace(os.sep, '/')


_lib_cache = {}


def lib_imports(test_path, seen=None):
    """Lib files a test imports directly, and through test/ helpers."""
    if test_path in _lib_cache:
        return _lib_cache[test_path]
    seen = seen or set()
    seen.add(test_path)
    out = set()
    for spec in IMPORT_RX.findall(read(test_path)):
        p = resolve(test_path, spec)
        if not p:
            continue
        if p.startswith('lib/'):
            out.add(p)
        elif p.startswith('test/') and p not in seen and os.path.exists(p):
            out |= lib_imports(p, seen)
    _lib_cache[test_path] = out
    return out


TEST_FILES = sorted(p for p in dart_files('test'))
INTEGRATOR_GOLDENS = ['test/goldens/kit/kit_foundation_golden_test.dart', 'test/goldens/settings_golden_test.dart',
                      'test/goldens/team_golden_test.dart', 'test/goldens/team_discover_golden_test.dart',
                      'test/goldens/team_sheets_golden_test.dart', 'test/goldens/phone_server_screens_golden_test.dart',
                      'test/goldens/phone_setup_golden_test.dart', 'test/goldens/work_tab_golden_test.dart']
INTEGRATOR_TESTS = set(INTEGRATOR_GOLDENS) | {'test/kit_ratchet_test.dart', 'test/design_standard_test.dart',
                                              'test/l10n_coverage_test.dart', 'test/ui_ledger_coverage_test.dart'}


def concurrency_sets():
    """Sets of units that run at the same time (assertion 1)."""
    sets = []
    for t in sorted({u['tier'] for u in units if u['wave'] == 1}):
        sets.append((f'wave 1 tier {t}', [u for u in units if u['wave'] == 1 and u['tier'] == t]))
    sets.append(('wave 2a', [u for u in units if u['wave'] == '2a']))
    sets.append(('wave 2b + 2c', [u for u in units if u['wave'] in ('2b', '2c')]))
    sets.append(('wave 2d', [u for u in units if u['wave'] == '2d']))
    return sets


golden_owner = {}
GOLDEN_TESTS = [p for p in TEST_FILES if 'matchesGoldenFile' in read(p) and p.endswith('_test.dart')]
for label, us in concurrency_sets():
    owner = {}
    for u in us:
        key = 'CHAT' if u.get('lane') == 'CHAT' else u['id']
        for f in u['write']:
            if f.startswith('lib/') and f != K + 'kit.dart':
                owner.setdefault(f, set()).add(key)
    for tp in TEST_FILES:
        if not tp.endswith('_test.dart') or tp in INTEGRATOR_TESTS:
            continue
        owners = set()
        for f in lib_imports(tp):
            owners |= owner.get(f, set())
        if len(owners) == 1:
            o = owners.pop()
            targets = [u for u in us if (u.get('lane') == 'CHAT' if o == 'CHAT' else u['id'] == o)]
            for u in targets:
                u.setdefault('tests', [])
                if tp not in u['tests'] and tp not in u['write']:
                    u['tests'].append(tp)
            if tp in GOLDEN_TESTS:
                golden_owner.setdefault(tp, {})[label] = 'chat chain' if o == 'CHAT' else o
        elif tp in GOLDEN_TESTS and owners:
            golden_owner.setdefault(tp, {})[label] = 'integrator'
for u in units:
    u.setdefault('tests', [])
    u['tests'] = sorted(u['tests'])
GOLDEN_TABLE = {
    'rule': 'A golden test whose scenes import only one unit\'s files belongs to that unit for that concurrency set; '
            'everything else is the integrator\'s (R07). Units may render integrator goldens to look but must git checkout those PNGs before committing, and never stage test/**/failures/.',
    'integratorAlways': INTEGRATOR_GOLDENS + ['test/support/*.dart', 'tool/capture/census/**', 'docs/qa/screen-census/**'],
    'byTest': {k: golden_owner[k] for k in sorted(golden_owner)},
}

# ------------------------------------------------------------ estimate
def estimate():
    rows = []
    for label, wave, per in [('1 Kit', 1, (0.75, 1.25)), ('2a Shared widgets', '2a', (1.0, 1.5)),
                             ('2b Screens', '2b', (1.0, 1.5)), ('2c Chat chain', '2c', (1.25, 1.75)),
                             ('2d Kit hygiene', '2d', (1.0, 1.5)), ('3 Behaviour', 3, (1.25, 1.75))]:
        us = [u for u in units if u['wave'] == wave and u['kind'] != 'coordinator']
        n = len(us)
        tiers_ = collections.Counter(u.get('tier', 1) for u in us)
        if wave == '2c':
            wall = (n * per[0], n * per[1])
        elif wave == 3:
            rounds = max(sum(math.ceil(len(b) / SLOTS) for b in preview_batches), len(preview_lane))
            wall = (rounds * per[0], rounds * per[1])
        else:
            slots = sum(math.ceil(c / SLOTS) for c in tiers_.values())
            wall = (slots * per[0], slots * per[1])
        rows.append({'wave': label, 'units': n, 'tiers': len(tiers_), 'agentHours': [round(n * per[0]), round(n * per[1])],
                     'wallHours': [round(wall[0], 1), round(wall[1], 1)]})
    return rows


# =============================================================== ASSERTIONS
failures = []


def check(ok, msg):
    if not ok:
        failures.append(msg)


EXEMPT = lambda p: p == K + 'kit.dart' or is_hotspot(p)  # noqa: E731

# (1) disjoint write sets inside every concurrently running set.
for label, us in concurrency_sets():
    seen = {}
    for u in us:
        key = 'CHAT lane' if u.get('lane') == 'CHAT' else u['id']
        for f in u['write'] + u['tests']:
            if EXEMPT(f):
                continue
            if f in seen and seen[f] != key:
                check(False, f'(1) {label}: {f} is in {seen[f]} and {key}')
            seen.setdefault(f, key)
for n, b in enumerate(preview_batches, 1):
    seen = {}
    for s in b:
        for lk in by_id[s]['locks']:
            check(lk not in seen, f'(1) wave 3 batch {n}: lock {lk} held by {seen.get(lk)} and {s}')
            seen.setdefault(lk, s)
    check(sum('NATIVE' in by_id[s]['locks'] for s in b) <= 1, f'(1) wave 3 batch {n}: more than one NATIVE slice')

# (2) every after id resolves, and no cycle.
prog_ids = {p['id'] for p in programmes}
for u in units:
    for a in u['after']:
        ok = a in by_id or a == 'gate-P1.6a:go' or (a.startswith('programme-') and a[10:] in prog_ids)
        check(ok, f'(2) {u["id"]}: after id {a!r} does not resolve')
state = {}


def visit(i, stack):
    if state.get(i) == 1:
        check(False, '(2) dependency cycle: ' + ' -> '.join(stack + [i]))
        return
    if state.get(i) == 2:
        return
    state[i] = 1
    pool = [x['id'] for x in units if x['wave'] == 3]
    for d in sorted(expand(by_id[i], pool)):
        visit(d, stack + [i])
    state[i] = 2


for u in units:
    visit(u['id'], [])
for u in units:
    check('tier' in u, f'(2) {u["id"]} has no tier (unresolved dependency inside its wave)')

# (3) coverage: every G1/G16 file and every existing map file is owned.
owned = {f for u in units for f in u['write']}
allowed = ALLOWED_NOW | set(ALLOWED_PLANNED)
for f in sorted(set(G1) | set(G16) | map_files):
    check(f in owned or f in allowed, f'(3) {f} (G1/G16/map) is in no unit and not in _allowed')
for f in sorted(wave2_files):
    check(f in owned, f'(3) wave-2 candidate {f} is in no unit')
for f in missing_chat:
    check(False, f'(3) chat library file {f} is in no chain link')

# (4) no wave-3 slice names a wave-1 part it would rebuild.
for sid in WAVE3_IDS:
    u = by_id[sid]
    named = set(re.findall(r'\bKit[A-Z]\w*', u['title'] + ' ' + u['finishLine']))
    for name in sorted(named):
        pid = part_of(name)
        if pid and name not in u['kitReadOnly']:
            check(False, f'(4) {sid} names {name} (built by {pid}) without declaring it read-only adoption')
        if pid:
            clash = {f for f in by_id[pid]['write'] if f.startswith(K)} & set(u['write'])
            check(not clash, f'(4) {sid} seeds {sorted(clash)}, owned by {pid}')

# (5) every kit unit has a spec (C02, R16).
for u in units:
    if u['wave'] == 1:
        check(bool(u.get('spec')) and u['spec'].startswith('docs/ux-system/kit-api/'), f'(5) {u["id"]} has no kit-api spec')

# Extra checks from the rules.
for u in units:  # HOTSPOTS stay out of wave-2/3 write sets (C48, exemptions per its correction)
    if u['wave'] in ('2a', '2b', '2c', 3):
        bad = [f for f in u['write'] if is_hotspot(f) and not f.startswith(K + 'chat/')]
        check(not bad, f'(C48) {u["id"]} write set holds HOTSPOTS {bad}')
for u in units:  # R13: nobody but the owning kit unit writes a planned part file
    if u['wave'] != 1:
        for f in u['write']:
            stem = f.rsplit('/', 1)[-1][:-5] if f.endswith('.dart') else ''
            clash = [p for p in PLANNED_PARTS if snake(p) == stem]
            if clash and not (u.get('lane') == 'CHAT' and f.startswith(KC)) and u['id'] != 'kit-hygiene':
                check(False, f'(R13) {u["id"]} writes {f}, a planned part file')
w3 = {u['id'] for u in units if u['wave'] == 3}
check(len(w3) == 45, f'(C46) wave 3 has {len(w3)} slices, expected 45')
check(len([u for u in units if u['wave'] == 1]) == 68, f'(C25) wave 1 has {len([u for u in units if u["wave"] == 1])} units, expected 68')
tier_counts = [c for _, c in sorted(collections.Counter(u['tier'] for u in units if u['wave'] == 1).items())]
check(tier_counts == [28, 12, 15, 8, 3, 1, 1], f'(C25) wave-1 tiers are {tier_counts}, expected [28, 12, 15, 8, 3, 1, 1]')
check(len([u for u in units if u['wave'] == '2c']) == 9, '(C38) the chat chain has 9 links')
for prog in programmes:  # every approved slice is done, absorbed or a wave-3 unit
    if prog['id'] in DEFERRED:
        continue
    for s in prog['slices']:
        sid = s['id']
        check(sid in DONE or sid in ABSORBED or f'slice-{sid}' in by_id, f'(C41) {sid} is neither done, absorbed nor a slice')
REMOVE_MERGE_OK = {S + 'chat/session_sheets.dart': 'chat-6 carries the todos merge',
                   'lib/ui/search/search_index.dart': 'the index serves every page; P9.4 upgrades it'}
remove_merge_only = []
for u in units:
    if u['wave'] in ('2a', '2b', '2c'):
        for f in u['write']:
            ps = file_pages.get(f, [])
            if ps and all(page_proposal.get(p, '').startswith(('remove', 'merge')) for p in ps):
                if f not in REMOVE_MERGE_OK:
                    check(False, f'(R14) wave-2 file {f} has only remove/merge pages; move it to its wave-3 slice (C33)')
                else:
                    remove_merge_only.append(f)
for u in units:
    if u.get('kind') in ('kit-part', 'kit-change') and u.get('part') in KIT_CHAT_PARTS:
        check(all(not f.startswith((S + 'chat', cs)) for f in u['write']), f'(C03) {u["id"]} writes the chat library')

# ================================================================= output
summary = collections.Counter(str(u['wave']) for u in units)
wave1_tiers = dict(sorted(collections.Counter(u['tier'] for u in units if u['wave'] == 1).items()))
doc = {
    'generatedFrom': ['lib/**/*.dart (widget-declaring)', 'test/kit_ratchet_baseline.json', 'test/kit_ratchet_test.dart',
                      'docs/ux-system/map/all.json', 'docs/ux-system/programmes.json',
                      'docs/ux-system/programme-decisions-2026-09-26.json', 'docs/ux-system/kit-v2.json', 'test/**/*.dart'],
    'cut': 'v2 (cut review C01-C52, rules R01-R24)',
    'visualLanguageMerged': VL_MERGED,
    'maxLinesPerScreenUnit': MAX_LINES, 'maxRawPerUnit': MAX_RAW,
    'waves': dict(summary), 'wave1Tiers': {f'1{chr(96 + t)}': c for t, c in wave1_tiers.items()},
    'chatLaneOrder': [f'slice-{s}' for s in CHAT_LANE],
    'wave3Preview': {'batches': preview_batches, 'chatLane': preview_lane,
                     'note': 'seeded write sets only; the workflow re-packs after each slice names its write set'},
    'gates': {'gate-P1.6a': 'coordinator: on-device spike (arm64 and x86_64 emulators + read-only log from the owner\'s phone); record docs/qa/claude-inapp-spike-<date>/README.md and set go or no-go'},
    'hotspots': HOTSPOTS, 'lockGroups': LOCK_GROUPS, 'singleFileLocks': SINGLE_LOCKS,
    'plannedParts': PLANNED_PARTS, 'aliases': ALIASES, 'absorbed': ABSORBED, 'done': sorted(DONE), 'deferred': sorted(DEFERRED),
    'goldenOwners': GOLDEN_TABLE,
    'mapFilesMissing': sorted(map_files_missing), 'notUi': sorted(NOT_UI),
    'removeMergeOnlyKept': {f: REMOVE_MERGE_OK[f] for f in remove_merge_only},
    'carryMisses': carry_misses,
    'estimate': estimate(),
    'units': units,
}
with open(OUT, 'w') as f:
    json.dump(doc, f, indent=1, ensure_ascii=False)
    f.write('\n')

print('units per wave:', dict(summary), 'total:', len(units))
print('wave 1 tiers:', doc['wave1Tiers'])
print('wave 2 tiers:', {w: dict(collections.Counter(u['tier'] for u in units if u['wave'] == w)) for w in ('2a', '2b', '2c', '2d')})
print('wave 3 preview:', len(preview_batches), 'batches', [len(b) for b in preview_batches], '+ CHAT lane', len(preview_lane))
print('over budget (flagged):', [u['id'] for u in units if u.get('overBudget')])
print('provisional (VL merge):', [u['id'] for u in units if u.get('provisional')])
print('kit specs frozen:', sum(1 for u in units if u.get('specFrozen')), 'of', sum(1 for u in units if u['wave'] == 1))
print('carry misses:', carry_misses)
if failures:
    print(f'\nASSERTIONS FAILED ({len(failures)}):', file=sys.stderr)
    for m in failures:
        print('  ' + m, file=sys.stderr)
    sys.exit(1)
print('assertions: all passed (1 disjoint sets, 2 after ids and no cycle, 3 coverage, 4 no rebuilt kit parts, 5 kit specs, plus C25/C38/C41/C46/C48/R13/R14 checks)')
