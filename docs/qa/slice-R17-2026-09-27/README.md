# slice-R17 Move confirm names the destination; budget dialog and quota tones (2026-09-27)

Finish line: the move question names where the conversation goes in its title
and every answer, the budget dialog says per unit what to enter and what Save
saves, and the quota monitor's paused / Wi-Fi / source-changed states stop
borrowing the Needs-you attention tone. Non-goal: no change to P5.4's quota
answers (sentence rows, 80% alert, "Needs the quota collector") and no kit
change (R2 already places the alternative between confirm and Cancel and
hides the input reason until the first edit).

## What changed, per page

**session-destination-confirm-dialog** — `lib/ui/screens/session_destination_sheet.dart`

- Title `e7SharedDetail429`: "Move conversation to {destination}?" (was "Move
  conversation?").
- Confirm: "Move to {destination} with changes" (folder move), "Move to
  {destination} with a copy of changes" (cloud machine, where a copy goes),
  or "Move to {destination}" when there are no changes (or they could not be
  read). The alternative is "Move to {destination} without changes"; the kit
  renders it between the confirm and Cancel (phone: stacked; wide: one row).
- Both consequence items ("With changes, they go…", "Without changes, they
  stay…") use `KitConsequenceMark.neutral` (was info + check).
- No-changes body: "No working changes in {place}, so only the conversation
  moves." replaces "Continue to {destination}?", which repeated the title.

**usage-budget-dialog** — `lib/ui/screens/usage_screen.dart`

- `usageBudgetInvalid` split: "Enter an amount above 0, like 2.50" (USD) and
  "Enter a whole number of tokens above 0" (tokens).
- Confirm: "Save USD budget" / "Save token budget" (was "Save").
- The empty dialog shows no reason until the first edit (kit behaviour since
  R2; now covered by a test).

**provider-quota → Quota monitoring** — `lib/ui/widgets/quota_monitor_section.dart`

- Paused and Wi-Fi required: `AppStatusTone.neutral`; source changed (reads
  stopped because the source could not be verified): `AppStatusTone.failure`.
  This file no longer appears in kit_ratchet G17.

Copy: 8 new English strings (`sessionDestinationMoveWithChanges`,
`sessionDestinationWarpWithChanges`, `sessionDestinationMoveTo`,
`sessionDestinationNoChanges`, `usageBudgetInvalidUsd`,
`usageBudgetInvalidTokens`, `usageBudgetSaveUsd`, `usageBudgetSaveTokens`);
reworded `e7SharedDetail429` and `sessionDestinationMoveWithout` (now take
the destination); deleted what this made unused (`e7SharedDetail432`,
`e7SharedMove`, `e7SharedMoveWithChanges`, `e7SharedCopyChangesAndMove`,
`usageBudgetInvalid`) from en/ar; the reworded `e7SharedDetail429` Arabic entry
dropped. gen-l10n regenerated. `tool/capture/budgets_test.dart` taps the new
Save label.

## Tests

New (all pass): `test/revamp/slice_r17_test.dart` (8) — move title and every
answer name the destination, alternative between confirm and Cancel, two
neutral dots, move with changes sent; no-changes confirm and body; cloud move
copy labels and without-changes warp; USD dialog opens without a reason, says
"above 0, like 2.50" after an edit, saves with "Save USD budget"; token dialog
reason and label; paused / Wi-Fi / source changed render a KitNotice whose tone
is not attention. `test/revamp/slice_r17_golden_test.dart` (20 images).

Updated: `test/revamp/screen_usage_1_test.dart` and
`screen_usage_1_golden_test.dart` (new Save labels / reason); regenerated
goldens `chat_session_destination_confirm_dialog_with_changes_*`,
`usage_budget_dialog_*`, `usage_quota_monitor_source_*`.

Compared with the base commit (dd355a09) in a temporary worktree over
`usage_budgets_test`, `provider_quota_monitor_test`, `screen_usage_1_test`,
`screen_chat_1_test`, `shared_usage_1_test`, `chat_live_events_test`,
`release_blockers_test`, `kit_ratchet_test`, `ui_glossary_test`,
`l10n_coverage_test`, `screen_usage_1_golden_test`, `screen_chat_1_golden_test`:
no new failures; four base golden failures now pass (regenerated). Remaining
pre-existing failures: `chat_live_events_test` (33), `release_blockers_test`
(5), `screen_chat_1_test` (1), dark/wide goldens in screen_chat_1 /
screen_usage_1 / shared_usage_1 empty, `ui_glossary_test` G11/G28 (none name a
key this slice touched), kit_ratchet G21 (kit files) and G17 for
`library/integration_tiles.dart` (x2) and `provider_quota_screen.dart` (x1,
P5.4's ≥80% notice) — both outside this slice's write set, so G17 as a whole
still fails. `flutter analyze lib test tool`: clean.

## Images

Before/after pairs: `move_with_changes_dark`, `move_with_changes_1280x800_light`,
`move_no_changes_dark`, `move_no_changes_1280x800_light`,
`warp_with_changes_light`, `budget_usd_invalid_dark`,
`budget_usd_invalid_1280x800_light`, `budget_tokens_invalid_dark`,
`usage_budget_dialog_dark`, `usage_quota_monitor_source_light`,
`usage_quota_monitor_source_1280x800_dark` (each `before-*.png` /
`after-*.png`).

## Still needs a device

- A real move and a cloud move against OC2 with and without working changes
  (long folder names wrap in the title and buttons; checked only in goldens).
- Quota monitor paused / Wi-Fi states come from the background monitor; seen
  here only through a fixed-status test monitor.
