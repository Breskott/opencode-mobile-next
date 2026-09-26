# revamp-kit-KitStatusLine-v2: KitStatusLine v2 (2026-09-27)

## 1. Scope

- Unit: `kit-KitStatusLine-v2` (wave 1, tier 2, kit-change). Finish line: KitStatusLine gains the Now line (`next`), the 8 s escalation (`since`/`onSlow` on KitSince's clock), `KitStatus`/`KitStatusKind`/`KitStatus.highest`, `KitStatusLine.of`, and the status slot file, with every existing caller compiling unchanged. Non-goal: replacing any MaterialBanner or SnackBar call site, hosting the slot in KitScreen, or writing status sources.
- Files changed: `lib/ui/kit/kit_status_line.dart`, new `lib/ui/kit/kit_status_slot.dart`, new `test/kit/kit_status_line_test.dart`, new `test/goldens/kit/kit_status_line_golden_test.dart` and 24 goldens.
- Pages (map ids): none directly (kit part; the 30 map elements are adopted by screen units).
- Specs followed: `docs/ux-system/kit-api/KitStatusLine.md`; `KitScreen.md` "The status slot"; STANDARDS KIT-35, STATE-5, STATE-14, STATE-19, ARCH-8, A11Y-3, LOOK-4, LOOK-5, LOOK-21, KIT-43, LAY-8.
- Contract problems (PROC-20):
  1. `KitScreen.md` freezes `KitStatusLineSlot({status, slotKey})` with no `child`, yet `KitStatusContribution` "contributes to the nearest KitStatusLineSlot above" and `existsAbove` asks for a slot above a context. With no child, nothing can ever be below a slot, so a contribution from a KitScreen body (a sibling of the slot) can never reach it. Built exactly as frozen (ancestor lookup); contributions are inert until the contract adds a host. Proposal: an optional `Widget? child` on `KitStatusLineSlot` drawn under the line, or a `KitStatusSlotHost` that KitScreen wraps around bar, slot and body. Blocks kit-KitScreen-v2 test 4 and kit-KitRowParts-v2's risky-switch contribution.
  2. Gate G4 (`test/kit/kit_manifest_test.dart`, NAME-1) wants one public widget per `kit_<snake>.dart` file with its own test and gallery; `KitScreen.md` freezes `KitStatusScope`, `KitStatusLineSlot` and `KitStatusContribution` together in `kit_status_slot.dart` with tests in `kit_status_line_test.dart`. G4 now lists those three classes (not exported, name, gallery, test). Needs a coordinator allowlist entry or a spec change; the kit.dart export is the integrator's (R06).
  3. The spec names a shared tone map `KitTokens.toneFor`/`toneColor` (README D12) that does not exist. The line uses `KitIcon.status`, which carries the kit's one tone map (the stopgap KitIcon already documents), so no copy of the map was made.
  4. Galleries: the spec asks for 360x800, 915x412, 800x1280, 1600x1000 and Arabic; the owner decision of 2026-09-27 (phone 412x915 and 1280x800 only, no Arabic) wins. G4's gallery rule still asks for `kitGallerySizes`/`kitGalleryScaledSizes`/`_ar_` shots; KitStatusLine is already on the G4 allowlist for gallery.
  5. `package:clock` is imported by `lib/ui/kit/kit_since.dart` but not declared in `pubspec.yaml` (analyzer info `depend_on_referenced_packages`). Tests here derive the fake "now" through `KitSince.statusOf` instead of importing clock.
- New kit parts (KIT-3): `lib/ui/kit/kit_status_slot.dart` (`KitStatusScope`, `KitStatusLineSlot`, `KitStatusContribution`), frozen in KitScreen.md and assigned to this unit.
- Map items (EVID-11): deferred to the adopting units (coord-main, screen-system-2, shared-team-1).
- States per page (STATE-20): part states: condition (`connection` golden), working (progress icon test), slow (`slow` golden and escalation test), now-line (`now` golden and Now-line tests), error (`error` golden and tone test), disabled action (disabledReason test), stacked (`stacked` golden and stacking test).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitStatusLine-v2`, base `dcf05c5e`, code head: the branch's single commit.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new behaviour, not a fix | – | n/a |
| 2 | `test/kit/kit_status_line_test.dart` | passes | 20 passed | PASS |
| 3 | `test/goldens/kit/kit_status_line_golden_test.dart` (G5 in both themes) | passes | 24 passed | PASS |
| 4 | `test/kit_ratchet_test.dart`, `test/team_now_test.dart` | pass | passed; kit_status_line.dart G21 counts 4/2/2/1 → 0 | PASS |
| 5 | `test/work_tab_status_line_test.dart`, `test/chat_states_standard_test.dart`, `test/design_standard_test.dart`, `test/release_blockers_test.dart` | pass | passed | PASS |
| 6 | `test/kit_motion_test.dart`, `test/kit_motion_app_test.dart` | KitStatusLine entries pass | KitStatusLine entries pass; 15 failures in KitButton/KitActionBlock/KitConfirmSheet/KitStateView/KitProgressView "working" and the showKitMenu manifest line, none touching this part | PASS (pre-existing failures noted) |
| 7 | `test/text_scale_overflow_test.dart` | KitStatusLine scenes fit | both scenes fit; one failure lists KitConsequences, KitLtr, KitSelectable without scenes | PASS (pre-existing failure noted) |
| 8 | `test/kit/kit_manifest_test.dart` | pass | fails only on the three slot classes (contract problem 2) | FAIL (reported) |
| 9 | `flutter analyze` on the four changed Dart files | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_status_line_test.dart`) or golden |
  |---|---|
  | STATE-5 | "7 s: unchanged; 8 s: …", "with an action already there, the onSlow actions go first in More" |
  | KIT-35 | "highest follows KitStatusKind; ties keep the first; nulls are ignored", "shows the highest of the app-wide conditions and its own" |
  | SEC-9 | "a risky switch line is never dismissible" |
  | LOOK-4, LOOK-5 | "AppStatusTone.attention paints the icon in text1", "AppStatusTone.failure paints the icon in text1" |
  | KIT-43 | "keeps kit-status-more and kit-status-dismiss…", "at large text the action stacks under the words", "controlsTogether keeps action, More and dismiss on one row" |
  | G8 | "reduced motion settles after one pump (G8)" |
  | A11Y-3 | the escalation test counts live-region label changes (exactly one); the Now-line test shows a new time is not re-announced |

- Changed test expectations (TEST-19): none.
- Goldens added (each looked at): `test/goldens/kit/kit_status_line_{connection,slow,now,risky,update,error,stacked}_{dark,light}.png`, `kit_status_line_connection_1280x800_*`, `kit_status_line_{connection,now}_text2[_1280x800]_*`. The icon lines up with the first line when stacked; progress icon in accent; failure and attention icons in text1; Now line in text2; one-physical-pixel hairline under the line.
- Look changes that integrator-owned screen goldens will show (not rendered here): the message is KitText `body` (16/24, was `bodyMedium`), supporting and next are `secondary`, More and dismiss are KitIconButtons (20 dp glyph) with the KitMenu popup instead of PopupMenuButton/IconButton, the neutral icon is `text2`, attention and failure icons are `text1` (were amber and red).
- Accessibility: one live region holding the message (plus "Still waiting after 8 s" once slow); supporting and next sit outside it so a time update is not re-announced; More (`kitMore`) and dismiss (`dismissTooltip` or `kitSheetDismiss`) are 48 dp labelled KitIconButtons; 2.0 text checked in goldens at 412x915 and 1280x800. Arabic not checked (owner decision).
- Privacy and security: n/a, no credentials, stored data, links or notifications changed.
- Migration: n/a, no stored format changed.
- Copy: no new strings (reuses `kitMore`, `kitSheetDismiss`, `kitSinceStillWaiting`).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_status_line_test.dart test/goldens/kit/kit_status_line_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/work_tab_status_line_test.dart
```

## 7. NOT proven

- Not run on a device or emulator; TalkBack's live-region behaviour is inferred from the semantics tree.
- Slot contributions (contract problem 1) are untested: the frozen API cannot place a contribution under a slot.
- Screen goldens that include a KitStatusLine were not regenerated (integrator-owned).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes (slot contributions partial, PROC-32) | `revamp/kit-KitStatusLine-v2` |
| Enabled | Yes for existing callers; `KitStatusLine.of` and the slot have no callers yet | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
