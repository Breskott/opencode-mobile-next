# revamp-kit-KitReceipt: KitReceipt (2026-09-27)

## 1. Scope

- Unit: `kit-KitReceipt` (wave 1, tier 2, kit-part). Finish line: `KitReceipt` renders every frozen state, escalates a waiting write to "Not confirmed yet" with Try again after 8 s, offers Undo only inside the window, carries the automatic line (KitAutoLine), and `TeamReceiptChip` forwards to it. Non-goal: no screen adopts the receipt beyond the forwarding wrapper; no retry or mutation logic.
- Files changed: `lib/ui/kit/kit_receipt.dart` (new), `lib/ui/widgets/team_receipt.dart` (wrapper), `lib/l10n/app_en.arb` + generated `app_localizations*.dart`, `test/kit/kit_receipt_test.dart` (new), `test/goldens/kit/kit_receipt_golden_test.dart` + 26 PNGs (new).
- Pages (map ids): `chat` (chat-note-receipt-dismiss), `embedded-team-receipt-chip` (receipt), `team-home-needs-you-tab` (receipt): the part is ready; adoption is theirs.
- Specs followed: `docs/ux-system/kit-api/KitReceipt.md`; STANDARDS STATE-5, STATE-10, AUTO-4, DATA-11, COPY-7, A11Y-3, KIT-43, TEST-9, TEST-20; owner decision 2026-09-27 (no Arabic, galleries at 412x915 and 1280x800 only).
- Contract problems (PROC-20):
  1. Task acceptance says "team_receipt.dart becomes a @Deprecated wrapper"; STANDARDS KIT-43 says a kit change never uses `@Deprecated` (it would put infos into the 9 callers' analyze). Followed the rulebook: `/// Retired by kit-KitReceipt: use [KitReceipt]`. KIT-43 also asks for the old name as a G2 ratchet pattern; that lives in the shared ratchet test, so it is left to the integrator.
  2. KitReceipt.md's KIT-12 doc line ("States: sending, sent, confirmed, not confirmed, refused, answered elsewhere, automatic …") is not in the G4 manifest vocabulary {loading, empty, error, disabled, working, answered}; the manifest also asks `disabled` for the nullable `onRetry`/`onUndo`/`onTap`, which the spec rules out ("There is no disabled state"). Followed the spec verbatim (as KitUndo did); `kit_manifest_test` reports `states · KitReceipt`.
  3. The G4 manifest's gallery check wants `kitGallerySizes` and an `_ar_` shot; the owner decision of 2026-09-27 drops Arabic and limits sizes to 412x915 and 1280x800. Followed the owner; `gallery · KitReceipt` is reported by the manifest. The text2 shots use `kitGalleryScaledSizes` (exactly those two sizes).
  4. The spec's Tokens section names a shared `KitTokens.toneFor` / `toneColor`; it does not exist on the base. Colours come straight from ThemeRoles (`accent`, `success`, `text1`, `text2`) as the spec's table lists them.
  5. Spec gaps decided here (reviewer, please confirm): `label` replaces the word only for `confirmed` (a label never makes a sent write read as done, STATE-10); Undo shows only on a confirmed receipt; with no `at`, Undo stays while `onUndo` is passed; the Undo window rides `KitSince` (asserted `undoWindow == escalateAfter`, both 8 s); the visible line is "{word} at {time}" with the actions after it (no literal "·" between the words and a button).
- New kit parts (KIT-3): `KitReceipt`, `KitReceiptState` (KitAutoLine is `KitReceipt(automatic: true)`, no separate class).
- Map items (EVID-11): receipt on the three pages → deferred to their adopting units (slice-P4.1c, shared-team-2, chat chain) per KitReceipt.md "Replaces".
- States (STATE-20): sending, sent, sent escalated, confirmed (label + Undo), not confirmed, refused, answered elsewhere, automatic, span in rows → `test/kit/kit_receipt_test.dart` and the gallery.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitReceipt`, base `dcf05c5e`, code head `fd3a2793`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_receipt_test.dart` | passes | 26 passed (`run-kit-receipt-test.txt`) | PASS |
| 2 | `test/goldens/kit/kit_receipt_golden_test.dart` (compare, G5 in both themes) | passes | 26 passed with step 1 (`run-part-and-gallery.txt`, 52) | PASS |
| 3 | `test/kit_ratchet_test.dart`, `test/design_standard_test.dart` | pass | 48 passed | PASS |
| 4 | `test/l10n_coverage_test.dart`, `test/ui_glossary_test.dart` | pass | passed | PASS |
| 5 | `test/golden_harness_test.dart` | pass | fails only on `kit_page_route_golden_test.dart` arabicFont (not this unit; present on the base) | FAIL (pre-existing) |
| 6 | `test/kit/kit_manifest_test.dart` | no new receipt violations beyond the contract problems | 144 violations; KitReceipt's are `exported`/`docRow` (kit.dart is integrator-owned, R06), `states` (problem 2), `gallery` (problem 3) | FAIL (reported) |
| 7 | `test/team_gate_answer_test.dart` | behaviour unchanged | 30 passed, 1 failed: line 1060 `find.text('Unconfirmed')`; with the finder changed to 'Not confirmed yet' the test passes (probe, reverted) (`run-team-gate-answer.txt`) | FAIL (TEST-19 case 1, shared test) |
| 8 | `test/team_cycle_test.dart`, `test/team_conversation_screen_test.dart`, `test/team_controls_test.dart`, `test/team_one_page_test.dart` | pass | 43 + 37 passed | PASS |
| 9 | `flutter analyze` on changed paths | no new issues | one info: `depend_on_referenced_packages` for `package:clock` in the test, the same info `lib/ui/kit/kit_since.dart` and `test/kit/kit_since_test.dart` have on the base (`clock` is not in pubspec) | PASS (pre-existing class) |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_receipt_test.dart` + `--plain-name`) or golden | Output |
  |---|---|---|
  | STATE-10 | "sent renders "Sent" and its mark", "a sent receipt with a label never says the act" | `run-kit-receipt-test.txt` |
  | STATE-5 | "sent turns into Not confirmed yet at 8 s, announced once", "confirmed never escalates" | same |
  | A11Y-3 | "announcements: three transitions, three announcements; …" (engine semantics updates, spy binding) | same |
  | DATA-11 | "Undo shows until at + 8 s and calls onUndo once", "Undo is never offered on a receipt that is not confirmed" | same |
  | AUTO-4 | "automatic: "{label} at {time}" with Undo (KitAutoLine)", `kit_receipt_automatic_*.png` | same |
  | LAY-9 | "actions are 48 dp targets" | same |
  | G8 | "reduced motion: sending is a still dot and settles" | same |
  | C24 | "TeamReceiptChip wrapper (C24) …" (3 tests) | same |

- Changed test expectations (TEST-19): none in this unit's files. Shared test to update by the integrator: `test/team_gate_answer_test.dart:1060` `find.text('Unconfirmed')` → `find.text('Not confirmed yet')` (COPY-7: the kit word replaces the team chip word). The semantics label "Unconfirmed, open to retry" is kept and still found.
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
- Keyboard focus ring and hover look are not rendered in a golden.
- Not in the shared G8 motion test, G14 keyboard test or G6 overflow matrix (shared files; integrator).
- Not exported from `kit.dart` (R06).
- The full suite was not run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitReceipt` |
| Enabled | Yes, through `TeamReceiptChip` on its 9 call sites | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `fd3a2793` |
| Deployed | No | |
| Released | No | |
