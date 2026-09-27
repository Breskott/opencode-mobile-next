# slice-P8.2: A "Report a problem" page people want to use (2026-09-27)

Finish line: app-diagnostics becomes **Report a problem**: describe the
problem, attach the error and recent diagnostics (preview sheet), then send it
as a prefilled GitHub issue through `openExternalLink`, or copy or share it.
The two old paths (GitHub with the version only, the server-log send) are
merged into it. Non-goal: no in-app ticket tracking.

Builds on P8.1 (`docs/qa/revamp-slice-P8.1-2026-09-27/`): the page reads the
persisted, redacted `ReportProblem` store opened at start-up
(`ReportProblemStartup.current`), and falls back to this run's in-memory
errors when the store is not open.

## What changed, per page

| Page (map id) | Before | After |
|---|---|---|
| `app-diagnostics` | "App diagnostics": in-memory errors, **Send to the server's log** (or Copy on v2), Copy/Clear menu, Performance | **Report a problem**: one intro line, the attached error (when opened from a failure), "What happened?" (multiline, kept as a `KitDraft`), "Include recent diagnostics" switch (default on, with the event count), **Review report**, then the errors kept on this phone (persisted across restarts) with Clear on the list header, then Performance (unchanged). The server-log send is gone. |
| `report-problem-preview-sheet` (new) | none | "Review report · This is exactly what is sent": a public-issue notice, the whole report as selectable mono text, then **Open GitHub form** (primary, through `openExternalLink` and its host confirmation), **Copy report**, **Share report** (Android share sheet; this app is excluded as a target). When the GitHub link would pass 2048 characters, the sheet says so, and opening the form first copies the diagnostics (or the whole report) so they can be pasted. |
| `app-diagnostics-clear-sheet` | "Clear N errors? … since the app opened" from a ⋮ menu | The same confirm, opened by the list header's delete button; the body now says the saved report is cleared too. |
| `settings` (hub) | Help group: "Report a bug" (opened the GitHub form with the version only) | Help group: **Report a problem** with an error-count badge (`KitRowValue.count`, "N errors kept"); opens the page. Its search keywords include the old diagnostics words, and it maps page `app-diagnostics`. |
| Settings › Help | had an "App diagnostics" row | row removed (merged into the hub row; the `/debug` route and search still reach the page) |
| Failure states (`ProductErrorState`, Files, Terminal, Servers menu, Conversations, chat) | "Report a bug" opened the GitHub form directly | Same button, now "Report a problem", opens the page. `ProductErrorState` attaches its failure (title, cause and redacted details, error type); the chat/files/terminal buttons open it without an attachment (wiring every error tone with its error is P8.3). |

What a report holds (`lib/feedback/problem_report.dart`): a title (the error's
title, else the description's first line, 80 characters), the description, the
error's type/place/details, the app version and platform, and up to 10 recent
errors or Android exits (8 stack lines each) plus the 10 newest timings, newest
first. Every part goes through `problemReportScrub`: `KitRedact` (provider
keys, bearer tokens, passwords, registered secrets), then server addresses
(`scheme://host` becomes `scheme://[server]`, bare IPv4 becomes `[address]`)
and opaque 32+ character tokens. GitHub fields: `title`, `app-version`,
`what-happened`, `logs` of `.github/ISSUE_TEMPLATE/bug_report.yml`.

Screenshots: the GitHub form accepts them after it opens, and the page says so
under Review report. Attaching one inside the app would need a FileProvider and
an image share, so it is not built (see "Not proven").

## Files

- New: `lib/feedback/problem_report.dart`, `test/problem_report_test.dart`,
  3 goldens `test/revamp/goldens/system_report_problem_preview_*`,
  2 goldens `test/revamp/goldens/settings_hub_report_problem_*`.
- Page: `lib/ui/screens/app_diagnostics_screen.dart` (rewritten; class name and
  map id kept, `controller` now optional; adds `openReportProblem`).
- `lib/feedback/bug_report.dart`: now only `openBugReport(context, {error})`,
  which opens the page (kept for the callers in chat, which this slice may not
  edit). The copied-link fallback sheet is gone: `openExternalLink` shows its
  own alert, with the address and Copy link, when no browser opens.
- Share out: `ShareOut.text` in `lib/platform/share_intent.dart` and a
  `shareText` method on the `oc/share` channel in `MainActivity.kt`
  (`ACTION_SEND` text/plain in a chooser, `EXTRA_EXCLUDE_COMPONENTS` this app).
- Kit: `KitRowValue.count` in `lib/ui/kit/kit_row.dart`, documented in
  `docs/ux-system/kit-api/KitRow.md`.
- `lib/diagnostics/report_problem_startup.dart`: `ReportProblemStartup.diagnostics`
  (the app's diagnostics, for a page opened without a connection).
- Settings hub/Help/search: `settings_screen.dart`, `help_settings_screen.dart`,
  `search_index.dart`. `product_states.dart` attaches the failure.
- Copy: `lib/l10n/app_en.arb` only (22 new `reportProblem*` keys; changed
  `e7LibraryReportABug` to "Report a problem", `appDiagnosticsClearBody`,
  `settingsHubSearchBugAliases`; removed 18 keys made unused, including the
  server-log send, the Help row subtitles, the old empty state and the
  link-copied sheet). `flutter gen-l10n` rerun.
- Tests changed for the new behaviour: `app_diagnostics_screen_test`,
  `bug_report_test`, `settings_hub_test`, `settings_server_updates_test`,
  `v2_feature_gating_test`, `shared_system_1_test`, `motion_states_test`,
  `servers_reachability_test` (names), `kit_row_value_test`,
  `share_intent_test`, `share_intent_native_contract_test`, the settings and
  system golden tests, `test/support/settings_scenes.dart` (hub scene records
  two errors for the badge), and the census shots in
  `tool/capture/census/areas/j1_settings_more.dart`.
- Removed: the `system_bug-report_link-copied` golden test and its 4 PNGs (the
  sheet no longer exists).

## Tests

Pinned Flutter 3.47.1 (Shorebird cache), `--no-pub`.

| Run | Result |
|---|---|
| New: `test/problem_report_test.dart` (9), `test/app_diagnostics_screen_test.dart` (8), `test/bug_report_test.dart` (2), `KitRowValue.count` and `ShareOut` cases | all pass |
| Existing files for changed code (26 files incl. `kit_ratchet_test`, `architecture_boundaries_test`, `ui_glossary_test`, `design_standard_test`, `search_index_test`, `settings_*`, `v2_feature_gating_test`, the four golden files) | failures identical to the base commit `9dfdb414` run in a temporary second worktree; no new failure. The gate failure messages of `ui_glossary_test`, `kit_ratchet_test` and `l10n_coverage_test` were diffed line by line against base: identical (45 lines each). |
| `flutter analyze` (whole project) | No issues found |

Pre-existing failures (also on base, not touched): `kit_ratchet` G17/G21 (other
kit files), `architecture_boundaries` ARCH-1 (`tools_screen.dart`),
`ui_glossary` G11/G28 (other keys), `design_standard` (team_agent_controls
goldens missing), `search_index_test` (5), `settings_server_updates_test` (6
shell/appearance/privacy tests), `v2_feature_gating_test` (6), `motion_states`
chat (2), and every golden in the four golden files on this machine (renders
differ from the committed PNGs at base). Only this slice's goldens were
regenerated (app diagnostics, clear sheet, preview sheet, settings hub, hub
badge, `settings_diagnostics*`); the other drifted PNGs were left untouched.

Acceptance evidence:

| Acceptance | Where |
|---|---|
| report-problem-preview-sheet shows exactly what is sent | `app_diagnostics_screen_test`: "describe, review exactly what is sent, then open the prefilled GitHub form…" (the launched URL's fields are parts of the previewed text), "…Copy copies exactly the preview", "Share hands the preview to the share sheet…" |
| one Settings row, with an error-count badge | `settings_server_updates_test` "Settings has one Report a problem row with an error badge"; `settings_hub_test` (Help no longer has the diagnostics row) |
| never a credential (fake keys) | `problem_report_test` "never a credential or a server address": fake `sk-ant-`, `sk-proj-`, Bearer, `password=`, a registered secret and a `/config/providers` JSON body, plus host names and IPs, absent from the report text and the encoded and decoded link |
| GitHub through `openExternalLink`, nothing filed | the widget test taps through the link confirmation into a fake launcher; no network |
| survives restart, Clear empties the saved report | "errors saved before a restart are listed, and Clear…" (reopens a real `ReportProblem` store in a temp directory) |
| URL length limit | "long diagnostics go to the clipboard…", "a very long description copies the whole report", and the widget test with 12 long errors |

## Images

| | Before | After |
|---|---|---|
| Page, phone | `before_system_app_diagnostics_dark.png` | `after_system_app_diagnostics_dark.png` |
| Page, wide | `before_system_app_diagnostics_1280x800_dark.png` | `after_system_app_diagnostics_1280x800_dark.png` |
| Clear question | `before_system_app_diagnostics_clear_sheet_dark.png` | `after_system_app_diagnostics_clear_sheet_dark.png` |
| Preview sheet | (new) | `after_system_report_problem_preview_dark.png` (with an attached error), `after_system_report_problem_preview_1280x800_dark.png` |
| Settings hub, Help group | `before_settings_hub_help_group_dark.png` ("Report a bug") | `after_settings_hub_report_problem_dark.png` ("Report a problem", badge 2) |

## Needs a device (not proven here)

1. Emulator proof from the programme: trigger an error, open Settings › Report
   a problem (badge shows), type a description, Review report, Open GitHub
   form → the confirmation names github.com → the browser opens the prefilled
   issue form. Do **not** submit it. Also try from a `ProductErrorState`
   (e.g. Files with the server stopped mid-list gives a non-network error).
2. **Share report** on Android: the chooser opens and does not list OpenCode
   Mobile. The Kotlin change (`shareText` in `MainActivity.kt`) was not
   compiled here (no APK build in this unit, the machine was at load 7.4):
   the coordinator's release build is its compile check.
3. A long report: the form opens with "paste them here" in Diagnostics and the
   clipboard holds the diagnostics.
4. The saved report after a crash (P8.1's steps) shows its errors on this page.

## Not proven / follow-ups

- In-app screenshot attachment is not built (needs a FileProvider and an image
  share); the page points to the GitHub form's own attachment instead.
- `KitReportHook.handler` is still unset: the kit's error tones do not offer
  Report yet. P8.3 sets it with
  `KitReportHook.handler = (context, report) => openReportProblem(context, error: report);`.
- The chat's "Report a problem" button (chat files are owned by the chat chain)
  opens the page without its error attached.
- The desktop command palette still has its own "Diagnostics" command to
  `/debug` (same page) next to the search entry; `lib/main.dart` was not
  touched.
- `docs/ux-system/map/*.json` still describes the old page; the census shot for
  the new preview sheet is not added.

## State

| State | Yes/No |
|---|---|
| Implemented | Yes |
| Enabled | Yes (Settings row, failure states, `/debug`, search) |
| Verified | Unit/widget tests, goldens and analyzer only |
| Committed | Yes, branch `revamp/slice-P8.2` |
| Deployed / Released | No |
