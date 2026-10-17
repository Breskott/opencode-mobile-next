# KitContextRing — API (2026-10-11)

Unit: the chat context ring (owner-approved designs 1–5, 7, 8). Rules: KIT-1, KIT-12, LOOK-5, MOT-1, MOT-2 (G21: no scale transforms), MOT-5, A11Y-3.

## Purpose

Shows how much of the model's context window a conversation uses, as a ring with its percent beside it. It sits in the chat top bar (`KitTopBar.accessory`, left of the ⋯), opens the context details sheet on tap, and has a small 18 dp form for the chats list.

## File

`lib/ui/kit/kit_context_ring.dart`: `KitContextRing`, `KitContextLevel`, `KitContextRingSize`, `KitContextArcPainter`, `KitContextHaloPainter`. Tests: `test/kit/kit_context_ring_test.dart`. Gallery: `test/goldens/kit/kit_context_ring_golden_test.dart`.

## API

```dart
const KitContextRing({
  required double? used,          // 0..1 (clamped); null = unknown = draws nothing
  bool compacting = false,        // short arc turns, label "Compacting"
  VoidCallback? openDetails,      // bar size only; makes the ring one button
  KitContextRingSize size = KitContextRingSize.bar, // bar | large | row
  Key? ringKey,
});
```

## Look

- bar: 24 dp ring, radius 9, stroke 2.5, round caps, arc from 12 o'clock clockwise over a `text3` track at 35 % opacity; percent label beside it in tabular figures (`text2` under 70 %, the level's colour from 70 %). One tap target (the KitTappable floor, 48 dp) with semantics "Context N % used" and the tooltip "Show context details".
- large: 64 dp, radius 24, stroke 6, the percent inside; not tappable.
- row: 18 dp, radius 6.75, stroke 2; the number only from 70 %; never tappable, no halo.
- Levels: under 70 % `accent`, 70–94 % `attention`, 95 % and over `danger` (`KitContextLevel.of`).

## Motion (KitMotion.context*)

A new value moves the arc and counts the number together (600 ms, ease-out-cubic, whole percents); the colour crosses to the next level (320 ms); crossing 70 % or 95 % upward sends out one halo (r 11, stroke 2→9, opacity 0.6→0, 700 ms; `KitContextRing.haloKey` is present only while it is out); a falling value (compaction) drains over 900 ms; while compacting a 16 % arc turns (one lap 1.2 s, only where `KitMotion.loopsIn`). Reduced motion or Animations: Off: a still arc and number, no halo, no spin.

## States

None of its own (KIT-12): unknown, normal, filling, almost full, compacting and still are the data it is given.
