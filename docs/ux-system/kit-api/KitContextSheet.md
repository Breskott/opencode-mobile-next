# KitContextSheet — API (2026-10-11)

## Purpose

The body of the context details sheet (opened with `showKitSheet`): the big ring with the percent, "84,000 of 200,000 tokens", rows for the model, the context window and when it was measured ("After the last reply"), one plain paragraph on what the window is, and the per-reply `KitContextChart`.

## File

`lib/ui/kit/kit_context_sheet.dart`. Tests: `test/kit/kit_context_sheet_test.dart`. Gallery: `test/goldens/kit/kit_context_sheet_golden_test.dart`.

## API

```dart
const KitContextSheet({
  required int tokens, required int limit, required String modelName,
  required List<KitContextBar> bars, bool compacting = false, Key? chartKey,
});
```

The sheet's title ("Context window") and its "Compact now" primary belong to the opener (`_showContextDetails` in the chat screen), which offers the button only when the server can compact (`ServerCapabilities.sessionCompact`) and reuses the conversation's existing compact action. There is no "New chat from summary": the app has no such action.

## States

None: it shows the numbers it is given.
