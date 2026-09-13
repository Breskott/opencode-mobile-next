# Stable Chat

Finish line: chat clearly identifies the conversation and leaves a readable transcript and usable compose/send/stop controls on narrow phones with the keyboard open and enlarged text, without draft or navigation regressions. Non-goal: new features, theme redesign, controller/domain changes, localization changes, CI/signing/release/push.

## Evidence and defects

The 2026-09-09 quiet-chat captures (`docs/qa/quiet-chat-2026-09-09/dark-idle.png`, `dark-draft.png`, 390dp) showed two defects. The session title rendered as "Fix flaky checkou…" because the Tasks shortcut in the app bar always carried its text label beside the session menu, leaving the title roughly half of the bar, and less on a real phone with a back arrow or at large text, where the label scales but the icons do not. Under the newest reply, the message-actions target drew a bare 16dp "…" glyph with no boundary, which read as the answer trailing off or a typing indicator rather than a control. Reading the composer's keyboard path for a 320dp phone at 2.5x text found a third case: with a run active and a draft typed, the queue hint or delivery control above the field plus the field's full compact budget exceeded the remaining body height, which pushes Send and Stop under the keyboard.

## Changes

- `lib/ui/screens/chat_screen.dart`: below 600dp the Tasks shortcut is an icon button with the same key, badge, count tooltip and semantics; wider layouts keep the labelled button. The title may wrap to two lines on phones, and the toolbar height follows the title's own text scale (Material caps app-bar title scaling at 1.34x; the toolbar uses the same figure so two lines are never clipped, and stays 64dp at 1x). A `chat-title` key exists for tests.
- `lib/ui/screens/chat/message_view.dart`: the message-actions glyph sits on a 28dp tonal disc inside the unchanged 44dp target, with the same key, tooltip and "Message actions" semantics. The empty-transcript tip and the actions sheet are unchanged.
- `lib/ui/screens/chat/composer.dart`: compact large-text queue copy uses a short label and retains the explanation in a tooltip. The field budgets whole visible lines using the actual text scale and padding. A one-line viewport remains a multiline editor, preserving pasted newlines; its hint is constrained to the same viewport. The context selector keeps its tooltip and switches to an icon when its label cannot fit. No body text scale is clamped.
- `test/stable_chat_layout_test.dart` (new): 320dp app bar at 1x/2x/2.5x (icon-only Tasks, title width, two-line title inside the toolbar, Tasks still opens), wide bar keeps the label, short title keeps the 64dp bar, message-actions control is a labelled 44dp button that opens the sheet, 320dp keyboard at 1x/2x/2.5x with a run active keeps field/Send/Stop on screen and the draft intact through keyboard close and run end, and a phone-to-wide rotation swaps the shortcut without remounting the editor or losing the draft.
- `tool/capture/stable_chat_test.dart` (new): PNG harness for 390dp dark/light at 1x and 2x (idle and draft) and 320dp at 2.5x with the keyboard open while busy, written to `docs/qa/stable-chat-2026-09-13/`.

## Coordinator verification

The focused layout/composer tests and capture harness run serially on pinned Flutter 3.47.2. Integration added assertions that editable text stays inside its field and multiline drafts survive keyboard/run changes. This caught an InputDecorator hint-height regression missed by an overflow-only assertion; the final hint shares the one-line viewport limit.

Fresh dark/light, ordinary/enlarged text, and keyboard/busy images are in [stable chat captures](../qa/stable-chat-2026-09-13/). Full-candidate results and native limitations are recorded in [the integration record](stable-ui-2026-09-13.md). These synthetic widget captures are not evidence of an installed candidate, TalkBack, or live-server behavior.
