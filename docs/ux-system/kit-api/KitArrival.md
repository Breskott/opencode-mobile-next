# KitArrival: API (slice-P9.4)

Unit: `slice-P9.4` (Search that finds any setting). The domain half is `lib/domain/settings_search*.dart` (docs/qa/codex-p94-2026-09-27); this part is the UI half of its row-arrival contract.

## Purpose

A search result that means one row opens the page holding that row. The page arrives at the row: it waits until the row is laid out, scrolls it into view, moves the screen reader to it and washes it in the accent for a moment. The row is named by a stable anchor id (`effects-vibration`, `keep-running-battery`, `managed-recovery-option`), never by a route string or a widget key, so the index survives pages moving (P3.10).

## File

`lib/ui/kit/kit_arrival.dart`, exported from `kit.dart`. Tests: `test/kit/kit_arrival_test.dart`; gallery: `test/goldens/kit/kit_arrival_golden_test.dart`.

## Public API

```dart
/// The one-shot request, put around the page a result opens.
class KitArrivalScope extends InheritedWidget {
  KitArrivalScope({Key? key, required String rowId, required Widget child});
  String get rowId;
  static bool claim(BuildContext context, String id); // true at most once
}

/// One row a result can arrive at.
class KitArrival extends StatefulWidget {
  const KitArrival({Key? key, required String id, required Widget child});
  static const Duration hold;     // 2.4 s: how long the wash stays
  static const double washAlpha;  // .18: KitFindMark's passive hit
}
```

## Behaviour

- **Once.** The first `KitArrival` below the scope whose `id` equals `rowId` claims the request. A rebuild, the same row mounted again (a list that loads, a builder that swaps), or a second row with the same id never repeats it.
- **Laid out first.** It acts after the frame the row was first built in, so a row that appears only after the page loads (Keep running) or behind a gate (the heat row) is reached when it exists. A row that never appears is never reached; the request ends with the page. A page with arrival rows therefore lays them out: one `Column` inside its `ListView`, not lazy children far below the fold (Appearance, Keep running).
- **Scroll.** `Scrollable.ensureVisible` at alignment .3, `KitMotion.standard` with `KitMotion.emphasized`; a jump under reduced motion.
- **Screen reader.** The row gets its own semantics node and a `FocusSemanticEvent`, so TalkBack lands on it.
- **Mark.** The accent at `washAlpha` behind the row (never a text colour, LOOK-14), for `hold`, then it fades out over `KitMotion.entrance`; under reduced motion it goes at once. No ticker runs while it holds (a timer does), so a still screen settles.
- Without a claim it draws only its child: no extra node, no extra layer.

States: none — a passive mark around one row.

## Galleries

`kit_arrival_marked`: a row group with the middle row arrived at, at 412×915 and 1280×800, and 2.0 text.
