# revamp-kit-KitNav: KitNav, one destination list for dock, rail and sidebar (2026-09-27)

## 1. Scope

- Unit: `kit-KitNav` (wave 1, tier 3, kit part). Finish line: one `KitNavDestination` list builds the floating 60 dp glass dock with a lens tab, the glass rail from medium and the 296 dp PC sidebar from expanded, with the needs-you badge drawn by `KitNeedsYou.badge`. Non-goal: migrating the shell (`home_screen.dart`, which is screen-shell-1's job), any `KitGlass` change, and edits to `kit.dart`.
- Files changed: `lib/ui/kit/kit_nav.dart` (new), `lib/ui/widgets/glass_surface.dart` (forwarding wrapper: doc line and `dim: true`), `test/kit/kit_nav_test.dart` (new), `test/goldens/kit/kit_nav_golden_test.dart` plus 10 PNGs (new), and this record.
- Pages (map ids): `home-shell#home-shell-rail`, `home-shell` dock, `home-shell#home-shell-badge`. All are adopted later by screen-shell-1.
- Specs followed: `docs/ux-system/kit-api/KitNav.md`; kit-v2 §8.1, §8.2 and §9.2; visual language §4, §5 and §6; STANDARDS LAY-1, LAY-5, LAY-15, LOOK-27, LOOK-33, A11Y-8 and KIT-43.
- Contract problems (PROC-20):
  1. **Short wide window.** KitNav.md's Behaviour section says "a window < 480 dp tall keeps the dock (compact) or the rail (medium-or-wider)", so 915×412 gets the rail. Its "Tests required" 1 and its gallery list both say "915×412 (short): dock". The build follows Behaviour and matches `KitLayout.modalWindowOf`, which also treats a short wide window as medium. The test asserts the rail. Proposed text for test 1: "915×412 (short): rail". Nothing is blocked.
  2. **`@Deprecated` wrapper.** The computed task says `glass_surface.dart` "becomes a @Deprecated wrapper". KitNav.md (KIT-43) says "stays as a forwarding wrapper marked `/// Retired by kit-KitNav: use KitNavBar.` (no `@Deprecated`)". A `@Deprecated` annotation would add analyzer issues in `home_screen.dart` and in `tool/capture`. The build follows the frozen spec.
  3. **Trailing badge in the sidebar.** KitNav.md asks for a "trailing needs-you badge" on the sidebar rows. `KitNeedsYou.badge` (frozen, kit-KitNeedsYou) can only anchor a pill to a child's top-end corner and has no trailing form. The build anchors the badge to the destination's glyph in all three layouts. Proposed fix: either KitNeedsYou gains a `trailing` builder, or KitNav.md accepts the glyph anchor.
  4. **G5 reading order across side-by-side panes.** A11Y-4 wants navigation read before content in the rail and sidebar layouts. G5's reading-order check compares consecutive leaves only, so the jump from the sidebar's bottom primary (or the last rail destination) back up to the content's first row fails as "goes back up". In the wide galleries, the stand-in content is wrapped in `ExcludeSemantics`. The same failure will hit every two-pane screen gallery (screen-shell-1). Proposed fix: let the check reset at a semantics container boundary between side-by-side panes. That belongs to the harness owner.
  5. **Dependency on `KitShellControls`.** The sidebar header in the galleries is a stand-in, because kit-KitTopBar has not merged. KitNav types `sidebarHeader` as `Widget`, as the spec says.
- New kit parts (KIT-3): `KitNav`, `KitNavBar`, `KitNavRail`, `KitNavDestination` and `KitNavLayout` in `lib/ui/kit/kit_nav.dart`. The `kit.dart` export is left to the integrator (R06).
- Map items (EVID-11):
  - home-shell rail → done: `kit_nav_test.dart` "layout follows the window class" and golden `kit_nav_rail_needs_you_1280x800_*`.
  - dock → done: `kit_nav_dock_*` goldens.
  - badge → done: "needs-you count is read once with the label".
  - Adoption in the shell → deferred to screen-shell-1.
- States (STATE-20): each state below is covered by a test or golden.

  | State | Test or golden |
  |---|---|
  | default | `kit_nav_dock_default_*`, `kit_nav_sidebar_default_1280x800_*` |
  | needs-you | `kit_nav_dock_needs_you_*`, `kit_nav_rail_needs_you_1280x800_*`, sidebar badge 3 |
  | dock hidden (keyboard) | "keyboard open hides the dock and its clearance" |
  | glass solid | `kit_nav_dock_solid_*` and the glass test (`KitGlass.lookOf` solid) |

- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitNav`, base `024e97b0` (feat/phone-setup-v2). The code head is the commit that carries this record.
- No APK: unit agents do not build.

## 3. Devices

None. This unit was checked with tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

Owner decision 2026-09-27 (speed): only this unit's own test files were run, once each, and no other suite was run.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: this unit builds a new part | n/a | n/a |
| 2 | `test/kit/kit_nav_test.dart` | passes | 12 passed | PASS |
| 3 | `test/goldens/kit/kit_nav_golden_test.dart` (`--update-goldens`, run in two halves) | passes, including G5 | 10 passed | PASS |
| 4 | Ratchet, design-standard, l10n, glossary and ledger tests | not run (owner decision 2026-09-27) | not run | n/a |
| 5 | `flutter analyze` on the four changed Dart files | no issues | No issues found | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden |
  |---|---|
  | LAY-1, LAY-5 | `test/kit/kit_nav_test.dart` "layout follows the window class" and "clearance published per layout" |
  | LOOK-27 | "dock and rail are dim glass at navRadius; sidebar is not" |
  | A11Y-8 | "200% text at 320.0 / 412.0" |
  | A11Y-3 | "needs-you count is read once with the label" |
  | Keyboard (§8.3) | "keyboard: Tab lands on selected, arrows move, Enter selects" |
  | MOT (reduced) | "reduced motion: switching settles in one pump" |
  | KIT-43 | "GlassSurface forwards to KitGlass at radius 22" |

- Changed test expectations (TEST-19): none.
- Goldens (new; each one opened and looked at):
  - `kit_nav_dock_{default,needs_you,solid}_{dark,light}.png`, 412×915. The dock floats 8 dp above a 24 dp system inset, with 16 dp side margins. The selected tab sits on the lens, the Inbox badge shows 1, and the solid version is opaque.
  - `kit_nav_sidebar_default_1280x800_{dark,light}.png`: 296 dp ground column with a hairline end edge, a header stand-in, 48 dp rows with the selected row on surface3, a Work pane and a pinned "New conversation" primary.
  - `kit_nav_rail_needs_you_1280x800_{dark,light}.png`: an 80 dp glass rail inset 8 dp, with an icon and label for each destination, the lens on Work and a badge of 1 on Inbox.
  - Gallery sizes follow the owner decision of 2026-09-27: 412×915 and 1280×800 only, light and dark, no Arabic or RTL, no text-2.0 gallery. The spec's other sizes are not rendered.
- Accessibility:
  - Each destination is a `KitTappable` button with the `selected` state and the label "Inbox, 3 need you". The badge's own node is excluded, so the count is read once.
  - Each destination has a target of at least 48 dp, and the dock destinations fill the bar's full height.
  - Labels clamp at `navLabelMaxScale` (2.0) or at the width that fits, whichever is smaller.
  - Only the selected destination is a Tab stop; the arrow keys move between destinations.
  - Arabic and RTL review was dropped by owner decision.
- Privacy and security: n/a. No credentials, stored data, links or notifications changed.
- Migration: n/a. No stored format changed.

Known limits:
- The lens is a surface3 pill with a hairline rim, not a second glass layer (VL §6: glass never sits on glass).
- `KitTappable` still paints its hover fill on the dock and rail, where the spec asks for no lens preview on hover.
- The live-region announcement of a count change is left to the label change. The test does not assert that the count is announced exactly once.
- The spec's "`GlassSurface(` becomes a G2 ratchet pattern" is left to the integrator, because `test/design_standard_test.dart` and the ratchet baseline are shared files.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_nav_test.dart
$F test -j 1 test/goldens/kit/kit_nav_golden_test.dart
$F analyze lib/ui/kit/kit_nav.dart lib/ui/widgets/glass_surface.dart test/kit/kit_nav_test.dart test/goldens/kit/kit_nav_golden_test.dart
```
