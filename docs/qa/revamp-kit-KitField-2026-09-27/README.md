# revamp-kit-KitField: KitField, the one labelled text input (2026-09-27)

## 1. Scope

- Unit: `kit-KitField` (wave 1, tier 2, kit-part). Finish line: `KitField` (text, multiline, mono, path, url, number), `KitField.composer` and `KitField.secret` exist in `lib/ui/kit/kit_field.dart` to the frozen spec, with behaviour tests and galleries, and `KitSecretField` keeps working by forwarding to the secret kind. Non-goal: migrating any screen (wave-2 screen units), editing `kit.dart`.
- Files changed: `lib/ui/kit/kit_field.dart` (new), `lib/ui/kit/kit_secret_field.dart` (now `export 'kit_field.dart' show KitSecretField;`), `lib/l10n/app_en.arb` (12 `kitField*` keys), `test/kit/kit_field_test.dart` (new), `test/goldens/kit/kit_field_golden_test.dart` (new) and 28 PNGs `test/goldens/kit/kit_field_*.png`.
- Pages (map ids): none (a kit part; the 26 map elements that it replaces migrate in wave 2).
- Specs followed: `docs/ux-system/kit-api/KitField.md`; STANDARDS KIT-20, KIT-21, KIT-40, KIT-43, SEC-3, SEC-12, DATA-1, DATA-2, STATE-5, STATE-8, LAY-9, LOOK-21, MOT-7, G8, G21; kit-v2 §1.4, §4.9, §4.10, §8.
- Contract problems (PROC-20):
  1. **@Deprecated vs KIT-43.** The unit's acceptance line says "KitSecretField becomes a @Deprecated wrapper (R12)"; STANDARDS KIT-43 and KitField.md say never `@Deprecated` (it would put infos into every caller's analyze) and use `/// Retired by kit-KitField: use KitField.secret`. STANDARDS wins (its §0.2 and the task's own authority order): built with the retire note, no `@Deprecated`. Proposed: drop "@Deprecated" from the R12 acceptance text for kit units.
  2. **KitSecretField's file vs G4 `name`.** KitField.md puts `KitSecretField` in `kit_field.dart` (it forwards through a private constructor there) and makes `kit_secret_field.dart` a re-export; `test/kit/kit_manifest_test.dart` G4 `name` wants the class declared in `kit_secret_field.dart`. Built to the spec; the G4 allowlist needs a `name · KitSecretField` entry (or the manifest a re-export rule). Blocks nothing at runtime.
  3. **G4 gallery / stateScenes vs the owner decision.** G4 wants `kitGallerySizes` (five sizes), an `_ar_` golden and `kitGalleryShot(` calls with literal state names; the owner decision of 2026-09-27 drops Arabic and limits galleries to 412x915 and 1280x800, and kit galleries of non-modal parts use `kitGalleryPart`, which the manifest parser does not read. Recorded for the integrator's allowlist.
  4. **Copy keys.** The spec lists `kitFieldShow`/`kitFieldHide` "with the field label appended in semantics"; concatenating words is not localisable, so two keys were added: `kitFieldShowNamed` "Show {label}" and `kitFieldHideNamed` "Hide {label}" (tooltip = semantic name, G14). `kitFieldStillChecking` carries `{seconds}` from `KitMotion.escalateAfter`, like `kitSinceStillWaiting`.
  5. **Arabic copy.** R04 asks for `app_ar.arb` too; the owner decision of 2026-09-27 (later, wins) says en only. No Arabic entries were added.
  6. **Constructor asserts that are not constant.** KitField.md's frozen constructors assert `identical(controller, draft.controller)`, `onSlow.length <= 2` and `action.icon != null`. None of these is a constant expression (an `identical` call on fields, a `List.length` read, a member read through a nullable field), so a `const` constructor cannot carry them. They run in `_KitFieldState._checkStructure`, called from `initState` and `didUpdateWidget`, so a wrong structure asserts when the field mounts or updates rather than when it is constructed. The test "5. three onSlow actions assert" exercises the `onSlow` one at mount; the draft-controller and action-icon asserts have no dedicated test. Proposed: amend KitField.md to move these three into a "Checked at mount" list, keeping only the constant asserts (`enabled || disabledReason != null` and similar) on the constructors.
  7. **Replace's semantic name.** KitField.md names no copy for a field-specific Replace. Instead of adding a `kitFieldReplaceNamed` key, the saved row is one merged semantics node, "API key, Saved, Replace". Its tap is Replace, and its hint is the helper or error, with a disabled Replace's own reason. This keeps every saved key on a screen distinct (KIT-20) with no new copy. Proposed: record this in KitField.md's a11y section.
- New kit parts (KIT-3): none beyond this unit's own `KitField` (plus `KitFieldKind` and the `@visibleForTesting` `KitNumberFormatter`).
- Map items (EVID-11): n/a (no pages in this unit).
- States (STATE-20): default, focused, filled, error, disabled, checking, checking-slow, counter, limit, secret-masked, secret-revealed, secret-saved, multiline-draft-restored → tests 1–16 in `test/kit/kit_field_test.dart` and the galleries below. The doc comment's machine line is `States: empty, error, disabled, working.` (the G4 vocabulary); the part's own list follows it.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitField`, base `dcf05c5e`, code head `a1410445`. Review fixes (paste formatters, saved-row semantics, Replace reason, redacted editable controller) are in the commit after `4e2e22eb`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_field_test.dart` | passes | 37 passed (incl. 12 G8x samples) after the review fixes. With the fixes reverted, the 4 new or extended tests fail (paste formatters, saved semantics, disabled saved reason, element-tree diagnostics) | PASS |
| 2 | `test/kit/kit_secret_field_test.dart` (existing contract) | passes unchanged | 3 passed | PASS |
| 3 | `test/goldens/kit/kit_field_golden_test.dart` | 28 shots match, G5 clean in both themes | 28 passed (unchanged by the review fixes: `secret_saved` renders the same pixels) | PASS |
| 4 | `test/mcp_setup_screen_test.dart` (the one KitSecretField caller) | passes unchanged | passed | PASS |
| 5 | `test/kit_ratchet_test.dart` | no new G-counts for the changed files | passed (G21 reports 20 dropped base entries, integrator regenerates) | PASS |
| 6 | `test/design_standard_test.dart`, `test/l10n_coverage_test.dart` | pass | passed | PASS |
| 7 | `test/kit_motion_test.dart` | KitSecretField samples pass | KitSecretField passes; 14 other failures are on the base (KitButton/KitActionBlock/KitConfirmSheet/KitStateView/KitProgressView "now settles" ratchet entries, `showKitMenu` missing samples) | PASS for this unit |
| 8 | `test/kit/kit_manifest_test.dart` | KitField rows only as expected before the integrator's export | `exported`, `docRow` (integrator, R06), `name · KitSecretField`, `gallery`, `stateScenes` (problems 2–3 above); the test was already red on the base | see §1 |
| 9 | `test/golden_harness_test.dart` | no KitField violation | only `arabicFont: kit_page_route_golden_test.dart` (base) | PASS for this unit |
| 10 | `flutter analyze` (whole tree) | no issues in changed paths | none in changed paths; base issues remain: `kit_image_test.dart` `KitIconButton.label` errors, `clock` dependency infos | PASS for this unit |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_field_test.dart` `--plain-name`) or golden |
  |---|---|
  | KIT-20 | "1. the label shows above, names the field, and focuses it" |
  | KIT-21 | "2. the counter appears at 80 %…", "3. the error replaces the helper…", "5. checking says so without a spinner…" |
  | STATE-5 | "5. checking says so…", "5. three onSlow actions assert" |
  | STATE-8, G37 | "4. disabled without a reason asserts", "4. disabled shows its reason…" |
  | SEC-3, SEC-12, KIT-40 | "10. secret asserts an empty controller at mount", "10. secret is obscured, never learned, reveals, pastes…", "10. saved shows Saved · Replace…" |
  | KIT-20 (saved), STATE-8 (saved), G37 | "10. saved shows Saved · Replace…" (one node reads "API key, Saved, Replace", tap is Replace), "10. a disabled saved secret says why Replace is off" |
  | SEC-2 | "10. secret is obscured…" (no `sk-ant` in `rootElement.toStringDeep()`, masked and revealed), "diagnostics never carry the controller text" |
  | Paste = keyboard paste | "10. Paste runs through the input formatters, like a keyboard paste" (`'  sk-abc\n'` with a whitespace-deny formatter → `sk-abc`) |
  | KIT-43 | "11. KitSecretField keeps its contract…", `test/kit/kit_secret_field_test.dart`, `test/mcp_setup_screen_test.dart` |
  | DATA-1, DATA-2 | "8. multiline with a draft restores, saves under its key and clears" |
  | MOT-7, G8 | "14. under reduced motion one pump settles the error fold", `KitField (MOT-7)` samples |
  | LAY-9, G14 | "15. the trailing action is a labelled 48 dp target"; G5 `androidTapTarget` in every gallery shot |
  | G6 | "16. no overflow from 320 to 1600 dp at text 1.0-2.0…" |

- Changed test expectations (TEST-19): none.
- Goldens (all new, each opened and looked at): `kit_field_{default,focused,filled,error,disabled,checking,checking_slow,counter,secret_masked,secret_saved,multiline}_{dark,light}.png` at 412x915, `kit_field_default_1280x800_{dark,light}.png`, `kit_field_default_text2[_1280x800]_{dark,light}.png`. Approved VL canvas render: none for KitField (EVID-12).
- Before and after: no before render (new part); the goldens above are the after images.
- Accessibility: the label is the editable's semantic label (not read twice), helper/error/reason is its hint; in the saved state the row carries the label (one node "API key, Saved, Replace") and a disabled Replace carries its reason as hint; the error line is a live region labelled "Error: …"; the counter ("8 of 10", "Limit reached") and "Still checking after 8 s" are announced once each; a single-line editable sits on a line box of at least 48 dp so the field itself is a 48 dp target (found by G5 on the first render and fixed); reveal/paste/action are 48 dp `KitIconButton`s whose tooltip is the semantic name; 200 % text checked in galleries and in test 16.
- Privacy and security: the secret kind has no suggestions, autocorrect, IME learning or autofill hints; it asserts an empty controller at mount; the value is never the semantics value while masked, and never in `KitField`'s diagnostics or anywhere in the element tree's diagnostics (tested). In the secret modes the editable edits a private twin of the host's controller, kept in step both ways, whose `toString` is redacted; Paste runs through the same formatter chain as a keyboard paste (tested); Paste reads the clipboard once on tap (tested). When the person reveals the value, the framework field exposes it to a screen reader, which is what reveal asks for.
- Migration: n/a: no stored format changed (drafts use the existing `KitDraft` key `oc.draft.<target>.<profileId>`).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/kit/kit_field_test.dart test/kit/kit_secret_field_test.dart
$F test -j 1 test/goldens/kit/kit_field_golden_test.dart test/mcp_setup_screen_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart
$F analyze
```

## 7. NOT proven

- Not run on a device or emulator (IME behaviour, the real clipboard, TalkBack reading of the live region and announcements).
- `kit.dart` does not export `KitField` yet (integrator, R06), so the manifest-driven gates (`kit_motion_test`, keyboard, overflow, accessibility lists) have not run against it; its own G8x samples are registered in `test/kit/kit_field_test.dart` for when they do.
- The G2 ratchet pattern for `KitSecretField(` (KIT-43) is not added: its baseline file is integrator-owned.
- Number kind: the spec says typed digits keep their shape on screen and the value is ASCII; this build normalises the controller text itself, so Arabic-Indic digits show as ASCII once typed (Arabic is dropped for now).
- The secret's render tree: while revealed, `RenderEditable` holds the plain text (it draws it), so a render-tree dump (`debugDumpRenderTree`) shows the value then. While masked it holds the obscuring characters. The element tree and widget diagnostics are redacted in both states (tested).
- Reveal and paste glyph swap: `KitIconButton` keys its glyph by role, so the eye/eye-off change is instant rather than a `KitMotion.quick` cross-fade.
- `Form.reset()` on a validated field clears the error on the next rebuild of the field (any keystroke or parent rebuild), not in the same frame.
- The `checking` semantic hint reads the phase at build; the visible line switches at 8 s through `KitSince` while the hint updates on the next rebuild.
- `KitField.composer` has no frame and a 1-line minimum; its 48 dp target is `KitComposer`'s job.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitField` |
| Enabled | No: not exported from `kit.dart` and no screen uses it yet | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `a1410445` |
| Deployed | No | |
| Released | No | |
