# P0.3 + P0.4 — a team task opens one page; stop it from there (2026-09-26)

Slices (docs/ux-system/programmes.json):

- **P0.3 "A team task opens one page from every door"** — finish line: team-home
  task rows, the team notification and team-home's "Give the team a task" all
  land in the task conversation, as Work rows and board cards already do.
  Non-goal: deleting RunScreen or its tabs (P3.5); no visual change to team-home.
- **P0.4 "Stop the task from its conversation"** — finish line: the
  conversation's menu has "Stop task" → the confirm sheet "Stop this task?"
  (cancel "Keep running") → `cancelRun` → a receipt in the conversation.
  Non-goal: worker-level stop from the family strip (P3.6); no auto-heal.

Design decision: docs/design/team-conversation-2026-09-26.md, option A (a team
task is a conversation; workers are sub-agents).

Branch `fix/p0-team-one-page`, based on `ebbc1a71`.

## Door → landing

| Door | Before | After |
|---|---|---|
| Team-home task row (`TeamHomeScreen._openRun` fallback) | `RunScreen` | `TeamConversation.open` → conversation |
| Team-home row, when team-home was opened from a conversation's "AI Team" button | a second `RunScreen` on top of the conversation | same task: pops back to that conversation (no second copy); another task: its conversation |
| Team-home "Give the team a task" | `showStartRunSheet`, stays on team-home (planning card / snackbar receipt) | `TeamConversation.start` → the new task's conversation; back returns to team-home with its planning card. A refusal the sheet did not say (work made, pool refused it) is still said once on team-home |
| Team notification / `opencode-mobile://team` link, kind run (`main.dart _pushTeamDestination`) | `RunScreen` | `TeamConversation.route(team, runId:)` → conversation |
| Work tab team-task row | conversation | conversation (unchanged) |
| Board card with a task | conversation | conversation (unchanged) |
| Board "+" | adds to backlog | unchanged (different job) |
| Conversation menu "Task details" | `RunScreen` | `RunScreen` (kept on purpose — the task's detail page until P3.5) |

Every remaining `RunScreen(` construction in `lib/` after this change:
`lib/ui/screens/chat/team_conversation_view.dart` (`_openDetails`, the
conversation's "Task details" menu entry). The notification and team-home pushes
are gone.

## Stop task (P0.4)

- The conversation's overflow menu is now the kit's `KitRowMenu` (was a raw
  `PopupMenuButton`): "Task details" always; **"Stop task"** (destructive) only
  while the run is not completed / cancelled / failed **and**
  `capabilities.controlCancelRun` — never the flavor enum.
- Stop opens the existing `showConfirmSheet` (destructive tone, warning icon):
  title "Stop this task?", body names the task and says its running workers stop
  and finished work stays, confirm "Stop task", cancel "Keep running". Backing
  out sends nothing.
- Confirm calls `OrchestrationController.cancelRun(run.id)` (the gateway's
  `cancelRun`). The receipt is the conversation's existing receipt pattern
  (`TeamReceiptChip`, as sent messages use): "Stop task · Sent", then
  "Stop task · Confirmed" when the host reports the run cancelled, or
  "Stop task · Refused" with the host's words; Retry when the record allows it.
- Copy in `app_en.arb` and `app_ar.arb` (`teamChatStopTask`,
  `teamChatStopConfirmTitle`, `teamChatStopConfirmBody`, `teamChatStopKeepRunning`).

Kit rule (2026-09-26): no new raw widgets were added; one raw `PopupMenuButton`
was replaced by `KitRowMenu`. No kit gaps.

## Tests

New: `test/team_one_page_test.dart` (7 tests):

| Test | Before fix | After fix |
|---|---|---|
| a team-home task row opens its conversation, not RunScreen | fail | pass |
| team-home opened from a conversation comes back to the same task instead of stacking a second copy | fail | pass |
| "Give the team a task" on team-home lands on the new task's conversation | fail | pass |
| Stop asks first, cancels the task and shows the receipt (Keep running sends nothing; Sent → Confirmed) | fail | pass |
| a refusal reads as the host's own words | fail | pass |
| no Stop on a finished task | fail¹ | pass |
| no Stop where the host takes no cancel control | fail¹ | pass |

¹ fail before because the menu had no "Task details" key; the absence of Stop
alone would hold vacuously before the fix.

Updated to the new landing (each failed against the fix before the update, i.e.
they asserted the old two-page behaviour):

- `test/team_gate_answer_test.dart` — "a completed-run notification tap opens the
  task's conversation (P0.3), not the run page" (fails before the fix).
- `test/team_controls_test.dart` — the three start-a-task tests now expect the
  conversation, then go back to see the planning card on team-home.
- `test/team_motion_test.dart` — the planning-card motion test goes back from the
  conversation before checking the card.
- `test/support/team_chat_fixture.dart` — `TeamChatGateway.cancelRunAnswer` so a
  test can script the host refusing a cancel.

Board card (`test/team_board_test.dart` "tapping a card opens its conversation")
and Work row (`test/team_discover_test.dart`) doors were already covered.

Command (pinned Flutter 3.47.1, `-j 2`):

```
flutter test -j 2 test/team_one_page_test.dart test/team_controls_test.dart \
  test/team_motion_test.dart test/team_gate_answer_test.dart \
  test/team_conversation_screen_test.dart test/team_home_test.dart \
  test/team_board_test.dart test/team_discover_test.dart \
  test/ui_ledger_coverage_test.dart test/search_index_test.dart \
  test/team_agent_chat_render_test.dart test/team_design_standard_test.dart \
  test/team_home_stable_layout_test.dart \
  test/background_notification_navigation_test.dart \
  test/l10n_coverage_test.dart test/gesture_audit_test.dart
```

Result: `+205: All tests passed!` (16 files). Before the fix (lib changes stashed):
`team_one_page_test.dart` 7/7 fail and the notification test fails.

`flutter analyze` (whole project): No issues found. `flutter gen-l10n` run once after the copy settled.

UI ledger: parts updated (notification and team-home row now land on
`team-conversation`; new `team-conversation-menu-stop` element and
`team-conversation-stop-confirm-sheet` page; `RunScreen` reached from the
conversation's "Task details"), `build_ledger.py` rerun.
`tool/qa/check_ui_ledger.py` reports the same 43 pre-existing errors as at the
base revision (none new).

The full serial suite was not run (focused-check ladder; coordinator's gate).

## Emulator proof: pending coordinator

No APK, emulator or adb was used by this slice. Steps for the coordinator, on an
emulator with the spike city (Gas City fixture or the in-app AI Team) and a
build of this branch:

1. Work tab → AI Team door → team-home. Tap a task row → the task's
   conversation opens (title in the top bar, the lead's reply, "Message the
   team…"), not the tabbed run page.
2. In that conversation tap the AI Team (agent) icon → team-home → tap the same
   task → you are back on the same conversation; system Back goes to where you
   came from before the conversation (no second copy of it).
3. Team-home → "Give the team a task" → send a task → its conversation opens
   ("Sent to the team"); Back → team-home shows the planning card / the task.
4. With a task running, trigger a team notification (a completed task or a
   task link `opencode-mobile://team?...kind=run`) and tap it → the task's
   conversation opens.
5. In a running task's conversation: ⋮ → "Stop task" → sheet "Stop this task?"
   naming the task → "Keep running" sends nothing; again → "Stop task" →
   receipt "Stop task · Sent" then "Stop task · Confirmed"; the board shows the
   task cancelled and ⋮ no longer offers "Stop task".
6. Arabic: switch the app language and repeat step 5 once; the sheet reads
   "هل تريد إيقاف هذه المهمة؟" with "دعها تعمل".

Record screenshots / a screen recording under this folder.
