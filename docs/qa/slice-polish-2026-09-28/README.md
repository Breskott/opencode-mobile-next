# slice-polish — 2026-09-28

Branch `revamp/slice-polish` (worktree `oc_app-slice-polish`), from
`feat/phone-setup-v2` at 521ab553 (app and kit golden reviews merged). Owner
polish items from the golden reviews (lane notes, "POLISH" lines), plus two
coordinator follow-ups. Item 6 (permission command wrap) was dropped: the kit
golden review already fixed it in `kit_request_sheet.dart` (test 10b).

Every image is BEFORE (left) and AFTER (right), taken from the goldens this
slice refreshed.

## What changed

| # | Page | Change | Image |
|---|------|--------|-------|
| 1 | Library › Providers | Only a sign-in the person must finish in the browser ("Sign-in waiting") has the needs-you mark. "Sign-in may not have started" is neutral (the provider's logo, secondary text) and shows how to continue on the same line: "Check the server before you start again". Failed/expired use the failed mark and done uses the done mark, so amber means "needs you" only. | `01-signin-marks.png` |
| 2 | Review: Run results, Review the undo | At 1.3× text and larger, file-name titles break only after `_`, `-` or before the extension's dot, and show in full (no line limit, no ellipsis). Before, "checkout_page.da / rt"; now "checkout_page / .dart". The path under the title is unchanged, and Run results already cuts long paths in the middle. New kit option `KitRow.titleIsFileName` and helper `kitBreakableFileName`. Screen readers read the plain name. | `02-review-filename-text2.png`, `02b-undo-review-filename-text2.png` |
| 3 | Chat (phone and 1280) | Undo bars now appear above the composer. Chat shows them from a context under `KitComposer.layer`, so the clearance they read includes the composer (restore, clear draft, returned-to-draft, reasoning/timestamp toggles). `KitUndo` also re-reads its clearance after each frame while it is visible, so a composer that grows under the bar (a restored prompt) pushes the bar up. The phone had the same overlap as wide. | `03-undo-above-composer-phone.png`, `03b-undo-above-composer-1280.png` |
| 4 | Usage / quota (KitProgressRow) | A full or exceeded limit uses the danger colour for both the bar and "Limit reached". It used to be text colour. `tone: failure` now uses danger too. KitProgressRow.md is updated. | `04-limit-danger.png`, `04b-budget-danger.png`, `04c-kit-at-limit.png` |
| 5 | AI Team page, stopped by Android | Below "Android stopped the team… Start the team again", the page now lists the last-known team: "Tasks as of 10:42 AM" and "Agents as of 10:42 AM", with rows dimmed, each showing its last state and none opening. "Give the team a task" stays in place but is off, with the reason "Start the team again to give it a task or open one." Storage: a small `TeamLastKnown` record (task id/title/state, agent id/name/pool/state, asOf) at `oc.orchestration.<profileId>.lastKnown`. It is saved after every successful refresh and redacted like the snapshot. The plugin sweep and profile deletion already remove this prefix. | `05-team-stopped-last-known.png` |
| a | Team home goldens | Clock pinned with `withClock(Clock.fixed(teamSceneClock))` in `screen_team_2_golden_test.dart`, the same way as `slice_p34`. The images now say "waiting 12 min" instead of an age that depends on the date. | `06-team-home-pinned-clock.png` |
| b | Work goldens | `work_workspace_context_sheet_*` and `work_workspace_folder_chooser_*` refreshed to "This phone · Termux" (intended in 2fec0fc3). | `07-work-this-phone-termux.png` |

Copy added to `lib/l10n/app_en.arb` (gen-l10n run): `integrationsSignInUncertainNext`,
`teamHomeLastKnownTasks`, `teamHomeLastKnownAgents`, `teamHomeStoppedStartFirst`.

## Tests

Each new test was checked to fail without its fix:

- `test/revamp/screen_library_3_test.dart`: only a waiting sign-in has the needs-you mark; an unconfirmed start is neutral and shows how to continue.
- `test/kit/kit_row_test.dart`, group "KitRow file-name title": at 2.0 text the name wraps only between words and stays whole (3 names); the semantics label has no zero-width spaces; the title is plain at 1.0; the helper keeps the characters in order. With `titleIsFileName: false` all 3 cases fail (mid-word break and cut).
- `test/kit/kit_progress_row_test.dart`: 100 % paints the bar and "Limit reached" in danger.
- `test/revamp/saved_prompts_golden_test.dart`: the bottom of the restored-prompt Undo bar is at or above the composer's top on phone and at 1280. Before the fix, 781 > 773 and 666 > 658.
- `test/revamp/team_phone_v2_golden_test.dart` (stopped team): last-known rows, both "as of" labels, the row is disabled with no onTap, and "Give the team a task" is off with its reason.
- `test/team_last_known_test.dart` (new): upkeep runs are left out; the record round-trips under `oc.orchestration.<profile>.`; the sweep covers it; unreadable data gives no record.

Existing tests updated for the intended copy (the neutral row now carries its next step on the same line): `integration_auth_recovery_test.dart` and `screen_library_3_test.dart` use `textContaining`.

Ran 110 test files: the gates (kit_ratchet, redaction, ui_glossary, no_raw_error_text, kit_manifest, kit_draft_manifest, architecture_boundaries, golden_harness, team_storage_redaction) plus every test file that touches the changed files. All pass except `test/prompt_shelf_test.dart` "stash and restore … at 411/320", which **fails the same way at base 521ab553** (checked in a separate base worktree). It is an existing failure, not caused by this slice.

`flutter analyze` (whole project): no issues.

Goldens refreshed (23, each looked at): `kit_progress_row_at_limit_{dark,light}`,
`agent_account_limit_reached_{dark,light}`, `usage_budget_reached_{dark,light}`,
`library_integrations_pending_auth_{dark,light}`,
`review_run_result_finished_text2_dark`, `review_staged_revert_staged_text2_dark`,
`saved_prompts_restored_undo{,_1280x800}_dark`,
`team_home_loaded{,_1280x800}_{dark,light}`, `team_home_search_{dark,light}`,
`team_v2_team_home_killed_light`,
`work_workspace_context_sheet_{dark,light}`, `work_workspace_folder_chooser_{dark,light}`.

## Still needs a device

- Stopped team: an Android kill of the phone team with the app killed too, then reopening the Team page, should show the saved team "as of" the last refresh. The fixtures cover saving and reading it back, but a real kill on a device has not been tried.
- Undo bars while typing grows the composer, and with the keyboard open on a real phone.
