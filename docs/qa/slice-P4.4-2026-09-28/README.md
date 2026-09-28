# slice-P4.4 One connection status — 2026-09-28

Finish line: the app shows **one** status line per window, in each KitScreen's
status slot, fed by the controller's one connection snapshot
(`ConnectionController.connectionStatus`, Codex backend:
[codex-status-2026-09-28](../codex-status-2026-09-28/README.md)). The chat's,
the team pages' and the app's own lines (update ready, share waiting) go into
that same slot, so two lines never show at once.

Non-goal: no reconnect-engine rewrite; no new states in the controller.

## What was already in place (Codex, merged before this slice)

The controller-owned snapshot and eight-second clock, `AppConnectionStatusScope`
above the navigator, `connectionKitStatus`, and the chat's own statuses already
contributing to `KitScreen.status` (the chat-9 header line was migrated by the
Codex merge; `connection-status-banner` / `chat-status-*` keys are the slot's
drawn line keys and still resolve). This slice closes the remaining gaps.

## What changed, per page

| Page | Before | After |
| --- | --- | --- |
| root-connecting (`main.dart` `_Root`, `SavedServerConnectionCard`) | The card ran its own `GraceTimer` (a second 8 s clock). The slot above it drew the connection line too: "Laptop isn't answering / Reconnect" over "Could not connect / Try again" (said twice). | The card escalates on the controller's clock (`notAnswering` from `connectionStatus`, only once an attempt began). Its KitScreen declares `bodySays: {connection}`: the card *is* the connection status, so the line shows the next condition down (a share waiting) instead. |
| connection-status-details-sheet (the line's Details) | Generic "Connection lost" + a paragraph + the raw error. | Same diagnosis as root-connecting's card (`ConnectionFailure.diagnose`): its title, explanation and "What to check" list; the raw error stays in the Details fold. The way out is named "Switch server" as on root-connecting (the unit's finish line); `e7BannerChangeServer` removed from both ARBs. |
| Team home, board, agents, agent (`team_states.teamStatusLine`) | Stale / refresh-failed / read-only lines drawn in the page header (a second line under a connection line). | Returned as a `KitStatus` into `KitScreen.status`; same keys (`team-*-stale`, `team-*-refresh-failed`, `team-board-read-only`). |
| Worker live output (`chat/team_watch_live.dart`) | `chat-watching-banner` drawn in the header. | In the slot (same key); a connection or app line outranks it. |
| Kit | — | `KitScreen.bodySays` → `KitStatusLineSlot.omit`: app-wide condition kinds a page already says are not repeated. Tested in `test/kit/kit_status_slot_test.dart`. |
| Composer (`kit/chat/kit_composer.dart`, KIT-24 follow-up) | With KIT-24 the delivery choice stacks as radio rows; at 200 % text on 320 dp the composer overflowed by 40 px. | The note / delivery / suggestions / attachments area scrolls and gives its room to the field and the send row when the height is bounded. No truncation; `kit_composer_test` "200 % text at 320 dp" passes with its overflow assertion. |

Ledger row 22 ("Connecting…" forever): the root card and every status line
now escalate on the controller's single 8 s clock; the worker live page already
escalated after 8 s (P3.6). No surface keeps "Connecting…" without a clock.

## Audit2 fixes (docs/qa/codex-audit2-2026-09-28)

- **A2** — `task_details_sheet.dart`: every timeline line (activity summaries,
  request errors, and composed sentences with server-derived names) goes
  through `KitRedact.text` at the presentation boundary.
  Test: `team_task_details_test.dart` "what the host reported is redacted"
  (registered opaque secret + a named `ghp_` token; neither renders).
- **A4** — `chat/watching.dart`: the send captures the edit revision; an
  acknowledgement clears the field and its draft only when nothing was typed
  since. Newer words stay and their draft is saved. Tests in
  `test/revamp/slice_p4_4_test.dart` (typed-on, edit away and back, refused,
  untouched).

Both regression tests were run against the unfixed code and fail there
(A2, A4, and the `bodySays` slot filter each reverted in turn).

## Chat perf (docs/qa/codex-perf-2026-09-28/chat.md)

Probe: `test/perf_chat_test.dart` (Codex's harness, unchanged), pinned
Flutter, serial, through `tool/qa/machine_lock.sh`. Debug widget-test CPU
time, not device frames. The machine was shared (load 7–47), so timings are
noisy; counters are deterministic and unchanged.

Finding: instrumenting the harness showed the ChatScreen build, text merge and
turn derivation cost ~3–8 ms per token for the 5,000-fragment reply; the
seconds per frame were **semantics**: the reply's thousands of paragraph nodes
were recompiled with the whole turn on every frame (even frames with no
rebuild). In an instrumented copy of the probe, ten spaced tokens took 43 s
with semantics on and 7.7 s with it off.
Fixes applied:

1. `KitMarkdown` is its own semantics boundary
   (`Semantics(container: true, explicitChildNodes: true)`); each block stays
   its own node for a screen reader. This is the fix that moves the numbers.
2. Codex fix #1: `_mergeTextParts` is linear (tracks the trailing newline
   instead of `buffer.toString()` per fragment). Parity oracle tests in
   `slice_p4_4_test.dart` (whitespace-only, CRLF, newline edges, split fence,
   5,000 fragments, first-part identity).

Codex fixes #2 (turn-derivation cache) and #3 (delta index) were not built:
measured, they cost milliseconds per 10 tokens (display 26–88 ms, owners
28–64 ms, token dispatch 0–23 ms for 10 tokens), against seconds of
semantics. #4 (virtualizing one giant reply) is no longer needed for the
measured case.

Three alternating runs each (base = `feat/phone-setup-v2` tip in a detached
worktree, after = this branch; load average 3.4–9.2), medians with the three
samples in brackets. "Load" is hydration + initial pumps.

| Shape | Parts | Batch | Load ms before → after | Pump ms before → after |
| --- | ---: | --- | ---: | ---: |
| one part per message | 1,000 | ten spaced | 674 → 606 | 827 → 730 (827, 664, 828 → 1475, 730, 694) |
| one part per message | 1,000 | 100 burst | 674 → 606 | 74 → 58 |
| one part per message | 5,000 | ten spaced | 278 → 248 | 772 → 636 (822, 560, 772 → 1199, 636, 602) |
| one part per message | 5,000 | 100 burst | 278 → 248 | 74 → 69 |
| one fragmented reply | 1,000 | ten spaced | 675 → 591 | 739 → 377 (736, 739, 805 → 597, 377, 344) |
| one fragmented reply | 1,000 | 100 burst | 675 → 591 | 76 → 41 |
| **one fragmented reply** | **5,000** | **ten spaced** | **5,784 → 3,139** | **12,003 → 1,102** (14105, 11726, 12003 → 1593, 1102, 1071) |
| one fragmented reply | 5,000 | 100 burst | 5,784 → 3,139 | 1,140 → 114 |

The headline case (Codex measured 15,988 ms for ten spaced tokens) is ~11×
faster, the burst ~10×. The separate-message cases were already bounded by
message virtualization and are within noise. An earlier pair on this
branch's pre-merge base under heavier load (13–30) measured the same case at
85,607 → 1,064 ms.

Rebuild/parse/flush counters are identical before and after in every case
(10 screen builds, 10 Markdown parses, 10 flushes for ten spaced tokens; 1/1/2
for the burst; 190/19 turn callbacks for separate messages).

## Evidence images (Flutter golden renders, not device screenshots)

- Root-connecting with a share waiting — phone dark:
  [before](before_root_share_waiting_phone_dark.png) (line and card both say
  the server is down) → [after](after_root_share_waiting_phone_dark.png) (the
  card says it; the line says the share waits). Wide light:
  [before](before_root_share_waiting_wide_light.png) →
  [after](after_root_share_waiting_wide_light.png).
- The line's Details — phone dark:
  [before](before_details_sheet_phone_dark.png) →
  [after](after_details_sheet_phone_dark.png); wide light:
  [before](before_details_sheet_wide_light.png) →
  [after](after_details_sheet_wide_light.png).
- Updated goldens: `test/revamp/goldens/coord_main_share_waiting_*.png`.

## Tests

New: `test/revamp/slice_p4_4_test.dart` (17: one line with chat + update +
connection; card keeps no clock; `bodySays`; Details diagnosis; merge parity;
A4), `test/kit/kit_status_slot_test.dart` (+1 omit), `test/team_task_details_test.dart`
(+1 A2). Migrated: `coord_main_golden_test` (share waiting),
`work_tab_cleanup_test` item 10, `motion_setup_test` not answering,
`goldens/work_tab_golden_test` not answering (card fed `notAnswering`),
"Change server" → "Switch server" in four tests.

Every existing test file for a changed file was run on this branch and on
the integration tip in a separate detached worktree; failure sets were
compared by name. **No new failures.** Pre-existing failures (same names on
the base): chat_live_events 32, home_navigation 20 (incl. the two
destination-motion cases now failing on the tip), work_tab_golden 22 (whole
file), kit_composer_golden 30, kit_screen_golden 9, kit_markdown_golden 8,
markdown_reading 15, stable_chat_layout 7, chat_transcript_placement 4,
markdown_streaming 1, v2_transcript_rows 1, team_controls 16, team_home 9,
team_home_layout 1, team_agent_screen 5, team_now 3, team_gate_answer 4,
team_task_details 1, motion_setup 5, e7_setup_layout 2, shared_shell_1 4,
launch/session/share routing 5, text_scale_overflow 1 (KitComposerChips).
Fixed by this slice: `kit/kit_composer_test` "200 % text at 320 dp".

Gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text, kit_manifest,
kit_draft_manifest, credential_ingress_redaction, team_storage_redaction pass.
`flutter analyze`: no issues.

## Still needs a device

Emulator proof of the unit (stop the server, watch the stages and the 8 s
escape on root-connecting and in a chat; restart it) was not run. TalkBack on a
long streamed reply (the semantics boundary) was not checked on a device.

Known, not changed here: the team home's in-list Now/heat line
(`team_now_line_view`, P5.1) is a `KitStatusLine` in the list, so with a
connection line in the slot the window draws two lines (KitScreen's debug
check would flag it). Moving the Now block into the slot changes P5.1's
decision to let it scroll with the list; left for the team owner.
