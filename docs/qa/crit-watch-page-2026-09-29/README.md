# Watching page critique fixes (2026-09-29)

Source: owner screenshot of the chat page watching an AI Team worker (flat step list, internal session title, generated name).

## Done
1. Auto-fold: `KitWorkLine.tail` (kit). While a turn's work is running, an opened line shows only the newest 3 steps (the live one included) and one "Show N earlier steps" row for the rest; needs 3+ hidden to fold. `_WorkGroup` passes `tail: 3` while running. Finished work keeps the old 25-step cap.
2. "Collapse all steps": top-bar action (unfold-less icon, label `chatCollapseAllSteps`) left of the info button, watching page only, shown only while some step/fold/thought is open. `_ExpansionStore` (chat_screen.dart) reports when the first block opens or the last closes; the tap sets every stored choice to closed.
3. Title: `ChatWatch.title` gives the task title (work item found by `currentWorkId`, else the item's `sessionId`); the top bar shows it instead of the session title.
4. Names: banner, composer hint and the "About" action use the task's role name (roles loaded once per server, `roleOfTask` by work id or run id), else "Worker"/the agent's kind. Banner reads "Watching the {role} · {state}".

## Skipped
- Internal (Gas City) session title under Details: the Details page is `lib/ui/screens/team/**` (another agent's). Needs a follow-up there; the generated name is already shown on that page.
- Collapse all does not see blocks that are open only by default (never touched); they count once touched.

## Files
kit_work_line.dart, message_view.dart, watching.dart, team_conversation_view.dart, chat_screen.dart, app_en/ar.arb (+ generated l10n), tests: team_agent_chat_test, team_conversation_screen_test, revamp/slice_p3_6_test (banner/hint words).

## Device check
Watch a worker with a long turn: open the work line, only the last 3 steps show plus "Show N earlier steps"; open a few steps, the collapse icon appears and one tap folds all; top bar shows the task title; strip says "Watching the Worker/Frontend · Working"; composer "Message Worker…".

## Follow-up (reviewer page, instructions, wide bubbles)
- Title: the reviewer's task is its project's work item waiting in review (newest); with none, the title is "Reviewer", never "New conversation".
- "Reviewer (merges)" is now "Reviewer" (teamUiAgentRoleReviewer, en and ar).
- Empty watching page says what the agent does from team state: Starting / Reviewing the changes of "task" / Working on "task" / Waiting (idle). Elapsed time not added (no reliable start time on the agent).
- Kit: `KitStateView` inline size used for the in-transcript empty state (top, compact); `KitMessage.prompt` gained `bubbleWidth: KitBubbleWidth {auto, compact, full}` (auto: full width past about 6 lines, 360 chars, or code); time line stays at the end edge.
- Team-sent messages: in a watched session, a user-role message that starts with a "[..]" stamp or is long shows as one folded `TranscriptNotice` "Instructions from the team · N words · time" (stamp line dropped). A short message typed by the person stays a bubble.
- Session title: `AgentScreen.sessionTitle` shows the session's own title under Technical details ("Session title").
- Device check: reviewer page shows task title, plain Reviewer, compact top-aligned empty state; instructions row expands to full-width markdown; long own prompts span the width.
