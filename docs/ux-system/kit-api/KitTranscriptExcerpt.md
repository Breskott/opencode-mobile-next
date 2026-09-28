# KitTranscriptExcerpt: API (slice-chat-speed-fixes)

Unit: `slice-chat-speed-fixes` (chat opens instantly). The backend half is
`ConnectionController.cachedSessionTail` / `loadSessionTail`
([codex-speed-2026-09-28](../../qa/codex-speed-2026-09-28/README.md), contract
item 2); this part is the chat's UI half, the transcript's counterpart of
[KitLastKnown](KitLastKnown.md).

## Purpose

The end of a conversation as it read the last time it loaded, shown
read-only while the live history is on its way, so a chat opens with its own
words instead of placeholder turns.

## File

`lib/ui/kit/chat/kit_transcript_excerpt.dart`, exported from `kit.dart`.
Tests: `test/kit/kit_transcript_excerpt_test.dart`; gallery:
`test/goldens/kit/kit_transcript_excerpt_golden_test.dart`.

## Public API

```dart
@immutable
class KitExcerptMessage {
  const KitExcerptMessage({
    required String text,      // saved words (redacted, cut short when saved)
    required bool fromPerson,  // prompt bubble (true) or reply prose (false)
    Key? key,
  });
}

class KitTranscriptExcerpt extends StatelessWidget {
  const KitTranscriptExcerpt({
    Key? key,
    required List<KitExcerptMessage> messages, // oldest first
    required String updated,   // "Updated 5m ago", the host's words
    bool refreshing = true,    // line adds " · Refreshing"
    double bottomClearance = 0, // room for a floating composer
    Key? labelKey,
  });
}
```

## Behaviour

- Prompts are `KitMessage.prompt` bubbles and replies `KitMessage.reply`
  prose, with the transcript's cap, gutters and gaps (a prompt's inner gap
  `space4`, `sectionGap` after a reply), newest at the bottom, so the live
  transcript lands where the excerpt was.
- Under the newest message one caption line: `updated`, and while
  `refreshing` `kitLastKnownRefreshing` ("{updated} · Refreshing").
- Nothing is pressable (no menu, copy, link or selection): the whole part is
  under `IgnorePointer` and Markdown is drawn non-interactive. A saved
  excerpt is not the conversation: tools, thoughts, attachments and older
  turns are left out.
- Taller than its space, older messages are cut off at the top; never an
  overflow, never a scroll.
- One semantics hint for the group, `kitTranscriptExcerptHint` ("Saved from
  last time. The conversation opens fully once it loads.").
- No spinner and no ticker: the screen's loading bar carries progress.
- The host replaces it with the live transcript as soon as that arrives,
  including an empty one or a load error. It never enters the chat's message
  list, pagination, pending-send reconciliation or copy/export.

States: loading (refreshing).

## Galleries

`kit_transcript_excerpt_loading` at 412×915 and 1280×800 (dark, light, 2.0
text).
