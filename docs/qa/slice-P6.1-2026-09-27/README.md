# P6.1 What runs by itself (2026-09-27)

Branch `revamp/slice-P6.1`, from `feat/phone-setup-v2` at `24b76eb8`. Builds on
Codex's backend half (`docs/qa/codex-p61-2026-09-27/`, commit `dff34356`).

**Finish line:** a per-server AutomationPolicy and the "What runs by itself"
page (`automation-settings`) hold supervision, auto-approve rules (Always
allowed actions inside), housekeeping consents and background monitoring;
each automatic behaviour can be turned off.
**Non-goal:** no new automatic behaviours.

## What changed, per page

| Page | Change |
|---|---|
| automation-settings (**new**, `lib/ui/screens/automation_settings_screen.dart`) | One page per server, kit parts only. An intro line naming the server; **How much the AI Team decides alone** (High / Balanced / Autonomous, `KitChoiceList`) when the server has a team, stored in `oc.automation.<profileId>` and said as chosen only after storage took it (a refused write shows a notice and the level stays); **Without asking you**: *Always allowed actions* (opens `saved-permissions`) and *Watch in the background* (value On/Off from the monitor's own rule; opens Notifications at the servers section). Each part is present only where the server supports it; nothing is set in two places. |
| settings (hub) | The server group's "Always allowed actions" row is replaced by **What runs by itself**; its value is the team's level when there is a team. The search entry for Always allowed actions stays (now "inside" What runs by itself), so it is still found by its own words. |
| saved-permissions | Unchanged; now reached from automation-settings (ledger updated). |
| start-run sheet (team) | Supervision now starts at the server's level from What runs by itself (High until chosen, per personas-verticals.md §3) instead of a hard-coded Balanced. A pick in the sheet is for that task only. |

State: `AutomationPolicyController.forProfile(prefs, id)` is the one shared
instance per profile (page, start sheet); `OrchestrationController.automation`
exposes it. `ConnectionController.deleteProfileAndLocalData` now awaits
`AutomationPolicyController.closeProfile` before the scoped sweep, so an
in-flight write cannot resurrect `oc.automation.<id>`.

## Deliberately not shown (honest state, no workaround)

The policy's other flags exist in storage but **no executor consults them
yet**, so the page shows no switch for them (a switch that changes nothing
would contradict the app):

- Housekeeping consents (`restartDevServices`, `stopIdleHelpers`,
  `cleanCaches`, `updateWhenIdle`): no executor exists in the app.
- `autoApprove` / `autoMergeOnGreen`: merge-on-green is P6.4; there is no
  team auto-approve executor. Contract conflict noted by Codex stands:
  `TeamSupervision.balanced.line` tells the planner to ask before merges, while
  personas §3 says Balanced consents to merge on green. The page uses the
  planner's existing wording.
- `monitorOtherServers` / `monitorQuota`: monitoring already has a store the
  monitor reads (`oc.notifyRules.<id>`, shared quota alerts). The page links
  to it instead of adding a second, unwired switch.
- The 25 default-on routine-recovery flags (reconnect, phone-server restart,
  team housekeeping, …).

### Call sites that still need wiring (owners)

- `lib/state/connection.dart` `_maybeAutoApprove`, reconnect and queue paths:
  consult the policy (single-owner file; only the deletion drain was added).
- This phone's "Restart the server if it stops" (`ManagedServerRecoveryOption`
  on `this_phone_screen.dart`, P1.7 agent's area): a door row from this page
  once that owner agrees on one home.
- Team housekeeping, phone recovery and update owners: consult
  `value.allows(behavior)` before scheduling.
- Moving the per-server watch switch itself from Notifications into this page
  (target IA: Notifications = "what notifies me") — a Notifications-owner
  change.
- No `lib/background/` code was touched; nothing assumes unbounded lifetime.

## Tests

- New `test/automation_settings_test.dart` (7): fresh server = High with no
  write; choosing stores for this server only and survives a restart; refused
  save is said and the level stays; no team → no level; watch row reflects and
  opens Notifications; hub row → page → Always allowed actions; deleting a
  profile closes the controller and sweeps the key (reverting the deletion hook
  makes this test fail — checked).
- New in `test/team_policy_test.dart` (2): the start sheet starts at High by
  default and at a stored Autonomous.
- Updated: `settings_hub_test`, `search_index_test`,
  `settings_server_updates_test` (Always allowed actions is now inside),
  `team_controls_test` (default is now High), `support/settings_scenes.dart`
  (new `automation` scene), `revamp/screen_settings_1_golden_test` (page, phone
  and 1280x800).
- Goldens: new `settings_automation_*` (revamp and test/goldens); regenerated
  only the hub images (`settings_hub_*`). Other settings goldens in those two
  files already fail on the base and were left untouched.
- `flutter analyze lib test`: clean. `automation_policy_test` (Codex's 7) pass.
- Compared with the base in a second worktree: **no new failures**. Already
  failing on the base and left alone: `settings_hub_test` search ("battery",
  then "font"), six `settings_server_updates_test` cases, `kit_ratchet` G17/G21,
  `ui_ledger_coverage`, `gesture_audit`, 20 `team_controls_test` cases (the
  start-a-run harness never reaches the gateway), `e7_library_layout` ×3,
  `teaching_empty_states` ×2, and 36 settings golden images.
- UI ledger: `automation-settings` added to `parts/j1-settings-more.json`,
  rebuilt (the rebuild also picks up other merged parts that the base ledger
  had not yet included).

## Images

Before (base): `before-settings-hub-phone.png`, `before-settings-hub-wide.png`.
After: `after-settings-hub-phone.png`, `after-settings-hub-wide.png`,
`after-automation-phone-light.png`, `after-automation-phone-dark.png`,
`after-automation-wide.png`.

## Still needs a device

The unit's proof asks for emulator screenshots: open Settings › What runs by
itself on a server with the AI Team, choose Balanced, start a team task and
see Balanced preselected; delete the server and confirm the key is gone.
Not run here (goldens and widget tests only).
