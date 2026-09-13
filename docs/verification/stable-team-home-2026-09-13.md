# Stable AI Team home: section selector and run filters on compact phones (2026-09-13)

Branch `fix/stable-team-home-20260913`, worktree `oc_app-stable-team`, on top of
`5e3b8a4`. One bounded UI fix in `lib/ui/screens/team/team_home_screen.dart`.

## Problem (captures from 5e3b8a4, FixtureOrchestrationGateway)

[Normal baseline](../qa/stable-ui-2026-09-13/before/06-team-normal.png) (390dp) and
[large-text baseline](../qa/stable-ui-2026-09-13/before/07-team-large-text.png) (320dp, 2.5x):

- 320dp at 2.5x: the four filter chips stack four rows high and take most of
  the list; the segmented Runs / Agents / Needs you button scrolls sideways so
  Agents and Needs you are off screen.
- 390dp at normal text: the filter chips wrap onto two rows.

## Change

- **Normal text**: the segmented button is unchanged. The filter chips sit on
  one row that scrolls sideways instead of wrapping, with slightly tighter chip
  padding so all four fit at 390dp. Same keys, same `ChoiceChip` widgets, so the
  home, agent and gate tests that tap `team-home-filter-*` / `team-home-segment-*`
  at normal text are untouched.
- **Large text** (`AppTheme.stackedActions`, text scale above 1.6): both the
  section selector and the filters become one labelled menu button each
  (`_CompactChoice`, a `PopupMenuButton` with `CheckedPopupMenuItem`s):
  - `team-home-segments-menu` shows the current section with its count
    ("Runs (1)", "Agents (2 · 1 off)", "Needs you (0)"); the menu items keep
    the `team-home-segment-runs|agents|needs-you` keys.
  - `team-home-filter-menu` shows the chosen filter ("All", "Blocked", …) with a
    filter glyph and the reused localized "Filters" label as the semantics
    heading; the items keep the `team-home-filter-<name>` keys.
  - The selected option is checked in the menu and named on the button, so the
    state is never colour-only. Counts, stale dimming, loading, error, the
    Start a run FAB and the planning cards are unchanged; no controller, gateway
    or l10n edits (labels reused: `teamUiHomeFilter*`, `teamUiHomeSegment*`,
    `e7ModelUiFilters`).

No text is scaled down anywhere; nothing measures text or lays out by hand.

## Focused tests (coordinator runs serially)

With the pinned Shorebird Flutter from AGENTS.md
(`~/.shorebird/bin/cache/flutter/<rev>/bin/flutter`), from this worktree:

```bash
flutter test --concurrency=1 test/team_home_stable_layout_test.dart
flutter test --concurrency=1 test/team_home_layout_test.dart
flutter test --concurrency=1 test/team_home_test.dart
flutter test --concurrency=1 test/team_agent_screen_test.dart
flutter test --concurrency=1 test/team_gate_answer_test.dart
```

- `test/team_home_stable_layout_test.dart` (new): 390dp normal text keeps the
  segmented button and all four chips fully on screen on one row and filtering
  works; 320dp normal text scrolls the chip row and the last chip still works;
  320dp at 2.5x shows the two menu buttons inside the viewport, the run row and
  the FAB are hit-testable without scrolling, every filter and section is
  choosable from its menu, the chosen filter reads on the button and survives
  switching sections.
- `test/team_home_layout_test.dart` (updated): the 2.5x LTR/RTL, en/ar sweep now
  drives sections and filters through the menus and asserts no `ChoiceChip` and
  no segmented button at that size.
- The other three files are unchanged and run at normal text; listed because
  they tap the shared keys.

## Coordinator verification

Existing Team behavior/layout tests passed serially, including the 2.5x LTR/RTL en/ar sweep. Three new layout tests passed after loading the app capture fonts rather than using Ahem width assumptions. Fresh [normal](../qa/stable-ui-2026-09-13/team-1.0x.png) and [large-text](../qa/stable-ui-2026-09-13/team-2.5x.png) fixture renders were reviewed: run status and primary actions remain visible. Menus are selected by text scale, including on tablets; tablet and native TalkBack behavior were not visually tested. See the integration record for the final candidate gate. Local implementation only; nothing pushed or released.
