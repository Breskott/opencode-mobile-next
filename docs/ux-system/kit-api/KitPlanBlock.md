# KitPlanBlock: one plan of a group of plans

Added 2026-10-14 for Usage › Plans (owner-approved mock: one card group, one
block per plan).

## Purpose

A row holds a title and at most one supporting line. A plan holds more: its
name, how low it is, and one line per limit window. `KitPlanBlock` is that
block. Put several in one `KitRowGroup`; the group draws the one card and the
hairlines between blocks.

```dart
KitRowGroup(
  leadingIcons: false,
  children: [
    KitPlanBlock(
      title: 'Codex',
      titleNote: 'Plus',
      summary: '12% left',
      onTap: openPlan,
      children: [
        KitWindowRow(inline: true, title: '5 hours', left: .12,
            valueLabel: '12% · 1:25 PM'),
      ],
    ),
  ],
)
```

## Rules

- The first line is the name with the small `titleNote` after it (the tier),
  and at the end one small `summary` in secondary text. Never a pill.
- The name and the summary wrap rather than cut; from 1.3x text the summary
  drops under the name.
- `children` are the lines under the first line: `KitWindowRow(inline: true)`
  and quiet notes.
- The whole block is one tap target that opens the plan. Controls inside
  (a "Try again" button) keep their own tap.
- One merged label for a screen reader: "{title}, {titleNote}, {summary}".
- It draws no surface of its own.

## Replaces

A `KitRow` with a `below` of window lines (the standard counts a `KitRow` with
more than two lines as a finding).
