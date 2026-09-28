# slice-fix-team — behaviour failures, team page group (2026-09-28)

Base: `feat/phone-setup-v2` @ `bb9261ad` (the failure list came from a full
run on `7954e980`). Branch `revamp/slice-fix-team`.

Scope: the 44 non-golden failures in 18 test files listed for this group in
`behaviour-failures.txt`. Golden pixel diffs are out of scope (a reviewed
refresh follows); they are named at the end.

Verdicts: **PRODUCT BUG** = the product was wrong, fixed in `lib/`, test
unchanged and failing before the fix. **STALE TEST** = the test asserted
behaviour an intentional 26–28 Sept change replaced (commit cited), or a
test-harness defect the change exposed; the test now asserts the new
behaviour, with no coverage dropped.

## Team, library and tools (7 files, 19 tests)

| Test | Verdict | Why / fix | Cited |
|---|---|---|---|
| team_plugins_screen: host kind "offers three kinds with Desktop computer preselected" | STALE | The kind-of-computer question left the host form ("the kind-of-computer question is gone"). Now: "the form asks no kind; a new host is a Desktop computer" (no label, hint or chips; saved kind is `pc`). | 19640c8b |
| team_plugins_screen: host kind pc / laptop / wsl "persists into the config" (3) | STALE | No chips to tap. Now each saved kind persists through Change address: form shows no kind question, re-test at a new address keeps the kind in the controller and in `ProfileStore`, page is the team's. | 19640c8b |
| team_plugins_screen: "Change reopens the form with the saved kind" | STALE | Folded into the three per-kind Change address tests above (the saved kind is carried, not shown). | 19640c8b |
| team_plugins_screen: "a host that reports a phone keeps the phone kind" | STALE | Same assertion, without tapping the removed laptop chip. | 19640c8b |
| team_controls: "start a run sends objective + supervision to the Mayor, shows Planning, resolves" | STALE (test defect) | The planning conversation reads the page's pinned test clock (threaded through `openPlanning(now:)` since P5.1), so `pump(9 s)` never moved it past the 8 s Why threshold. The test now advances its clock with the pump, as the file does elsewhere; the Why fold, Watch planner and resolve steps are unchanged and pass. The step was never reached before: P5.1's own run stopped earlier (Send off-screen). | e49922e3 / e5148e4a |
| team_gate_answer: layout 320dp 2.5x × {ltr,rtl} × {en,ar} (4) | STALE | At 250 % text the kit sheet's header scrolls away through a header spacer sliver, outside any scroll ancestor, so `ensureVisible` cannot bring Close back. The test scrolls the sheet body to the top (as a person does), then checks the header is inside the sheet, Close ≥ 48 dp, and closing works. | 2d0ac9fe |
| shared_team_2: host details "copying a value puts it on the clipboard and shows no snackbar" | STALE (test defect) | The address row now sits below the fold at 412×915. The test tapped right after `ensureVisible`, with no frame in between, at the stale position. Added `pumpAndSettle` before the tap. | 2d0ac9fe / 24be364a (sheet frame) |
| library_commands: "loading command destinations retains arguments…" | STALE | Run command is a kit sheet with `KitField` (a `TextFormField`). Cast updated. | 06102116 |
| library_commands: "new workspace creates a chat and runs without duplicate submission" | STALE | No `AlertDialog`: the review sheet `run-command-sheet` stays open while the command starts. Duplicate-submission checks unchanged. | 06102116 |
| library_commands: "failed command retains arguments and retries the same new chat" | STALE | `TextFormField` cast. | 06102116 |
| library_skills: "skill content uses the shared Markdown and code renderer" | STALE | One skill sheet: rendered with `KitMarkdown`, Raw is a `KitCodeBlock` named SKILL.md, and the heading that only repeats the name is stripped. Asserts exactly that. | cf8f5eda |
| library_skills: "skill preview fits a narrow large-text phone" | STALE (test defect) | The test wrapped the app in `MediaQueryData(textScaler: 2)` with a zero size. The full-height kit sheet measures the screen, so it laid out 0 px tall. It now sets 200 % through `platformDispatcher.textScaleFactorTestValue`, and asserts the prose shows, not the stripped heading. | cf8f5eda |
| library_skills: "standalone references copy their exact OpenCode mention" | STALE | A reference opens its sheet, whose one action copies `@name`. Copy is `KitCopy` (button says Copied), with no snackbar. | cf8f5eda |
| tools_screen: "Settings exposes one native tools destination" | STALE | Commands & tools moved inside Settings › Tools (Agent group). Path is now `settings-tools` → `settings-commands-tools` → `capabilities-tab-Tools` → `ToolsScreen`. | 2bec3ed3 |

## Files, motion and desktop (5 files, 10 tests)

| Test | Verdict | Why / fix | Cited |
|---|---|---|---|
| run_result_screen: "opens the recorded tool output without re-fetching" | STALE | The KitSheet v2 header plus the rebuilt tool record come to 444 dp. The test now measures the gap under the record (< 48 dp) and caps the sheet at 90 % of the window, so "hugs its record" is still checked. | bea04d0d, db11d2d9 |
| screen_files_1: "the changes sheet is one list by path…" | STALE | The changes sheet is gone; the changed-files row opens Review directly. Now asserts one row ("3 changed files", "+31 −3"), no status groups, and that a tap opens `review-workspace` at "Change 1 of 3". | d4f01730 |
| motion_adopt: "a failed refresh unfolds, settles, and folds away" | STALE (finder) | The terminal list failure is a `KitNotice` (`terminal-list-notice`), not a MaterialBanner. Motion checks unchanged. | 6b2903df |
| motion_adopt: "the first paint shows the rows at once; a new one unfolds" | **PRODUCT BUG — fixed** | The terminal list rebuild dropped `KitAnimatedRows`, so terminals no longer unfolded or folded away (kit-v2 motion). Rows are back inside `KitAnimatedRows` in the `KitRowGroup`. The test also now measures the one-physical-pixel `KitDivider` instead of assuming 1 dp. It failed before the fix (64 vs 65, no unfold). | `lib/ui/screens/terminal_screen.dart` |
| motion_adopt: "a queued message unfolds under the transcript" | STALE | Everything waiting to send is one `KitQueuedMessage` bubble (keys `queued-send-0`, `pending-send-msg_1`). The unfold is still checked through its `KitAnimatedRows`. | 557920e3 |
| motion_adopt: "send ticks; a finished reply confirms with KitHaptics.done" | **PRODUCT BUG — left failing** | One send fires two ticks: `KitComposer._send` (`lib/ui/kit/chat/kit_composer.dart:359`, 0b6c298c) and the chat send path (`lib/ui/screens/chat_screen.dart` ~2751). The chat chain owns both files. | needs chat chain |
| desktop_file_drop: "a dropped file keeps its bytes in the attachment payload" | STALE (harness) | The file preview and `KitViewer` read `AppLocalizations`, which every real host provides. The test app had no delegates, so it got a null-check crash. Delegates added. | 036e14a3, f4622b0e |
| desktop_pointer: "android leaves the file link cursor alone" | STALE | `KitMarkdown` gives file links the click cursor for any mouse (kit-v2 §8.1). Renamed to match. | 79d941e4 |
| desktop_pointer: "the Files split divider resizes and shows a resize cursor" | STALE | Files uses `KitScreen.twoPane`: a fixed list width and a hairline seam (kit-v2 §8.2), no drag splitter. Asserts the list width, seam ≤ 1 dp, no handle and no resize cursor. | 6f21d378 |
| desktop_pointer: "android keeps the plain Files hairline divider" | STALE | Same change: kit panes and seam, no `VerticalDivider`. | 6f21d378 |

## Work and workspace (6 files, 15 tests)

| Test | Verdict | Why / fix | Cited |
|---|---|---|---|
| workspace_hierarchy: 320dp 2.5x LTR keeps search and session creation reachable | STALE | New conversation opens a chooser (Solo / Team / Separate copy) when there is more than one way to start; the test picks Solo. | a2605a09 (P4.5) |
| workspace_hierarchy: 320dp 2.5x RTL, same | STALE | Same. | a2605a09 |
| workspace_hierarchy: empty Workspace has one New session action that opens a session | STALE | Same; also asserts nothing is created until Solo is picked. | a2605a09 |
| workspace_stable_layout: "shop" / "shop-front" / "shopfront" keep the largest title size (3) | STALE | The project name is a `KitText` sized by kit roles (largeTitle / title / headline), not a `Text` at 24/20/16. Asserts the role; an extra "app" case keeps largeTitle covered. | 23b2efb5 |
| workspace_stable_layout: session details disclose usage without cluttering the list | STALE + **PRODUCT BUG — fixed** | Stale: rows have no overflow button; long-press opens the row menu, and Details opens Conversation context. Bug: when the Work row's details sheet merged into Conversation context, the diff size ("+120 −34 · 6 files") and the server's cost before replies load were dropped. Restored under Details (cost only while no usage is measured, so it is said once). Failed on `$0.42` before the fix. | 23b2efb5, 00cafa13, 34353c2f; `lib/ui/screens/session_context_screen.dart` |
| other_projects_panel: a project where an agent is stopped on you says so, live | STALE | The badge comes from the attention feed, which counts another project's request only for a saved server whose server-wide channel reported it. The test controller had neither. The badge check moved into a test that connects, sends the event on the server-wide channel, and sees the badge go up and back down. | c96a7fb4 |
| project_health_screen: workspace exposes project health without compact overflow | STALE | `find.byType(Scrollable).first` now hits the page's status line (Work is a KitScreen). Targets the list's own scrollable. | 9dbcc1a7, 23b2efb5 |
| slice_p3_11a: a Work row's menu opens Conversation context | STALE | The menu entry is "Details" under "Go to" (P10.2). Asserts exactly one Details entry and that it opens Conversation context. | 34353c2f |
| slice_p6_6a_defaults: the review, Work and model default notices (5) | STALE | Default notices are remembered and shown only for a saved server (a profile under `oc.profiles`). setUp now saves the server; each notice is asserted as before. | 7c6d009c |

## Counts

| Verdict | Count |
|---|---|
| STALE TEST (incl. 4 test-harness defects the change exposed) | 41 |
| PRODUCT BUG, fixed | 2 (terminal list motion; Conversation context details) |
| PRODUCT BUG, left failing | 1 (double send haptic, chat chain) |
| GATE / INVENTORY | 0 |
| **Total** | **44** |

The workspace_stable_layout "session details" test counts once, as a product bug; its finder update is part of the same fix.

## Product edits

- `lib/ui/screens/terminal_screen.dart`: terminal rows back inside `KitAnimatedRows` within the `KitRowGroup` (unfold/fold on add/remove), the same pattern as `servers_screen`.
- `lib/ui/screens/session_context_screen.dart`: Details carries the diff size and, before usage loads, the server's cost again. Existing strings only; no copy or l10n change.
- No kit, glass, chat, setup or l10n files touched.

## Checks

- The 18 files plus `terminal_input_queue_test` in one run: all pass except the two named below.
- `flutter analyze` (whole project): no issues.
- Gates: `kit_ratchet`, `redaction`, `ui_glossary`, `no_raw_error_text`, `kit/kit_manifest`, `kit/kit_draft_manifest`, `architecture_boundaries` all pass, plus `session_context_screen_test`.
- Other terminal-screen users pass: project_hub, library_refresh, terminal_accessibility, motion_states, desktop_shortcuts.
- `dart format --language-version=3.10`: clean.

Still failing:
- `motion_adopt_test` "send ticks; a finished reply confirms with KitHaptics.done": a real product bug (two send ticks). The fix belongs to the chat chain: drop one of `KitHaptics.send` in `lib/ui/kit/chat/kit_composer.dart:359` or `lib/ui/screens/chat_screen.dart` (~2751).
- `shared_team_2_test` "golden: open · dark": pixel diff only.

## Left for the golden refresh (pixel diffs only)

- `test/revamp/shared_team_2_test.dart` "team-host-details-sheet golden: open · dark" (0.05 %, 180 px).
- `screen_terminal_1_golden_test` empty, surface, surface menu, shell sheet, unavailable and phone-not-set-up (0.16–0.99 %). These screens don't render the terminal rows changed here; the row goldens (list, list wide, list row menu) still match pixel for pixel.
- `test/revamp/screen_chat_1_golden_test.dart`: 14 pixel diffs (chat, session-context-loaded, terminal, settings-console). They are identical with the session_context change reverted, so they were there before it.
