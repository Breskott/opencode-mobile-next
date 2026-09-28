# slice-P10.1-2 (2026-09-28)

Chat lane. Branch `revamp/slice-P10.1-2`, base `feat/phone-setup-v2` at
`4308b155`. Units P10.1 "Command sheet with per-backend catalogues" and
P10.2 "Session menu: Go to / Do".

Finish line: one command sheet shows the current backend's commands in
plain words, grouped and searchable, and runs them in the conversation; the
Library's Commands tab and the chat's "/" are that sheet; a backend that
does not share its commands is named, never faked; the conversation menu is
one KitMenu with "Go to" and "Do", the same menu from a Work row, and every
fork lands in the copy. Non-goals: plugin command links (removed in P3.1),
new actions, a Paseo or Codex command adapter (below).

## Feasibility (P10.1, done first)

Built on `docs/qa/codex-p101-2026-09-27/README.md` (Codex, read-only
checkout of the adapters and the daemons' schemas) and re-checked against
the current adapters.

| Backend | List commands | Run a command | "!" shell | In the app now |
| --- | --- | --- | --- | --- |
| OpenCode 1 | `ProductRepository.listCommands()` (`GET /command`) | `OpenCodeApi.slashCommand()` | `OpenCodeApi.shell()` | listed, run in the conversation; "!" runs |
| OpenCode 2 | `Api2Operations` → `client.commands()` | `Api2Gateway.slashCommand()` (`{command, text}`) | `Api2Gateway.shell()` | same as OpenCode 1 |
| Claude Code (Paseo 0.8.0, protocol 1) | none callable: `PaseoGateway.listCommands()` returns `[]`; newer daemon source (0.9.x) has `list_commands_request` per agent, not verified against the pinned protocol | typed unavailable fallback | none (`terminal: false`) | **named as missing**: "Claude Code commands unavailable … can't list them, run them, or run ! shell commands"; a typed `/compact` or `!ls` is not sent |
| Codex (app-server 0.153.4) | no catalogue in the public client union; native `thread/compact/start`, `review/start`, `skills/list`, `thread/shellCommand` exist but are unmapped and unproven | typed unavailable fallback | none | **named as missing**, same copy with "Codex"; nothing sent |

Gate: new `ServerCapabilities.slashCommands` (true by default, false in
`lib/paseo/gateway.dart` and `lib/codex/gateway.dart`). The UI never reads
the backend kind to decide; the backend's name is used only in copy
(`commandSheetAgentName`, as the composer already did). Blocker for real
Claude Code / Codex catalogues (not built, per AGENTS.md rule 2): a
version-matched, live-proven list → run → output contract for each daemon
(Codex queue item; see the Codex record's "Required next proof").

## What changed

**Command sheet (P10.1)** — `lib/ui/widgets/command_sheet.dart`
(`CommandSheet`, `CommandSheetEntry`, `serverCommandEntries`):
- One sheet for the chat ("/" inline "show all", the "+" Commands row,
  Ctrl+K) and Settings › Tools › Commands & tools › Commands (the tab now
  embeds the same `CommandSheet`). Same search, same grouping, same rows.
- The server's commands lead, under "Commands from <server>", in plain
  words: the description is the title, `/name` the typing hint, "Runs with
  <agent>" under it; a server row's long-press copies `/name`. Enter in the
  search runs the best match (PC).
- In a chat a pick runs in that conversation; in the Library it asks which
  conversation (most recent first) and opens it there.
- Lists commands only: the conversation menu's acts (changes, context,
  share/unshare, rename, timeline, fork, compact) are no longer listed but
  still run when typed. What left the old menu is a command now: Run shell
  command, Retry last prompt, Note for the agent, Approvals, Reload
  messages, Tasks (`/plan`).
- `!command` in the composer runs in the conversation's shell (same call
  as Run shell command; its output is the transcript's shell step).
- Failures: "Couldn't load commands" / "Couldn't refresh" with plain words,
  technical text under Details, Try again.
- The chat's private `_CommandLauncherSheet` and `_ChatCommand` class are
  gone (`command_launcher.dart` keeps the action enum and a typedef).

**Conversation menu (P10.2)** — `lib/ui/widgets/session_menu.dart`
(`sessionMenuItems`, `SessionMenuOffer`, `SessionMenuAction`):
- The chat title bar's overflow (tooltip "Conversation menu") is one
  KitMenu: **Go to** Changes, Timeline, Find (Ctrl+F shown on PC),
  Subagents, Details; **Do** Share / Stop sharing, Compact context, Fork
  conversation, Rename conversation, Continue on computer, Open on another
  phone, each "Do" with its one line. Gated on `ServerCapabilities`.
  The old bottom sheet `SessionMenuSheet` is deleted.
- Fork lands in one place: menu Fork, `/fork`, a prompt's Fork and the
  timeline row's Fork all replace the chat with the copy
  (`_landInFork`); `/fork` no longer opens a timeline picker.
- Work row menu = the same items (plus the row's own Review, Open, Pin,
  Archive, Delete). Details, Share, Stop sharing and Rename run on Work;
  the rest open the chat with `ChatRouteArguments.menuAction` and the chat
  runs the pick once its history is in (wide window: the detail pane).
- Team conversation menu: Task details under Go to, Refresh under Do,
  Stop task last (confirms).
- Lane hand-off taken: a Work row that needs you lands on the waiting
  request's card (`landOnRequestID`, phone route and wide detail pane).

**Kit** — `KitMenuGroup` (a named `KitMenuItem.group` draws a header,
never focusable; KitMenu.md) and `KitTopBar.menuLabel` (the overflow's
tooltip/semantic name when it is one thing's menu; KitTopBar.md).

**Strings** — 26 new `sessionMenu*` / `commandSheet*` keys; 21 keys the
slice made unused deleted (en and ar). The display toggles stay in
Settings › Appearance and as `/thinking`, `/timestamps`.

**Single-owner touches** — `lib/domain/server_gateway.dart` (one flag),
`lib/main.dart` (one line: pass `menuAction` into `chatLandingPage`),
`lib/paseo/gateway.dart`, `lib/codex/gateway.dart` (one flag each).

## Tests

- New: `test/revamp/slice_p10_1_2_test.dart` (8: menu from capabilities,
  headings order, fork from menu and `/fork`, sheet lists commands only in
  plain words and runs one, Library tab is the same sheet, Codex named and
  `/compact`/`!ls` not sent, `!ls -la` runs the shell, Work row same menu
  hands Fork to the chat); `test/kit/kit_menu_test.dart` +2 (layout
  headings, header semantics/no focus); `test/chat_menu_hierarchy_test.dart`
  rewritten for the new menu (order, 320dp/2.5x reachability).
- Updated to the new doors (the tests assert the same behaviour): 17 files
  (chat_live_events, calm_chat_disclosure, codex_chat_capabilities,
  e7_session_approvals_layout, release_blockers, screen_library_4,
  screen_work_1 (+golden steps), projects_screen, safety_confirms,
  session_pins, stable_chat_layout, transcript_search, undo_from_here_flow,
  v2_feature_gating, chat_8). Goldens refreshed only where this slice
  changed the picture: chat_states (overflow icon) ×10, chat_4 command
  launcher ×8, chat_5 permission sheet ×4.
- Affected sweep: 184 test files (every file touching the chat, Work,
  Library, KitMenu/KitTopBar, routes, plus the gates) in 4 serial chunks,
  `flutter test --no-pub --concurrency=1`. 262 failing tests, all failing
  identically on the base `4308b155` (temporary base worktree): golden drift
  (kit_menu, kit_scanner, kit_screen, work_tab, screen_library_1–4, …),
  library_commands ×3, chat_8 validation copy ×2, e7 approvals 320dp ×6,
  calm_chat Context capsule, etc. **New failures: 0.**
- Gates green: kit_ratchet (G1 chat_screen showModalBottomSheet 3 → 2),
  ui_glossary, redaction, no_raw_error_text, kit_manifest,
  kit_draft_manifest, architecture_boundaries. `flutter analyze` clean.

## Images

Phone 412×915 and wide 1280×800, dark, real fonts, the same steps on base
and slice: `before_*` / `after_*` for `conversation_menu`, `command_sheet`,
`command_sheet_codex`, `library_commands`, `work_row_menu`;
`compare_*_412x915.png` side by side.

## Still needs a device / not done

- Emulator proof (unit proof line): run a command from the OpenCode 1
  catalogue and show the Paseo sheet naming the gap; menu screenshots.
- Claude Code / Codex catalogues: blocked on the contract above.
- The timeline sheet still carries its unused fork-mode branch
  (`_TimelineSheet.forkMode`, always false now); remove with P3.7a/R11.
- Global Sessions rows keep their own menu (the unit asked for Work).
