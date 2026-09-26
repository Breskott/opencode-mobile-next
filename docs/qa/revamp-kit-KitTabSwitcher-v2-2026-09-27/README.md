# revamp-kit-KitTabSwitcher-v2: KitTabSwitcher v2 (2026-09-27)

## 1. Scope

- Unit: `kit-KitTabSwitcher-v2` (wave 1, kit-change). Finish line: the kit has a strip of labelled tabs (`KitTab`, `KitTabStrip`, `KitTabSwitcher.tabs`), the body no longer scales, and `TeamBoardTabs` forwards to `KitTabStrip` with its constructor and keys unchanged. Non-goal: adopting the raw `TabBar`s or editing `team_board_screen.dart` (wave-2 units).
- Files changed: `lib/ui/kit/motion/kit_tab_switcher.dart`, `lib/ui/widgets/team_board_tabs.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/kit/kit_tab_switcher_test.dart` (new), `test/goldens/kit/kit_tab_switcher_golden_test.dart` (new) and its goldens.
- Pages (map ids): n/a: a kit part (the team board's column strip renders through the wrapper).
- Specs followed: `docs/ux-system/kit-api/KitTabSwitcher.md` (frozen API); STANDARDS MOT-2 and Appendix A #23 (no scale), LOOK-24 (needs-you only through `KitNeedsYou.badge`), KIT-43, R11, R12.
- Contract problems (PROC-20):
  - Task text says `team_board_tabs.dart` becomes a `@Deprecated` wrapper (R12); the frozen spec says "marked `/// Retired by kit-KitTabSwitcher-v2: use KitTabStrip` (KIT-43: no `@Deprecated`)". Followed the spec (a `@Deprecated` class would also raise `deprecated_member_use` in `team_board_screen.dart`, which this unit may not edit).
  - The spec's kit copy is "en and ar" and its galleries include Arabic and text-2.0 shots; the owner decision of 2026-09-27 drops Arabic, and galleries are 412x915 plus 1280x800 only. `kitTabLabel` is in `app_en.arb` only; the gallery follows the owner decision (see Evidence).
  - `KitNeedsYou.badge` draws its pill at its child's top-end corner (an overlay), while the spec says "after the label". The strip reserves `KitTokens.badgeMinWidth` of end padding after the tab's words so the pill sits after them rather than over the count.
- New kit parts (KIT-3): `KitTab` and `KitTabStrip` (in the existing file, per the frozen spec). Not exported from `kit.dart` (R06: the integrator adds the export).
- Map items (EVID-11): n/a: no page records for a kit part.
- States: default, counts loading, needs you, overflowing, focused → goldens below; behaviour in `test/kit/kit_tab_switcher_test.dart`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitTabSwitcher-v2`, base `8dc4ebf4` (feat/phone-setup-v2), code head `32ae02e8`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_tab_switcher_test.dart` | passes | 43 passed | PASS |
| 2 | `test/goldens/kit/kit_tab_switcher_golden_test.dart --update-goldens`, each PNG opened | renders, G5 checks pass | 18 rendered and passed; opened default, needs_you, overflowing and focused | PASS |
| 3 | `flutter analyze` on the changed lib and test files | no issues | no issues (after dropping one unused test parameter) | PASS |

Owner decision 2026-09-27 (speed): no other suites were run (ratchet, design-standard, l10n coverage, `test/team_board_test.dart` are the integrator's).

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_tab_switcher_test.dart` + `--plain-name`) or golden |
  |---|---|
  | onSelected once, never for the selected tab | "another tab calls onSelected once; the selected one nothing" |
  | counts loading shows no number; "Working, 3" | "null shows no number; 3 shows \"3\" and \"Working, 3\"" |
  | LOOK-24: one attention colour, the badge | "a badge by needsYouKey, the merged label, one attention colour" |
  | overflow scrolls inside, selected into view | "eight tabs at 320 dp scroll inside the strip; the last selected scrolls into view" |
  | G6 320–1600 dp and 915x412, text 1.0/1.3/2.0, LTR/RTL | "no exception at …" (30 cases) |
  | G14 keyboard (Tab, arrows, Home/End, Enter/Space, RTL) | "Tab enters on the selected tab…", "in RTL, Left moves forward" |
  | MOT-2 no scale; state kept | "switching shows no scale and keeps each destination's state" |
  | `.tabs` in step; mismatched lengths assert | ".tabs keeps strip and body in step", ".tabs with mismatched lengths asserts" |
  | G8 reduced motion | "a switch and a count change settle after one pump" |
  | Wrapper keys (TEST-5) | "renders a KitTabStrip with the board keys", "loading columns show no counts" |

- Changed test expectations (TEST-19): none (no existing test edited).
- Goldens (new, each opened and looked at): `test/goldens/kit/kit_tab_switcher_{default,counts_loading,needs_you,overflowing}[_1280x800]_{dark,light}.png` and `kit_tab_switcher_focused_{dark,light}.png` (18 PNGs). No approved VL canvas render exists for this part (EVID-12: n/a).
- Before and after: no before render (a new gallery; the old `TeamBoardTabs` look is in the integrator-owned `team_board` goldens, which this unit did not regenerate).
- Accessibility: each tab is one `button` node with `selected`, labelled "{label}, {count}" (`kitTabLabel`) plus the badge's ", 1 need you"; the strip is a semantics container named by `semanticsLabel`; tabs are at least 48x48 dp with 8 dp between; the strip scrolls at 2.0 text without overflow; the focus ring is KitTappable's.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_tab_switcher_test.dart
$F test -j 1 test/goldens/kit/kit_tab_switcher_golden_test.dart
$F analyze lib/ui/kit/motion/kit_tab_switcher.dart lib/ui/widgets/team_board_tabs.dart test/kit/kit_tab_switcher_test.dart test/goldens/kit/kit_tab_switcher_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- `test/team_board_test.dart` and `test/goldens/team_board_golden_test.dart` (integrator-owned) were not run; the wrapper keeps their keys, but the board goldens will change (new strip look: surface3 pill, 48 dp tabs, badge instead of the 7 dp dot).
- Shared gates not run (owner decision 2026-09-27): `kit_ratchet_test` (the MOT-2 KitTabSwitcher ratchet entry should now drop), `design_standard_test`, `l10n_coverage_test` (the new key has no Arabic entry), `kit_motion_test` and `kit_motion_app_test` (they pump `KitTabSwitcher`; the body's fade is unchanged, only the scale is gone).
- No Arabic or text-2.0 golden (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitTabSwitcher-v2` |
| Enabled | Yes: the team board's strip renders through the wrapper | `lib/ui/widgets/team_board_tabs.dart` |
| Verified | Unit tests and goldens only | this record |
| Committed | Yes | `revamp/kit-KitTabSwitcher-v2` |
| Deployed | No | |
| Released | No | |
