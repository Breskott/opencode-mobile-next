# revamp-kit-KitToolRow: KitToolRow, one step of the work as a line of the reply (2026-09-27)

## 1. Scope

- Unit: `kit-KitToolRow` (wave 1, tier 5, kit part). Finish line: `lib/ui/kit/chat/kit_tool_row.dart` implements the frozen KitToolRow API (step line and `.agent` form) with its behaviour tests and gallery. Non-goal: migrating `tool_card.dart` or `team_conversation_view.dart` (chat-2, chat-4), mapping `ToolState` to words, exporting from `kit.dart`.
- Files changed: `lib/ui/kit/chat/kit_tool_row.dart` (new), `test/kit/kit_tool_row_test.dart` (new), `test/goldens/kit/kit_tool_row_golden_test.dart` and its 24 PNGs (new), `lib/l10n/app_en.arb` (12 `kitTool*` keys, additive), regenerated `lib/l10n/app_localizations*.dart`.
- Pages (map ids): `embedded-tool-card` (header, subagent), `team-conversation` (agent line).
- Specs followed: `docs/ux-system/kit-api/KitToolRow.md` (frozen); STANDARDS rules STATE-16, KIT-41, AUTO-15, STATE-9, STATE-15, LOOK-5, PERF-2, KIT-32, MOT-5, MOT-11, A11Y-3, A11Y-8; kit-v2 §9.2; visual-language §1, §5.
- Contract problems (PROC-20):
  - KitToolRow.md "Depends on" names `KitExpandRow`'s fold behaviour, but its "Motion" section forbids size animation (MOT-5) while `KitExpandRow` unfolds through `KitReveal` (a size reveal). Built on `KitTappable` + `KitSpin.chevron` with an in-part fade instead; `KitExpandRow` is not used. Proposed text: "the fold's chevron and keyboard behaviour match KitExpandRow; the body appears at once (no KitReveal)". Blocks nothing.
  - Kit copy says "en + ar"; the owner decision of 2026-09-27 dropped Arabic, so only `app_en.arb` gained keys (the generated Arabic class falls back to English).
  - Galleries list 360x800, 915x412, 800x1280, 1600x1000 and Arabic RTL; the owner decision of 2026-09-27 limits galleries to 412x915 and 1280x800, light and dark. Built to the owner decision.
  - The spec's row label is "[title], [path or detail], [status word]". The part also reads the +/- counts ("4 added, 1 removed", required by test 4) and, when finished, the duration words after the status word.
- New kit parts (KIT-3): KitToolRow (planned; this unit's own).
- Map items (EVID-11):
  - embedded-tool-card: "long shell output capped like edits" → done: golden `kit_tool_row_done_open` (the host passes `KitCodeBlock(maxLines: 12)`; "Show all 30 lines" visible).
  - embedded-tool-card: "waiting for permission (shows running)" → done: `test/kit/kit_tool_row_test.dart` "waitingForYou never shows a progress indicator" and golden `kit_tool_row_waiting_for_you`.
  - Owner fix on embedded-tool-card ("words for exit codes", mapping) → deferred to chat-2 (host adapter `ToolCard`).
  - team-conversation-agent: plain sub-agent card → done: goldens `kit_tool_row_agent`, `kit_tool_row_agent_done`; the screen migration is deferred to chat-4.
- States per page (STATE-20): notRun, pending, running, waitingForYou, done, failed, stopped, background → `kit_tool_row_test.dart` "status marks and words" group; folded/open → "opening" group and goldens `done_open`, `edit_open`; agent running/done/not tappable → "agent" group and goldens.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitToolRow`, base `8dc27c66`, code head `7caae51e`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: new part, no fix | n/a | PASS |
| 2 | `test/kit/kit_tool_row_test.dart` | passes | 42 passed | PASS |
| 3 | `test/goldens/kit/kit_tool_row_golden_test.dart` (generated, then each image opened) | passes | 24 passed | PASS |
| 4 | `dart analyze` on the part and both test files | no issues | no issues | PASS |
| 5 | Ratchet, design-standard, l10n and full suite | not run (owner decision 2026-09-27: only the unit's own tests) | not run | n/a |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | AUTO-15 | `test/kit/kit_tool_row_test.dart` "waitingForYou never shows a progress indicator" | run 2 |
  | LOOK-5 | "failed paints no danger role and its word in text1" | run 2 |
  | LOOK-14 | "notRun title is text3 and reads Not run" | run 2 |
  | KIT-32 | "mono, LTR under RTL, middle-cut at 320 dp, full in semantics" | run 2 |
  | STATE-9 | "+4 −1 shows signs and reads as words" | run 2 |
  | MOT-5, G8x | "no size animation; reduced motion settles in one pump" | run 2 |
  | A11Y-3 | "semantics: expanded button, 48 dp, no live region" | run 2 |
  | G14 | "desktop: Tab reaches the row, Enter opens it, ring and path tooltip" | run 2 |
  | G6, A11Y-8 | "200 % text at 320 dp" group (every status, LTR and RTL) | run 2 |

- Changed test expectations (TEST-19): none.
- Goldens added (each opened and looked at): `test/goldens/kit/kit_tool_row_{running,waiting_for_you,done,done_open,edit_open,failed,not_run,agent,agent_done}_{dark,light}.png`, `kit_tool_row_default_1280x800_{dark,light}.png`, `kit_tool_row_default_text2[_1280x800]_{dark,light}.png`. Approved render `docs/design/visual-language-2026-09-26/Chat.png` shows the work chip and an edit block but no single tool row; differences: none against what it shows (no frame or fill on the line; code/diff blocks are KitCodeBlock/KitDiffView).
- Before and after: no before render (new kit part; pages `embedded-tool-card`, `team-conversation` are migrated by chat-2/chat-4). After: `after-embedded-tool-card-waiting-for-you.png`, `after-embedded-tool-card-done-open.png`, `after-embedded-tool-card-edit-open.png`, `after-team-conversation-agent-running.png`.
- Accessibility: a row that opens is one button with `expanded` state and label "[title], [path or detail], [+/- words], [status word][, duration]"; glyph, marks and chevron are excluded; ≥ 48 dp; the agent row is a button with hint "Open its conversation" (or `openLabel`), plain text without `onOpen`; minute ticks are not a live region; 200 % text at 320 dp moves the path and words under the title with the mark at the end, no overflow (LTR and RTL).
- Privacy and security: n/a: the row shows no output itself; output goes through KitCodeBlock in `body`.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_tool_row_test.dart
$F test -j 1 test/goldens/kit/kit_tool_row_golden_test.dart
dart analyze lib/ui/kit/chat/kit_tool_row.dart test/kit/kit_tool_row_test.dart test/goldens/kit/kit_tool_row_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Ratchet, design-standard, l10n-coverage and the full suite were not run (owner decision 2026-09-27); `kit.dart` does not export the part yet (integrator, R06).
- No screen uses the part yet; ToolCard and the team conversation migrate in chat-2 and chat-4.
- No Arabic copy or RTL gallery (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitToolRow` |
| Enabled | No: not exported from `kit.dart`, no screen uses it | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `7caae51e` |
| Deployed | No | |
| Released | No | |
