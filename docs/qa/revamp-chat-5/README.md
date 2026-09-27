# revamp-chat-5: Chat requests on the one card (2026-09-27)

## 1. Scope

- Unit: `chat-5` (wave 2c, screen-revamp, absorbs slice-P4.1b). Finish line: chat's permission, question and form requests are the one `KitRequestCard.ask`, answered in place where the answer is common, with Details opening the one request sheet and a receipt after every answer; every file in the write set has zero G1, G16, G7 and look-pattern counts. Non-goal: no gateway call, controller field or stored format added; no team gates (P4.1c); the session-menu and voice redesigns wait for their slices.
- Files changed: `lib/ui/screens/chat/{approvals_sheet,attention_card,empty_chat,form_flow,permission_sheet,voice_conversation}.dart`; `lib/ui/screens/chat/timeline_sheet.dart` (deleted the now-unused `_SessionSheetRow`, coordinator ruling on unused declarations); `lib/l10n/app_en.arb` and generated `app_localizations*.dart`; tests `test/revamp/chat_5_test.dart`, `test/revamp/chat_5_golden_test.dart` (+16 goldens), and the write-set tests `test/chat_permission_test.dart`, `test/chat_question_card_test.dart`, `test/chat_form_test.dart`, `test/permission_sheet_test.dart`, `test/chat_empty_start_test.dart`.
- Pages (map ids): embedded-auto-approval-indicator, embedded-permission-attention-card, embedded-question-attention-card, embedded-voice-conversation-controls, permission-sheet, permission-sheet-always-dialog, session-approvals-sheet, session-menu-sheet.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-15, KIT-16, KIT-30, KIT-33, KIT-34, KIT-38, KIT-41, LOOK-4, LOOK-5, LOOK-24, STATE-8, STATE-9, STATE-10, DATA-1, DATA-2, MAP-1, COPY-30; kit-api KitRequestCard.md and KitRequestSheet.md; visual-language §1, §5 (Chat.png).
- Contract problems (PROC-20):
  - The task text says new copy goes to `app_en.arb` AND `app_ar.arb` (R04); the owner decision of 2026-09-27 drops Arabic. The later owner decision was followed: 15 new keys in `app_en.arb` only.
  - KitRequestSheet has no slot for "From tool call" (the old sheet's source chip) and does not show the card's `detail`; the chip was removed (see "Moved or removed" below). No change to the kit was made.
  - `chat_screen.dart` (the call sites of the cards, the composer status strip and the session-menu host) is outside the write set. The cards reach the chat's controller with `findAncestorStateOfType<_ChatScreenState>()` (same library), and the approvals indicator stays a chip in the existing strip instead of moving onto a `KitStatusLine` (the map's proposal for embedded-auto-approval-indicator).
- New kit parts (KIT-3): none.
- Moved or removed (owner rule 2026-09-27, rethink):
  - Permission card: "Review" (a second step for every approval) is replaced by Allow once and Reject in place; "Details" opens the sheet.
  - Permission sheet: the separate "Confirm broader access" dialog (permission-sheet-always-dialog) is gone; "Always allow requests like this" is a risky switch in the sheet that states its scope in one sentence before anything is sent (KIT-30). "Always allow" is never on the card.
  - Permission sheet: the "From tool call" chip is removed; the card already sits in the conversation under the tool call it asks about. `onShowSource` is kept on `showPermissionSheet` and `PermissionSheet` for their callers (KIT-43) and documented as not drawn.
  - Permission sheet: the full-screen "See full diff" route is replaced by the read-only `KitDiffView` inside the sheet.
  - Provider retry: moved off the needs-you card (LOOK-4, it does not need the person) onto a working `KitNotice`.
  - Approvals sheet: the Close button is dropped (the sheet has its own Close); "Ask each time / Approve automatically" radios become one risky switch; the snackbars become an inline error notice.
  - Empty chat: the second, blinking caret beside the folder name is removed (the drawing already carries the caret; the screen now holds still).
  - Form "already answered elsewhere" snackbar becomes one `showKitAlert`.
- Map items (EVID-11):
  - embedded-permission-attention-card: Allow once inline → done (`chat_5_test` "Allow once answers a permission in place with one tap"); Reject inline → done (`chat_permission_test` "a failed reply keeps the card…"); Always allow from here via Details → done (`chat_5_test` "Details opens the one request sheet…"); count of other pending requests → done ("1 more request is waiting.", `chat_permission_test` "chat queues concurrent permissions…"); expired/answered-elsewhere while shown → the card leaves with the request (`chat_permission_test` "external resolution…"); diff size (+5 −2) on the card → deferred to slice-P4.1c (no field on the card today); "Waiting for you" work line → chat-1 (AUTO-15).
  - embedded-question-attention-card: clear send semantics (a tap sends and carries the receipt; typed text sends from Something else) → done (`chat_question_card_test`); answer failed → done ("Not accepted", `chat_question_card_test` "a failed answer keeps the card and says why"); converge with the OC2 form card → done (both `KitRequestCard.ask`, `chat_5_test` "an OpenCode 2 form is the same card…"); rename "More" → "Details"; Undo an answer → deferred (no withdrawal on the gateway, DATA-11); Dismiss / let the agent decide → deferred to slice-P4.1c (no reject call wired in chat).
  - permission-sheet: plain verbs → the title is the plain-words ask; answered elsewhere while open → closes itself (`KitRequestSheet` routes, `request_sheet_lifecycle_test` covers the old sheet); diff too large → `KitDiffView`'s own states; which conversation from Activity → the Activity caller's context label is the sheet subtitle; session-scoped middle step → deferred (the server offers once/always only).
  - permission-sheet-always-dialog: one plain sentence of what runs unasked and until when → done (`chatRequestAlwaysScope`, "Until I turn it off"); the safe choice is the stronger button → "Not now" stays beside "Turn on" in the risk step, and Allow once stays the sheet's one primary.
  - session-approvals-sheet: contradicting footer → the note swaps with the server-wide switch; error-toned server-wide row → risky switch look (LOOK-5); one leading edge → `KitRowGroup` of `KitSwitchRow`s; drop the Close button → done; paused because disconnected → done (`approvals-paused` notice, `approvalsUiPausedDetail`); revoke saved grants here → deferred (needs an import of `SavedPermissionsScreen` in `chat_screen.dart`, outside the write set); time-box auto-approval → deferred (no controller support; wave-2 non-goal).
  - embedded-auto-approval-indicator: paused reason and when it resumes → done (chip label "Auto-approve paused", spoken "…This phone is not connected. Automatic approval resumes when it reconnects."); how many approved → kept (the count on the chip); KitStatusLine / turn off in one tap → deferred to slice-P4 status-line work (the strip lives in `chat_screen.dart`).
  - embedded-voice-conversation-controls (redesign): kit-only rebuild of today's layout, Listen is now the one primary, "Stop reading the reply" names what it stops; the composer-mode redesign is deferred to slice-P10.3 (`// revamp: redesign (slice-P10.3)` above the builder).
  - session-menu-sheet (redesign): kit-only rebuild (chips, `KitExpandRow`s, `KitRow`s); the Go to / Do menu is deferred to slice-P10.2 (`// revamp: redesign (slice-P10.2)` above the class).
- States per page (STATE-20): permission card waiting / sending / refused → `chat_5_test`, `permission_sheet_test` "a reply is sent once and shows Sending…"; question card waiting / refused → `chat_question_card_test`; form card waiting / refused → `chat_form_test` "a 400 invalid answer…"; approvals sheet default / risk step → `chat_5_test`, `chat_5_approvals_sheet_*` goldens; empty chat → `chat_empty_start_test`.
- Deferred states (STATE-21): card `answered` / `answeredElsewhere` collapsed rows → the chat removes the card when the request leaves the pending list (owner: slice-P4.1c for an in-transcript receipt).

## 2. Builds

- Branch `revamp/chat-5`, base `86b19f8e` (feat/phone-setup-v2), code head: see `git log -1` on the branch.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/chat_5_test.dart` | passes | 6 passed | PASS |
| 2 | `test/revamp/chat_5_golden_test.dart --update-goldens` | renders | 16 rendered, each opened | PASS |
| 3 | `test/chat_permission_test.dart` | passes | 8 passed | PASS |
| 4 | `test/chat_question_card_test.dart` | passes | 11 passed | PASS |
| 5 | `test/chat_form_test.dart` | passes | 6 passed | PASS |
| 6 | `test/permission_sheet_test.dart` | passes | 7 passed | PASS |
| 7 | `test/chat_empty_start_test.dart` | passes | 11 passed, 4 failed; the same 4 fail on the base `86b19f8e` (chat-3's composer is a `TextFormField`, the tests cast to `TextField`; 2.5x/3.2x layout) | PRE-EXISTING |
| 8 | Ratchet (`KIT_RATCHET_WRITE=1`, baseline restored after) | write-set files at 0 in every gate | 0 in G1, G2, G7, G16, G17, G21, G48 for all six files; timeline_sheet dropped | PASS |
| 9 | `test/kit_ratchet_test.dart`, `test/l10n_coverage_test.dart`, `test/design_standard_test.dart` | no new failures | failures only in files this unit did not touch (kit parts' G21, quota_monitor_section G17, team_agent_controls goldens) | PRE-EXISTING |
| 10 | `dart analyze lib test` | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | KIT-30 | `test/revamp/chat_5_test.dart` "Details opens the one request sheet; Always allow states its scope before anything is sent" | run 1 |
  | STATE-10 | `test/permission_sheet_test.dart` "a reply is sent once and shows Sending until it lands" | run 6 |
  | DATA-1 | `test/revamp/chat_5_test.dart` "an OpenCode 2 form is the same card, and its answers survive closing and a restart" | run 1 |
  | KIT-30 (approvals) | `test/revamp/chat_5_test.dart` "the server-wide approval switch states its scope before it turns on" | run 1 |

- Changed test expectations (TEST-19): `chat_permission_test` (Review → Allow once in place; Always allow dialog → risk switch; "Reply failed" → "Not accepted"), `chat_question_card_test` (QuestionOptionRow → KitChoiceList rows; Send button → a tap sends / Something else; More → Details), `permission_sheet_test` (rewritten for the retired wrapper that now draws the card), `chat_form_test` (the refusal shows twice: in the form and on the card), `chat_empty_start_test` (no caret; off-screen starters scroll into view; bidi-isolated folder name).
- Goldens (new, each opened): `test/revamp/goldens/chat_5_{permission_card,permission_sheet,question_card,approvals_sheet}[_1280x800]_{dark,light}.png`. Against Chat.png: the card matches the frame, tile, caption, summary inset and side-by-side decide buttons; labels are "Reject"/"Allow once" (the kit defaults) where the render shows "Don't run"/"Run once"; the "Always allow…" line on the render is in the sheet (KIT-30).
- Before and after: `before-embedded-permission-attention-card-command.png` → `after-embedded-permission-attention-card-waiting.png`; `before-permission-sheet-always-dialog.png` → `after-permission-sheet-always-switch.png`; `before-embedded-question-attention-card-inline.png` → `after-embedded-question-attention-card-inline.png`; `after-session-approvals-sheet.png`.
- Accessibility: answers are kit buttons ≥ 48 dp (asserted at 1.0 and 2.5 in `permission_sheet_test`); the card announces once and carries its receipt in a live region (kit); the approvals chip keeps its full spoken label and names "paused" in words; request cards are capped at 45 % of the window and scroll inside (short windows, keyboard up). Arabic dropped by owner decision.
- Privacy and security: no credentials, links or notifications changed. The reject note is a `KitDraft` under `oc.draft.request.<id>.note.<profileId>` and the question's typed answer under `oc.draft.request.<id>.<profileId>`, both swept with the profile (key pattern `oc.<what>.<profileId>`); drafts are cleared once the answer lands.
- Migration: n/a: no stored format changed (new draft keys only).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/chat_5_test.dart test/revamp/chat_5_golden_test.dart
$F test -j 1 test/chat_permission_test.dart test/chat_question_card_test.dart test/chat_form_test.dart test/permission_sheet_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator, against OC1 or OC2 (P4.1b's emulator proof is coordinator work).
- Shared tests outside the write set that use the changed keys were not run (owner decision 2026-09-27); they are listed in the build record as likely broken.
- The "Waiting for you" work line (chat-1) and the collapsed answered row in the transcript.
- A failed answer given from the Activity or monitor sheet is recorded on the conversation's card only; those screens show the request still pending but not the refusal words.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/chat-5` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
