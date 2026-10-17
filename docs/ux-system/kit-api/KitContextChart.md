# KitContextChart — API (2026-10-11)

## Purpose

How full the context window was after each assistant reply: one bar per reply, coloured by level, a dashed line where compacting is suggested (80 %), and a thin mark where the conversation was compacted. Used by `KitContextSheet`.

## File

`lib/ui/kit/kit_context_chart.dart`: `KitContextChart`, `KitContextBar`, `KitContextChartPainter`. Tests: `test/kit/kit_context_chart_test.dart`. Gallery: `test/goldens/kit/kit_context_chart_golden_test.dart`.

## API

```dart
const KitContextChart({
  required List<KitContextBar> bars,  // oldest first; the newest 40 are drawn
  double threshold = 0.8,
  Key? chartKey,
});
const KitContextBar({required double fraction, bool compactedBefore = false});
```

Fewer than two bars draw nothing. Older bars: `text3` under 70 %, `attention` to 94 %, `danger` from 95 %; the newest bar always shows its level's strong colour (accent while calm). The dashed line and its "80 %" label use `attention`. Semantics: "Context after each of N replies, the newest at P %". The chart mirrors under right-to-left.

## States

None: it draws the bars it is given.
