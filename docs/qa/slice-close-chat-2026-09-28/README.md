# slice-close-chat (2026-09-28): the chat lane's review-board closure

Branch `revamp/slice-close-chat`, from `feat/phone-setup-v2` (merged again at `cd3f9a48`: P9.10, close-team, close-security, close-misc, P2.4/5). Source: `docs/qa/review-board-closure-2026-09-28/README.md` (chat-area entries, gaps 9, 14, 17, 18, 21, 24, the chat lows, team-agent-output). That README's rows are updated: 11 pages move to done.

## What changed, per page

| Page | Before | After | Where |
|---|---|---|---|
| embedded-pending-sends-strip (owner note) | A queued message the server refused offered only Edit and Discard; its reason was the server's raw text. | The reason in the app's words ("Not accepted: The model provider is overloaded right now."); the bubble's one action is **Try again** ("Try all N again" for several); each refused item's ⋯ has Try again first. Sends at once, even with automatic sending off; offline there is no Try again. | `chat/message_view.dart` `_PendingSendsStrip`; `ConnectionController.retryQueuedPrompt` |
| embedded-prompt-error-banner | "Choose model" only; the failed prompt carried no mark. | **Use ⟨suggested model⟩ and resend** when the server's "Did you mean" names a model this server has (switches this conversation, sends the prompt again); **Send again** for other failures (not for context-full, sign-in, content filter, which keep their own fix); **Not answered** under the prompt. On the status line (server refused before any step) and under the failed turn. Only for the newest turn, only for a prompt of words alone (a resend from here cannot bring files). | `chat/chat_states.dart` `_suggestedModel`, `_promptErrorStatus`; `chat/message_view.dart` `_unansweredTurn`, `_AssistantErrorRow`; `chat_screen.dart` `_resendUnanswered` |
| chat-leave-unsaved-draft-sheet | The words said copy or retry; the only answers were Leave without saving and Keep editing. | **Copy draft and leave** (main), **Try saving again** (leaves once saved; "Still not saved. Copy your text before you leave." when it fails again), **Leave without saving** (danger, last). Back, Esc and a swipe keep editing. Without text: Try saving again is the main answer. | `chat_screen.dart` `_askLeaveUnsavedDraft` |
| chat-run-shell-dialog | One mono line; the start of a long command scrolled out of view. | The field starts at one line and wraps up to four, so the whole command reads. Enter and the keyboard's action run it; Shift+Enter adds a line. Kit: `showKitInputDialog(maxLines:)`, `KitField(minLines:)`. | `kit/kit_dialog.dart`, `kit/kit_field.dart`, `chat_screen.dart` `_runShellDialog` |
| chat (gap 17, decision delegated) | In a finished turn, text written before the last tool step folded under the work line, so an explanation could be hidden. | **Decision: fold only the work.** A finished turn gathers its tool and thought steps into one work line, and folds only *passing words* (one short line, or one line leading into the next step with a colon: "Looking into it.", "Now let me run the tests:"). An explanation (a second line, a paragraph, a code block, or longer than one short line) stays in view below the work line, before the closing words. A running turn is unchanged: its words and steps stay where they happened. This follows the turn model (prompt, turn, step; one work line per turn; work folded under one line) and the critic's "assistant prose always stays". | `chat/message_view.dart` `_isPassingWords`, `_markFoldedWork`, `_timelineDisplayParts` (pool) |
| chat-read-aloud-consent-sheet | Consent reset on every conversation or server change and on restart. | Asked once and remembered on this phone (`oc.readAloudConsent`, app-wide: the speech engine is the phone's). The sheet says "This phone remembers your answer." Automatic reading of replies still lapses with the conversation. | `chat/read_aloud.dart`, `chat_screen.dart` |
| embedded-composer | Working with text: Stop and Send side by side, expand in the send row. | One trailing control (owner Fix): Send when there is text, Stop when empty. While a run works and text waits, Stop leads the row after "+". The full-screen editor opens from the field's top-end corner. KitComposer.md updated. | `kit/chat/kit_composer.dart` |
| embedded-transcript-find-bar | The match card repeated the count and the prompt below it. | The count lives in the bar only. A match in words already on screen is marked in place; the excerpt shows only for text the transcript does not show (thoughts, tool data, file names, folded passing words, far down a long message) and names where it is ("Tool data"). | `chat/message_view.dart` `_matchNeedsExcerpt`; `widgets/transcript_highlight.dart` |
| session-approvals-sheet | The switch said new conversations are approved; the footer said "New conversations always ask." | The rule is said once, by the switch; one footer ("The server's own deny rules still apply…") whatever is chosen. `approvalsUiServerRulesNote` deleted. | `chat/approvals_sheet.dart` |
| command-auth-sheet | Recovery mechanics as copy ("could not safely recover its attempt…", "Refresh Providers to see…"). | Three plain states: "Signing in on the server… Finish any steps it asks for there. Closing this doesn't stop it." / "Signed in." (the catalog refreshes itself) / "Sign-in didn't finish." with **Try again**. A check that fails says "Couldn't check the sign-in. Try again."; a start that fails before anything left the phone says "Sign-in didn't start." with Try again. | `screens/library/command_auth_sheet.dart` |
| team-agent-output | An ended session with no output kept "This conversation fills in as the agent works". | "This conversation has ended" in place with **Back to the task** (or Back to the worker) and **About ⟨worker⟩**; the status line does not repeat it. ("session" is not a label word, G11 glossary.) | `chat/team_watch_live.dart` |

Also:
- **Tap feedback (coordinator):** `KitComposerChips` zones (model chip, attachment body and remove, suggestion rows) moved from the InkWell highlight onto `KitPressTracker`: the pressed fill shows on the next frame and a quick tap is still seen.
- `test/calm_chat_disclosure_test.dart` no longer looks for the removed Context capsule (it asserts the More tools section) and reads the composer through its `EditableText`.
- Stale `test/revamp/chat_8_test.dart` assertions follow KitDialog's "nothing judged before the first try".

## Not done here

- **embedded-completion-digest-card:** its body is drawn by `lib/ui/widgets/completion_digest.dart` inside the Inbox (`activity_screen.dart`), not by a chat part. Left for the Inbox owner.
- **Choose another model** beside "Use ⟨model⟩ and resend" under a failed turn: KitNotice shows at most two actions and Error details must stay, so the model picker there is the composer's model chip. The status-line form has Choose another model under its ⋯.
- A way to take back the read-aloud consent (it only gates the disclosure; every reading is still an explicit tap). Needs a settings row if the owner wants one.

## Tests

New, each failing on the base (`feat/phone-setup-v2` at `cd3f9a48`, test files copied into a second worktree) and passing here:

| File | Tests |
|---|---|
| `test/kit/kit_composer_chips_test.dart` | tap feedback on the next frame: pointer-down fill, quick tap on the model chip, quick tap on an attachment (the last two failed on base) |
| `test/session_draft_test.dart` | leaving with a draft that could not be saved: the sheet offers what it says; Copy draft and leave; Try saving again fails then leaves; Leave without saving |
| `test/revamp/chat_8_test.dart` | a long shell command wraps; Enter runs it, Shift+Enter adds a line |
| `test/pending_sends_strip_test.dart` | a queued message the server refused: plain reason and Try again sends it; menu order; offline has no Try again |
| `test/chat_server_state_ui_test.dart` | a prompt that got no answer: suggested model one tap; status-line form; Choose model without a known model; Send again; answered/older turns offer nothing |
| `test/chat_transcript_placement_test.dart` | a finished turn keeps the explanation in view, one work line above it |
| `test/read_aloud_test.dart` | consent is asked once, across a new screen and controller |
| `test/transcript_search_test.dart` | a match in words on screen has no excerpt; the tool-data excerpt has no count |
| `test/revamp/chat_2_test.dart` | the excerpt names where it is, no count |
| `test/revamp/chat_5_test.dart` | the new-conversation rule is said once |
| `test/revamp/screen_library_3_test.dart` | server sign-in: Signed in / didn't finish + Try again / check failed |
| `test/kit/kit_composer_test.dart` | Stop leads and Send trails at 320 dp 200 %; the editor opens from the field corner; Tab: field, editor, "+" |
| `test/revamp/slice_p3_6_test.dart` | an ended session says so once, in place, with the ways on |
| `test/chat_live_events_test.dart` | a finished turn gathers its tool chain into one work line (was: two lines split by the text) |

Runs on the final tree (pinned Flutter 3.47.1, `--concurrency=1`, `tool/qa/machine_lock.sh`):
- The 16 changed test files above plus `calm_chat_disclosure_test`, `kit_dialog_test`, `kit_field_test`: 324 passed.
- `chat_live_events_test`, `offline_queue_test`, `release_blockers_test`, `revamp/chat_3_test`, `voice_reply_pipeline_test`, `codex_chat_capabilities_test`, `team_agent_chat_test`, `team_agent_chat_render_test`, `team_conversation_screen_test`, `nudge_moments_test`, `demo_isolation_test`, `text_scale_overflow_test`: 780 passed (the lane hand-offs in these files — prompt editor at 320 dp 2x, the approval-tip overflow, the demo request list, the chips at 1.3x — pass on this tree).
- Gates: `kit_ratchet`, `redaction` (one reviewed `redact: false` added: Copy draft and leave copies the person's own draft), `ui_glossary` (G11 baseline shrinks by the retired leave confirm), `no_raw_error_text`, `kit_manifest`, `kit_draft_manifest`, `architecture_boundaries`, `kit_motion`: pass. `kit_motion_app_test` "working button …" (2) fails identically on the base: not this slice.
- `flutter analyze` on the whole project (lib, test, tool): no issues.
- Pre-existing on the base, unchanged here: `test/e7_session_approvals_layout_test.dart` (6, the approvals opener no longer finds the command search at 320 dp 2.5x); `golden_harness_test` G23 (the new gallery adds no violation).

Goldens refreshed (only the ones this slice changed; each failed here and passed on the base): `kit_composer` busy_cannot_send, busy_text, busy_text·text2, default 1280x800, glass_off, idle_text, offline, sending, suggestions (dark and light); `chat_send_error` (dark, light); `chat_find_excerpt` (dark, light). Other failures in those golden files are the known stale ones (R9/R5 drift) and fail the same on the base.

## Images

Gallery `test/revamp/slice_close_chat_golden_test.dart` (phone 412x915 and 1280x800, dark), rendered on both trees; side by side, before left, after right, in `images/`:

- `close_chat_no_answer_*` — Not answered, Use GPT-5.6 Sol Pro and resend
- `close_chat_finished_turn_*` — the explanation in view under one work line
- `close_chat_queued_refused_*` — plain reason, Try again
- `close_chat_working_composer_*` — Stop leads, Send trails, editor in the field corner
- `close_chat_leave_sheet_*` — the three answers (the base already carried the new sheet words, which reached `feat/phone-setup-v2` through 47d9d881, but still had Leave without saving / Keep editing)
- `close_chat_shell_dialog_*` — the command wraps
- `find_excerpt_dark`, `kit_composer_*`, `chat_send_error_composer_dark` — golden before/after pairs

## Still needs a device

The composer's Stop position and the editor corner under a real keyboard and one hand; Shift+Enter in the shell dialog on a hardware keyboard (Android's IME action is Enter's only job there); the read-aloud consent surviving an app restart on the phone.
