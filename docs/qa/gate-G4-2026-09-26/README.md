# gate-G4: kit manifest (2026-09-26)

## 1. Scope

- Unit: gate `G4` (W1, STANDARDS.md §18.1 row G4 and §18.2 "G4 (ratchet on a shrinking allowlist)"). Finish line: `test/kit/kit_manifest_test.dart` reads the `kit.dart` exports into a manifest, checks every exported part and `showKit…` opener, passes on today's code through a checked-in allowlist that may only shrink, and fails on a new violation. Non-goal: fixing any part, and moving G5, G6, G8x or G14x onto the manifest (those gates' own files).
- Files changed: `test/kit/kit_manifest_test.dart`, `test/kit/kit_manifest_allowlist.json`, this folder.
- Pages (map ids): none (a gate, no page).
- Specs followed: STANDARDS.md rules NAME-1, KIT-3, KIT-10, KIT-11, KIT-12, KIT-13, KIT-14, KIT-27, KIT-32, LAY-4, LAY-13, LOOK-23, TEST-9, TEST-14, TEST-15.
- Contract problems (PROC-20): the rules do not say how a part "declares its states in its doc comment" (KIT-12). This gate settles it as one doc line `/// States: loading, empty, error.` (or `/// States: none.`), with values from {loading, empty, error, disabled, working, answered}; a gallery scene per state is a golden name `<snake>_<state>` in the part's gallery file (for example `kit_sheet_loading`). Also, `kitGallerySizes` in `test/goldens/kit/kit_gallery.dart` lacks the LAY-4 gallery size 915×412; it is allowlisted as `harness · kitGallerySizes 915x412` for the owner of that file (G5/G23).
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a, no page.
- States per page (STATE-20): n/a.
- Deferred states (STATE-21): none.

### What the gate checks

The manifest is every public class exported by `lib/ui/kit/kit.dart` whose superclass chain reaches a Flutter widget (resolved through every `class … extends` under `lib/` and `test/kit_ratchet_flutter_widgets.json`), or `KitScene`, plus every public `showKit…` function. It follows `show`/`hide` combinators, re-exports (`kit_effects.dart` → `lib/state/effects.dart`) and `part` files (`kit_confirm_sheet.dart`). A widget in a file that declares a `showKit…` opener is modal; a class whose name ends in `Row` is a row. It fails loudly if the scan finds nothing (KitSheet, KitConfirmSheet, KitRow, showKitSheet and showKitConfirm must be there) or a `show` name resolves to no declaration.

| Check | Rules | Applies to | Passes when |
|---|---|---|---|
| name | NAME-1 | parts, scopes, scenes | class `Kit<Name>` in `lib/ui/kit/kit_<snake>.dart` or `lib/ui/kit/chat/`; scenes in `lib/ui/kit/scenes/kit_<snake>.dart` |
| states | KIT-12 | drawn parts | one valid `States:` line in the doc comment |
| stateScenes | KIT-12, TEST-9 | drawn parts | every declared state has a `<snake>_<state>` golden in its gallery |
| gallery | TEST-9, TEST-14, LAY-4, KIT-32 | drawn parts | `test/goldens/kit/<snake>_golden_test.dart` uses `kitGallerySizes`, `kitGalleryScaledSizes`, `text2`, `_ar_`; for a scene, dark and light shots |
| test | TEST-15, NAME-1 | parts, scopes | `test/kit/<snake>_test.dart` exists |
| docRow | KIT-14 | parts, scopes, scenes, openers | a `/// |` row of the `kit.dart` table names `[<Name>]` |
| motion | TEST-15 (G8) | drawn parts | named (class or opener) in `test/kit_motion_test.dart`, or that file imports the manifest |
| keyboard | TEST-15 (G14) | modal parts and rows | named in `test/kit/kit_keyboard_test.dart`, or that file imports the manifest |
| overflow | TEST-15 (G6) | drawn parts | named in `test/text_scale_overflow_test.dart`, or that file imports the manifest |
| openerReturn | KIT-11 | openers | `Future<…>`; exactly `Future<T?>` / `Future<bool>` / `Future<String?>` for showKitSheet / showKitConfirm / showKitInputDialog; `void` only for showKitUndo |
| openerKey | KIT-10 | openers except showKitUndo | an optional (not `required`) `Key? …Key` parameter |
| harness | LAY-4, TEST-9 | `kit_gallery.dart` | `kitGallerySizes` holds all six LAY-4 gallery sizes, `kitGalleryScaledSizes` both TEST-9 sizes |

KIT-3, KIT-13, KIT-27, LAY-13 and LOOK-23 are covered only as far as a part must have a gallery, tests and the matrix entries; their visual content stays with the reviewer (§17) and the part's own G9 tests.

The consumers (G5, G6, G8x, G14x) can `import 'kit_manifest_test.dart' show readKitManifest, KitManifestPart;` and iterate `readKitManifest().parts`; a consumer that imports it counts as covering every part for its check.

### Baseline (allowlist) at creation

Manifest: 40 widget classes (39 drawn parts, 1 scope `KitEffectsScope`), 1 scene (`KitPortalScene`), 2 openers (`showKitSheet`, `showKitConfirm`). 230 allowlisted violations:

| Check | Entries |
|---|---|
| name | 24 |
| states | 39 (no part declares states yet) |
| stateScenes | 0 |
| gallery | 38 (only KitSheet and KitConfirmSheet have galleries) |
| test | 37 |
| docRow | 13 |
| motion | 36 |
| keyboard | 3 (KitRow, KitSwitchRow, KitExpandRow) |
| overflow | 39 |
| openerReturn | 0 |
| openerKey | 0 |
| harness | 1 (`kitGallerySizes 915x412`) |

The §18.2 named predating parts (KitIconButton, KitSecretField, KitInset) are on it along with every other part that lacks something today.

## 2. Builds

- Branch `gate/G4`, base `9220f070`, code head: the record commit (the gate's code and this record land in one commit).
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_manifest_test.dart` on today's code | passes | 2 passed (`run-pass.txt`) | PASS |
| 2 | Probe 1: throwaway `lib/ui/kit/kit_zz_probe.dart` (KitZzProbe, no states/gallery/test/row; `void showKitZzProbe(context)`) exported from `kit.dart` | fails naming each missing item | failed, 10 violations (`run-fail-probe1.txt`) | PASS |
| 3 | Probe 2: same file with an unknown state (`sparkly`), a declared `loading` without its scene, a part in the wrong file, a non-`Kit` name, a well-formed opener and one whose only key is `required` | fails on each; the well-formed opener passes | failed, 26 violations; `showKitZzProbe` (optional `Key? probeKey`, `Future<void>`) not listed (`run-fail-probe2.txt`) | PASS |
| 4 | Probe files removed and `kit.dart` restored (`git checkout`) | tree clean apart from the gate files | clean | PASS |
| 5 | Stale entry: `KitSheet` added to the `keyboard` allowlist | passes and prints the smaller allowlist | passed, printed `keyboard · KitSheet` and the JSON (`run-shrink.txt`) | PASS |
| 6 | `KIT_MANIFEST_WRITE=1` with the stale entry | writes the smaller list, never adds | wrote it; identical to the committed allowlist (`run-write.txt`) | PASS |
| 7 | `flutter analyze test/kit/kit_manifest_test.dart` | no issues, no `// ignore:` | No issues found | PASS |

## 5. Evidence

- `run-pass.txt`, `run-fail-probe1.txt`, `run-fail-probe2.txt`, `run-shrink.txt`, `run-write.txt` (outputs of runs 1, 2, 3, 5, 6).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) | Output |
  |---|---|---|
  | NAME-1, KIT-10–KIT-14, TEST-9, TEST-14, TEST-15, LAY-4 | `test/kit/kit_manifest_test.dart` "G4: every kit part and opener meets the manifest (allowlist only shrinks)" | `run-pass.txt`, `run-fail-probe1.txt`, `run-fail-probe2.txt` |
  | (loud failure on an empty scan) | `test/kit/kit_manifest_test.dart` "G4: the manifest reads the kit library" | `run-pass.txt` |

- Changed test expectations (TEST-19): none.
- Goldens changed: none.
- Accessibility: n/a, a source scan.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/kit/kit_manifest_test.dart
# shrink the allowlist after a part is fixed (never adds entries):
KIT_MANIFEST_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/kit/kit_manifest_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/kit/kit_manifest_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (none needed for a source scan).
- The scan is textual: a class whose superclass lives outside `lib/` and outside the Flutter widget catalogue is not seen as a widget, and a consumer counts a part as covered by name only, not by what its test asserts.
- The gallery check reads the gallery source for `kitGallerySizes`, `kitGalleryScaledSizes`, `text2` and `_ar_`; it does not prove every shot renders or that the PNGs exist (G23), nor the TEST-9 device pixel ratio 3.0 (the harness pumps at 1.0; G23's).
- Non-widget exports (KitTokens, KitMotion, KitLayout, KitTechnicalValue, enums) are not required to have doc rows; KIT-14 is read as widget parts, scenes and openers.
- The allowlist only shrinking across commits is enforced by this test only within one run; across commits it is G31's job.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G4` |
| Enabled | Yes | runs with `flutter test` |
| Verified | tests only | this record |
| Committed | Yes | `gate/G4` |
| Deployed | No | |
| Released | No | |
