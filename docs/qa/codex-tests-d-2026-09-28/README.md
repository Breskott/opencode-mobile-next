# tests-d — non-golden repair batch, 2026-09-28

Finish line: reconcile the requested behavioral tests with the intentional UI changes, fix small uncovered product defects outside the other lanes, and retain failing gates for genuine unresolved defects. Non-goals: golden refresh, baseline increases, protected chat/team/state/server/glass edits, or publication.

Base: `6627d50b`, branch `codex/tests-a`. Final code/test candidate: `1d9e3108` (the final documentation commit contains reporting and ledger metadata only). The host crashed during the first post-repair run. Uncommitted edits survived; the original `/tmp` logs did not. The before counts below were recorded from the completed base sweep before the crash. All after results are rerun after recovery; local logs are under `.dart_tool/tests-d/`. Nothing from the interrupted run counts as final verification.

## Requested files

Counts are **passed / failed**. No golden comparisons or regeneration were requested or run. The requested nested `test/kit/kit_motion_test.dart` does not exist; its actual gate is `test/kit_motion_test.dart`.

| File under `test/` | Before | After | Classification |
|---|---:|---:|---|
| `kit_motion_test.dart` | 175 / 4 | 179 / 0 | Retired menu implementation finder; missing integration samples; obsolete baseline entries now tighten |
| `text_scale_overflow_test.dart` | 102 / 1 | 274 / 1 | Non-widget manifest classification; missing scenes; real KIT-24 integration defect |
| `demo_isolation_test.dart` | 2 / 4 | 5 / 1 | Stale kit finders plus real compact status overflow |
| `phone_server_screens_test.dart` | 9 / 2 | 11 / 0 | This phone replaces wizard; pinned version correctly hides Update |
| `termux_running_server_test.dart` | 23 / 8 | 31 / 0 | Zero-size MediaQuery fixture; kit editor; authored error recovery copy |
| `first_run_computer_path_test.dart` | 7 / 9 | 17 / 0 | Kit finders; real code-header overflow and unusable placeholder commands |
| `local_agent_onboarding_test.dart` | 18 / 1 | 19 / 0 | Restart consequence now a separate sentence |
| `tailscale_setup_test.dart` | 20 / 2 | 22 / 0 | External-link confirmation now embeds host in a sentence |
| `host_management_screen_test.dart` | 4 / 1 | 5 / 0 | Copy feedback moved to clicked command; scroll actual command list |
| `safety_confirms_test.dart` | 3 / 3 | 6 / 0 | Long-press KitRow opens actions; confirmations remain required |
| `codex_navigation_test.dart` | 1 / 1 | 2 / 0 | KitNav exposes logical destination IDs |
| `golden_harness_test.dart` | 7 / 1 | 7 / 1 | Genuine golden harness/artifact violations, unchanged gate |
| `design_standard_test.dart` | 14 / 1 | 15 / 0 | Team controls scene intentionally retired |
| `ui_ledger_coverage_test.dart` | 1 / 1 | 3 / 0 | New phone setup host/nonvisual refresh helper; deleted page cleanup |
| `search_index_test.dart` — ledger coverage group | 5 / 0 | 5 / 0 | Reachability and gesture audit retained; deleted draft exclusion removed |

## Evidence for intentional changes

- [Kit integration QA](../kit-gates-manifest-2026-09-27/README.md), especially Deferrals and Tests, records missing shared motion/overflow integration coverage. New samples instantiate the actual exported parts and real state changes. `KitScrollBehavior`, `KitNumberFormatter`, and `KitLogBuffer` inherit non-widget framework bases; the G6 parser now recognizes those bases while retaining loud failures for unknown inheritance and positive widget coverage. G8x retains exported retired forwarding widgets such as `KitSecretField` without changing the G4 deferral policy.
- The home-shell 2.5× and KitRowGroup/default cases already pass at this merged base; their checks and the empty overflow baseline are unchanged. The KIT-24 detector now recognizes generic runtime type names so it can check actual KitSegmented<T>/KitChoiceRow<T> trees.
- KitRowMenu now uses the kit action menu. Its real open callback settles under both reduced-motion policies; those two entries are removed from both G8x baseline and frozen ceiling. No entries were added. Four G4 test deferrals also leave the allowlist because ContextRegion and the three scrollbar parts now have dedicated tests.
- [This phone P1.3/P1.5](../slice-P1.3-P1.5-2026-09-27/README.md), commit `2045a435`, establishes status-first controls. `3a6fa2df` deliberately hides Update when already on the pinned version. Tests retain control ordering and stop confirmation.
- [Servers migration](../revamp-screen-servers-2-2026-09-27/README.md), Expected shared breaks, explicitly replaces the copy SnackBar with in-place feedback. Clipboard contents are still asserted exactly.
- [Shared system migration](../revamp-shared-system-1-2026-09-27/README.md), commit `06102116`, changes the external host label to a complete sentence. [No raw errors](../no-raw-errors-2026-09-27/README.md), `6cdfca4e`, replaces native diagnostic text with authored recovery copy; the test asserts raw text is absent.
- [Demo R16](../revamp-slice-R16/README.md), `253a6919`, deliberately moves Reset into the shared status action. Demo tests use the current kit buttons, inline request diff and TextFormField while retaining zero network/native/storage side effects.
- The Termux harness now preserves inherited viewport geometry when changing text scale. Replacing MediaQuery with fresh data previously set its size to zero, invalidating KitRow's width calculation. No viewport was enlarged.
- [Shared shell](../revamp-shared-shell-1-2026-09-27/README.md), `e10d84a4`, separates restart consequences; [shell navigation](../revamp-shared-shell-1-2026-09-27/README.md), `f4b7a51f`, moves destinations to KitNav. Capability assertions retain their logical IDs.
- [Team screen migration](../revamp-screen-team-1-2026-09-27/README.md) explicitly retires the separate controls/details scene. Only that stale scene name leaves G3; the team-agent scene remains required. No team production file changed.
- [Saved prompts P3.2](../slice-P3.2-2026-09-27/README.md), `331179d0`, absorbs legacy drafts. `acdd5efc` deletes return-brief panels. Their ledger pages and incoming obsolete actions are removed rather than retained as fictitious destinations. `531bb6ab` introduces the nonvisual Usage refresh slot; P5.3 introduces the persisted Termux job host.

## Product defects and remaining work

Fixed product defects:

- `lib/ui/kit/kit_status_slot.dart`: a large status message and Reset action could be 416px tall in a 302px room above the keyboard (114px overflow). The status now scrolls within a bounded share of the room while keeping page content available. A dedicated large-text regression verifies Reset remains reachable and callable. Empty status does not introduce an empty scrollable.
- `lib/ui/kit/kit_code_block.dart`: the setup command's labelled Copy action took unbounded width in its header, overflowing by 213px in English and 107px in Arabic. Only the labelled action flexes; icon target sizes stay intact.
- `lib/ui/setup_commands.dart`: fallback commands embedded literal password placeholders rejected by SEC-4, explicitly deferred in [P3.9 QA](../slice-P3.9-2026-09-27/README.md#tests). They now ask privately in Bash, preserve whitespace (`IFS= read -rsp`), reject blank input and export the entered value before execution. The test requires the complete command to survive the unchanged redactor.
- `lib/ui/kit/kit_page_route.dart`: reduced-motion page transitions rendered their final frame but still ran the standard-duration controller. Push/pop durations now become zero under either reduced-motion policy; normal motion remains unchanged. Dedicated push/pop and existing normal-motion tests pass.

Protected product failures retained without waivers:

- `lib/ui/kit/chat/kit_composer.dart:1056` / `:1070`, beneath `lib/ui/screens/chat_screen.dart:7530`: at 360×740, text 2.5 and a 320px keyboard, the demo's pending-request lists get **0px height** after sending. The status overflow is gone, Reset and Send work, but request Details is unreachable. `demo_isolation_test.dart` retains its strict request-action assertion.
- `lib/ui/kit/chat/kit_composer.dart:551`: the unchanged dedicated composer test overflows **40px vertically** at 320×800/text 2, with busy sending, delivery choices, model chip and offline notice. The original no-overflow and Stop/Send spacing assertions are retained. All new composer reduced-motion samples pass.

Other genuine contract defects retained without baselines:

- `lib/ui/kit/kit_board_lane.dart:157` / `:401`, with `lib/ui/kit/motion/kit_tab_switcher.dart:134`: selecting Backlog from Working shows the selected lane but leaves one transient frame callback after one pump under either reduced-motion policy. Explicit scrolling animations already jump; callback origin needs further attribution. The strict new samples remain failing. This is not evidence of continuing visual animation.

- `lib/ui/kit/kit_segmented.dart:48` and `:428`: KIT-24 stacking still has not been implemented even though KitChoiceRow is now merged. The new long-label scene exposes the original truncation/missing-stack defect. See [original deferred implementation](../revamp-kit-KitSegmented-2026-09-26/README.md). Production segmented code and its dedicated tests remain unchanged; fixing adaptive layout without regressing focus and one-pump settling needs a separate integration slice.
- `lib/ui/kit/kit_date_time_picker.dart:546`, `lib/ui/kit/kit_field.dart:474` / `:1086`: opening the time picker requests Hour focus after layout; the focus notification schedules another LayoutBuilder rebuild. Both reduced-motion opener samples retain the strict failure.
- `lib/ui/kit/kit_request_sheet.dart:643`, `lib/ui/kit/kit_code_block.dart:415`: the request's command scrollbar receives scroll metrics after layout and schedules a LayoutBuilder rebuild. The opener samples and existing reduced-motion assertion retain their failure.

For the last two, temporary `debugAssertNoTransientCallbacks` instrumentation identified **layout callbacks, not running animation tickers**. They nevertheless violate the unchanged one-pump-settled contract. No extra settling pump, callback filtering, lost autofocus, disabled scrollbar or baseline exception was introduced; instrumentation was removed.

G23 is intentionally unchanged: all seven scanner/self-tests pass, but the repository ratchet identifies 152 actual violations (22 missing explicit Android platform setups, 6 missing regeneration-review headers, 124 invalid golden names). See [complete violation list](golden-harness-violations.txt). Examples are `test/revamp/chat_2_golden_test.dart:277` (harness platform), `test/revamp/p67_consent_golden_test.dart:7` (review header), and `test/goldens/team_agent_dark_1280x800.png` (name order). Resolving these needs the separately reviewed golden/harness batch. No PNG was renamed, edited or generated, and no exception was baselined.

## Verification

Pinned SDK: `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin`.

- `flutter pub get --offline` succeeded after recovery.
- Test runs use `flutter test --no-pub -j 1 --reporter expanded <file>`, one process at a time in this lane.
- Formatting uses `dart format --language-version=3.10`.
- Ledger source checker: **0 errors / 52 existing warnings**. Screen coverage, search coverage and the 97-row gesture audit remain strict. Historical ledger findings are explicitly marked historical; generated pages/navigation contain the current 293-page / 1,690-element inventory.
- Scope is the requested files and affected dedicated kit behavior tests. This is **not** a claim of a full repository or golden-suite pass.
- Requested scope: **601 passed / 3 failed**, with 12 of 15 files/groups fully passing (before: 391 / 39). Coverage grew, so the pass-count increase is not a count of repaired failures. Remaining requested failures: compact demo request reachability, KIT-24 stacking, and G23 repository violations.
- Dedicated kit checks: **1,202 passed / 8 failed** across 40 complete files; [per-file results](kit-results.md). Remaining failures: board one-pump settling ×2, protected composer overflow ×1, time-picker one-pump settling ×2, request-sheet one-pump settling ×3. G4 is now **3/3** and its four completed deferrals were removed.
- Additional gesture audit: **3/3**. The search file's requested ledger/reachability group is **5/5**; gesture checks live in `test/gesture_audit_test.dart` and were run separately.
- Final `flutter analyze --no-pub`: **No issues found**. Pinned Dart formatting checked all 59 changed Dart files with no changes needed. `git diff --check` passes.
- No skips were added. No protected source or golden PNG changed. The motion baseline shrank by two entries, the manifest test allowlist by four, and the overflow baseline remains empty.

No push, release, signing, or deployment.
