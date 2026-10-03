# revamp-kit-KitTurn: KitTurn, one conversation turn (2026-09-27)

## 1. Scope

- Unit: `kit-KitTurn` (wave 1, tier 6, kit part). Finish line: `KitTurn` lays out a prompt, its blocks, a phase line and exactly one footer (Copy and More) once the turn has ended, to the frozen API in `docs/ux-system/kit-api/KitTurn.md`. Non-goal: grouping messages into turns, deriving the phase, and migrating `message_view.dart` / the team view (chat-1, chat-4).
- Files changed: `lib/ui/kit/chat/kit_turn.dart` (new), `lib/l10n/app_en.arb` (7 `kitTurn*` keys) plus the generated `lib/l10n/app_localizations*.dart`, `test/kit/kit_turn_test.dart` (new), `test/goldens/kit/kit_turn_golden_test.dart` (new) and 26 `test/goldens/kit/kit_turn_*.png`.
- Pages (map ids): `chat#embedded-message-view`, `demo#demo-chat`, `team-agent-output#team-agent-output-text` (the part only; the screens migrate in chat-1 / chat-4).
- Specs followed: STANDARDS STATE-16, KIT-41, STATE-5, AUTO-15, KIT-23, KIT-28, LOOK-26, LOOK-27, MOT-5; kit-v2 §9.2, §8.2; visual-language 2026-09-26 (Chat canvas).
- Contract problems (PROC-20):
  1. **Copy redaction (SEC-13 vs the frozen API).** The spec's header (SEC-13) says the turn copies verbatim, `KitCopy.copy(context, text, redact: false)`, but the API block names `KitIconButton.copy` and `KitMenuItem.copy`, and both copy through `KitCopy.copy` with the default `redact: true` (no parameter to turn it off). Built: SEC-13 wins (later coordinator decision) — the footer's Copy is a `KitIconButton(icon: AppIconography.copy, tooltip: "Copy reply")` and the long-press Copy is a plain `KitMenuItem` with the copy glyph, both calling `KitCopy.copy(..., redact: false)`. Cost: the footer Copy does not show `KitIconButton.copy`'s check glyph for `copiedHold`. Proposed: add `redact` (default true) to `KitIconButton.copy` and `KitMenuItem.copy` (kit-KitIconButton / kit-KitMenu owners), then KitTurn switches to them. Blocks: nothing.
  2. **Highlight band in light theme.** The band is `surface1` (spec, Tokens) and the prompt bubble is `surface2`; in the light pack both read as white, so on a highlighted turn the prompt bubble disappears into the band (see `after-light-text2-highlight.png`, right). Built as specified. Proposed: the band uses `surface2` with the bubble one step up, or the band uses a tinted `surface1` only in light. Blocks: nothing (the find-in-conversation match still reads).
  3. Test 6 wording: with `KitSinceTicks.none` the escalated line keeps the number it had when it turned slow ("· 8 s"), as the spec's test expects; a turn whose `since` is already older shows that age once. No change proposed.
- New kit parts (KIT-3): `KitTurn` (`lib/ui/kit/chat/kit_turn.dart`, with `KitTurnPhase`, `KitTurnFooter`). Not exported from `kit.dart` (integrator, R06).
- Map items (EVID-11): "a turn interrupted by server loss has no end marker" → done: `kit_turn_test.dart` "7 · … interrupted", golden `kit_turn_interrupted_*`; "first token slow > 8 s" → done: test "6 · the starting line", golden `kit_turn_starting_slow_*`; owner Fix "quieter per-turn footer (latest reply only)" → done: test "4 · meta words only on the latest turn", goldens `kit_turn_finished_*` vs `kit_turn_finished_latest_*`.
- States per page (STATE-20): starting, starting slow, running, waitingForYou, finished, finished latest, stopped, interrupted, failed, highlighted → each a golden at 412x915 dark and light, plus tests 2–9.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitTurn`, base `0003f9cd` (feat/phone-setup-v2), code head `02ba0ee1`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: a new part, no fix | – | n/a |
| 2 | `test/kit/kit_turn_test.dart` | passes | 21 passed | PASS |
| 3 | `test/goldens/kit/kit_turn_golden_test.dart --update-goldens` (includes the G5 accessibility checks in both themes) | passes | 26 passed | PASS |
| 4 | `flutter analyze` on the three new files | no issues | no issues | PASS |
| 5 | Ratchet, design-standard, l10n, glossary, ledger tests | pass | not run (owner decision 2026-09-27: only the unit's own test files) | NOT RUN |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | STATE-16 (one footer, order) | `test/kit/kit_turn_test.dart` "1 ·", "3 ·" | run 2 |
  | STATE-16 (no footer while running) | "2 · a running turn has no footer" | run 2 |
  | STATE-5 (8 s escalation) | "6 · the starting line" | run 2 |
  | KIT-23 / SEC-13 (copy at tap time, verbatim, announced once, no SnackBar) | "5 · Copy reads at tap time" | run 2 |
  | A11Y (custom actions, no live region, 48 dp, 8 dp apart) | "10 · one container" | run 2 |
  | LAY-10/11 (Tab order, right-click, Shift+F10) | "11 · desktop capabilities" | run 2 |
  | MOT-5 / G8x (reduced motion) | "12 · reduced motion" | run 2 |
  | G6 (200 % text at 320 dp, LTR and RTL) | "13 · 200 % text at 320 dp" | run 2 |

- Changed test expectations (TEST-19): none.
- Goldens (all new, each opened and looked at): `after-states-1-dark.png` (starting, starting slow, running, waiting for you, finished), `after-states-2-dark.png` (finished latest, stopped, interrupted, failed, highlighted), `after-light-text2-highlight.png` (interrupted light, default 2.0 text dark, highlighted light). Compared with `docs/design/visual-language-2026-09-26/Chat.png`: same prompt bubble, work line and prose; the canvas shows no footer (its turn is waiting), so the footer look follows the spec (meta caption at the start, Copy and More at the end).
- Accessibility: the turn is one semantics container whose custom actions are Copy reply and each menu item; phase lines are plain text (no live region); Copy and More are 48 dp, 8 dp apart, with tooltips "Copy reply" / "More for this reply"; at 2.0 text the meta wraps above the buttons. Arabic dropped by owner decision; RTL covered only by the G6 overflow test.
- Privacy and security: copy is verbatim by coordinator decision SEC-13 (the reply is the person's own content); `copyText` is read at tap time; nothing is logged.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_turn_test.dart
$F test -j 1 test/goldens/kit/kit_turn_golden_test.dart
$F analyze lib/ui/kit/chat/kit_turn.dart test/kit/kit_turn_test.dart test/goldens/kit/kit_turn_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared gates (ratchet, design-standard, l10n coverage, full suite) not run (owner decision 2026-09-27).
- The spec's full gallery grid (360x800, 915x412, 800x1280, 1600x1000, Arabic) is not rendered: owner decision 2026-09-27 narrowed it to 412x915 and 1280x800.
- No Arabic copy for the 7 new keys (owner decision 2026-09-27: `app_en.arb` only; Arabic falls back to English).
- Not wired into chat or the team view (chat-1, chat-4).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitTurn` |
| Enabled | No: no screen uses it until chat-1 | |
| Verified | Own tests and goldens only | this record |
| Committed | Yes | `revamp/kit-KitTurn` |
| Deployed | No | |
| Released | No | |
