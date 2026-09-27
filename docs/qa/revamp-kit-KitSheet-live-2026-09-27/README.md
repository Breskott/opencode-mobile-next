# revamp-kit-KitSheet-live: KitSheet live pinned actions (2026-09-27)

## 1. Scope

- Unit: `kit-KitSheet-live` (wave 1, tier 6, kit-change). Finish line: a sheet's pinned primary (Send/Submit) can enable, disable or change while the sheet is open and stays pinned, and at 2.0 text with a 300 dp keyboard at 412x915 the frame never overflows. Non-goal: moving any caller (including `showKitRequestSheet`'s `dirty` workaround) onto the new parameter.
- Files changed: `lib/ui/kit/kit_sheet.dart`, `test/kit/kit_sheet_live_actions_test.dart` (new).
- Pages (map ids): none directly (kit part; the 41 KitSheet pages in KitSheet.md benefit).
- Specs followed: coordinator ruling (contract problems from kit-KitRequestSheet and screen-shell-1); `docs/ux-system/kit-api/KitSheet.md` (Accessibility: "the pinned actions stay pinned and visible, also with `viewInsets.bottom` 300 (KIT-17)"; "a short window lets the header scroll with the body"); STANDARDS KIT-17, KIT-43, A11Y-8.
- Contract problems (PROC-20): the frozen KitSheet.md API block does not list `primaryListenable`; added under the coordinator ruling, which is later than the freeze. The name and semantics chosen: `ValueListenable<KitAction?>? primaryListenable`; while it holds null, `primary` is shown. The spec should add this line to its API block.
- New kit parts (KIT-3): none. Private seams added inside `kit_sheet.dart`: `_KitSheetFrame`/`_RenderKitSheetFrame` (header, scroll, pinned block layout), `_KitHeaderSpacer`, `_PullDownRecognizer`. The seams listed in KitSheet.md for the confirm part are unchanged.
- Map items (EVID-11): n/a: no page records in this unit.
- States per page (STATE-20): n/a (kit part). Frame states touched: `keyboard-open` at 2.0 text → `kit_sheet_live_actions_test.dart`; `disabled` → enabled live → same file.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitSheet-live`, base `0003f9cd` (feat/phone-setup-v2), code head `2d0ac9fe`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_sheet_live_actions_test.dart` | passes | 4 passed | PASS |
| 2 | `test/kit/kit_sheet_test.dart` (the part's existing tests, unchanged) | passes | 28 passed | PASS |
| 3 | `flutter analyze lib/ui/kit/kit_sheet.dart test/kit/kit_sheet_live_actions_test.dart` | no issues | no issues | PASS |

Ratchet, design-standard, l10n and golden suites were not run (owner decision 2026-09-27: run only the unit's own test files).

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) | Output |
  |---|---|---|
  | KIT-17 (live primary) | `test/kit/kit_sheet_live_actions_test.dart` "the pinned primary enables, changes and stays pinned when its listenable changes" | run 1 |
  | KIT-17 (keyboard + 2.0 text, no overflow) | `test/kit/kit_sheet_live_actions_test.dart` "at 2.0 text with a 300 dp keyboard at 412x915 the frame does not overflow" | run 1 |
  | KIT-43 | `test/kit/kit_sheet_test.dart` (all existing calls unchanged) | run 2 |

- Changed test expectations (TEST-19): none.
- Goldens changed: none regenerated. The frame is visually identical whenever the header fits (every existing gallery state); only the cramped case (header taller than the room above the pinned block) now scrolls the header instead of overflowing.
- Before and after: no before render (no gallery state covers 2.0 text with the keyboard open; no new galleries per the unit's acceptance).
- How the fix works: the header stays outside the body's scroll view (a swipe on the grabber still drags the bottom sheet). When header + pinned block leave the body less than `2 × minTarget`, the header's height is reserved as the scroll view's first sliver, the header is drawn at the scroll offset, clipped to the scroll area (never over the pinned block), and a drag on the header scrolls. The pinned block keeps its natural height up to the frame height less that reserve; beyond that it is cut at the bottom, never overflowed.
- Accessibility: title and subtitle still wrap untruncated (A11Y-8); Close stays a 48 dp KitIconButton and is reachable after scrolling back; the header's semantics clip follows the scroll area; 200 % text with the keyboard checked at 412x915.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_sheet_live_actions_test.dart test/kit/kit_sheet_test.dart
$F analyze lib/ui/kit/kit_sheet.dart test/kit/kit_sheet_live_actions_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The fix's test was not run against the base without the fix (owner speed decision); the test asserts the header scrolls away, a path that exists only with the fix.
- Other suites that open sheets (`test/kit/kit_request_sheet_test.dart`, `kit_keyboard_test.dart`, `kit_draft_test.dart`, screen tests, `kit_sheet_*` goldens) were not re-run.
- A pinned block taller than the frame less 96 dp (3.0 text with four actions in a landscape phone) is cut rather than scrollable.
- Intrinsic/dry layout of `KitSheet` is not supported (the previous Column already contained a LayoutBuilder through KitActionBlock).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitSheet-live` |
| Enabled | Yes (no caller uses `primaryListenable` yet) | |
| Verified | tests only | this record |
| Committed | Yes | code head `2d0ac9fe` |
| Deployed | No | |
| Released | No | |
