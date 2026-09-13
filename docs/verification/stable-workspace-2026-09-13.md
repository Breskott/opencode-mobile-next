# Stable workspace at phone widths and large text (2026-09-13)

Finish line: returning to a project and starting or resuming a session is
visually clear at phone widths including large text, with every existing
behavior preserved. Non-goal: new features, theme redesign, hiding supported
features, backend or controller changes, CI, signing, release or push.

Branch `fix/stable-workspace-20260913`, based on `5e3b8a4`. Files:
`lib/ui/screens/workspace_screen.dart`,
`test/workspace_stable_layout_test.dart` (new),
`tool/capture/stable_workspace_test.dart` (new), this note.
`lib/ui/screens/home_screen.dart` needed no change: the app bar and dock
already held at 320dp/2.5x in the shell captures. No localization files
changed; all copy is existing keys (`workspaceManage`,
`e7WorkspaceSwitchProject`, `workspaceNewSession`, `workspaceIsolatedTask`).

## Evidence

Source captures `docs/qa/shell-repair/tab-0-dark-390-1.0x.png` and
`tab-0-dark-320-2.5x.png` on the stable-ui checkout (current source):

- 320dp/2.5x: "shopfront" broke mid-word into two 60dp lines because the
  ListTile title shared the row with the leading icon, Manage and the
  chevron. Measured from the bundled Space Grotesk SemiBold: the word is
  292dp at 60dp, wider than even the full 288dp row.
- 320dp/2.5x: the primary action clipped to "New ses…"; the working row's
  facts line showed only "Working · …"; the list's fixed 96dp end could not
  clear a taller dock.
- 390dp/1x: the facts line already cut "6 files" to "6 …". Otherwise the
  normal layout held, so it keeps its row header and side-by-side dock.
- "Review status unknown" competes with the header at 390dp/1x. That row is
  `ReturnBriefCard`, outside this slice's write set; left as is.

## Changes

- **Header at large text (above about 1.3x)** is a stacked block: the name
  owns the full row (three lines before an ellipsis), the folder line holds
  the folder glyph, path and the context-sheet chevron, and Manage and a
  labelled Switch project button sit beneath as 48dp targets. Tapping the
  name or path still opens the context sheet (project switch plus
  workspaces); Switch project opens the projects list directly.
- **Title size ladder, not a scale clamp.** The name keeps the large title
  (24) wherever its longest unbreakable segment fits the row at the user's
  scale; otherwise it steps to 20, then 16, before the text would break
  inside a word. The text scaler is untouched, so the painted size is
  always the user's multiple of the chosen base.
- **Session facts line** wraps to two lines at normal text and three at
  large text. Status leads, so anything cut is the least essential.
- **Docked actions** measure the primary label with the button's own text
  style. On a narrow phone or at large text, the label keeps one line beside
  the 48dp isolated icon when it fits; otherwise the isolated action becomes
  a labelled button above a full-width primary. The label allows two lines
  before any ellipsis. The list's end spacer uses the same metrics, so the
  last row clears the dock whatever its height.
- Normal text (390dp/1x): unchanged apart from the two-line facts line.

Contracts, capability gates, menus, swipe actions, section order, the
context sheet and the archived sheet are unchanged.

## Focused checks for the coordinator

No Flutter, Dart or native process was run in this worktree; the coordinator
runs these serially:

```bash
dart format lib/ui/screens/workspace_screen.dart test/workspace_stable_layout_test.dart tool/capture/stable_workspace_test.dart
flutter analyze
flutter test --concurrency=1 test/workspace_stable_layout_test.dart
flutter test --concurrency=1 test/workspace_hierarchy_test.dart test/projects_screen_test.dart test/accessibility_guidelines_test.dart test/text_scale_overflow_test.dart test/session_needs_you_test.dart test/session_pins_test.dart test/v2_feature_gating_test.dart test/project_health_screen_test.dart
flutter test --concurrency=1 tool/capture/stable_workspace_test.dart
flutter test --concurrency=1 tool/capture/fluid_shell_test.dart
```

The capture harness writes `docs/qa/stable-workspace-2026-09-13/` (light and
dark at 390dp/1x, 320dp/2x, 320dp/2.5x, a hyphenated long name and the
scrolled end at 320dp/2.5x) and fails if the project name or "New session"
paints with an ellipsis, using the real bundled fonts.

## State

Implemented and committed on the branch. Not verified: no analyzer, test or
capture run happened here. Expected outcomes from the font measurements:
at 320dp/2.5x "shopfront" paints on one line at the 20 rung (50dp,
about 243dp wide), "New session" stacks above a labelled Isolated task; at
320dp/2x the name keeps the 24 rung and the dock stays a row. Remaining
after the focused checks: the coordinator's full serial suite, PNG
inspection of the new captures, and on-device confirmation at the phone's
largest text setting.

## Coordinator verification

Ten focused workspace layout tests and ten capture cases passed serially. Ordinary/large-text, long project names and scrolled-to-end captures were reviewed in `docs/qa/stable-workspace-2026-09-13/`. The nullable button-padding resolution was corrected at integration. Full-candidate status is recorded in `stable-ui-2026-09-13.md`.
