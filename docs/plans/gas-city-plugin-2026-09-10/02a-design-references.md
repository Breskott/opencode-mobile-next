# Design references (Mobbin pass, 2026-09-10)

The first canvas was judged overwhelming. The second follows these
patterns, each chosen for one screen:

| Screen | Pattern borrowed | Reference |
|---|---|---|
| Workspace card, Run overview | One status pill, one progress bar, two counts, one action; everything else behind tabs | [Asana project overview](https://mobbin.com/screens/905d6029-4f4a-4d8b-9d47-b4b300a364a8) |
| Workspace card headline | A big number and a single plain sentence that tells you how you're doing | [Oura readiness](https://mobbin.com/screens/6b2d9662-daa9-40d6-b2be-a7d5f39aa3de) |
| Work list | Grouped by state, one status glyph per row, tiny owner mark, no pills | [Linear Mobile issues](https://mobbin.com/screens/c4cfc742-1a09-4b85-a3c3-d6dd2b28f1de) |
| Agent detail | A plain step log ending in a single bottom action ("Approve plan and start work") | [GitHub Copilot agent](https://mobbin.com/screens/adf5041e-ddb8-4414-812c-71a4733bbf8d) |
| Needs you | One row, one action; nothing else competes | [Bond inbox](https://mobbin.com/screens/4898ed42-db35-4380-9f6e-1674d09cf58e) |
| Timeline | Dated, quiet, one line per event | [Revolut inbox](https://mobbin.com/screens/d25a8668-d08c-4c27-936a-d48232b9452c) |

## Rules distilled

1. One number, one sentence, one action per surface. Counts beyond two go
   behind a tap.
2. No decoration that carries information: no agent constellation, no
   textured bars, no cost chips on the card. Cost lives in Details.
3. Status is a dot and a word, never a pill wall.
4. The dependency graph is not a phone default; the Work list is. Graph is
   an opt-in view for tablets and desktop.
5. Every screen ends in the one thing you can do next, or nothing.

## v3 — next-gen board integrated (2026-09-10)

The owner supplied a polished "next-gen" board (`design/reference-nextgen-board.html`).
Its layout is now the spec, rebuilt on the app's own tokens in `design/gen3.py`:

Kept: hero number + sentence + one action; Working/Blocked pair; the
decision card above the vertical execution steps with "Next: testing";
tinted Work groups with dot rows; agent step log with the pinned answer bar
and an **optional note**; one coloured action per Activity row; the
Termux question card; the short Settings page.

Corrected: no fake OS chrome or notch (Android renders its own bars);
app palette `#83CDAA` on `#101310` / `#1C241F`, no glows or blurred
gradients; body type never below 13px (2.5x rule); blocked-by-dependency is
amber, red is reserved for failed runs; SVG icons instead of text glyphs;
"Mentions" tab and "fallback worker" card removed (not in scope); session
rows do not claim agents.
