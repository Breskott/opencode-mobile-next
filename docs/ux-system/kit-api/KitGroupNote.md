# KitGroupNote — API (slice-P3.10, 2026-09-27)

One muted line under a `KitRowGroup` that says what the group leaves out and offers one way to learn why. Target-ia §1.3: rows a server cannot serve stay off the Settings hub, and the group shows one line instead: "2 settings aren't available on this server · Why".

## File

- `lib/ui/kit/kit_group_note.dart`, exported from `kit.dart`.
- Tests: `test/kit/kit_group_note_test.dart`.
- Callers: the Settings hub (`settings_screen.dart`, one per group) and Settings › Tools (`tools_hub_screen.dart`).

## Public API

```dart
class KitGroupNote extends StatelessWidget {
  const KitGroupNote({
    super.key,
    required this.message, // one sentence: what the group leaves out
    this.action,           // KitAction, a tertiary button ("Why"); null: words only
  });
}
```

## Look

- On the group label's rail (gutter plus the label inset), `labelGap` below the panel.
- Words: `KitTextRole.secondary`, secondary tone. Action: `KitButton` tertiary, not expanded.
- A `Wrap`: when words and action do not fit one line (long words, large text) the action moves under the words, start-aligned.

States: none — a passive line; its one action has no state of its own. Gallery: `test/goldens/kit/kit_group_note_golden_test.dart`.
