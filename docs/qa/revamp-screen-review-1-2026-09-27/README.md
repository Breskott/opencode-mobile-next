# revamp-screen-review-1: Revamp review (1 file) (2026-09-27)

## 1. Scope

- Unit: `screen-review-1` (wave 2b, tier 1, screen-revamp). Finish line: `lib/ui/screens/review_workspace.dart` is built from kit parts only (G1, G2, G7, G15, G16, G17, G21, G48 at zero for the file), renders one `KitDiffView` with one "Change 1 of N" navigator, and the review comment survives typing, a swipe away and reopening. Non-goal: no gateway call, controller field or wave-3 behaviour (revert a file or hunk, send now, open the full file).
- Files changed: `lib/ui/screens/review_workspace.dart` (3,356 → about 870 lines), `lib/l10n/app_en.arb` (+14 `reviewWorkspace*` keys) and the generated `lib/l10n/app_localizations*.dart`, `test/review_workspace_test.dart` (rewritten), `test/review_handoff_test.dart` (widget group rewritten), new `test/revamp/screen_review_1_golden_test.dart`, 16 goldens `test/revamp/goldens/review_*.png`, this record.
- Pages (map ids): review-workspace, review-comment-sheet.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-17, KIT-20, KIT-22, KIT-23, KIT-28, KIT-32, KIT-34, KIT-35, KIT-36, LOOK-1, LOOK-2, LOOK-12, LAY-6, LAY-7, LAY-8, LAY-12, STATE-1, STATE-3, STATE-8, STATE-20, STATE-21, DATA-1, DATA-2, DATA-11, SEC-13, COPY-30, MAP-1; kit-v2 §9.1; kit-api KitDiffView.md, KitSheet.md, KitField.md, KitSegmented.md; visual-language §5 (sheets, rows).
- Contract problems (PROC-20):
  - `KitDiffView` (kit-api KitDiffView.md "Public API") has no callback for the file on screen (no `onFileChanged`). The page's "N of M viewed" progress and the map's "all files viewed" moment need it. This unit reads the current file from the one place the kit tells the host about it, the `fileActions(file)` call made when the header draws, and marks the file viewed after the frame (`_observeShown`). Proposed: add `ValueChanged<int>? onFileChanged` to KitDiffView (additive, kit-KitDiffView owner). Blocks: nothing; the screen should switch to the callback when it lands.
  - `KitDiffSelection` does not say whether the selection is a whole hunk, and the kit selects line ranges only (tapping an `@@` row does not select the hunk). "Select a hunk and stage it as a hunk" (`ReviewReferenceKind.hunk`) is gone; a selection stages as `selection` with its line label ("new lines 12–14"). Proposed: an optional `hunk` flag on `KitDiffSelection` if the owner wants hunk staging back. Blocks: nothing.
  - `KitTopBar`'s subtitle `AnimatedSwitcher` throws "Duplicate keys" when the subtitle goes A → B → A inside 150 ms (`lib/ui/kit/kit_top_bar.dart` ~l.368, key `'$needsYou|$subtitle'`). This unit avoids the flip (the first file counts as viewed from the first frame) but the kit should key by a counter or drop duplicates. Blocks: nothing.
  - The task text asks for new copy in `app_en.arb` AND `app_ar.arb`; the owner decision of 2026-09-27 (later, wins) drops Arabic, so only `app_en.arb` changed.
  - Callers do not pass the new optional `ReviewWorkspace(profileId:)` yet (`chat_screen.dart` `_showDiff`, `files_screen.dart` `pushWorkingTreeReview`; neither is in this write set). Until they do, the comment draft is kept in memory (survives swipe and reopening review within the app run) but not on disk. One line each: `profileId: _conn.profile?.id` / `profileId: controller.profileId`.
- New kit parts (KIT-3): none.
- Moved or removed (owner rule "rethink, not just restyle"):
  - The file strip, the wide file list, the per-file toolbar (file name shown three times), the phone toolbar and the bottom "N hunks" bar → one KitDiffView header, file picker / file list and navigator.
  - The Unified/Split buttons → removed: the diff picks side by side from its own width (expanded and up), unified below (map: `couldBeAutomatic`).
  - The app-bar Wrap button → the diff header's Wrap toggle (still saved in the reader preferences).
  - The "N on prompt" back button in the app bar → the top bar subtitle ("1 on prompt · 2 of 3 viewed"); Back returns to the conversation, and the finished moment offers "Back to the conversation".
  - "Ask" / "Ask about file" / "Add file" / "Copy patch" text buttons → the file header's More menu, each naming its file: "Comment on checkout_page.dart", "Add checkout_page.dart to the prompt", "Copy patch".
  - The selection bar's icon buttons and "Comment" → KitDiffView's selection bar (Comment primary, Add to prompt, Copy lines, Clear).
  - "Copied from review" and "Added … to the prompt" snack bars → KitCopy's "Copied" and the kit Undo bar (Undo takes the reference back off the prompt).
  - The comment sheet's Cancel → removed (the sheet's Close at the end does it, and nothing typed is lost).
- Map items (EVID-11):
  - review-workspace statesMissing: "loading skeleton (spinner)" → done: skeleton (`KitDiffView(loading: true)`), `review_workspace_test.dart` "a read slower than 8 s…" (first half); "binary / renamed / huge file" → done by the kit (KitDiffView states binary, renamed, too-big; the host passes status and binary through `_kitFileOf`); "all files viewed: a finished moment + 'send comments'" → done: `review_handoff_test.dart` "every file seen with notes waiting offers the way back", golden `review_all_viewed_*`; "slow diff >8 s" → done: "a read slower than 8 s says so and offers Try again", golden `review_slow_*`.
  - review-workspace actionsMissing: "one 'next change' across files" → done: "renders one KitDiffView with one "Change 1 of N" navigator across files"; "send all comments at once" → done as far as this page can: notes stage on the prompt and the finished moment returns to the conversation, where one send carries them all; "revert one file or hunk" → deferred (wave 3; needs a gateway revert call; DATA-11 confirm); "open the full file" → deferred (wave 3, slice-P3.7a / Files viewer hand-off; KitDiffView has no hook).
  - review-workspace infoMissing: "hunk as 'Lines 41-52'" → done by the kit ("Lines 12–22" rows); "folder on the phone file strip" → done (the picker lists full paths; the single-file header shows the folder); "which message made the change" → deferred (no data on FileDiff; no owner).
  - review-workspace elements: scope picker → KitSegmented (full width, start-aligned, check mark, words underneath); refresh banner → KitNotice with the reason and Try again; empty/error → KitStateView (error has its reason, verticals honest-state); motion timings → kit (no literal durations left).
  - review-comment-sheet statesMissing: "discard guard with text" and "draft restored on reopen" → done by keeping the draft instead of asking (map `couldBeAutomatic: keep the draft per file`): `review_workspace_test.dart` group "the comment sheet keeps what was typed" (swipe, reopen review, on disk with a profile). actionsMissing: "recover a comment lost to a swipe" → done (same tests); "send now" → deferred (wave 3: the review has no send path of its own; it hands off to the composer). infoMissing: "the selected lines as a quote" → done: "a comment on selected lines quotes them", golden `review_comment_sheet_*`. Elements: field placeholder named OpenCode → agent-neutral hint "What should the agent check or change?"; dialog cluster → one full-width pinned "Add comment to prompt" that says why it waits ("Type a comment first.").
- States per page (STATE-20):
  - review-workspace: loading → skeleton (`review-loading`); slow → golden `review_slow_*`; error → golden `review_error_*`, test "an error says why…"; empty → golden `review_empty_*`; loaded → goldens `review_loaded_*` (phone, 1280x800 split + file list); refresh failed over content → test "a failed refresh keeps the diff and says why"; selecting → golden `review_selecting_*`; staged → handoff tests; finished → golden `review_all_viewed_*`; not answering → the loader's error ("OpenCode is reconnecting.") shows as the error state.
  - review-comment-sheet: empty (primary disabled with reason), typed, quoted lines → golden `review_comment_sheet_*`, tests above.
- Deferred states (STATE-21): none beyond the map items above.

## 2. Builds

- Branch `revamp/screen-review-1`, base `9007257d` (feat/phone-setup-v2), code head: see `git log` (commits "feat(review): rebuild Review changes…" and "test(review): goldens…").
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/review_workspace_test.dart` | passes | 17 passed | PASS |
| 2 | `test/review_handoff_test.dart` | passes | 19 passed | PASS |
| 3 | `test/revamp/screen_review_1_golden_test.dart --update-goldens` | renders 16 | 16 passed | PASS |
| 4 | `test/kit_ratchet_test.dart` with `KIT_RATCHET_WRITE=1` (baseline restored after) | no row left for review_workspace.dart in any gate | 0 rows | PASS |
| 5 | `flutter analyze` on the changed lib, l10n and test files | no issues | no issues | PASS |

Not run (owner decision 2026-09-27, speed): the rest of the suite, design-standard, l10n, glossary and ledger tests.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | KIT-34 | `test/review_handoff_test.dart` "selected lines stage on the prompt, with Undo" (no SnackBar, `review-staged-undo`, Undo removes it) | run 2 |
  | DATA-1 / DATA-2 | `test/review_workspace_test.dart` "through typing, a swipe away and opening it again", "across closing and opening review again", "on disk under the profile when the profile is known" (`oc.draft.review.chat-1.lib/a.dart.p1`) | run 1 |
  | STATE-8 | "through typing…" ("Type a comment first." under the disabled primary) | run 1 |
  | STATE-3 | "an error says why and Try again leads to the empty state" | run 1 |
  | KitDiffView navigator | "renders one KitDiffView with one "Change 1 of N" navigator across files" | run 1 |

- Changed test expectations (TEST-19): `test/review_workspace_test.dart` and the widget group of `test/review_handoff_test.dart` were rewritten: the keys of the retired canvas (`review-line-<n>`, `review-file-<n>`, `review-mode-*`, `review-phone-toolbar`, `review-hunk-bar*`, `review-selection-*`, `review-staged-count`, `review-comment-action`) became KitDiffView's (`review-line-<file>-<side>-<n>`, `review-nav-*`, `review-file-header-<path>`, `review-selection-bar`) and the file menu keys (`review-file-comment`, `review-add-file`, `review-copy-patch`); the hunk-staging test became a line-selection test (contract problem 2); line text is asserted without its `+`/`-` (the kit draws the glyph in its own column); "viewed" follows the navigator instead of the file strip; the old 44 dp mode-button and toolbar-fit tests went with those controls, replaced by the 320 dp × 2.0 text fit test and the kit's own target rules.
- Goldens added (each opened and looked at, as contact sheets): 16 `test/revamp/goldens/review_{loaded,loaded_1280x800,selecting,comment_sheet,all_viewed,error,empty,slow}_{dark,light}.png`. Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Confirm.png` for the comment sheet (icon tile, start-aligned title, subtitle, full-width pinned primary: match); `Settings.png` for the segmented control and notices on the ground (match); the diff itself is KitDiffView's own look (its unit's galleries). Difference: on 1280x800 the view picker spans the full width (KitSegmented is full width by its contract).
- Before and after (EVID-10): `before-review-workspace-{loaded,empty,error}.png` and `before-review-comment-sheet.png` from `docs/qa/screen-census/f-files-review-terminal/`; `after-*.png` from the new goldens (dark), plus `after-review-workspace-loaded-1280x800.png`.
- Accessibility: every icon-only control is a kit `KitIconButton` with a label (navigator, Wrap, More, Clear); the file menu items and sheet title name the file; the disabled primary says why in visible text; the view picker has a group name ("Changes to show"); the 320 dp × 2.0 text test passes; the diff's line semantics ("Line 16 added: …") come from the kit.
- Privacy and security: the comment draft is stored under `oc.draft.review.<session>.<path>.<profileId>` (KitDraft), so `ProfileStore.profileScopedPreferenceKeys` sweeps it with the profile; without a profile id it is only in memory. Copies are verbatim through KitCopy (SEC-13: the person's own code); the staged snippet is the kit's redacted selection text. No links, credentials or notifications changed.
- Migration: n/a: no stored format changed (a new draft key only).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/review_workspace_test.dart test/review_handoff_test.dart
$F test -j 1 test/revamp/screen_review_1_golden_test.dart
$F analyze lib/ui/screens/review_workspace.dart test/review_workspace_test.dart test/review_handoff_test.dart test/revamp/screen_review_1_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests not run; likely affected (for the integrator): `test/product_ui_regression_test.dart` (taps "Ask about file", now "Comment on README.md" in the file header's More menu), `test/chat_live_events_test.dart` (~l.1797: `review-mode-split`, `review-line-2`, `review-comment-action`), `test/reader_preferences_test.dart` "review remains reachable in RTL large text…" (old line keys and capture), `test/teaching_empty_states_test.dart` (keys `review-empty`/`review-error` kept; the error body is now the reason, not `error.toString()`), `tool/capture/census/areas/f_files_review_terminal.dart` (old keys), `test/design_standard_test.dart` (`_migrated` entry for review_workspace.dart), `test/kit_ratchet_baseline.json` and the l10n coverage baseline (counts dropped to zero).
- The hunk-as-a-whole selection is not offered (contract problem 2).
- Viewed tracking relies on KitDiffView calling `fileActions` when its header draws (contract problem 1).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-review-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
