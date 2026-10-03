# KitLastKnown: API (slice-speed-ui)

Unit: `slice-speed-ui` (make the app feel instant). The backend half is
`ConnectionController.cachedSessionInventory`
([codex-speed-2026-09-28](../../qa/codex-speed-2026-09-28/README.md), contract
item 1); this part is the UI half.

## Purpose

What a list held the last time it was read, shown read-only while the live
answer is on its way, so a page opens with the person's own labels instead
of a spinner or placeholder rows. Used by the opening shell (the app root
while it connects to a saved server) and by Work's first load.

## File

`lib/ui/kit/kit_last_known.dart`, exported from `kit.dart`. Tests:
`test/kit/kit_last_known_test.dart`; gallery:
`test/goldens/kit/kit_last_known_golden_test.dart`.

## Public API

```dart
@immutable
class KitLastKnownRow {
  const KitLastKnownRow({required String title, String? detail, Key? key});
}

class KitLastKnown extends StatelessWidget {
  const KitLastKnown({
    Key? key,
    required List<KitLastKnownRow> rows,
    required String updated,   // "Updated 5m ago", the host's words
    bool refreshing = true,    // label adds " · Refreshing"
    Key? labelKey,
  });
}
```

## Behaviour

- A labelled `KitRowGroup` without leading icons. The label is `updated`,
  and while `refreshing` it reads `kitLastKnownRefreshing` ("{updated} ·
  Refreshing").
- Rows are `KitRow`s with no tap, menu or swipe: no `KitTappable`, no tap or
  long-press semantics. No running, waiting or pinned marks: a remembered
  label proves nothing about what exists or runs now.
- The group carries one semantics hint, `kitLastKnownHint` ("Saved from last
  time. They open once the live list loads.").
- No spinner and no ticker: progress belongs to the screen's loading bar or
  connection state. Nothing is shown twice.
- The host replaces it with the live list as soon as that arrives, including
  a live list that is empty.

States: loading (refreshing).

## Galleries

`kit_last_known_loading` at 412×915 and 1280×800 (dark, light, 2.0 text);
`kit_last_known_settled` at 412×915 (dark, light).
