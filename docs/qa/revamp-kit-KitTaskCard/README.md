# revamp-kit-KitTaskCard: KitTaskCard (2026-09-27)

## 1. Scope

- Unit: `kit-KitTaskCard` (wave 1, tier 3, kit-part). Finish line: one AI Team task renders as `KitTaskCard` (mark, title, meta line, one flag line or a move receipt, one named trailing action), and `TeamBoardCardView` builds it with the board's keys and behaviour unchanged. Non-goal: no board layout (KitBoardLane), no move sheet, no screen migration, no `kit.dart` export.
- Files changed: `lib/ui/kit/kit_task_card.dart` (new), `lib/ui/widgets/team_board_card.dart` (mapping file), `test/kit/kit_task_card_test.dart` (new), `test/goldens/kit/kit_task_card_golden_test.dart` (new) and its PNGs, this record.
- Pages (map ids): `team-board#team-board-card`.
- Specs followed: `docs/ux-system/kit-api/KitTaskCard.md`; STANDARDS LOOK-4, LOOK-5, LOOK-14, LOOK-24, KIT-27, KIT-28, KIT-43, STATE-9, STATE-10, COPY-13, A11Y-5, A11Y-8, MOT-11.
- Contract problems (PROC-20):
  1. **@Deprecated vs KIT-43.** The unit's acceptance line says "team_board_card.dart becomes a @Deprecated wrapper (R12)"; the frozen spec and STANDARDS KIT-43 say never `@Deprecated` (it puts infos into every caller's analyze) and mark `/// Retired by kit-KitTaskCard: use KitTaskCard`. Built to the frozen spec and KIT-43 (higher authority). Proposed: drop "@Deprecated" from R12 for kit parts.
  2. **Moving receipt words.** The spec says the move is `KitReceipt(state: sending, label: "Moving to Review…", since: movedAt)` and that it later reads "Not confirmed yet". `KitReceipt` shows `label` only once confirmed (non-automatic) or in every state (`automatic: true`), so no single receipt shows "Moving to Review…" and then "Not confirmed yet". The wrapper uses `automatic: true` (keeps the board's "Moving to Ready…" words); on escalation it keeps the words and shows the not-confirmed mark and Try again. Test 6 checks the plain receipt ("Sending…" → "Not confirmed yet" + Try again). Proposed: KitReceipt gains a sending-word override, or the spec accepts the automatic line.
  3. **No send time for a move.** `TeamBoardCard` has `moving` but no `movedAt`, so the board's receipt has no `since` and never escalates. Needs a `movedAt` in `state/team_board.dart` (not in this write set).
  4. **Needs-you flag label.** The board's only needs-you words are "Needs you", which the kit span already says ("Needs you · Needs you"). The card shows the word alone when the flag label is empty; the wrapper passes an empty label.
  5. **Mark box.** Spec token `iconTileSize` (30) for the mark's box; `KitTaskMark` is `markSlotSize` (32). The mark is used as is.
- New kit parts (KIT-3): `KitTaskCard`, `KitTaskMeta`, `KitTaskFlag`, `KitTaskFlagKind`, `KitPriority`, `KitPriorityGlyph` (all in `lib/ui/kit/kit_task_card.dart`; not exported from `kit.dart`, R06).
- Map items (EVID-11): `team-board#team-board-card` → card look done (gallery `kit_task_card_*`); board screen migration deferred to wave 2 (KitBoardLane).
- States per page (STATE-20): default, needs you, blocked, failed, stopped, done, moving, not confirmed, read-only → goldens `kit_task_card_<state>_<dark|light>.png`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitTaskCard`, base `024e97b0`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_task_card_test.dart` | passes | 11 passed | PASS |
| 2 | `test/goldens/kit/kit_task_card_golden_test.dart` (G5 checks in both themes) | passes | 20 passed | PASS |
| 3 | `flutter analyze` on the four changed files, `lib/ui/screens/team`, `team_board_move_sheet.dart` | no issues | no issues | PASS |
| 4 | Ratchet, design-standard, l10n, board tests | not run | owner decision 2026-09-27 | n/a |

A first gallery run failed G5 reading order in `moving` and `not_confirmed` (the receipt, inside the card's tappable, was read before the trailing action). Fixed by placing the receipt below the card's node and its action; it keeps its own live region and Try again, and a tap on it still opens the task.

## 5. Evidence

- Changed test expectations (TEST-19): none (no shared test edited).
- Goldens (new, owner decision 2026-09-27 sizes): 9 states × dark/light at 412x915, default × dark/light at 1280x800 = 20 PNGs. Arabic, 2.0 text and the other §8.4 sizes are dropped by the owner decision.
- Accessibility: one button node per card, labelled "{title}. {state word}. {meta}. {flag}"; the mark is excluded so the word is read once; the receipt keeps its own live-region node (and its Try again) so it announces itself; the trailing action is a 48 dp `KitIconButton` 8 dp from the edges; title 2 lines, 3 from 1.3×, full title in semantics and tooltip; meta and flag lines wrap.
- Look retired: attention panel on needs-you cards (LOOK-24), attention "Blocked" and red "Failed"/urgent (LOOK-4, LOOK-5), 35 % unlit bars (LOOK-14), the 40 dp "⋯" `IconButton` (KIT-27/28: now the named "Move or change" action with the swap glyph).
- Privacy and security: n/a: no credentials, stored data, links or notifications.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_task_card_test.dart
$F test -j 1 test/goldens/kit/kit_task_card_golden_test.dart
$F analyze lib/ui/kit/kit_task_card.dart lib/ui/widgets/team_board_card.dart test/kit/kit_task_card_test.dart test/goldens/kit/kit_task_card_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- `test/team_board_test.dart` and `test/goldens/team_board_golden_test.dart` (integrator-owned) were not run (owner decision: own files only); the board goldens will change (new card look).
- Ratchet, design-standard and l10n gates were not run (owner decision).
- The card's semantics label carries title, word, meta and flag; while a receipt is shown its words are its own live-region node after the action, not part of the card label.
- Keyboard Tab order was tested only for the card (Enter opens); the action being the next stop and Shift+F10 are KitTappable/KitIconButton behaviour, not re-tested here.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitTaskCard` |
| Enabled | Yes, through `TeamBoardCardView` on the board | |
| Verified | Own tests and gallery only | this record |
| Committed | Yes | `revamp/kit-KitTaskCard` |
| Deployed / released | No | |
