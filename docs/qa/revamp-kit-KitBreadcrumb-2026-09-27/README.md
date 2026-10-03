# revamp-kit-KitBreadcrumb: KitBreadcrumb, the folder trail (2026-09-27)

## 1. Scope

- Unit: `kit-KitBreadcrumb` (wave 1, kit-part). Finish line: `KitBreadcrumb` exists in `lib/ui/kit/` to its frozen API, with behaviour tests and a gallery. Non-goal: adopting it in `files_screen.dart` (the Files wave-2 unit, C36) and exporting it from `kit.dart` (integrator, R06).
- Files changed: `lib/ui/kit/kit_breadcrumb.dart` (new), `test/kit/kit_breadcrumb_test.dart` (new), `test/goldens/kit/kit_breadcrumb_golden_test.dart` (new) + 12 PNGs, `lib/l10n/app_en.arb` (5 `kitBreadcrumb*` keys) and the generated `lib/l10n/app_localizations*.dart`.
- Pages (map ids): `files#files-breadcrumb` (part only; the page adopts it in wave 2).
- Specs followed: `docs/ux-system/kit-api/KitBreadcrumb.md`; STANDARDS.md §1, §15, §16; kit-v2 §8.2, §8.4, §9.2; rules KIT-1, KIT-3, KIT-12, LOOK-6, LOOK-23, LAY-9, LAY-10, LAY-11, A11Y-4, A11Y-8, COPY-30.
- Contract problems (PROC-20):
  - Accessibility says "…" is "a button with a pop-up hint", but the spec's copy list has no hint string and Flutter 3.47.1 semantics has no has-popup flag. Built without a hint: the "…" node is a button labelled "{count} more folders" with the same tooltip. Proposed: add `kitBreadcrumbMoreHint` ("Opens a menu") or drop the hint. Blocks nothing.
  - Galleries: the spec asks for 28 PNGs (five sizes, 2.0 text and Arabic) and a scene "under a top bar". The owner decision of 2026-09-27 narrows this to 412x915 and 1280x800 in light and dark (12 PNGs), and KitTopBar has not merged, so the trail sits on ground within 16 dp rails. RTL test 7 is reduced to the isolation marks (Arabic dropped).
  - Copy: the spec asks for en and ar; the owner decision keeps `app_en.arb` only. The generated Arabic class falls back to English for the five keys.
- New kit parts (KIT-3): `KitBreadcrumb`.
- Map items (EVID-11): `files#files-breadcrumb` kitGap `KitBreadcrumb` → done: `test/kit/kit_breadcrumb_test.dart`; the screen swap is deferred to the Files wave-2 unit.
- States (STATE-20): default, collapsed, root only, truncated → goldens `kit_breadcrumb_<state>_*` and tests 1–4; focused → golden `kit_breadcrumb_focused_*`.
- Deferred states (STATE-21): none (loading and error are the host's).

## 2. Builds

- Branch `revamp/kit-KitBreadcrumb`, base `64128dba` (feat/phone-setup-v2 when the unit started; it has since moved to `03b3d678`, not merged here per R02), code head `383879a0`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_breadcrumb_test.dart` | passes | 9 passed | PASS |
| 2 | `test/goldens/kit/kit_breadcrumb_golden_test.dart --update-goldens` (G5 checks on every shot, both themes) | passes | 12 passed; each PNG looked at | PASS |
| 3 | `flutter analyze` on the part, both tests and `lib/l10n` | no issues | no issues | PASS |
| 4 | Ratchet, design-standard, l10n coverage suites | not run (owner decision 2026-09-27: own files only) | not run | n/a |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden |
  |---|---|
  | Select; the current crumb is not tappable | `kit_breadcrumb_test.dart` "1. select" |
  | Collapse rule; "…" menu in trail order | "2. collapse" |
  | Root, parent, current always kept; current wraps (G6) | "3. always kept at 320" |
  | A11Y-8 middle cut at `crumbMaxWidth`; full name in semantics and tooltip | "4. truncation" |
  | A11Y-4 container "Folder path", trail order, current selected, separators absent | "5. semantics" |
  | LAY-10 / G14 Tab order root, "…", ancestors; current not a stop | "6. keyboard" |
  | COPY-30 FSI…PDI isolation | "7. every folder name is isolated" |
  | LAY-9 48 x 48 targets, no overlap | "8. targets" |
  | G6 no overflow 320–1280 at 1.0/1.3/2.0; G8 settles after one pump | "9. no overflow" |
  | LOOK-6 focus ring | `kit_breadcrumb_focused_{dark,light}.png` |

- Changed test expectations (TEST-19): none.
- Goldens added (each opened and looked at): `kit_breadcrumb_{default,collapsed,root_only,truncated,focused}_{dark,light}.png`, `kit_breadcrumb_default_1280x800_{dark,light}.png`. No approved VL canvas render exists for this part (EVID-12: n/a).
- Before and after: no before render (`files#files-breadcrumb` is the Files screen's chip row; the screen is unchanged by this unit). After: `after-files-breadcrumb-default.png`, `after-files-breadcrumb-collapsed.png`.
- Accessibility: labels "Open {root}", "Open folder {folder}", "{count} more folders", "Current folder: {folder}" (selected, not a button) inside a "Folder path" container; every tappable crumb is at least 48 x 48; 2.0 text checked at 320–1280 with no overflow. No pop-up hint on "…" (see contract problems).
- Privacy and security: n/a: no credentials, stored data, links or notifications.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_breadcrumb_test.dart
$F test -j 1 test/goldens/kit/kit_breadcrumb_golden_test.dart
$F analyze lib/ui/kit/kit_breadcrumb.dart test/kit/kit_breadcrumb_test.dart test/goldens/kit/kit_breadcrumb_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Not exported from `kit.dart`, not used by any screen yet.
- Arabic / RTL layout and the 360, 800, 915 and 1600 sizes are not rendered (owner decision).
- The shared suites (kit ratchet, design standard, l10n coverage, golden harness G23) were not run.
- Hover fill on a fine pointer is KitTappable's and is not shot here.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitBreadcrumb` |
| Enabled | No: no screen uses it until the Files wave-2 unit | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `383879a0` |
| Deployed | No | |
| Released | No | |
