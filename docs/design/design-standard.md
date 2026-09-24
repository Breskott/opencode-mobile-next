# Design standard

Every screen is built from the same few parts, and each part is used the same way everywhere. This sits on top of the existing tokens: colour, type, radii and icons in `lib/ui/app_theme.dart`, `app_iconography.dart`, and `docs/design/refinement/shared-visual-system.md`. Those do not change here.

Owner's complaint that started it (2026-09-24): "every screen looks different and adhoc".

The parts live in `lib/ui/kit/`. A screen that needs something the kit lacks adds it to the kit, never a one-off. `test/design_standard_test.dart` checks the rules that code can check.

## 1. Screen

- A top bar with a title, back, and at most one icon action plus an overflow menu. The title says where you are, in sentence case.
- The body is a single scroll view with 16 dp side rails.
  - The last content always scrolls clear of anything pinned below it: bottom bar, primary button, keyboard.
  - `KitScreen` handles the padding. No screen pads by hand.
- One primary action per screen at most. On phones it is a full-width filled button pinned to the bottom, or it lives in the body when the screen has none pinned.

## 2. Buttons: one hierarchy

| Role | Widget | Where | How many |
|---|---|---|---|
| Primary: the one thing this screen or state is for | Filled | full width on phone, bottom of its block | at most 1 visible |
| Secondary: the likely other path | Tonal or outlined, full width under the primary | same block | at most 1 |
| Tertiary: rare paths | Text button, or the overflow menu when there are more than 2 | under the secondary, left-aligned | at most 2, the rest in overflow |
| Destructive | Error-coloured text or tonal, always confirmed | never primary unless the whole screen is the delete | — |

- Buttons in a block are stacked, full width, in the order primary, secondary, tertiary. Never right-aligned clusters, never mixed alignment.
- On widths of 600 dp and up, they may sit in one row, primary rightmost.
- A button is never a status display. "Starting the server…" is progress (§4), not a disabled button with a spinner.
- A disabled button needs a reason visible near it, or it is hidden.

## 3. States: one component

Every "not the normal content" moment uses `KitStateView`: loading for a whole screen, empty, error, stopped/offline, blocked or permission needed. It has fixed slots:

1. **Icon** in a tonal circle. Its tone is neutral, working (accent), warning or error, from `AppStatusTone`. Never a solid red block.
2. **Title**: one line that says the state now. It must never contradict the progress: "Starting OpenCode…", not "stopped" while it starts.
3. **Body**: at most two short sentences on what happened and what to do.
4. **Progress** (optional): §4.
5. **Actions**: §2 hierarchy.
6. **Details** (optional): a collapsed "Details" row at the bottom for technical text (address, error, logs), in mono. Never above the actions.

It shows in two sizes:
- **Page:** fills the body, centred vertically, with no card around it.
- **Inline:** inside a list, with the same slots at smaller type.

Cards are for content the person works with, not for wrapping a message.

A message that belongs to one part of a form or list (a connection test's verdict, a save that failed, a credential the app can no longer read) is too small for a whole state: it uses `KitNotice`. Tinted icon, optional title, the words, optional note lines, at most two tertiary actions, optional dismiss. It sits on the content's rails with no filled block and no card, and it is one live region.

## 4. Progress and loading

- **One loading bar per screen**: a 2 dp linear bar directly under the top bar or header, with a semantic label. Nothing else on the screen shows a bar.
- Lists that are loading show skeleton rows (`KitSkeletonRows`), never an empty-state text and never "load more".
- **Known progress** (bytes, steps): a determinate bar with one line under it ("29 of 30 MB · about 1 min left"), inside `KitStateView` or `KitProgressRow`.
- **Waiting on something slow:** after 8 s without an answer, the state says so in plain words and offers the way out (Retry, or Restart for a server the app owns). A spinner never runs silently longer than 8 s.

## 5. Status line

`KitStatusLine`: one row with icon, one line of text and an optional action, used for conditions on an otherwise working screen (offline, stale, something running).
- At most one per screen, the most important one.
- It is dismissible only when dismissing it changes nothing real.
- It is not a card.

## 6. Lists and sections

- Section header: `SectionLabel`, sentence case, with an optional count or action on the right.
- Rows: `KitRow`, with a leading icon or status dot, title (1 line), supporting line (1 line, muted), and a trailing value, chevron or single icon action.
  - A list of steps (setup's checklist) leads each row with `KitStatusMark`: waiting, working, done, failed. The mark is a state, not a second bar.
  - Only titles in the person's own words (conversation titles) may wrap, and app words may wrap at large text, so nothing is cut to a few letters.
  - A setting whose supporting line explains what it does, or carries an error to act on, may take two lines (`supportingMaxLines: 2`). A list of things keeps one.
  - An action that cannot run now dims (`enabled: false`) and its supporting line says why.
  - A row that deletes something is `destructive: true`: error-coloured title and icon, and it confirms before acting.
- State lives in the row (dot, mark, "Needs you"), not in extra cards above the list.
- The same thing appears once per screen.

## 7. Words

- Plain, short, in the person's terms: conversation, project, "this phone", "OpenCode".
- No paths, ports or internal names in titles. Put them under Details.
- The glossary test (`test/ui_glossary_test.dart`) is part of this standard.

## 8. Checked by tests (`test/design_standard_test.dart`)

- No `LinearProgressIndicator`, `CircularProgressIndicator`, `Card(` or raw `FilledButton` in screen files outside `lib/ui/kit/` once the screen is migrated.
  - Migrated screens are listed in the test. The list only grows.
  - An allowlist entry needs a reason.
- Each migrated screen has a golden render at 412×915, in dark and light, in `test/goldens/`. The renders are reviewed like code.

## 9. Migration order

1. Connection and server states (the connecting card, "stopped", "isn't answering").
2. The Work tab.
3. Phone setup (start, progress, ready) and the "This phone" card.
4. AI Team home and run.
5. Chat states (empty, errors, permission).
6. Settings.

Each step ships with its goldens and joins the checked list.
