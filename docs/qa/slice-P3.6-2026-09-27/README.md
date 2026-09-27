# slice-P3.6: A worker is its conversation (2026-09-27)

Branch `revamp/slice-P3.6`, from `feat/phone-setup-v2` at `42d3932d`. CHAT lane: this slice owned the chat library (`chat_screen.dart`, `chat/**`, `kit/chat/**`).

**Finish line.** Tapping a worker opens the chat in watching mode. This works from the family strip, the agents list, a gate's "Watch the agent", the cycle strip and the planner's card. When the session store cannot be read, the page shows the team's live output. Messaging a worker happens in the conversation's composer. team-agent is a short status page whose one action opens the conversation.
**Non-goal.** No lead agent.

## What changed, per page

### team-agent-output: removed (merged into chat, watching)

- `lib/ui/screens/team/agent_output_screen.dart` is deleted. No route pushes a "Live output" page.
- The fallback is now `TeamWatchLiveScreen` (`lib/ui/screens/chat/team_watch_live.dart`, a chat part). It is the chat's watching page with the live output as its transcript:
  - the same status line, from the session;
  - the same composer;
  - the same "About furiosa" action.
- The title is the task the worker is on (the map's infoMissing: "which task this output belongs to"). With no task, it falls back to "Live output".
- Kept from the old page:
  - follow-latest and Jump to latest;
  - Copy output;
  - the not-running action (Start furiosa / Why);
  - the 8 s rule ("Starting up · 3 min so far…").
- The reason it is the live output (`teamWatchFallback*`) is now the transcript's first line. It scrolls away, so it no longer squeezes the composer on a small window.
- Every door now goes through `openTeamAgentConversation` / `openTeamAgentConversationById`: the session in watching mode when it can be found, otherwise the live page. The doors:
  - the strip;
  - the worker line;
  - the agents list;
  - the Work sheet;
  - gate "Watch the agent" (was "View logs");
  - cycle strip "Watch the agent" (was "Open agent output");
  - planner card "Watch the planner" (was "Planner output").

### team-agent-message-sheet and chat-watching-message-sheet: removed (merged into the conversation composer)

- The watching page's composer is now a real `KitComposer`, "Message furiosa…". Its words go through the team's message control (`messageAgent`), never into the watched session.
  - The field clears only when the team takes the words.
  - The message's receipt sits above the composer (Sent → Confirmed, or the refusal with Try again).
  - The words are kept as a draft per worker and server: `oc.draft.team-message.<agentId>.<profileId>`, the same namespace the old watching sheet used. They survive leaving the page.
- A team that takes no messages shows "This team can't be messaged from here." in the composer.
- The old "Message fox" secondary, its sheet and its draft target `team-agent-message.<id>` are gone from the agent page.

### team-agent: a short status page

- The one pinned action is **Open conversation**. The "Live output" primary, its overflow item and the Message secondary are gone.
- When no session matched, the note under the action still says why, and the action opens the live page.
- Opened from here, the conversation offers no "About" action, so Back is the way back and nothing loops.
- The state, controls (Pause, Nudge, Restart, Stop), receipt and Technical details are unchanged.

### team-agents

- A row now opens the worker's conversation (map rationale). Its page is the conversation's top-bar action **About furiosa** (`chat-watching-details`).

### Chat watching mode (`chat/watching.dart`)

- The status line reads the worker's state from its session (`teamSessionState`, ledger row 21), for example "Watching furiosa · Worker · Working". It follows the session while the page is open: when the session stops, it reads "· Stopped".
- `ChatWatch` changed: `banner` is now a reader, and it gains `hint`, `onSend`, `draftId`, `receipt`, `changes` and `onDetails`. It lost `note` and `messageLabel`.

### Kit: `KitComposer.layer` (`kit/chat/kit_composer.dart`)

- The composer can no longer grow past the room. On a 320 dp window at 2.5× text it scrolls within the room, with the field and Send kept in view, instead of overflowing by 198 px (found by `team_agent_screen_test` "320dp 2.5x: the output page fits").
- Nothing changes when it fits: the pixel diffs of the chat goldens match base exactly, apart from the copy change below.

### Chat call sites left by merged slices

1. **P6.7**: `AlwaysAllowInvitation` sits directly under the permission card, keyed `always-allow-<requestId>` (not in the demo).
2. **P10.4**:
   - `_openVoice()` opens `showVoiceAutomaticSetupSheet(context, voice)`.
   - `_ensureSpeechReady` picks `readAloudVoiceForLocale(...)` before the choice sheet unless the person asked for "Read with another voice".
   - The consent button `readAloudContinue` said "Choose voice", but after this change no choice follows. It now says **Read aloud**.
3. **P3.5 leftover**: the team conversation's AI Team button opens the one team page (`openTeamPage`). A task row there comes back to this same conversation; `TeamPage` and `openTeamPage` gained `onOpenRun` for that. A team that is not the connected server's opens its home directly, as before.
4. **G11 copy**: all three titles now have four words or fewer, and their `ui_glossary_baseline.json` entries are removed.
   - `teamChatRefusedTitle` is "Task not taken".
   - `teamChatGoneTitle` is "Task no longer listed".
   - `chatRequestAlwaysTitle` is "Always allow these requests".

### Copy (English, `app_en.arb`; gen-l10n run)

- New: `teamWatchComposerHint`, `teamWatchComposerHintWorker`, `teamWatchComposerHintAgent`, `teamWatchAbout`, `teamWatchAboutRole`.
- Changed: `teamWatchBanner` and `teamWatchBannerRole` now carry `{state}` instead of "AI Team". The three door labels and the G11 titles are listed above.
- Deleted from en and ar, now unused: `teamWatchNote`, `teamWatchNoteNoMessage`, `teamWatchMessageWorker`, `teamWatchMessageAgent`, `teamAgentScreenMessageLabel`, `teamAgentScreenMessageFirst`, `teamUiControlMessageHint`, `teamUiControlMessageTitle`, `teamUiControlMessageSend`, `teamUiAgentOutputEmpty`.

### Ledger, map and census

- `docs/design/ui-ledger/parts`: team-agent-output and team-agent-message-sheet are removed, and chat-watching-live is added (in b1). The team-agent, team-agents, gate, cycle and planning targets are updated.
  - team-agent-reassign-sheet was removed too: its code was deleted by an earlier slice and its line refs had gone stale.
- `ledger.json`, `pages.md` and `navigation.md` were rebuilt, and `gesture-audit` was updated.
- `check_ui_ledger.py`: 181 errors, against 183 at base.
- `tool/capture/census`: the i1 shots now render `TeamWatchLiveScreen`, and the message-sheet shot is gone. The c_chat read-aloud voice shot now reaches the sheet through "Read with another voice". The census was not re-run, because it rewrites `docs/qa/screen-census`.

## For the coordinator

- `docs/ux-system/map/team.json` still lists team-agent-output and team-agent-message-sheet, and `tool/ux/check_kit_map_baseline.json` keeps their entries: G13 reads them from the map. P3.5 did the same for team-run. Map edits belong to the map owner.
- The census still has a 'team-agent-reassign-sheet' shot for a page that no longer exists.
- Files outside the chat library that were touched minimally:
  - `team/gate_sheet.dart`, `team/start_run_sheet.dart`, `widgets/team_cycle_strip.dart` (the doors);
  - `team/team_agents_screen.dart`, `team/agent_screen.dart` (the seeded page's neighbours);
  - `team/team_page.dart` (`onOpenRun`);
  - `tool/capture/census/areas/{i1_team_core,c_chat_compose}.dart` (kit-hygiene owns `tool/capture/**`; only compile and flow fixes here).

## Tests

**New: `test/revamp/slice_p3_6_test.dart`, 7 tests, all pass.**

- An agents-list row opens the watching conversation. "About" opens the agent page, whose Open conversation comes back without a loop.
- The status line follows the session (Working → Stopped).
- The live page is titled by its task. Its composer sends once, shows the receipt, and keeps and clears its draft (`oc.draft.team-message.<id>.phone`).
- A team without messaging says so in the composer.
- AI Team opens `TeamPage`, and the task's row comes back to the one conversation.
- **P6.7**: the third identical ask shows the invitation under its card.
- **P10.4**: the first mic tap without a model opens `voice-auto-setup`.

With the call-site lines reverted, the last two tests fail; that check was run.

**Migrated to the new behaviour:**

- `team_agent_chat_test`, `team_agent_chat_render_test` (plus a `TEAM_CHAT_CAPTURE_WIDE` switch), `team_agent_screen_test`, `team_controls_test`, `revamp/screen_team_1_test`.
- `team_cycle_test`, `team_gate_answer_test`, `team_now_test`, `team_conversation_screen_test`.
- `support/team_golden_fixture`, `design_standard_test` (the grandfathered count is now 57, and the baseline entry is dropped), `kit_ratchet_baseline` (agent_output entries dropped), `search_index_test`.
- `read_aloud_test`: its helper now uses the footer's More, which also fixes two tests that failed on base. It gains a test that no matching voice asks.
- `voice_reply_pipeline_test`.

**Regenerated goldens:**

- `team_agent_output_{dark,light}`, now the live watching page;
- `chat_5_permission_sheet_*` (copy).

**Compared with base `42d3932d` in a second worktree. No new failures.** The failures that remain also fail on base:

- `team_agent_screen_test`: the header test and 4 × "agent detail fits".
- `team_controls_test`: 17, against 19 on base.
- `team_now_test`: 3.
- `team_gate_answer_test`: 4 × 320dp layout.
- `design_standard_test`: `team_agent_controls` goldens.
- `chat_states_standard_test`: 2.
- `architecture_boundaries`: ARCH-1 and ARCH-2.
- `ui_ledger_coverage`, `gesture_audit`, `search_index`: 3.
- `voice_reply_pipeline_test`: 20.
- `read_aloud_test`: 1.
- Chat goldens `chat_3/4/5` and `screen_chat_3`: the same 58 stale on both sides, with identical pixel diffs apart from the permission sheet copy.

**Gates:**

- These pass: `kit_ratchet` (G16 and G17 included), `ui_glossary` (G11 and G28), `redaction`, `no_raw_error_text`, `kit_manifest`, `kit_draft_manifest`, `l10n_coverage`.
- `flutter analyze` on the whole repo: no issues.

## Images

The phone captures are 412 × 915 and the wide ones 1280 × 800, all with the app's fonts, from `team_agent_chat_render_test` (`TEAM_CHAT_CAPTURE_DIR`).

| | Before | After |
|---|---|---|
| Worker conversation (watching) | `before-watching-chat-{phone,wide}.png` (a "Message the worker" button that opens a sheet) | `after-watching-chat-{phone,wide}.png` (a composer, the state from the session, About furiosa) |
| Live output fallback | `before-live-output-fallback-{phone,wide}.png` ("Live output" page) | `after-live-output-fallback-{phone,wide}.png` (the watching page, titled by the task) |
| Agent page | `before-agent-screen-open-conversation-{phone,wide}.png` | `after-agent-screen-open-conversation-{phone,wide}.png` (one action) |

Also here: `after-live-output-golden-dark.png` (a streaming worker) and `after-permission-sheet-copy-dark.png`.

## What still needs a device

- The unit's proof: on the emulator or the owner's phone (read-only adb), watch a live worker. That means:
  - tap it on the agents list;
  - see "Watching … · Working" follow its session;
  - message it from the composer and see the receipt confirmed;
  - on a computer-hosted team, see the live page instead.
- The first mic tap now running the automatic voice setup (P10.4's device list).
- The third identical bash ask showing "Always allow" under the card (P6.7).

## Shipping states

- Implemented: yes.
- Committed: locally on `revamp/slice-P3.6`.
- Verified: by the tests above, not on a device.
- Enabled, deployed, released: no.
