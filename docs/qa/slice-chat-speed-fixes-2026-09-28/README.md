# slice-chat-speed-fixes (2026-09-28)

Chat lane slice after P4.4. Branch `revamp/slice-chat-speed-fixes`, based on
`feat/phone-setup-v2` (merged up to `fba8d755`). Owner priority: "make the app
blazing fast, or at least feel like it".

Finish line: a chat opens with its own words on the first frame, an Inbox row
or a notification lands on the exact card, and the handed-off chat bugs pass
their tests unchanged. Non-goal: device proof, golden refresh outside the
chat kit, Inbox/Work layouts (P4.2b/P5.5).

## 1. Chat opens instantly (speed contract items 2 and 3)

- While the first history read is on its way, the chat shows the end of the
  conversation as it read last time (`ConnectionController.cachedSessionTail`)
  in the new chat kit part **KitTranscriptExcerpt** (spec
  `docs/ux-system/kit-api/KitTranscriptExcerpt.md`): prompts and replies laid
  out like the transcript, read-only, a quiet "Updated … · Refreshing" line,
  and the composer ready at once. The excerpt never enters `_messages`,
  pagination, pending-send reconciliation or copy. The live history replaces
  it (no duplicate turn); a failed read shows the plain load error; no saved
  excerpt keeps the placeholder turns.
- Chat hydration reads through `ConnectionController.loadSessionTail`
  (same scope checks, merge, anchor and pagination as before), so a prefetch
  on the opening tap and the chat share **one** HTTP read. Watching, the demo
  and hosts without a saved connected server read the gateway directly
  (`canLoadSessionTail`, one additive method in `connection.dart`).
- Prefetch on intentional taps: Work's conversation row, Inbox `_openChat`,
  Sessions (global, in parallel with its details check), Inbox feed rows.
- Item 3: a test pins the optimistic prompt on the first frame after Send
  with session selection and the request both held (`PERF_SEND
  tap_to_bubble_frames: 1`).

Numbers (debug test harness, synthetic): first frame shows saved text with
1 read in flight and 0 answered; prefetch + open = 1 read. `perf_chat_test`
counters identical to base (stream flushes 10/2, markdown parses 10/1, turn
rebuilds 190/19, 10/1, controller notifications 0); serial CPU 1000 parts
spaced 668 ms vs 731 ms base (noise band).

## 2. P4.2a Inbox rows land on the card

- `ChatRouteArguments(landOnRequestID:, landOnFailure:)`; `chatLandingPage` /
  `chatLandingRoute` (lib/ui/navigation/attention_landing.dart) build the
  `KitArrivalScope` once per page. The chat puts the target request first
  and marks it once (KitArrival wash, focus event); `landOnFailure` scrolls to
  and marks the newest failed turn.
- Doors: Inbox phone rows (permission, question, form) and the digest's
  Review; the question notification (`initialQuestionSessionID`);
  `openMonitoredRequest` (notifications and other servers' rows, including a
  failed run via `landOnFailure`); the P4.2b feed rows
  (`openAttentionItem` in attention_feed_rows.dart carries the landing).
  The wide Inbox keeps its detail pane; server-wide forms keep their flow.
- Team: gate cards in a task conversation are landable
  (`TeamConversation.route(landOnGateId:)`); a gate with no conversation
  opens the task conversation for its run or its Gate sheet; after a switch
  to another server it opens once that team has listed it (bounded wait,
  plain message otherwise). No run is taken for a task, no conversation is
  guessed.

## 3. Handed-off chat bugs (each failed first on the base, test unchanged)

| Test | Fix |
|---|---|
| nudge_moments ×2 (43 px overflow) | the request above the composer takes the height left and scrolls |
| demo_isolation compact large text + keyboard | `KitComposer.layer(aboveMinHeight:)` keeps 40 % for a waiting request; the demo's Review changes steps aside while its keyboard is up (`ChatScreen.hostKeyboardUp`) |
| voice_reply_pipeline late reply | Listen is secondary while a request waits (one primary) |
| release_blockers prompt editor at 320 dp 2x | with words in the field the composer keeps the caret handle's height above the send row (not in a short room) |
| text_scale_overflow KitComposerChips/narrow | glyph alone when glyph + chevron no longer fit 48 dp |
| offline_queue offline banner counts drafts | chat status line again counts waiting drafts; connected, drafts for another server get "Move N waiting prompts to X" (showQueuedPromptMoveSheet) — new test |
| team_task_details newest first | stale test copy: "What the server reported" (copy rule a473c04a) |

Also: DiffPage replaces the diff_view shim (file deleted), Open on another
phone passes `SessionAddressOffer.of` (gated off).

## Tests

New: `test/chat_speed_test.dart` (7), `test/attention_landing_test.dart` (6),
`test/kit/kit_transcript_excerpt_test.dart` + gallery (6 goldens), one
offline_queue test. Updated for the P4.2a contract (they pinned the old
sheet): activity_screen ×2, activity_requests (opens the sheet directly),
screen_shell_1, release_blockers question sheet, product_ui_regression
permission wrap, background_notification question notification.

Affected-file sweep (136 files) against the base at the same integration
head (198 failing tests on the base, mostly golden drift): 38 of them pass
here (the handed-off tests and the refreshed composer goldens); the 7 this
slice first broke (tests pinning the old sheet, the glass flow, the
send-error golden) were fixed and rerun green; every other failure is the
same on the base. Gates pass: kit_ratchet, redaction,
ui_glossary, no_raw_error_text, kit_manifest, kit_draft_manifest,
architecture_boundaries, kit_motion, text_scale_overflow. `flutter analyze`
clean.

## Not done / hand-offs

- Composer `KitGlass(flow: true)`: reverted. Flow clips hit testing to the
  growing shape, so a control that just appeared (delivery choice, /unshare
  confirm) misses taps for the spring's length. Needs a kit_glass fix (hit
  test the full box during a flow) before the composer can flow.
- KitComposerChips `_zone` → `KitPressTracker`: the tracker is not merged yet.
- Work's "N need you" line landing: Work opens Inbox; its rows land.
- Not chat-owned, still failing on base: motion_setup ×5 (setup screens),
  shared_shell_1 embedded-connection-status-banner ×4 (connection banner).
- Kit ratchet: stale rows for deleted files (attention_overview,
  manage_project) cannot be tightened; the KIT-7 self-test needs a baselined
  MaterialPageRoute row (gate owner).
- One frame: the transcript and excerpt pad for the composer after the layer
  measures itself (existing layer behaviour).
- Device: open a long conversation on the phone twice (second open shows the
  excerpt), and answer a permission from a notification (lands on the card).

## Images

Phone 412×915 and wide 1280×800, dark, real fonts:
`before_chat_opening_*` (placeholder turns) → `after_chat_opening_*` (saved
words, composer ready); `before_inbox_request_tap_*` (sheet over the list /
detail pane) → `after_inbox_request_lands_on_card_*` (card first, marked);
`before/after_composer_with_text_412x915.png`;
`after_kit_transcript_excerpt_1280x800.png`.
