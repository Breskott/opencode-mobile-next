# revamp-kit-KitTopBar: KitTopBar (2026-09-27)

## 1. Scope

- Unit: `kit-KitTopBar` (wave 1, tier 3, kit part). Finish line: `lib/ui/kit/kit_top_bar.dart` provides `KitTopBar`, `KitTopBar.shell`, `KitTopBarExit`, `KitShellControls` and `KitShellControlsLayout` to the frozen API in `docs/ux-system/kit-api/KitTopBar.md`, with behaviour tests and a gallery. Non-goal: migrating screens, editing `lib/ui/kit/kit.dart`, hosting through `KitScreen(topBar:)`.
- Files changed: `lib/ui/kit/kit_top_bar.dart` (new), `lib/l10n/app_en.arb` (6 new `kitTopBar*` keys) and the generated `lib/l10n/app_localizations*.dart`, `test/kit/kit_top_bar_test.dart` (new), `test/goldens/kit/kit_top_bar_golden_test.dart` (new) and 22 `kit_top_bar_*.png`.
- Pages (map ids): none migrated (kit part only).
- Specs followed: KitTopBar.md; kit-v2 §1.18, §8.2; VL §6 (glass pill, glass search, PC glass toolbar); STANDARDS KIT-36, LAY-8, LOOK-17, A11Y-8, STATE-8, STATE-9.
- Contract problems (PROC-20):
  1. KitTopBar.md relies on `KitScreen(topBar:)` and `KitScreen.twoPane`, but neither exists on `feat/phone-setup-v2` (KitScreen has only `header`, `body` and `bottom`). Three things follow. Exit `auto` cannot tell that it is inside a KitScreen pane, so it resolves from the route only. The hairline that should appear when content scrolls under the bar has no scroll source to listen to. The rule that a second bar inside a tab asserts belongs to KitScreen. Until kit-KitScreen lands, a screen can put the bar in `KitScreen(header: [...])`. This blocks nothing in this unit; the owner is kit-KitScreen.
  2. The owner decision of 2026-09-27 (412x915 and 1280x800, light and dark) replaces the spec's gallery list (360x800, 915x412, 800x1280, 1600x1000, text 2.0 and Arabic). A behaviour test covers 200 % text instead.
- New kit parts (KIT-3): none beyond this unit's own.
- Map items (EVID-11): deferred to the screen units (no screen migrated).
- States (STATE-20):
  - Goldens: default, subtitle working, needs-you, switcher, brand, close, shell connected, shell reconnecting and shell needs-you.
  - Disabled action: test "a disabled action waits in the overflow with its reason".
  - Shell not answering: uses the same tone code path as the other shell states and has no golden of its own.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitTopBar`, base `024e97b0`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new part | n/a | n/a |
| 2 | `test/kit/kit_top_bar_test.dart` | passes | 16 passed | PASS |
| 3 | `test/goldens/kit/kit_top_bar_golden_test.dart` (rendered with `--update-goldens`; every image opened and looked at) | passes, G5 clean | 22 passed | PASS |
| 4 | `flutter analyze` on the three changed Dart files | no issues | no issues | PASS |

Owner decision 2026-09-27 (speed): no other suites were run. The ratchet, design-standard and l10n coverage suites and the full suite are the integrator's.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden |
  |---|---|
  | Header / namesRoute | `kit_top_bar_test.dart` "title is a header naming the route; subtitle in its label" |
  | LAY-8 exit placement | "exit auto: none at root, Back when pushed, Close in a dialog", "onExit overrides the pop" |
  | §8.2 compact / medium / expanded | "compact: first action plus overflow; overflow order", "compact: one action and no menu is one icon", "medium: two actions plus overflow", "expanded: labelled buttons; title keeps half the bar" |
  | STATE-8 | "a disabled action waits in the overflow with its reason" (also checks that Esc closes the overflow) |
  | G37 asserts | "asserts: no icon, destructive, switcher without label" |
  | Switcher + needs-you badge | "switcher: tap, label and needs-you badge" |
  | VL §6 glass, Effects off | "shell: pill with status word, search, dim glass", "shell: glass off makes the controls solid" |
  | Sidebar layout | "sidebar: pill, project, search stacked; no project row without onProject" |
  | A11Y-8 200 % text | "200 % text at 320 dp: no overflow, title wraps" |
  | RTL placement | "RTL: Back at the right, actions at the left" |
  | Reduced motion | "reduced motion: a subtitle change settles in one pump" |
  | STATE-9 visible status word | goldens `kit_top_bar_shell_*` (only the server name is shortened with an ellipsis; the word always shows) |

- Changed test expectations (TEST-19): none.
- Goldens added (every one opened and looked at):
  - `kit_top_bar_{default,subtitle_working,needs_you,switcher,brand,close,shell_connected,shell_reconnecting,shell_needs_you}_{dark,light}.png` at 412x915.
  - `kit_top_bar_default_1280x800_{dark,light}.png`: labelled actions on the glass toolbar.
  - `kit_top_bar_shell_sidebar_1280x800_{dark,light}.png`.

  `kitGalleryPart` centres its child at most 720 dp wide, so the 1280x800 shot shows the toolbar at that width.
- Accessibility:
  - The title is a header that names the route. The subtitle and the needs-you words are part of its label.
  - The switcher reads "shopfront, Switch project, 2 need you". The server pill reads "Laptop, Connected, Switch server".
  - Every target is at least 48 dp.
  - At 2.0 text the title wraps to two lines.
- Privacy and security: n/a (no credentials, stored data, links or notifications).
- Migration: n/a (no stored format).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_top_bar_test.dart test/goldens/kit/kit_top_bar_golden_test.dart
$F analyze lib/ui/kit/kit_top_bar.dart test/kit/kit_top_bar_test.dart test/goldens/kit/kit_top_bar_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Keyboard Tab order (exit, switcher, actions, overflow) follows from the order of the widgets only. No Tab-traversal test was written (owner speed decision).
- Tooltips with shortcuts on a fine pointer come from KitIconButton v2 and were not tested again here.
- For expanded windows, whether a labelled action fits is judged from an estimated button width (TextPainter), not a measured one.
- Pane detection for exit `auto` and the scroll hairline wait on kit-KitScreen (contract problem 1).
- The ratchet, design-standard and l10n-coverage gates were not run (integrator's job).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitTopBar` |
| Enabled | No: no screen uses it yet | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | `revamp/kit-KitTopBar` |
| Deployed | No | |
| Released | No | |
