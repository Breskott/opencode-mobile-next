# revamp-screen-review-2: Revamp review (2 files) (2026-09-27)

## 1. Scope

- Unit: `screen-review-2` (wave 2b, tier 1, screen-revamp). Finish line: `lib/ui/screens/run_result_screen.dart` and `lib/ui/screens/staged_revert_screen.dart` are built from kit parts only (every G1/G2/G7/G15x/G16/G17/G21/G48 row for both files is gone: `KIT_RATCHET_WRITE=1` leaves no entry for either file), both confirmations go through `showKitConfirm`, and each page is handled by its map proposal (all four are `fix`). Non-goal: no gateway call, controller field or persistence added; no wave-3 behaviour.
- Files changed: `lib/ui/screens/run_result_screen.dart`, `lib/ui/screens/staged_revert_screen.dart`, `lib/l10n/app_en.arb` (+46 `reviewRunResults*` / `reviewRevert*` keys, no key renamed or removed; generated `app_localizations*.dart` restored before commit per PROC-13), `test/staged_revert_workflow_test.dart` (widget tests rewritten, unit tests untouched), new `test/revamp/screen_review_2_test.dart`, new `test/revamp/screen_review_2_golden_test.dart`, 20 goldens `test/revamp/goldens/review_{staged_revert,stage_revert_sheet,run_result}_*.png`, this record with before/after PNGs.
- Pages (map ids): run-result, stage-revert-sheet, staged-revert, staged-revert-confirm-sheet.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-16, KIT-27, KIT-32, KIT-33, KIT-38, LOOK-1, LOOK-2, LOOK-5, LOOK-12, LAY-6, LAY-8, STATE-3, STATE-5, STATE-7, STATE-8, STATE-20, STATE-21, DATA-11, COPY-1, COPY-3, COPY-7, COPY-9, COPY-10, COPY-14, COPY-16, MAP-1, TEST-10, TEST-20; kit-v2 §9.1; kit-api KitSheet (showKitSheet, primaryListenable), KitConfirmSheet (showKitConfirm with action/routes/consequenceItems), KitScreen v2 (width reading, bottom), KitStateView v2 (error, since/onSlow), KitNotice v2, KitRow v2, KitRowParts v2 (KitSwitchRow, KitRowIcon, KitChevron); visual-language §5 (sheets, confirm, rows).
- Contract problems (PROC-20):
  - The task text asks for new copy in `app_en.arb` AND `app_ar.arb` and for `commit every new file`; the owner decision of 2026-09-27 (later, wins) drops Arabic, so only `app_en.arb` changed. PROC-13 says never commit the generated `lib/l10n/app_localizations*.dart`; they were regenerated locally and restored before committing, so the branch needs the integrator's `gen-l10n` to compile.
  - run-result rationale asks for a pinned "Open conversation". `RunResultView` (`lib/ui/widgets/run_result_view.dart`, not in this write set, owned by shared-review-1) draws its own "Open conversation" at the end of the list; pinning a second one would show the same action twice. This page pins only the new "Review changed files". Proposed (one line, RunResultView owner): make `onOpenConversation` optional and skip its KitActionBlock when null; then this screen pins `primary: Open conversation, secondary: Review changed files`. Blocks: nothing.
  - staged-revert actionsMissing "offer export first": `SessionExportScreen` requires a synchronous `markdown` builder, which lives in the chat library (`_transcriptMarkdown`). This page has no transcript, so a "Save a copy first" alternative on the confirmation cannot be offered honestly without a shared transcript builder. Deferred (wave 3 / chat library owner). The "cannot be undone" half is done (row line and confirmation body).
  - `showStageRevertSheet` gained an optional `stage:` callback (additive) so the sheet can show "stage failed" in place. The chat caller (`chat_screen.dart` `_stageFromMessage`, single-owner library, not in this write set) still stages after the sheet closes; until it passes `stage: (applyFiles) => _conn.stageSessionRevert(review, message.info.id, applyFiles: applyFiles)` the failure still reaches chat's own error path. One line for the chat owner.
- New kit parts (KIT-3): none.
- Moved or removed (owner rule "rethink, not just restyle"):
  - Staged revert: the raw message id (`msg_…`) under the prompt → removed (owner verdict: drop the id).
  - "Make revert permanent" (filled, accent-green) and "Clear staged revert" (outlined) buttons → two equal outcome rows under "Choose what happens", each naming the outcome and its consequence in one line: "Put everything back · Bring back the hidden messages and the files as they were." and "Keep the undo · Delete the hidden messages for good. This can't be undone." (destructive, last, danger text only; the fill is only on the confirmation's button, LOOK-5).
  - "These are the file changes reported… Staging may already have applied them." hedge → a labelled group "Files in this undo"; each row shows the file name, its folder (isolated LTR) and `+n −n`, and opens the diff.
  - The busy line plus the LinearProgressIndicator → the one KitScreen loading bar plus each outcome row's disabled reason.
  - "Review latest state" text button in the list → the stale state view's primary, with "Back to the conversation".
  - Stage sheet: the CheckboxListTile → a KitSwitchRow "Put files back too" with a one-line consequence; the Cancel text button → the sheet's own Close; the unlabelled prompt text → a labelled "From this prompt" quote row.
  - Run results: the MaterialBanner refresh error → a KitNotice.error above the kept result; the raw error string in the error state → words, with the raw text behind Details (COPY-14).
- Map items (EVID-11):
  - stage-revert-sheet: statesMissing "stage failed" → done in the sheet (`stage:`; test "the undo sheet keeps the files choice and stays open when setting up the undo fails"); caller wiring is the follow-up above. infoMissing "how many files change" → not knowable before staging (the server returns the preview only after staging); the review page shows it. "later messages hidden" → done in copy ("This prompt and everything after it are hidden while you review"). Rationale "'Undo from this message?', a labelled quote, KitSwitchRow" → done ("Undo from this prompt?"; the app's noun is prompt).
  - staged-revert: statesMissing "no files affected" → done (`staged-revert-no-files` row); "commit/clear failed" → done (question stays open with the kit's failure notice; the page then shows "That didn't finish…" with the reason behind Details; test "a failed "keep the undo" keeps the question open"); "done" → done (golden `review_staged_revert_done_*`, tests "keeping the undo asks first, then says it is done", "putting everything back names the files it replaces"). infoMissing "whether files were reverted (known)" → not in the data (`SessionRevert` has no applyFiles flag); deferred, needs a model field (wave 3). "which later messages are hidden" → deferred (no message list on this page). actionsMissing "say 'permanent' cannot be undone and offer export first" → first half done, export deferred (contract problem 3). Rationale "two equal outcomes with consequences, state the file result, drop the id" → done.
  - staged-revert-confirm-sheet: statesMissing "stale while open" → done: the question closes itself when the undo changes on the server (`RequestRoutes`), and the page shows "The undo changed" with "Review latest state" (test "a remote change closes an open "keep the undo" question and says so"). infoMissing "files edited since staging" → shown as a counted consequence ("1 file is replaced, with any edits made since"; "Files in this undo are replaced…" when the server sent no list). Rationale "KitConfirmSheet, error tone when edits are overwritten, two sentences" → done (destructive kind when files are replaced, neutral when the undo lists no files).
  - run-result: statesMissing "run still in progress" → done (notice `run-result-running`, golden `review_run_result_running_*`). actionsMissing "review the changed files (review-workspace)" → done: pinned "Review changed files" opens `pushWorkingTreeReview` at the first changed file (gated on `capabilities.fileBrowsing`, hidden otherwise like the Project hub's Changes). infoMissing "one-line verdict" and rationale "lead with what is known, name the run by time, file names not paths" → belong to `RunResultView` (shared-review-1, already file names); not in this write set.
- States per page (STATE-20):
  - run-result: loading (KitStateView with the 8 s escalation and Try again), error (golden `review_run_result_error_*`), empty, scope changed (Close run results), loaded (goldens `review_run_result_finished_*`, 1280x800, text2), still running (golden), refresh failed (test).
  - stage-revert-sheet: ready (golden `review_stage_revert_sheet_ready_*`), stale/busy (primary off with its reason; test), working (primary working), stage failed (test).
  - staged-revert: staged (goldens `review_staged_revert_staged_*`, 1280x800, text2), busy (loading bar, rows off with reason), failed, stale, nothing staged, no files, no preview (test at 320 dp × 2.0), done (golden).
  - staged-revert-confirm-sheet: keep (golden `review_staged_revert_confirm_sheet_keep_*`), put back (test), working/failed (kit), stale while open (test).
- Deferred states (STATE-21): none beyond the map items above.

## 2. Builds

- Branch `revamp/screen-review-2`, base `7011dc46` (feat/phone-setup-v2). No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at the wave 2b checkpoint.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/staged_revert_workflow_test.dart` | passes | 18 passed | PASS |
| 2 | `test/revamp/screen_review_2_test.dart` | passes | 5 passed | PASS |
| 3 | `test/revamp/screen_review_2_golden_test.dart --update-goldens` (two `--plain-name` halves) | renders 20 | 9 + 11 passed | PASS |
| 4 | `test/kit_ratchet_test.dart` with `KIT_RATCHET_WRITE=1` (baseline restored after) | no row left for either file in any gate | 0 rows | PASS |
| 5 | `flutter analyze` on the changed lib and test files plus every caller (`chat_screen.dart`, `workspace_screen.dart`, `activity_screen.dart`, both census areas) | no issues | no issues | PASS |

Not run (owner decision 2026-09-27, speed): the rest of the suite, design-standard, l10n, glossary and ledger tests.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | DATA-11 / COPY-9 | "keeping the undo asks first, then says it is done" (question, lost/kept consequences, nothing sent before confirm) | run 1 |
  | STATE-3 | "a failed "keep the undo" keeps the question open"; screen_review_2 "a raw load error says why in words…" | runs 1, 2 |
  | stale while open | "a remote change closes an open "keep the undo" question and says so" (no write) | run 1 |
  | STATE-7 / STATE-8 | "the undo sheet turns its primary off and says why while the conversation is busy" | run 1 |
  | COPY-14 | "a raw load error says why in words and keeps the raw text behind Details" (`10.0.0.2` not visible) | run 2 |
  | A11Y-2 | "missing preview and large text remain usable at compact width" (320×640, text 2.0); goldens `*_text2_dark` | runs 1, 3 |

- Changed test expectations (TEST-19): in `test/staged_revert_workflow_test.dart` "remote change disables an open permanent-revert confirmation" (asserted a disabled `FilledButton`) became "a remote change closes an open "keep the undo" question and says so": `showKitConfirm` has no live enable flag, so a stale question closes itself and the page explains. "missing preview and large text…" now also asserts the unknown-files consequence. Unit tests unchanged.
- Goldens added (each opened and looked at as contact sheets): 20 `test/revamp/goldens/review_staged_revert_staged_{dark,light,1280x800_dark,1280x800_light,text2_dark}.png`, `review_staged_revert_confirm_sheet_keep_{dark,light}`, `review_staged_revert_done_{dark,light}`, `review_stage_revert_sheet_ready_{dark,light}`, `review_run_result_finished_{dark,light,1280x800_dark,1280x800_light,text2_dark}`, `review_run_result_running_{dark,light}`, `review_run_result_error_{dark,light}`. The run-result state is named `finished` because `review_run_result_loaded_*` belongs to shared-review-1 (rendered once by mistake, then restored with `git checkout`). Approved renders (EVID-12): `Confirm.png` for both confirmations and the undo sheet (icon tile, start-aligned title, consequence panel, full-width stacked buttons: match); `Settings.png` for the row groups, labels and switch row (match).
- Before and after (EVID-10): `before-{staged-revert,stage-revert-sheet,staged-revert-confirm-sheet-commit,run-result}.png` from `docs/qa/screen-census/`; `after-{staged-revert,stage-revert-sheet,staged-revert-confirm-sheet-keep,run-result}.png` from the new goldens (dark).
- Accessibility: outcome rows carry their disabled reason as text; the sheet's primary says why it is off; the confirmation title is a question naming the thing; file folders are isolated LTR; 320 dp × 2.0 text passes; no icon-only control was added.
- Privacy and security: raw server errors reach the screen only behind Details (redacted by the kit); no links, credentials, storage keys or notifications changed.
- Migration: n/a (no stored format changed).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/staged_revert_workflow_test.dart test/revamp/screen_review_2_test.dart
$F test -j 1 test/revamp/screen_review_2_golden_test.dart
$F analyze lib/ui/screens/run_result_screen.dart lib/ui/screens/staged_revert_screen.dart test/staged_revert_workflow_test.dart test/revamp/screen_review_2_test.dart test/revamp/screen_review_2_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests not run; likely affected (for the integrator): `test/run_result_screen_test.dart` "…error…" (~l.555 expects the raw `offline` text on screen; it is now behind Details, the body says "The server didn't send this run's history."); `test/design_standard_test.dart` (`_migrated` entries for both files); `test/kit_ratchet_baseline.json` and the l10n coverage baseline (counts dropped to zero); `test/return_brief_widget_test.dart` (imports the screen; not expected to break).
- The chat caller does not yet pass `stage:` (contract problem 4), so "stage failed" in the sheet is proven only by the widget test.
- Export before "Keep the undo" is not offered (contract problem 3).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-review-2` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
