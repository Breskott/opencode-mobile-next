# revamp-kit-KitReceipt: KitReceipt (2026-09-27)

## 1. Scope

- Unit: `kit-KitReceipt` (wave 1, tier 2, kit-part). Finish line: `KitReceipt` renders every frozen state, escalates a waiting write to "Not confirmed yet" with Try again after 8 s, offers Undo only inside the window, carries the automatic line (KitAutoLine), and `TeamReceiptChip` forwards to it. Non-goal: no screen adopts the receipt beyond the forwarding wrapper; no retry or mutation logic.
- Files changed: `lib/ui/kit/kit_receipt.dart` (new), `lib/ui/widgets/team_receipt.dart` (wrapper), `lib/l10n/app_en.arb` (kitReceipt* keys only; the generated `app_localizations*.dart` are not committed: PROC-13/PROC-5, the integrator runs gen-l10n once after the merge), `test/kit/kit_receipt_test.dart` (new), `test/goldens/kit/kit_receipt_golden_test.dart` + 26 PNGs (new).
- Pages (map ids): `chat` (chat-note-receipt-dismiss), `embedded-team-receipt-chip` (receipt), `team-home-needs-you-tab` (receipt): the part is ready; adoption is theirs.
- Specs followed: `docs/ux-system/kit-api/KitReceipt.md`; STANDARDS STATE-5, STATE-10, AUTO-4, DATA-11, COPY-7, A11Y-3, KIT-43, TEST-9, TEST-20; owner decision 2026-09-27 (no Arabic, galleries at 412x915 and 1280x800 only).
- Contract problems (PROC-20):
  1. Task acceptance says "team_receipt.dart becomes a @Deprecated wrapper"; STANDARDS KIT-43 says a kit change never uses `@Deprecated` (it would put infos into the 9 callers' analyze). Followed the rulebook: `/// Retired by kit-KitReceipt: use [KitReceipt]`. KIT-43 also asks for the old name as a G2 ratchet pattern; that lives in the shared ratchet test, so it is left to the integrator.
  2. KitReceipt.md's KIT-12 doc line ("States: sending, sent, confirmed, not confirmed, refused, answered elsewhere, automatic …") is not in the G4 manifest vocabulary {loading, empty, error, disabled, working, answered}; the manifest also asks `disabled` for the nullable `onRetry`/`onUndo`/`onTap`, which the spec rules out ("There is no disabled state"). Followed the spec verbatim (as KitUndo did); `kit_manifest_test` reports `states · KitReceipt`.
  3. The G4 manifest's gallery check wants `kitGallerySizes` and an `_ar_` shot; the owner decision of 2026-09-27 drops Arabic and limits sizes to 412x915 and 1280x800. Followed the owner; `gallery · KitReceipt` is reported by the manifest. The text2 shots use `kitGalleryScaledSizes` (exactly those two sizes).
  4. The spec's Tokens section names a shared `KitTokens.toneFor` / `toneColor`; it does not exist on the base. Colours come straight from ThemeRoles (`accent`, `success`, `text1`, `text2`) as the spec's table lists them.
  5. Spec gaps decided here (reviewer, please confirm): on an ordinary receipt `label` replaces the word only for `confirmed` (a label never makes a sent write read as done, STATE-10); on an automatic line it replaces the state word in every state (States table, "automatic"); Undo shows only on a confirmed receipt; with no `at`, Undo stays while `onUndo` is passed. The Undo window is measured from `KitMotion.undoWindow` itself (one `KitSince` whose start is `at + (undoWindow - escalateAfter)`, so it closes at `at + undoWindow` for any values; no assert). The automatic line's " · " ends the words ("… at 10:42 ·") so a narrow line breaks after the separator and the action starts the next line; the live region's label does not carry it.
  6. KitReceipt.md "The wrapper keeps meaning" maps `unconfirmed` → notConfirmed with `onRetry: onOpen`. At the wrapper's live call sites (KitRow.trailing in `team_needs_you.dart:308`, ListTile.trailing in `activity_screen.dart:905`) the trailing slot is an unflexed Row child with unbounded width, so the receipt's Wrap never wraps and the extra 48 dp Try again overflows the row: "A RenderFlex overflowed by 276 pixels" at 360 dp and text x1.3, 548 at x2.0 (`run-trailing-overflow-before-fix.txt`). It also made two adjacent targets that both call `onOpen`. Kept today's behaviour, one compact tap target that opens the sheet: `KitReceipt(state, onTap: onOpen)` with no `onRetry`, at most 40 % of the screen wide so the words wrap (`TeamReceiptChip.maxWidthFraction`); the chip's semantics label is kept. Proposed text: "In a trailing slot the wrapper is one tap target: `unconfirmed` → notConfirmed with `onTap: onOpen` and no `onRetry` (the sheet it opens is where the retry lives), bounded to 40 % of the screen width." blocks: false.
  7. KitReceipt.md States, "automatic": "{label} at {time}", "the check in success, or the state's mark". Implemented as written (the label replaces the state word in every state; the state's mark stays, so a sent automatic line keeps the `text2` sent check). The Accessibility section excludes the mark "because the word already says it", which is no longer true on an automatic line in a non-confirmed state: TalkBack hears "Restarted the phone's server, at 10:42" for a line that was only sent, not confirmed or refused (STATE-10 tension). Evidence: `lib/ui/kit/kit_receipt.dart` `_plainWord`, test "automatic names the act in every state, beside the state's own mark". Proposed text: "automatic, not confirmed: the semantics label is '{label}, {state word}[, {reason}], at {time}'". blocks: false (confirmed, the common automatic case, is honest as is).
  8. The spec has no word for an automatic line the server refused. Following "the label replaces the state word", it reads "{label}: {reason}" (new key `kitReceiptActRefusedReason`) beside the error mark. Proposed text for the Default words table: "refused, automatic | {label}: {reason} | `kitReceiptActRefusedReason`". blocks: false.
  9. `where` is optional for answeredElsewhere, so a null or blank `where` needs words: "Answered on another device" (new key `kitReceiptAnsweredElsewhereUnknown`, also in `span`). Proposed text for the Default words table: "answeredElsewhere, no `where` | Answered on another device | `kitReceiptAnsweredElsewhereUnknown`". blocks: false.
- New kit parts (KIT-3): `KitReceipt`, `KitReceiptState` (KitAutoLine is `KitReceipt(automatic: true)`, no separate class).
- Map items (EVID-11): receipt on the three pages → deferred to their adopting units (slice-P4.1c, shared-team-2, chat chain) per KitReceipt.md "Replaces".
- States (STATE-20): sending, sent, sent escalated, confirmed (label + Undo), not confirmed, refused, answered elsewhere, automatic, span in rows → `test/kit/kit_receipt_test.dart` and the gallery.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitReceipt`, base `dcf05c5e`, first code head `fd3a2793`; `4220e4d5` drops the generated l10n from the unit; the review fixes follow it (see `git log dcf05c5e..`).
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_receipt_test.dart` | passes | 31 passed (`run-kit-receipt-test.txt`) | PASS |
| 2 | `test/goldens/kit/kit_receipt_golden_test.dart` (compare, G5 in both themes) | passes | 26 passed (`run-gallery.txt`); only `kit_receipt_automatic_{dark,light}.png` were regenerated (the " ·"), looked at | PASS |
| 3 | `test/kit_ratchet_test.dart`, `test/l10n_coverage_test.dart` | pass | 35 passed (`run-gates.txt`) | PASS |
| 4 | "unconfirmed fits a KitRow trailing at 360 dp" with the previous wrapper | fails (proves the test) | overflowed by 276 px (x1.3) and 548 px (x2.0) (`run-trailing-overflow-before-fix.txt`) | FAIL as expected; passes with the fix (step 1) |
| 5 | `test/team_gate_answer_test.dart` | behaviour unchanged | 30 passed, 1 failed: line 1060 `find.text('Unconfirmed')`; with the finder changed to 'Not confirmed yet' all 31 pass (probe, reverted) (`run-team-gate-answer.txt`) | FAIL (TEST-19, shared test, integrator) |
| 6 | `test/team_cycle_test.dart`, `test/team_controls_test.dart`, `test/team_conversation_screen_test.dart`, `test/team_one_page_test.dart` | pass | 62 + 18 passed (`run-team-other.txt`) | PASS |
| 7 | `flutter analyze` on the four changed Dart files | no new issues | one info: `depend_on_referenced_packages` for `package:clock` in the test, the same info `lib/ui/kit/kit_since.dart` and `test/kit/kit_since_test.dart` have on the base | PASS (pre-existing class) |
| 8 | earlier run (first build): `test/kit/kit_manifest_test.dart`, `test/golden_harness_test.dart`, `test/design_standard_test.dart` | see problems 2 and 3 | not rerun for the review fixes (no manifest-relevant change) | as first recorded |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_receipt_test.dart` + `--plain-name`) or golden | Output |
  |---|---|---|
  | STATE-10 | "sent renders "Sent" and its mark", "a sent receipt with a label never says the act" | `run-kit-receipt-test.txt` |
  | STATE-5 | "sent turns into Not confirmed yet at 8 s, announced once", "confirmed never escalates" | same |
  | A11Y-3 | "announcements: three transitions, three announcements; …" (engine semantics updates, spy binding) | same |
  | DATA-11 | "Undo shows until at + 8 s and calls onUndo once", "Undo is never offered on a receipt that is not confirmed" | same |
  | AUTO-4 | "automatic: "{label} at {time}" with Undo (KitAutoLine)", "automatic names the act in every state, beside the state's own mark", `kit_receipt_automatic_*.png` | same |
  | COPY-7 | "answered elsewhere with no device says "another device"" | same |
  | LOOK-21 | "onTap: keyboard focus draws the kit ring and Enter taps" | same |
  | LAY-9 | "actions are 48 dp targets" | same |
  | KIT-13 (200 % in place) | "unconfirmed fits a KitRow trailing at 360 dp, text x1.3 / x2.0" | same; before the fix `run-trailing-overflow-before-fix.txt` |
  | G8 | "reduced motion: sending is a still dot and settles" | same |
  | C24 | "TeamReceiptChip wrapper (C24) …" (3 tests) | same |

- Changed test expectations (TEST-19): in this unit's own file, the wrapper test "unconfirmed offers Try again into onOpen" became "unconfirmed is one tap target into onOpen" (contract problem 6), and the automatic test now expects the full line "{label} at {time} · | Undo" (the spec's " · "). Shared test to update by the integrator: `test/team_gate_answer_test.dart:1060` `find.text('Unconfirmed')` → `find.text('Not confirmed yet')` (COPY-7: the kit word replaces the team chip word). The semantics label "Unconfirmed, open to retry" is kept and still found.
- Goldens added (each opened and looked at): `test/goldens/kit/kit_receipt_{sending,sent,not_confirmed,confirmed,refused,answered_elsewhere,automatic,span_in_rows}_{dark,light}.png`, `kit_receipt_confirmed_1280x800_{dark,light}.png`, `kit_receipt_{not_confirmed,answered_elsewhere}_text2[_1280x800]_{dark,light}.png` (26). The "sending" card is merged into one semantics node in the gallery only: G5's textContrast mis-samples the lone short "Sending…" text2 word at 1x (the KitStatusMark-v2 finding). No approved VL canvas render exists for this part (EVID-12: none).
- Before and after: no before render (new part); after = the goldens above.
- Accessibility: one live region carries "{word}[, {reason}][, at {time}]"; the mark is excluded; Try again and Undo are 48 dp tertiary buttons 8 dp apart and Tab-reachable; `onTap` makes the words one button with a 48 dp target; 200 % text wraps (golden and test).
- Privacy and security: n/a: no credentials, stored data, links or notifications changed. `reason`/`where`/`label` are shown as given, isolated with `KitBidi.auto`.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_receipt_test.dart test/goldens/kit/kit_receipt_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart
$F test -j 1 test/team_gate_answer_test.dart
$F analyze lib/ui/kit/kit_receipt.dart lib/ui/widgets/team_receipt.dart test/kit/kit_receipt_test.dart test/goldens/kit/kit_receipt_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator; TalkBack's actual live-region speech is inferred from the semantics updates sent to the engine.
- The keyboard focus ring is proven by a behaviour test (ring decoration present on Tab focus, Enter taps), not rendered in a golden; hover is not tested.
- The wrapper in a trailing slot is proven at 360x800 with text x1.3 and x2.0 by a behaviour test (no overflow, one tap target), not rendered in a golden; `activity_screen.dart`'s ListTile.trailing is not tested separately.
- Not in the shared G8 motion test, G14 keyboard test or G6 overflow matrix (shared files; integrator).
- Not exported from `kit.dart` (R06).
- The full suite was not run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitReceipt` |
| Enabled | Yes, through `TeamReceiptChip` on its 9 call sites | |
| Verified | tests and goldens only | this record |
| Committed | Yes | `git log dcf05c5e..revamp/kit-KitReceipt` |
| Deployed | No | |
| Released | No | |
