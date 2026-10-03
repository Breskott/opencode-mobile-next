# Chat screens review (b1, b2, c, d)

60 pages, 95 renders, judged against `docs/design/principles.md`. Per-page scores and fixes are in [`chat.json`](chat.json).

**Verdict:** 9 keep, 46 fix, 5 rethink. 32 pages have a quick win. Issues found: 3 critical, 41 high, 69 medium, 31 low.

The transcript and composer are calm and legible. What lets the chat down is how the screen describes itself. It says "Running" while it waits for you, "Choose model" while a model answers, and "Composer tools" when you opened Commands. Around the conversation, the sheets each follow their own layout rules.

## The five most important problems

1. **The chat says the wrong thing about its own state.**
   - While a permission waits, the work line still reads "Running tools · Shell · flutter test…" with a spinner (`chat`, `embedded-permission-attention-card`).
   - The composer chip says "Choose model" while the line under each reply shows the raw `anthropic/claude-sonnet-4` (`chat`, `embedded-composer`, `embedded-message-view`). The chip falls back to "Choose model" whenever the server default is in use (`composer.dart` `_contextLabel`).
   - Fix: while blocked, show "Waiting for you" with a still mark. Show the default model by its presented name ("Sonnet 4 · default").
2. **Queued prompts are broken on screen** (`embedded-pending-sends-strip`, rethink).
   - The third bubble is clipped under the composer. The second runs past the right rail. The status is truncated ("review before r…").
   - A failed send offers edit and delete but no Retry. Up to three icon actions sit on each bubble, with delete beside send.
3. **Approving is two taps and the words are engine words.**
   - The attention card's only action is a full-width filled "Review" (regression row 4).
   - The sheet says "The agent wants to use bash / edit" and shows the edited file's path twice (absolute and relative).
   - The Approvals sheet contradicts itself: the server-wide switch says "new ones … included", and the footer says "New conversations always ask". That dangerous switch looks like any other and turns on without a confirm (`embedded-permission-attention-card`, `permission-sheet`, `session-approvals-sheet`).
4. **The conversation menu and the command launcher are toolboxes, not menus** (`session-menu-sheet` and `command-launcher-sheet`, both rethink).
   - Session menu: a ragged chip grid, then accordions, then plain rows. The title repeats the app bar. Destructive "Revert last prompt" sits between Retry and Fork.
   - Command launcher: titled "Composer tools" even when opened as Commands. The titles are slash syntax in mono, and every row carries a meaningless grey "mobile" tag. A second "+" sheet (Prompt tools) overlaps it.
5. **Finished work hides or garbles its own story.**
   - A finished turn folds the answer's explanation under "Read 3 files, edited 1 file, ran 1 command" (`chat`). Opening that group repeats the same summary line inside itself (`embedded-message-view`).
   - Long shell output is uncapped and pushes the card header off screen (`embedded-tool-card`).
   - The completion digest is mostly disclaimers ("Success or failure is not verified", "No AI summary or model call") under five text actions (`embedded-completion-digest-card`, rethink).

Two more pages are visibly broken:

- **`form-sheet`, full-screen variant:** the pinned Send bar floats mid-screen between black bands, and the page has no close control.
- **`voice-notices`:** raw Markdown with hard line breaks, written for maintainers (`pubspec.lock`, `~/.pub-cache` paths).

## Recurring patterns

- **Engine vocabulary above the fold:**
  - Transcript and prompt tools: run, steer, stash, context capsule, compact.
  - Permissions and tool cards: subagent, bash, edit, exit 0, unified-diff headers.
  - Voice setup: INT8, MiB, app-private storage.
  - Digest: cached metadata.
  - Raw model ids.

  `test/ui_glossary_test.dart` should grow to cover chat strings.
- **Four sheet header styles:**
  - A small `titleSmall` label (Prompt tools, Todo list, Approvals).
  - A large Space Grotesk title with a subtitle and an X next to the drag handle (Composer tools, Message timeline, Saved prompts).
  - The session title repeated (session menu).
  - No header at all (message actions).

  Pick one: a title-medium title with an optional one-line subtitle, the drag handle, and no X.
- **Button order and emphasis break the standard's §2:**
  - Side-by-side pairs on a phone (form sheet, voice setup, run-shell dialog).
  - Cancel above the primary (voice transcript).
  - The real fix demoted: "Open app settings" is outlined under a filled "Try again".
  - Destructive actions in accent colour: Revert, Delete voice model.
  - Non-destructive actions in error colour: cancel inbox message.
  - A disabled "Download" left visible during a download (regression row 19 again).
- **Duplication (U6):** "1 of 12 matches" twice in find, the file path twice in the edit permission, the command twice in the needs-you state, the agent name three times in the subagent card.
- **Confirm sheets:** they use a two-line display title and a centred body of three or more sentences. Several confirm things that should be undone instead: restoring a saved prompt, deleting a saved prompt.
- **Horizontal clipping with no hint:**
  - Code blocks, diffs and the run-shell field clip with no fade or wrap toggle.
  - Table cells break file names mid-token.
  - The full-screen code reader is still clipped.
- **Motion (from source):**
  - Chat uses literal durations (150, 180, 200, 220, 240, 360, 400 and 530 ms) instead of `KitMotion`.
  - `AnimatedSize` animates layout in `permission_sheet`, `form_renderer` and `chat_screen`.
  - The empty-state caret blink checks only the system "remove animations" flag, not Effects › Animations Off (M1).
  - The streaming reply's tinted container vanishes at completion, so the layout jumps.

## Quick wins (copy or one-widget changes)

- Add Copy to both error-details dialogs (`chat-prompt-error-details-dialog`, `chat-message-error-details-dialog`).
- Error banner: add "Use GPT-5.6 Pro and resend", since the server already suggests it (`embedded-prompt-error-banner`).
- Rename "Composer tools" to "Commands" and remove the "mobile" tags (`command-launcher-sheet`).
- Unsaved-draft sheet: add "Copy draft and leave", because the body tells you to copy but offers no way to (`chat-leave-unsaved-draft-sheet`).
- Fix the Approvals contradiction and give the server-wide switch error styling and a confirm (`session-approvals-sheet`).
- Show the find count once and delete "All available message content searched." (`embedded-transcript-find-bar`).
- Cut the read-aloud consent from seven sentences to two, with the rest under Details (`chat-read-aloud-consent-sheet`). Cut the prompt-history intro from five lines to one (`prompt-history-sheet`).
- Todos: use `KitStatusMark` instead of "completed / in progress" text and checkboxes, and remove the card from the empty state (`todos-sheet`).
- Timeline: strip Markdown backticks from previews and count messages, not occurrences (`timeline-sheet`).
- Voice notices: render the Markdown (`voice-notices`).
- Delete the voice model with an error-coloured button (`voice-model-setup-sheet-delete-dialog`).
- Revert confirm: one name for the target, quote the prompt, error-toned "Roll back" (`chat-revert-confirm-sheet`).
- Name the draft in the discard sheet, name where a shared conversation goes (`chat-discard-queued-draft-sheet`, `chat-share-confirm-sheet`).

Not reviewed as product issues (harness artefacts, per the census README): the `Settings ▯ Saved permissions` missing glyph and relative times. `embedded-model-shortcuts` (desktop-only) and the two removed return-brief pages are listed as keep, with no images.
