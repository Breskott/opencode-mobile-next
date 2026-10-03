# Screen review: files, servers, session tools

*2026-09-26. Areas `f-files-review-terminal` (18 pages), `g-servers` (32) and `k-session-misc` (17). I looked at all 105 census renders and checked the source where a still image can't show the behaviour. Scored against `docs/design/principles.md`. Per-page scores and fixes are in [`files-servers-misc.json`](files-servers-misc.json).*

**Verdicts:** 4 keep, 55 fix, 8 rethink. 3 critical, 77 high, 98 medium and 24 low issues. None of the 67 pages is done by the principles' bar. The only keeps are `servers-welcome`, `files-changes-sheet`, `terminal-rename-dialog` and `continue-on-phone-sheet`.

Rethink: `review-workspace`, `connection-help`, `provider-quota`, `provider-quota-enroll-dialog`, `usage`, `profile-monitor`, `add-agent`, `session-handoff-dialog`.

## The five most important problems

1. **Typed work is lost without a question (critical, X2).** In `context-capsule`, the notes and errors a person collects disappear on Back. There is no PopScope, and the copy itself says "Unapplied edits are kept only while this screen is open". In `review-comment-sheet`, a code-review comment is a plain dismissible sheet, so one swipe throws it away. `session-note` already asks before discarding, so reuse that guard. `session-note` itself deletes the saved note at once, with no confirm and no undo.
2. **Review changes is the core screen, and it is the weakest (`review-workspace`, `diff-view`).** The file name appears three times and the +/− counts three times. There are two up/down navigators. Raw `--- a/` `+++ b/` `@@ -41,9 +41,12 @@` headers show above the code. Wrapped code returns to column 0 under the line numbers, so it reads as new lines. The empty and error states use the old centred style. `diff-view` is a second, different diff renderer. Build one diff component: a sticky file header, one "Change 1 of 3" navigator and hanging indents.
3. **Settings pages written as operator manuals (`provider-quota`, its enroll dialog, `usage`, `connection-help`, `tailscale-setup`, `host-management`).** They carry walls of words like "collector", "same origin", `/ocmn/quota/v1`, "tool/quota/README.md in the app repository", "date-window start", "loopback", "reverse proxy", "HTTPS origin" and "VPN connection is unverified". Some sentences contradict themselves ("An optional collector is required"). The number the person came for (cost, quota left) sits below the fold or behind a checkbox. Lead with the answer and fold the mechanics into Details. `host-management` also pipes an unpinned script from a personal GitHub `master` branch into bash, with no pin, checksum or summary (P10).
4. **Destructive and irreversible actions look safe.** "Make revert permanent" is the green primary (`staged-revert`). "Discard" (`profile-editor-discard-sheet`), "Clear saved … thresholds" and "Clear … budgets" are green filled. "Remove agent", "Stop task", "Forget saved task" and "Delete saved note" are accent text links, sometimes placed right next to each other. Four different confirmation sheet styles are in use: a centred sheet with a trash icon, one with a "?" icon, a left-aligned one with no icon, and Material dialogs. Adopt one kit confirmation with an error tone for anything that removes something.
5. **Engine words and raw values above the fold, across all three areas.** Server rows show `192.168.1.20:4096` and `/work/shopfront`. Other pages show `msg_assistant`, `ses_transfer`, `anthropic/claude-sonnet-4`, `text/plain` or `application/json` as subtitles, "PID 4821", "Run …ssistant" (an id cut to a few letters), "A2A 1.0 · JSON-RPC", "HTTP bearer credential", "compaction", "Saved-server attention · Current observation". The worst case is `agent-choice`, which re-introduces the "Paseo daemon … Experimental" wording that regression row 15 removed from Add server. Its three options are also in a different order.

## Recurring patterns

- **Doubles.** The same thing appears twice on one screen, which breaks U6/P1:
  - Files has two headers and two "Try again" buttons.
  - Terminal empty state has "New terminal" plus the FAB.
  - Servers has "Connect OpenCode 2" plus "Add server".
  - The Inbox shows a request row plus "1 pending".
  - Subagents shows the conversation name twice.
  - There are two "Continue on computer" flows (a dialog and a sheet) with different commands.
  - Two file viewers each show two copy buttons.
- **Top bars with three icons** (Servers: bell, info, help; terminal surface: copy, a person figure, refresh). The standard allows one icon plus an overflow.
- **Messages in cards instead of kit states.** The Codex account "Ready to sign in" card, External agents' filled empty box, Add agent's note card, external task status cards and Tailscale's step 1 card are all wrapped as cards. Several error and empty states still use the pre-kit centred icon: Review changes, the pairing scanner, Subagents.
- **Contradictions (C2).** Server settings shows "Version 1.18.25" next to "Current server: unknown", and the upgrade sheet repeats "unknown". Servers says "Password re-entry required · Connected ·". The add-server failure names `opencode serve` under an `opencode2 pair` instruction. An empty note counts "2 / 8192 bytes". The profile monitor uses a green dot for "Permission needed".
- **Truncation (P8).** Code in the file viewer runs off the edge by default. The Codex command, the continue-on-computer command, "Subagent conversatio…" and the "…ssistant" run label are all cut.
- **Text that says too much.** Many bodies run three or four sentences of hedging ("may", "reported", "not verified", "self-reported"), where one plain sentence plus Details would do.
- **Motion.** From source, `review_workspace.dart` uses off-token 160 ms and 220 ms easeOutCubic. Servers and Add server use KitMotion, KitReveal and KitAnimatedRows correctly. Everything else needs a device recording.

## Quick wins (small, local changes)

- Add discard guards to `context-capsule` and `review-comment-sheet`. Add confirm or undo to Delete saved note.
- Error-tone every destructive confirm: Discard, both Clear dialogs, Stop task, Remove agent. Use the trash icon, not "?".
- Give `InfoLabel` a 48 dp hit area. It is about 24 dp today (critical X1).
- Files:
  - Hide the change-marks banner when listing fails.
  - Drop the per-row ⋯.
  - Hide `.git`.
  - Use the folder as the subtitle instead of repeating the file name.
- Servers and server settings:
  - Put kind and state in server rows instead of address and port. Remove the "Connect OpenCode 2" row.
  - Use the health check's version in the update row and sheet.
  - Turn the "Restart to use 1.19.0" pseudo-button into a row that leads to a copyable command.
- Reuse Add server's three rows, words and order in `agent-choice`.
- Plain-word the titles: "Subagents", "Other servers", "Add context", "Undo from this message?".
- Remove `msg_assistant` and `ses_transfer` from the page, and fix "1 message records".
- Terminal:
  - Show one "new terminal" action when the list is empty.
  - Remove the PID from the status line.
  - Move the figure and refresh icons into an overflow.

## Harness notes (not reported as issues)

- Screens pushed with `kit.pumpApp` render without a back arrow.
- The terminal surface's stair-stepped output comes from the fixture's line endings. The same text renders correctly in text mode.
- Key-bar arrow boxes, absolute fixture dates and "Private title" come from the census fixtures and fonts.
