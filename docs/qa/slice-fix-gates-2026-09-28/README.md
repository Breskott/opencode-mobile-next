# slice-fix-gates (2026-09-28)

Test-failure repair for the repository gates, shell, theme, settings shell
and kit (not glass). Worktree `oc_app-slice-fix-gates`, branch
`revamp/slice-fix-gates`, base `bb9261ad` (full-suite failures recorded at
`7954e980`).

## Verdicts

| Test | Verdict | Fix |
|---|---|---|
| `analyzer_suppressions_test` G26 | GATE: offending code | 5 new suppressions removed, none added to the baseline. `kit_choice_list_test` had an unneeded `ignore_for_file`. `kit_glass_test` and `team_controls_test` now use `debugPrint` instead of `// ignore: avoid_print` + `print`. `kit_top_bar_test` had a stray ignore. `tool/capture/bugfix_nonchat_test` now sets the public `SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty()` instead of test-only `setMockInitialValues`. |
| `gesture_audit_test` (evidence past end of file) | GATE: inventory | 9 rows were stale. 4 gestures no longer exist, so their ledger element and audit row are gone: command sheet pull-to-refresh (P10.1 `34353c2f`), chat title tooltip, work-graph pinch/pan (KitWorkGraph has none), and the voice sheet dismiss (voice sheet retired, P10.3 `3273d7ef`). 5 rows now cite current evidence: chat Ctrl+F, the command refresh callback, the graph node tap, the commands open-chat follow-up and the board card long press. One new row covers the MCP catalogue's pull to refresh. The `.md` twin is updated to match. |
| `ui_ledger_coverage_test` (2) | GATE: inventory | Parts rebuilt with `build_ledger.py`. **Removed pages:** `profile-monitor` (Background checks; `ProfileMonitorScreen` was deleted in slice-close-misc `d0047ca3`, along with the Servers row `servers-background-checks`). The switch-server question stays, reached from the Inbox rows, the other-servers panel and notifications. Also removed: `embedded-team-cycle-strip`, `team-cycle-how-sheet` and `team-cycle-stop-confirm-sheet` (replaced by the team's Now line, P5.1 `e5148e4a`, added as `embedded-team-now-line`), and `voice-composer-sheet` (P10.3; voice edges now say dictation lands in the draft). Pages with moved files: `confirm-sheet` → `kit_confirm_sheet.dart`/`showKitConfirm`; `diff-view` → `DiffPage` in `review_workspace.dart`. **Added pages:** `mcp-add-sheet`, `mcp-catalog`, `mcp-catalog-node-sheet` and `mcp-catalog-remove-sheet` (P2.4/P2.5 `5e14dba4`); `ai-setup` (`6962eb0b`) with its Server settings row. Deleted-file `notPages` were dropped. |
| `golden_harness_test` G23 | GATE: harness fix, no pixels | **androidPlatform (30 files):** `debugDefaultTargetPlatformOverride = TargetPlatform.android` is set before each render and reset in `finally`; the test host's default is already Android, so pixels are unchanged. **regenerateHeader (10 files):** the standard TEST-7 header. **goldenNames:** 126 PNGs renamed with `git mv`, and the name builders changed to match (map in `golden-renames.txt`, 132 moves including set-consistency ones). Baseline shrank: trackedFailures 24→0, goldenNames −2, arabicFont 1→0. |
| `golden_harness_test` baselined, for the reviewed refresh | GATE: justified entries (`ratchet-tighten`) | `screen_shell_1_golden_test` renders its desktop shots as `TargetPlatform.linux` (`24adc02d`); switching to Android changes pixels. `aisetup_oc1_all_settings_412x2300_{dark,light}` uses a non-gallery size; a gallery size changes pixels. |
| `repository_hygiene_test` TEST-12 | GATE: inventory | The failure PNGs are no longer tracked: the baseline list is empty and `_test12Ceiling` is 0. |
| `repository_hygiene_test` notices | GATE: inventory | `THIRD_PARTY_NOTICES.md` is updated for the intended upgrades: dio 5.11.1 (`87403c3c`), flutter_secure_storage 11.2.0 and platform_interface 2.1.1 (`c96b0998`). |
| `kit_status_line_golden_test` error · dark/light (G5) | PRODUCT BUG (kit) | A screen reader read "Try again" before the message. More spans both rows of a stacked line, and the inset action starts further left. Since `8c30b7bc` made KitIconButton a semantics container, the geometric order put the action first. Fix: when the line is stacked with its controls apart, it orders message → More → Dismiss → action with `OrdinalSortKey`. The wrappers are always present, so the elements stay the same. Pixels unchanged. |
| `kit_motion_app_test` working button (2) | PRODUCT BUG (kit) | Since `77cc154f`, the in-flight Semantics wrapper appeared only while working. That rebuilt the whole button, so the icon no longer crossfaded and the width jumped. Fix: the wrapper is always there and empty when idle. |
| `product_ui_regression_test` stale terminal create | PRODUCT BUG (kit) | `KitPressTracker` (`1647f3a4`) made a Listener KitButton's outermost render object. `getSemantics(find.byKey(button))` then resolved to the parent node (TEST-1/TEST-5 tooling). Fix: `MergeSemantics` around KitButton, so the button's element maps to its own node. A screen reader still hears the same single button. |
| `shared_settings_1` Arabic share | PRODUCT BUG | The language sheet claimed 90 % Arabic. The real share is 62 % since Arabic was dropped (owner, 2026-09-27). `arabicTranslatedPercent` = 62. The language-sheet golden text changes: this is **pixel work for the reviewed refresh** (`settings_language_sheet_loaded_*`). |
| `shared_settings_1` theme preview Apply | STALE TEST | Apply is the last item in the preview sheet's scrolling body (`appearance_picker.dart`, `063f4741`). On the 800x600 test window it is below the fold. The test now brings it into view before tapping. |
| `theme_packs_test` (2) | STALE TEST | The theme preview sheet (`063f4741`) shows a live working mark, so `pumpAndSettle` never settles. The tests now use reduced motion, as `shared_settings_1` already does, and `ensureVisible` for Apply (built but off-screen). They close the Undo window that Apply now offers. |
| `shared_shell_1` connection banner (4) | STALE TEST | `3d64653c` made the line present the controller's `connectionStatus` snapshot. An isolated controller is hidden, and "Connection lost" became "{server} isn't answering". The fake now supplies a not-answering snapshot. The assertions are unchanged apart from that wording. |

Counts: PRODUCT BUG 5 (4 kit + 1 settings). STALE TEST 3 files (7 tests). GATE/INVENTORY 7 gate tests.

## Checks run (pinned Flutter 3.47.1, `tool/qa/machine_lock.sh`)

- My files, after the fixes: all pass except `golden_harness_test` "baseline
  only shrinks". That check fails until this commit lands, because it carries
  the `ratchet-tighten` trailers.
- Required gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text,
  kit_manifest, kit_draft_manifest and architecture_boundaries all pass.
- `flutter analyze` on the whole project: no issues.
- The 50 changed golden and test files were run once. Remaining failures are
  pixel diffs (the reviewed refresh), plus these that were already failing and
  belong to other lanes:
  - `chat_states_golden_test` disconnected ×2
  - `screen_phone_1_golden_test` start fresh
  - `shared_team_2_test` clipboard
  - `team_controls_test` start a run

  None comes from missing goldens or the platform override.
- Base comparison (`bb9261ad` worktree): `kit_action_golden_test` disabled ·
  dark ×2 and `kit_icon_button_golden_test` disabled · dark fail the same way
  on base. They are existing pixel diffs.

## Left for the reviewed refresh

- `settings_language_sheet_loaded_*` (Arabic share now 62 %).
- `screen_shell_1` desktop shots rendered as Linux (ARCH-11).
- `aisetup_oc1_all_settings_412x2300_*` (non-gallery size).
- Possible UX follow-up, not changed here: the theme preview's Apply is not
  pinned, so on a short landscape window the person scrolls to reach it.
- `tool/qa/check_ui_ledger.py` still reports stale element line numbers in
  chat and team parts. `ui_ledger_coverage_test` does not check them.
