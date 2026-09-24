# AI Team: redesign for the person, not the engine (2026-09-24)

The owner, on the AI Team home and the Work tab card rendered after step 4 of the design standard: "This is very ugly".

The kit made these screens consistent, not good. They still show Gas City's insides, and they give a three-run team the controls of a dashboard.
- Before renders: `docs/qa/design-standard-aiteam-2026-09-24/after-*.png`.
- Phone-hosted goldens: `test/goldens/team_home_loaded_phone_*`, `team_card_phone_*`.

This spec changes content, words and layout. It does not change behaviour or the gateway. It builds on `docs/design/design-standard.md` and `lib/ui/kit/`.

## What is wrong

| Where | Seen | Why it is wrong |
|---|---|---|
| Home header | "127.0.0.1 · This phone · Gas City 1.4.1 · city phone · controls" | An address, a version, and the words "city" and "controls". The standard (§7) keeps these out of titles, and here they are the first thing on the screen. |
| Home controls | Three tabs (Runs, Agents, Needs you), four filter chips, and a search field above three runs | A dashboard's controls for a short list. They push the content down and make the person choose before they can see anything. |
| Run rows | "Batch · convoy · 1 of 5 done", "Run · formula mol-upgrade · 2 of 4 done", "Working" / "Needs you" stacked on the right | Engine words (convoy, formula, the formula id) on every row, and two states competing. |
| Needs you | A row state plus a tab count | The one thing the person must act on is not the first thing on the screen. |
| Card on the Work tab | "20% done." as a headline, a segmented bar, the run list, `○○○○○○○ Routed`, "1 completed run", three dots, Open plus Refresh | Six kinds of indicators in one card. The dots and the step strip mean nothing without a legend, and the card is taller than the conversations it sits among. |
| Run screen | An 8-step strip (Routed, Agent starting, Claimed, Working, Pushed, Handed to merge, Merged) and chips for counts and cost | Machinery vocabulary. Most people need: what it's doing, how far along, what it needs from me. |

## The target

### Words (one vocabulary, in `lib/ui/widgets/team_vocabulary.dart`)

- **A run is a "task".** A convoy (a batch of items) is a "task" with steps ("3 of 5 steps done"). A formula run is also a "task", named by its title only; the formula id goes under Details.
- **Never on a list row or card:** convoy, formula, bead, rig, city, polecat, refinery, sling, wisp, `127.0.0.1`, versions.
  - The run screen keeps them only under a "Technical details" sheet.
  - Agents are named by role in plain words: "Worker", "Reviewer (merges)", "Supervisor". Their Gas City names stay under details.
- **Progress stages in plain words, at most 4 visible:** Waiting, Working, Reviewing (handed to merge), Done (merged). The 8-step strip becomes this 4-step line on the run screen only.
- **The host line** is one short phrase:
  - "On this phone" or "On {computer name}";
  - plus "· Paused" or "· Not answering" when true.
  - Everything else goes under the header's info button.

### Home (`team_home_screen.dart`)

1. **Title "AI Team"**, with the host phrase as a muted subtitle. It is not a card or a box.
2. **"Needs you" first**, only when something does:
   - one `KitRequestCard`-style block per question, with the question and its answer buttons, as in chat;
   - several questions become a short list of rows.
3. **Tasks:** one list, running first, then waiting, then "Done today" (collapsed after 3).
   - Each row has the title (2 lines allowed), one supporting line ("Working · 3 of 5 steps" / "Waiting for a worker" / "Done · merged 5h ago"), and one leading status mark (`KitStatusMark`). There is no second state word on the right.
4. **Agents:** one row, "3 agents · 1 working", which opens the agents list. It is not a tab.
5. **Filters and search appear only when there are more than 8 tasks.** They go behind a search icon in the top bar, not chips.
6. **The primary action is "Give the team a task"**, pinned at the bottom as today. The empty state teaches in one sentence and does not repeat the button.

### The Work tab card (`team_card.dart`)

It becomes **one section of at most three rows**, the same height budget as a conversation group:
- Header row: "AI Team" plus the host phrase, and a trailing "Open" chevron. The whole row taps through, and there is no Open button.
- **"Needs you"** row, when there is one: the question's first line and "Answer".
- **One row per running task** (at most 2): the title and "Working · 3 of 5 steps".
- If nothing is running or waiting: one muted line, "Nothing running · Give the team a task".

Removed:
- the big percentage;
- the segmented bar;
- the step strip;
- the dots;
- "N completed runs";
- the Refresh button (the card refreshes itself; pull-to-refresh on the Work tab already exists).

### Run screen (`run_screen.dart`)

- **Overview:** the title, one status line, the 4-step line, and "Needs you" if any. Then "Steps" (the items) as rows.
- Count, cost and usage go under a "Details" row.
- Keep Overview, Work, Agents and Timeline if needed. Consider folding Timeline into Details, and record the decision.

## Rules

- Behaviour, the gateway, and existing data paths stay as they are. This is presentation and copy.
- Keep the finished-run behaviour ("Done · merged", a finished run's steps listed) and the phone-hosted host line.
- Kit only (`lib/ui/kit/`); additions in new files.
- `test/ui_glossary_test.dart` gains the banned engine words for these screens' list and card strings, so they cannot come back.

## Proof

- Update the goldens for: home loaded (computer and phone), home empty, card (computer and phone), run overview, run steps, and the agents list.
- Before/after renders go in `docs/qa/aiteam-redesign-2026-09-24/`, including a side-by-side of today's card and the new one, with a README in the `docs/qa/README.md` format.
- Tests: a failing-first test for:
  - no engine words on rows or cards (a glossary rule);
  - Needs you first;
  - no filters with 3 tasks;
  - a card of at most 3 rows.
