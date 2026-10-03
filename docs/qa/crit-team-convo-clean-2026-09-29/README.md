# Team conversation: clean page (2026-09-29)

Owner: "clean this page". Not run on a device; analyze clean, tests edited but not run (coordinator gates).

## Done
1. One live status: the Now line. Its body sentence is dropped when it only restates the title (working, review). Worker-activity body not added: the state has no last-tool field. "Next:" and Why? kept. Worker row draws no spinner (new `KitToolRow.agent(liveMark: false)`).
2. Chip row (KitAgentStrip) and its divider removed; each worker is one timeline row that opens its session.
3. One clock: the Now line counts from pickup; the worker row shows no timer.
4. Generated names gone from page copy: "Worker", "Worker 2" when several of one role (`teamChatWorkerNumbered`). Names stay on the worker's own page.
5. "The team" heading removed. Lines: "Worker started · 10:08", "Worker took the task · 10:10:47".
6. Composer note: "Your message goes to Worker" / "Worker 2". Skipped: "to the team" before a worker exists (composer is read-only then, no note shown).
7. Empty band under the header gone with the chip row; 16 dp gutter unchanged.

## Files
lib/ui/screens/chat/team_conversation_view.dart, lib/ui/widgets/team_now_line_view.dart, lib/ui/kit/chat/kit_tool_row.dart, app_en/ar.arb (+ generated), tests: team_conversation_screen_test, team_agent_screen_test, revamp/slice_p3_5_test.
Removed strings: teamChatLeadClaimed, teamChatLeadClaimedIt.

## Device check
Worker row reads "Worker · Running" with no spinner; Now line is the only live mark; no gap above the prompt; composer note one line.
