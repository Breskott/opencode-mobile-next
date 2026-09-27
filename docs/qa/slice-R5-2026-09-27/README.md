# slice-R5 — Buttons, menus and tokens (2026-09-27)

Definition: `docs/ux-system/revamp/leftover-units.json` id `slice-R5`, plus the
chat chain's deferred ask (a `redact` parameter on the copy constructors, for R11).

## What changed

- **Tertiary buttons** (`lib/ui/kit/kit_buttons.dart`): enabled words are
  `accent` (was `text2`, which read as disabled beside muted text);
  destructive stays `danger`, disabled stays `text3`. Every screen that shows
  a tertiary action (inline "Rename", "Show details", notice offers, undo,
  confirm-sheet alternatives, ask-line answers, …) picks this up.
- **Copy without redaction**: `KitIconButton.copy`, `KitMenuItem.copy` and
  `KitAction.copy` take `redact` (default `true`, today's behaviour) and pass
  it to `KitCopy.copy`. It is carried through `KitButton.fromAction`, the
  action block's "More", `KitTopBar` (action -> menu item / icon button) and
  `KitTappable`'s menu. R11 can now give `KitTurn`'s footer
  `KitIconButton.copy(redact: false)`.
  Not changed (chat lane owns them): `lib/ui/kit/chat/kit_message.dart:363`
  and `kit_turn.dart:243` call `KitCopy.copy(context, copyText())` for menu
  items and so ignore `item.redact`; R11 or the chat chain should pass
  `redact: item.redact` there.
- **Tokens** (`lib/ui/kit/kit_tokens.dart`): `KitTokens.spinnerStroke` = 2
  (logical) is the one small-spinner stroke for `KitButton`'s `_Spinner`,
  `KitIconButton`'s working glyph and `KitStatusMark`'s working ring (the mark
  used `focusRingWidth`, 2 physical px, so about 0.7 dp on a phone).
  `KitTokens.badgeOffset` = `badgeHeight / 3` (6) replaces the literal in
  `KitNeedsYou`'s badge.
- **Icon-button tooltip**: `margin` = `tokens.gutter` on each side, so a long
  label at 412 dp and 2.0 text wraps inside the screen instead of running edge
  to edge (the framework default margin is 0).
- **Specs**: `docs/ux-system/kit-api/KitAction.md`, `KitIconButton.md`,
  `KitMenu.md`, `KitStatusMark.md`, `KitNeedsYou.md`, `KitAskLine.md`,
  `_new-tokens.md`, STANDARDS LOOK-23 and the visual language §buttons now
  match the code.

## Images

- `kit_action_block_default_light_before_after.png` (phone 412x915)
- `kit_action_block_default_1280x800_dark_before_after.png` (wide window)
- `kit_icon_button_default_text2_light_before_after.png` (tooltip margin at 2.0 text)
- `chat_4_team_conversation_needs_you_light_before_after.png`
- `kit_notice_offer_dark_before_after.png`, `team_home_loaded_light_before_after.png`

## Tests

New (all pass):
- `kit_icon_button_test.dart`: `redact: false` copies a fake key verbatim and
  still shows the check; working spinner uses `spinnerStroke` at DPR 3; long
  tooltip keeps a 16 dp side margin at 412 dp / 2.0 text (fails without the
  fix: left edge 0).
- `kit_menu_test.dart`: `KitMenuItem.copy(redact: false)` copies verbatim.
- `kit_action_test.dart`: enabled tertiary is `accent`, disabled `text3`,
  destructive `danger`; `KitAction.copy(redact: false)` copies verbatim in a
  block and from "More".
- `kit_pre_wave_tokens_test.dart`: `badgeOffset` 6, `spinnerStroke` 2.
- `kit_status_mark_test.dart`: working ring stroke is `spinnerStroke`.

Existing redacting-copy tests (default `true`) still pass. Run:
kit_action, kit_icon_button, kit_menu, kit_copy, kit_redact, kit_status_mark,
kit_needs_you, kit_tokens, kit_pre_wave_tokens, kit_top_bar, kit_tappable,
kit_ratchet. `flutter analyze` clean.

Pre-existing failures, identical on the base commit 5b66961d (checked in a
second worktree): `kit_ratchet_test` G17 (integration_tiles,
quota_monitor_section) and G21 (kit_choice_list, kit_task_card, …, none of
this slice's files); `kit_manifest_test` G4; `ui_glossary_test` G11/G28;
`golden_harness_test` G23; `revamp/shared_team_2_test` clipboard test; and
stale goldens on base (e.g. `kit_menu_*`, `kit_status_mark_*`,
`kit_icon_button_disabled`, `kit_action_*_disabled`, `settings_*`) whose
drift is from earlier merges (a chevron in the menu, etc.), not this slice.

## Goldens

All 143 golden-producing test files were re-run with `--update-goldens` here
and on the base commit. 830 PNGs are committed: those where this slice's
render differs from the base's own re-render. PNGs that changed identically
on base (pre-existing drift, 840) were reverted, so this commit carries only
what R5 changes. A kept PNG whose base was already stale also carries that
drift. Sampled diffs are the tertiary accent, the tooltip margin and the
thicker working ring; nothing else was seen.

Note for the coordinator: golden PNGs under `test/goldens/chat_*` and
`test/revamp/goldens/chat_*` changed too (tertiary words in chat sheets); the
chat chain may re-render the same files.

## Still needs a device

Tertiary contrast in accent on the real phone (both themes), and the
long-press tooltip on a phone at the largest system font.
