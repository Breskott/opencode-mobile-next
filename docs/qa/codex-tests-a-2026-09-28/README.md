# tests-a: non-golden regression repairs (2026-09-28)

Finish line: repair the 15 assigned non-golden test files against the intended
September 27 UI, retain behavioral/security gates, and record per-file results
with clean analysis and small local commits.

Non-goals: golden refreshes, new product features, the chat lane, connection
controller, servers screen, full-suite certification, pushes, CI or releases.

## Candidate and method

- Starting revision: `f83e1e304755852f769e26770192561260d037b9` on `codex/tests-a`.
- Pinned tools: `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin`.
- Dependency setup: `flutter pub get --offline` passed.
- Each assigned file runs separately with `flutter test --no-pub <file>
  --concurrency=1 --reporter=expanded`. One process at a time in this job.
- Formatting: pinned `dart format --language-version=3.10` on changed Dart files.
- No golden PNGs or gate baselines may change.

## Ownership

All edits stay in this assigned worktree. Independent test owners:

| Slice | Exclusive test files | Dependency / acceptance |
|---|---|---|
| Library | library_integrations, integration_auth_recovery, e7_library_layout, teaching_empty_states, v2_feature_gating | Existing production APIs; retain authentication and capability assertions |
| Projects | project_hub, projects_screen, work_tab_cleanup, e7_project_attention_layout, project_health_screen | Existing production APIs; retain navigation, cleanup, attention and health behavior |
| Usage/settings | provider_quota_screen, usage_hub_screen, usage_statistics, settings_server_updates, reader_preferences | Existing production APIs; retain quota isolation, persistence and accessibility behavior |

Owners inspect current source, September 27 QA and history; coordinator alone
runs Flutter checks, reviews changes, writes this report and commits. Any small
production correction requires a separately assigned write set.

## Results

Baseline completed for all 15 files: **109 passed, 111 failed, 1 existing
opt-in capture skipped**. No file was missing. The final unchanged candidate
passed **220 tests, zero failures, one existing opt-in capture skip**.

| File (`test/`) | Before pass / fail / skip | After pass / fail / skip |
|---|---:|---:|
| `e7_library_layout_test.dart` | 0 / 3 / 0 | 3 / 0 / 0 |
| `e7_project_attention_layout_test.dart` | 2 / 2 / 0 | 4 / 0 / 0 |
| `integration_auth_recovery_test.dart` | 2 / 2 / 0 | 4 / 0 / 0 |
| `library_integrations_test.dart` | 5 / 22 / 0 | 27 / 0 / 0 |
| `project_health_screen_test.dart` | 10 / 2 / 0 | 12 / 0 / 0 |
| `project_hub_test.dart` | 1 / 12 / 0 | 13 / 0 / 0 |
| `projects_screen_test.dart` | 17 / 10 / 0 | 27 / 0 / 0 |
| `provider_quota_screen_test.dart` | 0 / 27 / 1 | 27 / 0 / 1 |
| `reader_preferences_test.dart` | 3 / 6 / 0 | 9 / 0 / 0 |
| `settings_server_updates_test.dart` | 12 / 5 / 0 | 17 / 0 / 0 |
| `teaching_empty_states_test.dart` | 20 / 2 / 0 | 22 / 0 / 0 |
| `usage_hub_screen_test.dart` | 3 / 4 / 0 | 7 / 0 / 0 |
| `usage_statistics_test.dart` | 14 / 2 / 0 | 16 / 0 / 0 |
| `v2_feature_gating_test.dart` | 12 / 6 / 0 | 18 / 0 / 0 |
| `work_tab_cleanup_test.dart` | 8 / 6 / 0 | 14 / 0 / 0 |


## Intentional changes traced before repairs

- Quota and Usage: [usage screen rebuild](../revamp-screen-usage-2-2026-09-27/README.md)
  explicitly lists the old Checkbox, button, progress, AppBar and TabBar finders
  as shared tests needing repair. [Quota answers](../slice-P5.4-2026-09-27/README.md)
  replaces exact remaining-percentage labels with sentence answers; the bar
  represents consumption. Consent and an explicit read remain separate.
- Project hub: [files rebuild](../revamp-screen-files-1-2026-09-27/README.md)
  puts Changes first, moves Search into Files and moves the full path out of the
  header (`6f21d378`). [Shell rebuild](../revamp-screen-shell-2-2026-09-27/README.md)
  and [R14](../slice-R14-2026-09-27/README.md) replace the old Material navigation
  and current-tab title with the kit navigation.
- Projects: [work rebuild](../revamp-screen-work-4-2026-09-27/README.md)
  explicitly records missing test localization delegates and Rename moving to
  the row menu (`3599f22f`). [Workspace rebuild](../revamp-screen-work-1-2026-09-27/README.md)
  records row menus, kit text and Undo replacing old Material controls.
- Integrations: [library rebuild](../revamp-screen-library-1-2026-09-27/README.md)
  and [auth sheets](../revamp-screen-library-3-2026-09-27/README.md) document row
  menus and revised sign-in/confirmation sheets (`101cc2df`, `0d4d1e71`).
  [R18](../slice-R18-2026-09-27/README.md) removes redundant provider totals
  (`c0efb78c`).
- Library capability behavior: [library tabs](../revamp-screen-library-2-2026-09-27/README.md)
  deliberately keeps Tools visible with an unavailability explanation when the
  server lacks it (`93f915ac`). Tests must still prove the unsupported tool
  screen never opens.
- Readers: [Markdown kit](../revamp-kit-KitMarkdown-2026-09-27/README.md) flags
  obsolete popup-menu assertions; [shared files](../revamp-shared-files-1-2026-09-27/README.md)
  flags the replaced target-line key. Reader preference behavior remains required.

## Per-file repair classification

All changes below are stale test expectations or harness setup unless explicitly
marked as a product bug. No new skips are added and no baseline is raised.

| File | What changed in the test |
|---|---|
| `provider_quota_screen_test.dart` | Kit consent/actions/progress; bidi-isolated origin; technical route under Details; rounded remaining sentence and used fraction; scoped stale notices; keyboard navigation through segmented providers. Consent, cancellation, no polling, private-copy checks, contrast and 48 dp gates retained. |
| `project_hub_test.dart` | Kit navigation, Changes-first order, Search within Files, path in menu, actual last-row reachability. |
| `projects_screen_test.dart` | Localization delegates; long-press Rename/session menus; kit Undo/confirmations; pump field validation before pressing the action. |
| `library_integrations_test.dart` | Row menus and named sign-in actions; kit sheets and inline choices; rich supporting text; debounced search; removed aggregate provider count. Mutation counts, credential identity, callback validation and unsafe-URL checks retained. |
| `integration_auth_recovery_test.dart` | Pending-auth row/menu and confirmation names; code is still visible before browser launch and forgetting still makes no extra server request. |
| `usage_hub_screen_test.dart` | Kit top bar/tabs, current default range, notification toggle scope and scrolling long tab labels into view at 2.5x. |
| `usage_statistics_test.dart` | Rich provider supporting text and user-visible amount under KitText. |
| `e7_library_layout_test.dart` | Cloud environment Close control, named permission action and scrolling that action into view. Cancellation still causes zero mutations. |
| `teaching_empty_states_test.dart` | Kit create action, P4.5 explicit Solo choice, pinned Worktree create action; secure-storage mock. |
| `v2_feature_gating_test.dart` | Tools explanation instead of removed tab; unsupported ToolsScreen stays absent; kit tab state, long-press menus, debounced search; secure-storage mock. |
| `work_tab_cleanup_test.dart` | Kit title/navigation and Switch server copy. **Real bug:** narrow large-text server status overflows; fixed in the kit, not hidden by the test. |
| `settings_server_updates_test.dart` | Scroll the vertical settings list rather than pinned search; selected shell is shown in row; counted Delete labels; KitSwitchRow. |
| `e7_project_attention_layout_test.dart` | Long-press Rename, isolated path text and pumping validation before Save; existing monitor tests preserved. |
| `project_health_screen_test.dart` | Reveal the result notice after Git initialization; expand Details to read workspace path. |
| `reader_preferences_test.dart` | Direct kit code controls, explicit wrap fixtures reflecting compact defaults, real Markdown full-reader caller, file filter menu, explicit hidden-file choice, review gutter and focused code line. Storage refusal and profile deletion assertions retained. |

## Real product bugs

`lib/ui/kit/kit_top_bar.dart`, `_KitServerPillContent` (original line 946):
the compact server pill reserved an unconstrained single-line status beside the
server name. At 320 dp and 2x text while reconnecting, it overflowed by 170 px.
`test/work_tab_cleanup_test.dart`, `text scale 2 at 320 dp: nothing overflows`,
reproduced it before any repair and still failed after stale finders were fixed.
The kit now measures the status using the actual caption style/text scale and
places it below the name with wrapping when the inline label cannot fit. The
full accessible server/status label is retained. Temporary error diagnostics
were removed after locating the offending Row. The original Work regression
passes 14/14 after the fix.

A second real bug surfaced after restoring the full-reader journey:
`lib/ui/widgets/markdown.dart`, `_CodeReaderPageState.build` (original line 225),
created wrap and copy actions without icons. `KitTopBar` requires an icon for
each action and asserted when a capped Markdown block opened full output.
The reader now supplies the existing wrap and copy icons. The
`reader_preferences_test.dart` snapshot/wrap test still opens the actual reader
and checks preference behavior; no exception is ignored. The reader suite
passes 9/9 after the fix.

A third real bug appeared once the RTL review test reached the current line
selection control: `lib/ui/kit/kit_diff_view.dart:1428` (original line), the
bounded lines Column, laid out its selection footer without a height limit.
At 320 dp and 2.5x text it overflowed vertically by 233 px after selection.
The existing no-overflow assertion remains. The selection footer is now bounded
and scrollable, so both the code and
selection actions remain reachable. Its bounded layout wrapper stays mounted
when selection starts, preserving active drag gestures. Reader tests pass 9/9;
the kit diff guard passes 46/46 and its wrapper passes 8/8.

### Additional kit guard scope

`test/kit/kit_top_bar_test.dart` passed 16/16. The first additional run of
`test/kit/kit_top_bar_r1_test.dart` unintentionally included its four gallery
comparisons: seven behavioral tests and two gutter goldens passed; the two
sidebar golden comparisons failed (dark and light). No golden was regenerated
or tracked PNG edited. The sidebar branch is unchanged by this fix; golden
review is outside this job. Subsequent verification filters this mixed file to
its non-golden `KitTopBar`/`KitShellControls` groups only.


## Verification and remaining work

- `flutter analyze --no-pub`: **No issues found** (30.5 s).
- Pinned `dart format --language-version=3.10 --output=none
  --set-exit-if-changed` on all 18 changed Dart files: **0 changes**.
- `git diff --check`: clean; README relative links resolve.
- Production write ownership: coordinator owns `kit_top_bar.dart`; usage/settings
  worker owns the authorized small fixes in `markdown.dart` and `kit_diff_view.dart`.
- Final candidate: base `f83e1e304755852f769e26770192561260d037b9` plus these edits.
  SHA-256 of the sorted changed Dart paths and contents (path, NUL, bytes, NUL):
  `e57dea2b0dc55427a195641ebedc4229dda694ee2b751147601ee84eca090d3a`.
- Run logs and candidate manifest: `/tmp/codex-tests-a-20260928/`
  (`*.before.log`, iterative `*.afterN.log`, `*.final.log`, `analyze.log`,
  `final-candidate.json`). The per-file table above is the durable count record.
- Full repository suite, devices/emulators, APKs, signing, release and CI are
  outside this assigned non-golden repair job and were not performed.
- No protected chat/connection/servers paths, generated localization, gate
  baselines or tracked PNGs changed. No push.

The final sweep ran each of the 15 assigned files separately, serially, on the
unchanged candidate above. All **220 passed**, with the original optional quota
preview capture skipped (1); no new skips. All 77 additional non-golden checks
passed: top bar 16, filtered R1 groups 7, kit diff 46, diff wrapper 8.

Nothing remains in the assigned non-golden test scope. Three small real product
bugs were fixed and regression-tested. Golden review remains a separate task;
the two incidental sidebar comparison mismatches are recorded above.

## Local commit batches

- `8e11abad` — test: repair library and capability UI expectations [skip ci]
- `7e7846bf` — fix: restore project tests and wrap narrow server status [skip ci]
- `85a29536` — test: repair quota usage and settings UI expectations [skip ci]
- `10ea70e3` — fix: restore full reader and accessible diff selection [skip ci]

This report is committed separately. All five commits use the requested
`[skip ci]` subject suffix and exact Co-Authored-By / Claude-Session trailers.
Commits remain on `codex/tests-a`; nothing was pushed.
