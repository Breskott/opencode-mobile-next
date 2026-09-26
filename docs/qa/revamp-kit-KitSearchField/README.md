# revamp-kit-KitSearchField: Build KitSearchField (2026-09-27)

## 1. Scope

- Unit: `kit-KitSearchField` (wave 1, tier 3, kit-part). Finish line: `KitSearchField` and `KitSearchNoMatch` exist in `lib/ui/kit/kit_search_field.dart` to the frozen API, with behaviour tests and galleries. Non-goal: no call-site migration, no search index, no `kit.dart` export (integrator, R06).
- Files changed: `lib/ui/kit/kit_search_field.dart` (new), `lib/l10n/app_en.arb` (+7 keys) and the generated `lib/l10n/app_localizations*.dart`, `test/kit/kit_search_field_test.dart`, `test/goldens/kit/kit_search_field_golden_test.dart` and 16 PNGs, this record.
- Pages (map ids): none migrated (wave 2).
- Specs followed: `docs/ux-system/kit-api/KitSearchField.md`; STANDARDS KIT-20, STATE-8, STATE-11, A11Y-3, AUTO-20, MOT-1, MOT-5; kit-v2 §1.5, §2.12, §8.2, §8.3.
- Contract problems (PROC-20):
  1. `kitSearchRemoveFilter` "Remove filter {name}": `KitChip.removable` has no parameter for its remove label and always says `kitChipRemove` ("Remove Symbols"). The key is not added; the chip says "Remove Symbols". Proposed: KitChip gains an optional `removeLabel`, then this part passes `kitSearchRemoveFilter`.
  2. "Depends on KitField: the shared field chrome": KitField draws a visible label above the field and exposes no reusable chrome, so this part draws the same frame from the same tokens (`surface1`, `hairline`, `accent`, `KitTokens.fieldRadius`, `hairlineWidth`, `focusRingWidth`, `buttonHeight`). Proposed: a shared `KitFieldFrame` in kit_field.dart in a later unit.
  3. `KitScreen.search` (kit-KitScreen-v2, C06) and KitTopBar are not merged; the gallery pins the field in today's `KitScreen.header` under a plain title row.
  4. Owner decision 2026-09-27 (Arabic dropped; galleries 412x915 and 1280x800 only) replaces the spec's 32-PNG list with 16 PNGs; no `app_ar.arb` keys.
  5. Arrow Down moves focus with `focusInDirection(down)`: the first focusable below the field. With an active filter chip that is the chip's remove, then the first result.
- New kit parts (KIT-3): `KitSearchField`, `KitSearchNoMatch` (planned; this unit).
- Map items (EVID-11): n/a: no pages migrated.
- States per page (STATE-20): part states empty, typing, results, partial, no-match, filtered, disabled → goldens `kit_search_field_<state>_{dark,light}.png`, tests 1–8.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitSearchField`, base `024e97b0`, code head: the commit carrying this record.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new part | n/a | n/a |
| 2 | `test/kit/kit_search_field_test.dart` + `test/goldens/kit/kit_search_field_golden_test.dart` | pass | 29 passed | PASS |
| 3 | Ratchet, design-standard, l10n tests | not run (owner decision 2026-09-27: own tests only) | not run | NOT RUN |
| 4 | `dart analyze` on the three new Dart files | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden |
  |---|---|
  | A11Y-3 | `test/kit/kit_search_field_test.dart` "4. the count is announced once after settling" |
  | STATE-11 | "4b. a partial count shows and announces so"; golden `kit_search_field_partial_*` |
  | STATE-8 | "7. disabled needs a reason and shows it"; golden `kit_search_field_disabled_*` |
  | §8.3 keyboard | "3. Esc and back clear first, then leave", "8. Enter submits; Arrow Down moves to the first result" |
  | MOT-1 | "1. onChanged fires once after settling" (`KitMotion.typingSettle`), "11. reduced motion: one pump settles" |
  | G6 | "12. no overflow across sizes, text scales and directions" (320x800, 915x412, 1600x1000; 1.0/1.3/2.0; LTR/RTL) |

- Changed test expectations (TEST-19): none.
- Goldens added (each opened and looked at): 7 states x dark/light at 412x915, typing x dark/light at 1280x800 (word "Filter" from medium up). G5 contrast/targets pass in both themes.
- Accessibility: the field's name is `label` (the hint equals it and is excluded from semantics); magnifier excluded; clear is a 48 dp `KitIconButton` "Clear search"; filter is "Filter" / "Filter: Symbols" (tooltip on compact, semantic name on the wide word button); count announced once via `SemanticsService.sendAnnouncement`; `KitSearchNoMatch` is a live-region `KitStateView`.
- Privacy and security: n/a: the query is plain text, never stored or sent by the part.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_search_field_test.dart test/goldens/kit/kit_search_field_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared gates (ratchet, design-standard, l10n coverage) not run by this unit.
- The `KitScreen.search` placement (not merged) and the Ctrl/Cmd+F shortcut (shell layer).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitSearchField` |
| Enabled | No: no caller until wave 2 | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
