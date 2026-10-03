# revamp-chat-4: command launcher and the team conversation (2026-09-27)

## 1. Scope

- Unit: `chat-4` (wave 2c, tier 4, screen-revamp). Finish line: the command launcher and the team conversation are built from `lib/ui/kit/` parts only, in the visual language, with G1, G16, G7, G17 and G21 at zero for the write set, and the team conversation handles its map proposal `fix`. Non-goal: no gateway call, controller field or persistence is added; the launcher's plain-language redesign fed by per-agent catalogues waits for its wave-3 slice.
- Files changed (code head, see `git diff 87100f73...HEAD`):
  - write set: `lib/ui/screens/chat/command_launcher.dart`, `lib/ui/screens/chat/team_conversation_view.dart`, `lib/ui/screens/team_conversation/team_conversation.dart` (`lib/ui/kit/chat/kit_agent_strip.dart` is used unchanged);
  - chat library clean-up under the coordinator ruling: `lib/ui/screens/chat_screen.dart` (dropped the unused `agent_color.dart` import and the unused `TeamComposerField`, `TeamReceiptChip` shown names), `lib/ui/screens/chat/message_view.dart` (deleted `_FoldLine` and `_FoldSteps`, which only the old lead fold used);
  - copy: `lib/l10n/app_en.arb` plus the generated `app_localizations*.dart` (no Arabic entries: owner decision 2026-09-27);
  - census guard (TEST-17 registry): `tool/capture/census/areas/b2_chat_screen.dart` now expects the launcher title "Commands and agents";
  - tests: `test/team_conversation_screen_test.dart`, `test/revamp/chat_4_test.dart`, `test/revamp/chat_4_golden_test.dart`, 16 PNGs under `test/revamp/goldens/chat_4_*`.
- Pages (map ids): `command-launcher-sheet` (proposal redesign), `team-conversation` (proposal fix).
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-41, STATE-5, STATE-12, STATE-16, LOOK-4, LOOK-24, DATA-2, COPY-13, TEST-5, TEST-19; kit-v2 §9.1; KitAgentStrip.md, KitTurn.md, KitWorkLine.md, KitToolRow.md, KitComposer.md; visual language Chat.png.
- Contract problems (PROC-20):
  - KitMessage.prompt `time` renders a 12-hour UTC-looking time ("7:49 PM") while the team's own lines use `teamClockLabel` on the phone's clock ("23:49" on this machine). Passing it would show two different times for one event, so the team conversation passes no prompt time; the lead's lines carry the times. Evidence: the first gallery run (not committed). Proposed: KitMessage formats `time` with the same local 24/12-hour rule as the rest of the app. Blocks nothing.
  - There is no kit toast. The old watching-mode message receipt was a SnackBar (G1). It is now shown in place inside the message sheet, which stays open until the person closes it. Blocks nothing.
- New kit parts (KIT-3): none. KitAgentStrip (already merged by kit-KitAgentStrip) is adopted.
- Map items (EVID-11):
  - `team-conversation` actionsMissing:
    - Stop task: done (was already on the menu; kept on the task's own menu with the confirm that names the task): `test/team_conversation_screen_test.dart` "Stop task is on the task's own menu and asks first".
    - open a step: deferred to the wave-3 team-conversation slice (no step page exists; the worker on a step opens from its sub-agent line and the agent strip).
    - edit and resend a refused task: partial: a refused task shows the host's reason and, when the record may be retried, "Send the task again" (`retryMutation`); editing before resending is deferred to the wave-3 slice (the start sheet takes no prefill).
    - draft kept when leaving: done (kept per task while the app runs; nothing stored): "the draft is kept when the person leaves and comes back".
    - undo a message: deferred (no undo in the team's message control; no owner).
  - `team-conversation` statesMissing:
    - host error / offline as a page state: done as the Now line's "The team isn't answering" with Retry after 8 s (existing behaviour, now in the error tone instead of the attention roles).
    - task cancelled or removed: done: "a task the team no longer lists says so, with its page" (cancelled was already the lead's "The task was cancelled." and the turn's Stopped phase line).
    - planner refused (pending never binds): done: "a task the planner refused says so with the reason".
    - still planning after N min with an action: done (10 min, Open AI Team): "a task waiting long for the team says so and offers its page".
  - `team-conversation` infoMissing "who the composer message goes to before typing": done (KitComposer note line): "the task reads as a conversation from the team's real data".
  - `command-launcher-sheet` (redesign: kit-only rebuild of today's layout; the new structure is deferred to the wave-3 action-launcher slice). Fixed on the way because the old copy was wrong: the title "Composer tools" became "Commands and agents"; actions read by name with the slash word as a trailing hint; the "mobile" tag is gone; "search with no match" has its designed empty with Clear search (`test/revamp/chat_4_test.dart`); an agent that cannot list its own commands says so (`command-launcher-agent-commands-unavailable`, no test: the chat harness cannot switch `serverCatalog` off). Deferred to the wave-3 slice: agent-native commands on Claude Code and Codex, pin or reorder, arguments.
- States per page (STATE-20):
  - `team-conversation`: loading (KitScreen loading bar), pending, working, needs you, finished, stopped, not answering, removed, refused, still waiting, composer cannot / nobody (read-only composer with the reason) → tests above and goldens `chat_4_team_conversation_working_*`, `chat_4_team_conversation_needs_you_*`.
  - `command-launcher-sheet`: commands, search no match, server commands error with Try again, delegate (loading, error, empty) → `chat_4_command_launcher_*`, `chat_4_command_launcher_no_match_*` (the chat harness has no action repository, so both galleries also show the server-commands error line, a real state).
- Deferred states (STATE-21): none beyond the map items above.

### Moved or removed (owner rule 2026-09-27, rethink)

- Team conversation: the family strip's hand-built chips became KitAgentStrip; the words "running / waiting / done / failed" now come from KitTaskMark (Working, Waiting, Done, Failed, Stopped, Needs you).
- Team conversation: the lead is marked "Needs you" in the strip while a gate of this task waits, and the header subtitle carries the one needs-you marker; the Now line no longer draws the attention look for needs-you, stalls or not answering (LOOK-4: only KitNeedsYou and KitRequestCard draw it).
- Team conversation: the step rows' second state word ("Queued" beside "Waiting") was removed: one mark and one word per step.
- Team conversation: the task prompt's own time was removed (it contradicted the lead's times; see contract problems).
- Team conversation: the watching-mode message receipt moved from a snack bar into the message sheet.
- Command launcher: the aliases next to each slash word ("/clear", "/resume") are no longer drawn; they still match a search.
- Command launcher: the second drag handle (KitSheet's own under the route's) was removed.

## 2. Builds

- Branch `revamp/chat-4`, base `87100f73`, code head `5a8c7902`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/team_conversation_screen_test.dart` | passes | 16 passed | PASS |
| 2 | `test/revamp/chat_4_test.dart` | passes | 2 passed | PASS |
| 3 | `test/revamp/chat_4_golden_test.dart --update-goldens`, then each PNG opened | 16 images, looked at | 16 written and looked at | PASS |
| 4 | `test/kit_ratchet_test.dart` with `KIT_RATCHET_WRITE=1` (baseline restored with `git checkout` afterwards, R05) | write set at 0 for G1, G16, G7, G17, G21, G48 | no entry for any write-set file | PASS |
| 5 | `dart analyze lib tool/capture test/revamp test/team_conversation_screen_test.dart` | no issues | No issues found | PASS |

Not run (owner decision 2026-09-27: run only the unit's own test files): the design-standard, l10n, glossary and ledger tests, and the other team and chat suites.

## 5. Evidence

- Fixes only: none of the map items is a regression fix of shipped behaviour, so no failing-first output (TEST-2); the new states are new code.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-1 / G16 | `test/kit_ratchet_test.dart` (write mode) | run 4 |
  | STATE-16 / KIT-41 | `test/team_conversation_screen_test.dart` "many steps fold under one line" | run 1 |
  | DATA-2 | `test/team_conversation_screen_test.dart` "the draft is kept when the person leaves and comes back" | run 1 |
  | STATE-12 | `test/revamp/chat_4_test.dart` "a search with no match says so, and Clear search brings the list back" | run 2 |

- Changed test expectations (TEST-19), all in `test/team_conversation_screen_test.dart`:
  - `tester.widget<Text>(key).data` on the Now line, agent line and composer note → the words drawn under the key (`_words`), or the visible text: the parts now draw through KitText and KitComposer (KIT-1).
  - the worker's state "Working" → "furiosa · Worker · Running": KitToolRow.agent's status word (KIT-41).
  - `find.text('furiosa · Worker')` taps → the sub-agent line's key, scrolled into view first (the composer now floats over the list, KitComposer.layer).
  - lead blocks found by `assistant-text-block` → `team-conversation-lead-reply` (the lead is a KitMessage.reply, not the chat's message view).
  - "one line of the reply, height < 64" → the task sits under the title line (KitToolRow.agent draws who and state on one line, the task under it).
  - the Needs-you test also checks the header's needs-you marker.
- Goldens changed (each opened and looked at): all new.
  - `test/revamp/goldens/chat_4_command_launcher[_1280x800]_{dark,light}.png`: the launcher sheet with its tabs, search and named actions.
  - `test/revamp/goldens/chat_4_command_launcher_no_match[_1280x800]_{dark,light}.png`: "Nothing matches “deploy”" with Clear search.
  - `test/revamp/goldens/chat_4_team_conversation_working[_1280x800]_{dark,light}.png`: Now line, agent strip, prompt bubble, the lead's lines, "2 steps · 0 done" work line opened, furiosa's sub-agent line, composer with "Goes to furiosa · Worker through the AI Team".
  - `test/revamp/goldens/chat_4_team_conversation_needs_you[_1280x800]_{dark,light}.png`: header "Needs you · AI Team · On this phone", the lead marked needs-you in the strip, two earlier updates folded, the Decision card.
  - Approved render `docs/design/visual-language-2026-09-26/Chat.png` (EVID-12): same header shape (title, one state line, ⋯), end-aligned prompt bubble, prose on the start edge, work folded under one chip, attention card, glass composer pill. Differences: the team page adds the Now line and the agent strip under the header (team-conversation-2026-09-26); the composer has no model chip or "+" (a team gets words only); the page has no code block because a team task has no diff in its turn.
- Before and after (EVID-10): `before-command-launcher-sheet-commands.png`, `before-command-launcher-sheet-search.png` (from base census `docs/qa/screen-census/b2-chat-screen/`), `after-command-launcher-sheet-commands.png`, `after-command-launcher-sheet-no-match.png`; team conversation: no before render (census has it as codeOnly), `after-team-conversation-working.png`, `after-team-conversation-needs-you.png`.
- Accessibility: agent chips read "{name}, {role}, {state}" with the hint "Open {name}'s conversation" (KitAgentStrip); the lead chip is not a button; sub-agent lines keep the hint "Open conversation"; the composer field is labelled "Message the team…" and a read-only composer says why; targets are the kit's 48 dp. 200 % text not re-checked in this unit (the parts' own galleries cover it).
- Privacy and security: the watching-mode message sheet now keeps unsent words with KitDraft under `oc.draft.team-message.<agentId>.<profileId>`, a per-profile key the profile-deletion sweep finds (`oc.<what>.<profileId>`); nothing else stored; no links or notifications changed. The team conversation's draft lives in memory only.
- Migration: n/a: no stored format changed (one new per-profile draft key, created on demand).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/team_conversation_screen_test.dart test/revamp/chat_4_test.dart
$F test -j 1 test/revamp/chat_4_golden_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart && git diff test/kit_ratchet_baseline.json; git checkout test/kit_ratchet_baseline.json
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator; the keyboard lifting KitComposer over the team transcript is not proven on a phone.
- The shared suites that open the team conversation were not run (owner decision); `test/team_one_page_test.dart` reads the title with `tester.widget<Text>(team-conversation-title)`, which is now a KitTopBar semantics node and is expected to fail there (listed for the integrator). `test/team_agent_chat_test.dart` (watching-mode message) should still pass through the same field and send keys but was not run.
- The "agent commands unavailable" notice in the launcher has no widget test.
- Arabic and right-to-left were not reviewed (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/chat-4` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `5a8c7902` |
| Deployed | No | |
| Released | No | |
