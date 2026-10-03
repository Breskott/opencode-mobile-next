# revamp-shared-chat-1: Revamp chat, model sheet, handoff sheets, transcript toggles (2026-09-27)

## 1. Scope

- Unit: `shared-chat-1` (wave 2a, tier 1, screen-revamp). Finish line: every
  file in the write set has a G1/G16/G7/G2/G17/G21 count of zero, is built
  from kit parts in the visual-language look, and each page is handled by its
  map proposal. Non-goal: no gateway call, controller field or persistence is
  added; callers outside the write set (chat screen, session menu, command
  launcher) are not changed.
- Files changed: `lib/ui/widgets/pickers.dart`,
  `lib/ui/widgets/session_handoff_sheets.dart`,
  `lib/ui/widgets/transcript_display_toggles.dart`, `lib/l10n/app_en.arb` (+
  generated `app_localizations*.dart`), tests
  `test/revamp/shared_chat_1_test.dart`,
  `test/revamp/shared_chat_1_golden_test.dart` (+ 22 goldens under
  `test/revamp/goldens/chat_*`), `test/session_handoff_sheet_layout_test.dart`,
  `test/session_selection_sync_test.dart`, `test/v2_transcript_rows_test.dart`,
  and the census guard registry `tool/capture/census/areas/j1_settings_more.dart`
  (PROC-13: two guards of merged pages).
- Pages (map ids): continue-on-computer-sheet, continue-on-phone-sheet,
  embedded-transcript-display-toggles, model-picker-sheet,
  model-picker-sheet-agent-dialog, model-picker-sheet-options-dialog,
  model-picker-sheet-unloaded-providers-dialog.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-16
  (no sheet on a sheet: every former dialog is now in-place), KIT-20, KIT-22,
  KIT-23, KIT-24, KIT-25, KIT-27, KIT-32, KIT-33, KIT-43, LOOK-1, LOOK-4,
  LOOK-5, LOOK-12, LOOK-15, LOOK-21, MAP-1, STATE-8, COPY-8; kit-v2 §1.1, §1.5,
  §1.6, §1.7, §9.1; visual-language §5 (sheets, rows).
- Contract problems (PROC-20):
  1. **showKitSheet primary is fixed at open** (kit_sheet.dart, `primary:
     KitAction?`). The model sheet's pinned "Use …" action cannot show its
     disabled reason or working state from the body, so in the no-models and
     catalog-failed states it stays pressable (it then says "Choose a model
     first." in the body) and the in-flight save shows as the sheet's loading
     bar. Proposed: `primary` also accepts a `ValueListenable<KitAction?>`.
     Blocks nothing.
  2. **KitSheet body is always a SingleChildScrollView** (no virtualised
     body). The model list therefore shows 60 rows and grows with "Show N
     more models" instead of the old `ListView.builder`. Proposed: a
     `KitSheet` sliver/list body mode. Blocks nothing.
  3. **KitSheet header does not scroll at 2.5x text**: on 320x760 with the
     host's 85 % cap the frame's header overflows. The handoff layout test
     used 2.5x; it now runs at 2x, the kit's stated maximum (KIT-17 says
     200 %). Proposed: header scrolls with the body above 2x.
  4. The task names `docs/qa/revamp-<unit id>/README.md`; EVID-1 and the
     sibling records add the date. This record follows EVID-1.
  5. R04 asks for `app_ar.arb` entries; the owner decision of 2026-09-27
     (later) dropped Arabic, so new copy is in `app_en.arb` only.
- New kit parts (KIT-3): none.
- Moved or removed (owner rethink rule 2026-09-27):
  - Options dialog: removed. The chosen model's row unfolds in place into its
    details in words (context, answer length, can think / use tools / read
    attachments, price) with the id under Details (copyable).
  - Agent dialog: removed (it was unreachable: no caller passes focusAgent).
    Agent is chosen in place under "Your choice" with one-line descriptions;
    `focusAgent` now opens with that choice unfolded.
  - Duplicate agent dropdown in the options dialog: removed (one place).
  - Unloaded-providers dialog: removed. The explanation and a "Reload
    providers" action sit in the notice.
  - Provider dropdown, capability chips and the Filters toggle: moved into
    the search field's Filter menu (active filter shown as a removable chip).
  - Footer summary ("Default mode · build" + Options): removed; "Your choice"
    group on top says the same with actions.
  - Refresh: moved beside the "N models" section label.
  - Two-letter provider tiles: removed (a11y); the provider is named in the
    row's supporting line.
  - Handoff: the version note moved under Details; "Export conversation" is
    the pinned sheet action; the "Link copied" snackbar is replaced by the
    kit copy check.
  - Transcript toggles: the supporting line no longer flips with the switch;
    it says what "on" does, and a line says the switches are app-wide.
- Map items (EVID-11):
  - continue-on-computer-sheet: actionsMissing "Reload on the unavailable
    state" → done in the sheet (`offerReload`, pops `'reload'`): test
    `shared_chat_1_test.dart` "a missing folder offers Reload…"; wiring the
    host (chat screen passes `offerReload: true` and reloads) → deferred to
    the chat screen owner (no owner in this wave). Rationale "absorbs the
    handoff dialog" → `session-handoff-dialog` is not in this write set: no
    owner.
  - continue-on-phone-sheet: statesMissing "other phone lacks the server" →
    done: the server note, test `session_handoff_sheet_layout_test.dart`
    "continue on phone stays reachable", golden
    `chat_continue_on_phone_sheet_qr_*`.
  - embedded-transcript-display-toggles: infoMissing "per conversation or
    app-wide" → done: test "say what on does, flip in place, and name their
    scope". Rationale "keep one visible home" (/thinking, /timestamps) →
    deferred to slice-P3.10 (merge-into:settings noted in search_index.dart).
  - model-picker-sheet: statesMissing "no provider signed in" → done (test
    "no models leads to signing in", golden `…_no_models_*`); "empty
    Favorites/Recent copy" → done (existing copy in a KitStateView);
    "basic-catalog notice over rows with context" → done (test "the
    basic-catalog notice shows only when details are missing").
    actionsMissing "pick the agent in the sheet" → done (test "the agent is
    chosen in the sheet, in words"); "sign in to a provider from here" →
    done (Open providers → IntegrationsScreen providers mode). infoMissing
    "one-line strengths or price" and "what mode and agent mean" → done
    (details lines, explanations under Thinking and Agent; test "details and
    thinking unfold in place"). couldBeAutomatic "reload providers
    automatically once after sign-in" and "default to the last used or a
    recommended model" → no owner (controller behaviour, not wave 2).
  - model-picker-sheet-unloaded-providers-dialog (merge-into): statesMissing
    "reloading" → done (the Reload action's working state); "reload failed"
    → shown by the catalog-failed state; actionsMissing "Reload providers" →
    done (test "unloaded providers explain in place and offer Reload").
  - model-picker-sheet-agent-dialog (merge-into): statesMissing "what each
    agent does" → done.
  - model-picker-sheet-options-dialog (merge-into): actionsMissing "copy
    model id" → done (Details fold copy and the row menu "Copy model id").
- States per page (STATE-20): model sheet: loaded (golden `…_loaded_*`),
  details (golden `…_details_*`), empty (golden `…_no_models_*`), error
  (golden `…_failed_*`), loading (KitSkeletonRows, code only), applying
  (sheet loading bar, code only); continue on computer: available,
  unavailable (goldens); continue on phone: qr (golden), unavailable (test);
  transcript toggles: default (golden).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/shared-chat-1`, base `b24addac`, code head `fa9fc679`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2
checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a | n/a: new behaviour, no bug fix | PASS |
| 2 | `test/revamp/shared_chat_1_test.dart` | passes | 14 passed | PASS |
| 3 | `test/revamp/shared_chat_1_golden_test.dart` | passes | 22 passed (regenerated once, looked at) | PASS |
| 4 | `test/session_handoff_sheet_layout_test.dart`, `test/session_selection_sync_test.dart` | pass | 20 passed | PASS |
| 5 | `test/v2_transcript_rows_test.dart`, `test/model_presentation_new_test.dart`, `test/usage_labels_test.dart` | pass | all passed | PASS |
| 6 | `test/kit_ratchet_test.dart` (gate check only) | write-set files at 0; no rise from this unit | write-set counts all dropped to 0; G17 fails on `quota_monitor_section.dart` and G21 on several kit files, both already on the base, none in this unit's files | PASS (unit) |
| 7 | `flutter analyze lib test tool/capture` | no issues in changed paths | 8 pre-existing issues, none in changed paths | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | KIT-16 | `shared_chat_1_test.dart` "opens as one kit sheet with the choice on top" (no AlertDialog/Dialog) | run 2 |
  | KIT-23 | `session_handoff_sheet_layout_test.dart` "continue on computer stays reachable" (copy writes exactly the command) | run 4 |
  | STATE-8 | `shared_chat_1_test.dart` "a model without levels says so instead of a dead control" | run 2 |
  | MAP-1 | goldens `test/revamp/goldens/chat_model_picker_sheet_*` | run 3 |

- Changed test expectations (TEST-19):
  - `session_handoff_sheet_layout_test.dart`: `agent-command-block`/
    `agent-command-copy-0` → `continue-on-computer-command`/
    `continue-on-computer-copy`; plain `find.text` of the command/link →
    rich-text finder inside the code block (KIT-32: KitCodeBlock renders
    technical values); RTL variants removed (owner decision: no Arabic);
    2.5x → 2x (contract problem 3).
  - `session_selection_sync_test.dart`: options dialog + agent dropdown +
    Done → agent row unfolds in place and "Plan" is chosen (MAP-1
    merge-into); MaterialApp gains localization delegates (kit parts read
    AppLocalizations).
  - `v2_transcript_rows_test.dart`: the session scope note is visible
    without opening Options (MAP-1 merge-into); hosts gain localization
    delegates.
- Goldens added (each opened and looked at), all new under
  `test/revamp/goldens/`: `chat_model_picker_sheet_loaded_{dark,light}`,
  `…_loaded_1280x800_{dark,light}`, `chat_model_picker_sheet_details_*`,
  `chat_model_picker_sheet_no_models_*`, `chat_model_picker_sheet_failed_*`,
  `chat_continue_on_computer_sheet_available_*` (phone and 1280x800),
  `chat_continue_on_computer_sheet_unavailable_*`,
  `chat_continue_on_phone_sheet_qr_*` (phone and 1280x800),
  `chat_transcript_display_toggles_default_*`. Approved render
  `docs/design/visual-language-2026-09-26/Confirm.png` (sheet frame):
  differences: none in the frame (grabber, icon tile, start-aligned title,
  stacked full-width actions on the phone, end-aligned on 1280x800).
- Before and after (EVID-10), next to this README: `before-*.png` from the
  base census (`docs/qa/screen-census/...`), `after-*.png` from the new
  goldens (dark). The dialogs have no after image of their own: they are
  merged into `after-model-picker-sheet-details.png`.
- Accessibility: every icon-only control is a labelled KitIconButton (close,
  refresh, favourite "Favorite <model>", copy "Copy command"/"Copy link");
  choice rows are 56 dp radio rows; the sheet title names the route; the
  model row states "In use" and "New" in words; the handoff sheets pass at
  2x text on 320 dp; provider two-letter tiles are gone.
- Privacy and security: the QR and link still carry only the saved server's
  id and the session id; the link is copied through `KitCopy` (no
  snackbar). No credentials, stored data, links or notifications changed.
  Provider credentials are not read or shown.
- Migration: n/a: no stored format changed.
- Shared tests expected to break (not run, owner decision): see the build
  record's `sharedTestsBroken`: `test/model_picker_test.dart`,
  `test/chat_menu_hierarchy_test.dart`, `test/chat_live_events_test.dart`.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/shared_chat_1_test.dart test/revamp/shared_chat_1_golden_test.dart
$F test -j 1 test/session_handoff_sheet_layout_test.dart test/session_selection_sync_test.dart
$F test -j 1 test/v2_transcript_rows_test.dart test/model_presentation_new_test.dart test/usage_labels_test.dart
$F test -j 1 test/kit_ratchet_test.dart
$F analyze lib test tool/capture
```

## 7. NOT proven

- Not run on a device or emulator.
- The chat screen still opens the handoff sheets through its own
  `showModalBottomSheet` with the whole-sheet widgets (legacy route, drag
  handle drawn by Material); switching it to `showContinueOnComputerSheet`
  / `showContinueOnPhoneSheet` and passing `offerReload` is the chat
  screen owner's work.
- Shared tests listed above were not run; the full suite was not run.
- Performance of the non-virtualised model list beyond the 60-row page was
  not measured.
- The three merged dialogs keep their entries in
  `docs/design/ui-ledger/parts/j1-settings-more.json` and their census shots
  (whose guards now check the merged state). R09 allows this unit only to
  append to the parts file, so removing those ledger pages and shots is left
  to the integrator.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/shared-chat-1` |
| Enabled | Yes (no flag) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `fa9fc679` |
| Deployed | No | |
| Released | No | |
