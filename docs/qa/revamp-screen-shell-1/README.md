# revamp-screen-shell-1: Revamp shell (5 files) (2026-09-27)

## 1. Scope

- Unit: `screen-shell-1` (wave 2b, screen-revamp, tier 1). Finish line: every file in the write set has G1, G16, G7 and look (G17/G21) counts of zero, the Inbox is `KitScreen.twoPane` from expanded, Claude Code in search explains its gate, and each page is handled by its map proposal. Non-goal: no gateway call, controller field or persistence added; behaviour planned for wave 3 (other servers as rows, answered-elsewhere notices) stays out.
- Files changed:
  - `lib/ui/screens/activity_screen.dart` (rebuilt from kit parts; Inbox, question sheet)
  - `lib/ui/search/search_index.dart` (kit routes and sheet; Claude Code gate entry)
  - `lib/ui/desktop/context_menu.dart` (forwarders to the kit menu and `KitContextRegion`)
  - `lib/ui/desktop/desktop_interaction.dart` (scroll classes forward to `KitScrollbar`; selection forwards to `KitSelectable`; unused `ClickCursor` removed)
  - `lib/ui/desktop/file_drop.dart` (kit alert and kit surface overlay; label localised)
  - new: `lib/ui/kit/kit_scrollbar.dart`, `lib/ui/kit/kit_context_region.dart`
  - `lib/l10n/app_en.arb` (21 new keys, English only per the owner decision of 2026-09-27)
  - tests: `test/activity_screen_test.dart`, `test/activity_requests_test.dart`, `test/completion_digest_capture_test.dart`, `test/request_sheet_lifecycle_test.dart`, new `test/revamp/screen_shell_1_test.dart`, new `test/revamp/screen_shell_1_golden_test.dart` and 16 PNGs in `test/revamp/goldens/`.
- Pages (map ids): activity, embedded-context-menu-region, embedded-desktop-file-drop-target, file-drop-failed-dialog, question-sheet, question-sheet-dismiss-dialog, settings-transcript-display-sheet.
- Specs followed: STANDARDS.md §1.1, §4 (KIT-1, KIT-2, KIT-6, KIT-11, KIT-15, KIT-16, KIT-20, KIT-25, KIT-27, KIT-28, KIT-33, KIT-34, KIT-43), §5 (LOOK-1, LOOK-2, LOOK-5, LOOK-12, LOOK-21, LOOK-24), §6 (LAY-5, LAY-6, LAY-7, LAY-8, LAY-12), §9 (STATE-8, STATE-20, STATE-21), DATA-11, MAP-1; kit-api KitScreen.md (twoPane), KitScrollbar.md, KitMenu.md, KitRequestCard.md, KitSheet.md, KitDialog.md.
- Contract problems (PROC-20):
  1. KitScrollbar.md says its unit removes the G16 `Scrollbar` exception in `test/kit_ratchet_test.dart` and adds G2 patterns for the retired names. That test file is shared (R10/R05), so this unit did not edit it. Proposed: the integrator removes `_scrollbarHome` and adds `AppScrollBehavior(`, `DesktopScrollbarArea(`, `OwnScrollbar(`, `DesktopSelectionArea(`, `ContextMenuRegion(`, `ContextMenuAction(`, `showContextMenu(` to `_retiredApis` with `ratchet-tighten: G16 Scrollbar` in the commit body. Blocks nothing.
  2. `showKitSheet` takes a fixed `primary`, so a sheet whose Send enables as the person answers cannot keep it pinned. The question sheet puts its `KitActionBlock` at the end of the body instead (it scrolls with the body). Proposed: a `ValueListenable<KitAction?>` for `showKitSheet(primary:)` in a KitSheet change. Blocks KIT-17 "pinned actions" for this one sheet.
  3. KIT-43 says old names are kept "never @Deprecated"; the task text says "@Deprecated wrappers". KIT-43 was followed: forwarders are marked `Retired by screen-shell-1: use …` in their doc comments.
- New kit parts (KIT-3):
  - `KitScrollbar` (`lib/ui/kit/kit_scrollbar.dart`): `KitScrollBehavior`, `KitScrollArea`, `KitScrollbar`, `KitOwnScrollbar`, built to the frozen KitScrollbar.md API (the spec's unit was never cut). Not added to `kit.dart` (R06); the integrator adds the export row.
  - `KitContextRegion` (`lib/ui/kit/kit_context_region.dart`): the desktop right-click/Shift+F10/Menu-key region moved out of `context_menu.dart` under R12 so that file reaches G16 zero; it opens `showKitMenu`. No frozen contract exists: coordinator to confirm or fold it into `KitTappable`/`KitRow.menu` when the seven callers move.
- Map items (EVID-11):
  - activity: proposal fix → kit rebuild (golden `shell_activity_*`); actionsMissing "answer a simple permission inline (Allow once)" → done: trailing Allow once on each permission row and Allow once / Reject on the detail-pane card (`screen_shell_1_test.dart` "a permission row allows once without a sheet", "from expanded the pick is answered in the detail pane"); "undo a dismissed digest" → done (`"a hidden digest comes back with Undo"`); "other servers' requests as rows" → deferred: `ProfileMonitorInbox` lives in `profile_monitor_screen.dart` (not this write set), owner screen unit for that file / slice of target-ia §1.2. Rationale "Finished while you were away" → done (section renamed). C37 twoPane → done.
  - question-sheet: proposal fix → kit sheet with `KitChoiceList`, `KitField` "Or write your own answer", full-width Send with its reason while disabled; actionsMissing "open the conversation for context first" → done ("Open conversation" when the caller can open it). statesMissing "send fails: no inline error" → done (`KitNotice.error` with Try again); "multi-prompt question: no progress" → done ("Question 1 of 3" captions); "server lost while answering" → done as far as detectable (Send disabled with "Reconnect to the server to answer." when no gateway). infoMissing "why Send is disabled" → done.
  - question-sheet-dismiss-dialog: merge-into:confirm-sheet (slice-P3.11a) → already `showKitConfirm`; inside the kit sheet it replaces the content in place (KIT-16). "Undo after dismissing" not added: dismissing is a server act with no inverse, so it is confirmed (DATA-11).
  - settings-transcript-display-sheet: merge-into:settings (slice-P3.10) → kit-only with the least change (`showKitSheet`), comment `// revamp: merge-into:settings (slice-P3.10)` above it.
  - embedded-context-menu-region: keep → kit menu (golden `kit_context_region_open_*`); "drop the outline": the menu is the kit menu, the region keeps only the 2 px kit focus ring (LAY-10).
  - embedded-desktop-file-drop-target: keep → kit surface overlay with a localised "Drop to attach"; "hide it when the server takes no attachments" was already done by the caller (`chat_screen.dart` `_composerDropTarget` checks `_supportsPromptAttachments`).
  - file-drop-failed-dialog: keep → `showKitAlert` (test "a failed drop says so in the kit alert, never the error").
- States per page (STATE-20):
  - activity: loading (`KitSkeletonRows` + the one loading bar), empty all-clear (golden `shell_activity_empty_*`), status unknown (owned test `activity_screen_test.dart`), error-empty (`KitStateView.error`, owned test "failed pending check never shows all clear"), refresh failed with rows (`KitNotice.error`), waiting (golden `shell_activity_waiting_*`), not answering (running rows "Last seen running", test), two panes picked (golden `shell_activity_picked_1280x800_*`), digests open (owned tests).
  - question-sheet: unanswered (golden), choice made / sending / failed (owned tests `activity_requests_test.dart`, `request_sheet_lifecycle_test.dart`), answered elsewhere closes (lifecycle test), no server (test).
  - file-drop-failed-dialog: shown (test). Others: states of their hosts.
- Deferred states (STATE-21):
  - activity "request answered on another device disappears without a word" → needs a per-request answered-elsewhere signal from the controller; owner: no owner.
  - activity "other servers not checked yet shows '1 unknown'" → lives in `ProfileMonitorInbox` (`profile_monitor_screen.dart`); owner: that file's screen unit.
  - file-drop-failed-dialog "some files attached and some failed", infoMissing "which files and why" → needs the drop handler (`chat_screen.dart`) to report per-file results; owner: chat unit.
  - activity infoMissing "how long each request has waited" → permissions, questions and forms carry no timestamp; no owner.

## 2. Builds

- Branch `revamp/screen-shell-1`, base `8dc27c66`, code head: see `git log`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_shell_1_test.dart` | passes | 15 passed | PASS |
| 2 | `test/revamp/screen_shell_1_golden_test.dart --update-goldens`, then each PNG opened | 16 renders | 14 tests, 16 PNGs looked at | PASS |
| 3 | owned tests `activity_screen_test`, `activity_requests_test`, `request_sheet_lifecycle_test`, `completion_digest_capture_test` | pass | 18 + 7 passed, 1 skipped (capture test needs a capture dir) | PASS |
| 4 | `test/kit_ratchet_test.dart` (read only for this unit's counts) | this unit's files at zero | every G1/G16/G2/G17/G21 entry of the five files dropped to 0; the two failing rows are pre-existing on the base (`quota_monitor_section.dart`, and kit files from other units) | PASS for this unit |
| 5 | `flutter analyze lib test` | no issues in changed paths | 1 pre-existing info in `test/goldens/kit/kit_tappable_golden_test.dart` | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | LAY-5 / C37 | `test/revamp/screen_shell_1_test.dart` "from expanded the pick is answered in the detail pane" | run 1 |
  | P7.4 | `test/revamp/screen_shell_1_test.dart` "Claude Code explains its gate where Termux is missing", "opening it says why and where Claude Code runs" | run 1 |
  | STATE-8 | "Send says why it cannot send until every prompt is answered" | run 1 |
  | DATA-11 | "a hidden digest comes back with Undo" | run 1 |
  | SEC (no exception text) | "a failed drop says so in the kit alert, never the error" | run 1 |
  | KIT-6 | "KitScrollArea hands a controller and pins one thumb", "KitScrollbar keeps one thumb over its own box" | run 1 |

- Changed test expectations (TEST-19):
  - `activity_screen_test.dart`: subagent count is now words in the running row's line ("1 subagent", not a badge "1"); the digest section explains itself while folded and is named "Finished while you were away" (map rationale).
  - `activity_requests_test.dart`: selection is read from `KitChoiceRow` instead of `QuestionOptionRow`; Send and Dismiss are found by key (kit buttons); the own-answer field is "Or write your own answer" (map proposal).
  - `request_sheet_lifecycle_test.dart`: rows tapped by title instead of `ListTile`; Send/Dismiss by key.
  - `completion_digest_capture_test.dart`: section title.
- Goldens added (each opened and looked at), in `test/revamp/goldens/`:
  - `shell_activity_waiting_{dark,light}`: Needs attention panel (permission with Allow once, question), Running with "Running · oc_app · 1 subagent", Finished while you were away.
  - `shell_activity_picked_1280x800_{dark,light}`: list pane 296 with the picked question selected; the question answered in the detail pane.
  - `shell_activity_empty_{dark,light}`: all clear with the tray drawing.
  - `shell_question_sheet_unanswered_{dark,light}`: kit sheet, choices, own answer, disabled Send with "Answer every question first.", Open conversation, Dismiss.
  - `shell_search_claude_code_gate_1280x800_{dark,light}`: the kit alert explaining the gate with "Open servers".
  - `kit_context_region_open_1280x800_{dark,light}`: the kit menu at the pointer, destructive item last after a divider.
  - `kit_scrollbar_default_1280x800_{dark,light}`: pinned thumb on a desktop list.
  - Approved renders (EVID-12): compared by eye with `docs/design/visual-language-2026-09-26/` Main and Desktop: surface1 panels, 16 dp gutter, icon tiles, sentence-case section labels; the `Saved servers` row belongs to `ProfileMonitorInbox` (not this write set) and is not yet in the VL look.
- Accessibility: every icon-only control is a labelled `KitIconButton` (Allow once); disabled Send carries its reason as visible text and semantic hint; running state is a word as well as a mark; the question field has a visible label.
- Privacy and security: the drop failure never shows exception text (test); no credentials, stored data or links changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/revamp/screen_shell_1_test.dart test/revamp/screen_shell_1_golden_test.dart
$F test -j 1 test/activity_screen_test.dart test/activity_requests_test.dart test/request_sheet_lifecycle_test.dart test/completion_digest_capture_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared consumers were not run (owner decision 2026-09-27): `home_navigation_test`, `team_activity_test`, `background_discoverability_test`, `v2_feature_gating_test`, `desktop_context_menu_test`, `desktop_file_drop_test`, `desktop_scrollbar_test`, `desktop_pointer_test`, `search_index_test`, `background_notification_navigation_test`, `release_blockers_test`, `accessibility_guidelines_test`, `text_scale_overflow_test`, `design_standard_test`.
- No overflow pump at every LAY-4 size for the Inbox; only 412×915 and 1280×800 renders.
- The drag-over overlay of the file drop target is not rendered (it needs the plugin's drag events).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-shell-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
