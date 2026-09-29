# crit team-glance (2026-09-29)

Branch crit/team-glance from b92cf1e7. Analyze clean; no tests run (coordinator gates).

## Done
1. `lib/domain/team_glance.dart`: `TeamGlance {working, needsYou, top}` and `TeamGlanceTask {id, title, stepsDone, stepsTotal, needsYou}`, built by `TeamGlance.fromTasks`; `teamGlanceOf(controller)` in `lib/ui/widgets/team_task_row.dart` derives it from the held team snapshot (no network).
2. Work strip (`_teamStrip` in workspace_screen.dart): header "AI Team · 2 working · 1 needs you" (zero counts omitted, "AI Team · nothing running" when idle) opens the team page; up to 3 tasks (needs-you first) reuse `TeamTaskRow` and open the task conversation. Mixed-in team rows removed from the list. Hidden when the team is off.
3. Dock Inbox badge already includes team gates (`AttentionKind.teamGate` in `attentionFeed.knownAttentionCount`); no change.
4. Ongoing progress notification: `CodingAlertKind.teamProgress` ("team_progress"), native branch in BackgroundConnectionService.kt with a new low-importance channel `opencode_team_progress`, ongoing, silent, 20-minute self-timeout, fixed lock-screen public version. Posted from `ConnectionController._syncTeamProgress` under the same rules as other alerts (background, live mode on, server alert toggle, quiet hours); cleared when nothing works. Copy: "AI Team: TITLE · step 3 of 5" / "AI Team: N tasks working". Tap uses the existing team run link.
5. Naming: "Plugins" search keyword removed from the AI Team search entry (and "plugin" from discoverTeamAliases). Remaining "Gas City" copy is under Details/setup text; `lib/ui/screens/team/**` untouched.

## Tests edited/added
- test/team_on_work_test.dart: strip present/absent assertions.
- test/team_glance_test.dart: new, model counts and ordering.

## Skipped
- The Work strip does not show while Work is in its loading/error-only states.
- `teamUiRowTitle` ("AI Team · Gas City") kept: used only in Technical details.
- UI ledger: no page added or removed.

## Device check
Team on with 2 running tasks and 1 gate: strip counts and rows on Work, tap header opens the team page, tap row opens conversation; no duplicates in the list. Background the app: quiet ongoing notification updates step text, disappears when tasks finish, done/needs-you alert still fires; tap opens the task. Team off: no strip.
