# crit/chat (2026-09-29)

Not run: no tests, no emulator (coordinator gates). `flutter analyze`: clean.

## Items
1. Interrupted reply: done. When the stream is not connected and the newest reply is unfinished, the turn is drawn as interrupted (no "Thinking..." animation), with the line "The connection dropped before this reply finished." and a "Send again" action (existing `_retryLast` path). A user Stop is unchanged (aborted stays "stopped"). Reconnect already refetches (`dataRefreshRevision` -> `_load`), so the line goes when the reply arrives done.
2. Compact: done. `_compact` asks first through `showKitConfirm` (icon, one line, "can't be undone"); the request runs inside the sheet's `action` so it shows progress and keeps the question open with Try again on failure. Summary notice header now reads "Earlier messages were summarized to save space" (key `chatUiContextCompacted`, en + ar). Only the OpenCode 2 notice is labelled; OpenCode 1 has no separate summary bubble in the transcript model.
3. Code blocks: done in `lib/ui/kit/kit_code_block.dart` (outside the listed dirs, needed): scrollbar stays visible on touch while a block overflows, a start-edge fade appears once scrolled (end fade already existed), Copy and Wrap wrapped in 48x48 minimum.
4. Stop: red (`dangerFill` / `onDangerFill`) in `kit_composer.dart`.
5. Composer semantics: the field already carried a semantic label ("Message"); chat now passes a specific one, "Message to the agent" (`composerFieldLabel`), hint stays separate.

## Tests edited
- `test/v2_transcript_rows_test.dart` (new summary label).
- `test/nudge_moments_test.dart` (compact now asks first; taps Compact in the sheet).

## Device check
- Drop the connection mid-reply: animation stops, line + Send again; reconnect removes it when the server finished.
- Compact from menu, nudge, error card, Compact again: sheet, progress, note.
- Code block at font 2.0: scrollbar + fades visible, Copy/Wrap 48 dp.
- Stop is red in light and dark; TalkBack reads "Message to the agent".
- Risk: any existing test with an unfinished message and a disconnected controller now renders the interrupted line.
