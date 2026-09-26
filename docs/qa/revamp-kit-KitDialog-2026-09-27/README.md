# revamp-kit-KitDialog: KitDialog (2026-09-27)

## 1. Scope

- Unit: `kit-KitDialog` (wave 1, tier 3, kit-part). Finish line: `showKitInputDialog` and `showKitAlert` exist to the frozen API in `docs/ux-system/kit-api/KitDialog.md`, with behaviour tests and a gallery. Non-goal: migrating any call site (wave 2); editing `lib/ui/kit/kit.dart` (the integrator adds the export, R06).
- Files changed: `lib/ui/kit/kit_dialog.dart` (new), `test/kit/kit_dialog_test.dart` (new), `test/goldens/kit/kit_dialog_golden_test.dart` (new) and its PNGs, this record.
- Pages (map ids): none migrated (the 21 KitDialog elements move in wave 2).
- Specs followed: KitDialog.md; STANDARDS KIT-11, KIT-15, MOT-2, DATA-1, DATA-3, STATE-8, COPY-8; kit-v2 §8.2.
- Contract problems (PROC-20):
  1. **Tab order vs the wide row.** KitDialog.md says Tab goes field → primary → alternative → Cancel "following reading order", and that from medium the actions are one end-aligned row with the primary at the end. In `KitActionBlock`'s row the reading order is alternative, Cancel, primary, so both cannot hold. Built: stacked (compact, or any destructive alternative) = primary, alternative, Cancel, matching the Tab order; wide non-destructive row = reading order. Proposed text: "Tab follows reading order: stacked primary → alternative → Cancel; in the row, alternative → Cancel → primary."
  2. **Haptics on the discard question.** The spec says "Haptics: none (MOT-11)" and that the discard question works "exactly as showKitSheet's" one. The in-place discard reuses `KitConfirmSheet` (kind discard), which plays `KitHaptics.commit` on "Discard changes", as `showKitSheet`'s does. Proposed: accept the commit on the discard confirm (it loses input), or say the dialog's discard is silent.
  3. **Disabled field while working needs a reason.** `KitField` asserts `enabled || disabledReason != null`; the spec disables the field with no copy for it. The existing `kitWorking` ("Working") is used; no new key.
  4. **KitBidi.auto on a title placeholder.** The kit gets a finished title string and cannot find the placeholder in it; callers must wrap it (`KitBidi.auto(name)`) when building the title. Arabic/RTL dropped by the owner 2026-09-27, so not tested.
  5. **Alert focus.** Focus starts on the alert's own focus node (Esc and Enter close), not on the action/Close button: `KitButton` takes no focus node. Tab reaches the buttons.
  6. **G5 vs KitActionBlock's reason gap.** A disabled primary's reason sits `space1` (4 dp) under the filled button; flutter_test's text-contrast check inflates the text's bounds by 4 dp (`accessibility.dart` line 645), samples the button fill and fails (1.10:1 in light). The `kit_dialog_input_invalid` shot is therefore `skip: true` (behaviour covered by test 2). Proposed: KitActionBlock uses `space2` above a reason under a filled button (as `KitConfirmSheet`'s typed-name reason does), then the integrator unskips the shot. Blocks: that one golden.
  7. **Selection on open.** The text is selected before the field takes focus (not with `KitField.selectAllOnFocus`), because a programmatic select after focus raised Android selection handles over the helper line in the gallery.
- New kit parts (KIT-3): none beyond KitDialog itself.
- Map items (EVID-11): n/a (no page migrated).
- States: input-default, input-invalid, input-error, input-working, input-discard, alert, alert-with-action, alert-with-details → gallery shots below; behaviour in tests 1–12.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitDialog`, base `024e97b0` (feat/phone-setup-v2). Code head: see `git log`.
- No APK (unit agents do not build).

## 3. Devices

None: tests and goldens only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter analyze lib/ui/kit/kit_dialog.dart test/kit/kit_dialog_test.dart` | no issues | No issues found | PASS |
| 2 | `flutter test -j 1 test/kit/kit_dialog_test.dart` | passes | 38 passed | PASS |
| 3 | `flutter test -j 1 --update-goldens --plain-name dark|light test/goldens/kit/kit_dialog_golden_test.dart` | renders, G5 passes | 20 passed, 2 skipped (input_invalid) | PASS |

Owner decision 2026-09-27 (speed): no other suites were run (ratchet, design-standard, l10n not run by this unit).

## 5. Evidence

- Rule evidence (PROC-31), all in `test/kit/kit_dialog_test.dart`:

  | Rule | Test (`--plain-name`) |
  |---|---|
  | KIT-11 (names, Futures, keys) | "14. both functions return Futures and take keys" |
  | STATE-8 (reason once) | "2. an invalid empty field" |
  | DATA-1, DATA-3 | "6. changed text without a draft", "7. with a draft" |
  | STATE-7 (working) | "4. async submit" |
  | SEC-3 (secret never prefilled) | "8. the secret kind" |
  | LAY-9, LAY-14 | "9. a destructive alternative" |
  | KIT-15 (alert, one action) | "10. showKitAlert" |
  | G14 keyboard | "11. keyboard" |
  | MOT-2 (fade, no scale) | "12. reduced motion" |
  | G6 overflow | "13. overflow" (320–1600 dp, 915x412, text 1.0/1.3/2.0) |

- Goldens (new, dark and light): `kit_dialog_input_default`, `_input_default_1280x800`, `_input_default_text2`, `_input_default_text2_1280x800`, `_input_error`, `_input_working`, `_input_discard`, `_alert`, `_alert_with_action`, `_alert_with_details` (20 PNGs, DPR 3; each opened and looked at; `input_invalid` skipped, contract problem 6). Arabic/RTL and the other §8.4 sizes dropped by the owner decision of 2026-09-27.
- Changed test expectations (TEST-19): none.
- Accessibility: the title names the route (`namesRoute`, header) inside a `scopesRoute` node; the disabled primary's reason is visible text; buttons 48 dp; 200 % text wraps the title and keeps the helper whole (body scrolls, actions pinned).
- Privacy and security: the secret kind uses `KitField.secret` (redacted controller, obscured, no suggestions), asserts on a prefill or a draft, and returns the value only through the Future.
- Migration: n/a (no stored format changed; drafts use the existing `oc.draft.<target>.<profileId>` key).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_dialog_test.dart
$F test -j 1 test/goldens/kit/kit_dialog_golden_test.dart
$F analyze lib/ui/kit/kit_dialog.dart test/kit/kit_dialog_test.dart test/goldens/kit/kit_dialog_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator; IME behaviour on a real keyboard is untested.
- Arabic/RTL (owner decision) and the 360x800, 800x1280, 1600x1000, 915x412 gallery sizes.
- The shared gates (ratchet, design standard, l10n coverage, G4 manifest) were not run by this unit.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitDialog` |
| Enabled | No: not exported from `kit.dart` and no call site yet (wave 2) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
