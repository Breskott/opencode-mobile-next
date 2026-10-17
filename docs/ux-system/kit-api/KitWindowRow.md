# KitWindowRow: one limit window, name and value over a bar

Added 2026-10-13 for Usage › Plans (owner review of the plan cards). Revised the
same day: the bar shows what is left, and every bar is full width.

## Purpose

A plan shows its 5-hour and weekly limits together. `KitProgressRow` is a
panel of its own, too tall to put two in a card. `KitWindowRow` is the name
and the value on one line with a full-width bar under them.

```dart
KitWindowRow(
  title: '5 hours',
  left: 0.18,
  valueLabel: '18% left · 14:10',
  tone: KitWindowTone.low, // normal | low | out | calm
)
```

## Rules

- The bar fills with the share left, like a fuel gauge. A short bar always
  means little left, and it matches the "% left" text beside it.
- Every bar spans the full width, so two windows line up.
- Tones: `normal` uses accent. `low` (past the person's alert level) draws
  the bar and the value in strong neutral text1; amber stays for "needs you"
  (LOOK-4). `out` leaves the bar empty with a strong value, never red (LOOK-5).
  `calm` (old or offline numbers) is muted.
- The name and the value wrap rather than cut, at any text size.
- It draws no surface and takes no taps; the card around it opens the plan.
- One merged semantics label: "{title}, {valueLabel}".

## Replaces

A `KitProgressRow` per window inside a plan card.
