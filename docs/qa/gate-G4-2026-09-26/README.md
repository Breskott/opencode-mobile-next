# gate-G4: kit manifest (2026-09-26)

## 1. Scope

- Unit: gate `G4` (W1, STANDARDS.md §18.1 row G4 and §18.2 "G4 (ratchet on a shrinking allowlist)"). Finish line: `test/kit/kit_manifest_test.dart` reads the `kit.dart` exports and every file under `lib/ui/kit/` into a manifest, checks every part, scene and `showKit…` opener, passes on today's code through a checked-in allowlist that only shrinks (new, stale and grown entries all fail), and fails on a new violation. Non-goal: fixing any part, and moving G5, G6, G8x or G14x onto the manifest (those gates' own files).
- Files changed: `test/kit/kit_manifest_test.dart`, `test/kit/kit_manifest_allowlist.json`, this folder.
- Pages (map ids): none (a gate, no page).
- Specs followed: STANDARDS.md rules NAME-1, KIT-3, KIT-10, KIT-11, KIT-12, KIT-13, KIT-14, KIT-27, KIT-32, LAY-4, LAY-13, LOOK-23, TEST-9, TEST-14, TEST-15.
- Contract problems (PROC-20):
  1. **States line.** The rules do not say how a part "declares its states in its doc comment" (KIT-12). This gate settles it as one doc line `/// States: loading, empty, error.` with values from {loading, empty, error, disabled, working, answered}, or `/// States: none — <why, at least three words>.` A bare `States: none.` fails.
  2. **KIT-12's second sentence, read from the fields.** The gate reads the part's own `final <Type> <name>;` fields. A nullable `on…` callback requires `disabled`. `onDismiss` and `onClose` are exempt, because a null close callback removes the close affordance rather than disabling it; this is a deliberate narrowing of the review's "on…" wording. A `working`/`busy`/`sending`/`submitting` flag or an `onSubmit…`/`onSend…` callback requires `working`. A `Future`/`Stream`/`AsyncSnapshot`/`ValueListenable<List…>` field, or a `List`/`Iterable`/`Map` of a non-UI type (anything other than `Widget`, `Kit…`, `String`, numbers, `bool`, `IconData`, `Color`, geometry, spans, `Key`, `Duration`, `Animation`, `TextInputFormatter`, shadows, `Locale` and keyboard keys), counts as server data and requires loading, empty and error. Function-typed fields are callbacks, not data. All 41 drawn parts sit on the `states` allowlist today, so this binds from the first `States:` line a part writes. Today it would demand: `disabled` from KitButton, KitIconButton, KitPanel, KitRow, KitSwitchRow, ProductEmptyState and ProductInlineEmpty; `working` from KitButton and KitConfirmSheet.
  3. **Golden naming for state scenes.** Each declared state needs a golden at 412×915 in dark and in light (TEST-9). The golden counts when its name starts `<snake>_<state>`, followed by the end of the name, `_` or `$`. The name is taken from the `name:` argument of `kitGalleryShot` or from a `matchesGoldenFile` literal. A mode is covered by a literal `dark`/`light` in the name, or by `$mode` when the file has both `'dark'` and `'light'` literals. The size is covered by `412x915` in the name, or by a `size:` argument that is `Size(412, 915)`, a variable bound to it, or the loop variable over `kitGallerySizes`/`kitGalleryScaledSizes`. **This conflicts with the existing KitConfirmSheet gallery.** Its goldens are named `kit_confirm_*` (`kit_confirm_stop_working_$mode`, `kit_confirm_failed_$mode`, …), but its snake is `kit_confirm_sheet`. Migration: when KitConfirmSheet writes its `States:` line (working, error, …), its owning unit renames those shots in `test/goldens/kit/kit_confirm_sheet_golden_test.dart` to `kit_confirm_sheet_<state>_…_$mode` and regenerates its own PNGs, for example `kit_confirm_stop_working_$mode` → `kit_confirm_sheet_working_$mode` and `kit_confirm_failed_$mode` → `kit_confirm_sheet_error_$mode`. The other shots may keep their names. KitSheet already matches (`kit_sheet_loading_$mode`, `kit_sheet_disabled_$mode` at `phone = Size(412, 915)`; run 7 proves it).
  4. **Unexported kit files (found in review).** The first version read only `kit.dart`'s exports. It never saw 23 KitScene subclasses: KitFoldersOpenScene, the 5 Setup*/ServersLink scenes, ServersWelcomeScene, the 6 States*Scene, StatesWorkingScene, the 7 Team*Scene and the 2 TeamDiscover* scenes. It also missed TerminalKeyBar and LiquidGlassFilter. Screens import all 25 of these by path. The review counted them as 25 scenes out of 26; the actual count is 23 of 24 scenes, plus 2 widgets. The gate now scans every `.dart` file under `lib/ui/kit/` and fails `exported` for anything `kit.dart` cannot reach. Today's 25 are allowlisted under exported, name, gallery and docRow, and the two widgets under every drawn-part check as well. Their scene goldens exist but live outside the NAME-1 gallery path (`test/kit_states_scenes_test.dart`, `test/setup_scenes_test.dart`, `test/servers_scenes_test.dart`, `test/goldens/team_scenes_golden_test.dart`, `test/goldens/team_discover_scenes_golden_test.dart`, `test/goldens/folder_browser_golden_test.dart`), so TEST-14 is allowlisted for them until they move. `export` lines with double quotes are now read (run 4), and commented-out directives are ignored.
  5. **The allowlist is missing from PROC-13 and G31 (not fixable here).** PROC-13's "Baselines" list and G31's inputs (§18.2 G31) do not name `test/kit/kit_manifest_allowlist.json`. Both live in `docs/ux-system/revamp/STANDARDS.md`, and G31's tool, `tool/qa/check_ratchets_only_shrink.py`, belongs to another gate, so this gate cannot edit either (PROC-10). Reported to the coordinator. Meanwhile the test enforces the ratchet itself: an entry outside `_creationAllowlist`, the frozen 338-entry set written into the test, fails. Growing the allowlist therefore means editing the gate's own test, a KIT-44 `ratchet-tighten: G4 <check>` change.
  6. `kitGallerySizes` in `test/goldens/kit/kit_gallery.dart` lacks the LAY-4 gallery size 915×412. It is allowlisted as `harness · kitGallerySizes 915x412` for the owner of that file (G5/G23).
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a, no page.
- States per page (STATE-20): n/a.
- Deferred states (STATE-21): none.

### What the gate checks

The manifest has three sources. The first is every public class that `lib/ui/kit/kit.dart` exports. The scan follows `show`/`hide`, re-exports (`kit_effects.dart` → `lib/state/effects.dart`), `part` files (`kit_confirm_sheet.dart`) and either quote style. The second is every public class declared in any `.dart` file under `lib/ui/kit/`, which catches files imported by path. A class from either source enters the manifest when its superclass chain reaches a Flutter widget or `KitScene`; chains resolve through every `class … extends` under `lib/` and `test/kit_ratchet_flutter_widgets.json`. The third is every top-level `showKit…` function. Every source is read with its comments blanked, and bracket matching ignores string contents, so neither a comment nor a string can satisfy a check. A widget in a file that declares a `showKit…` opener is modal, and a class whose name ends in `Row` is a row.

The first test fails loudly in four cases: the scan misses KitSheet, KitConfirmSheet, KitRow, showKitSheet, showKitConfirm, StatesSheetScene or TerminalKeyBar; a `show` name matches no declaration; or a top-level `showKit…` cannot be read into a return type and parameter list (run 9).

| Check | Rules | Applies to | Passes when |
|---|---|---|---|
| exported | KIT-14, NAME-1 | parts, scopes, scenes, openers | reachable from `kit.dart` |
| name | NAME-1 | parts, scopes, scenes | class `Kit<Name>` in `lib/ui/kit/kit_<snake>.dart` or `lib/ui/kit/chat/`; scenes in `lib/ui/kit/scenes/kit_<snake>.dart` |
| states | KIT-12 | drawn parts | one valid `States:` line, a reason after `none`, and every state its fields require (contract problem 2) |
| stateScenes | KIT-12, TEST-9 | drawn parts | each declared state has a `<snake>_<state>…` golden at 412×915 in dark and in light (contract problem 3) |
| gallery | TEST-9, TEST-14, LAY-4, KIT-32 | drawn parts, scenes | `test/goldens/kit/<snake>_golden_test.dart` whose code uses `kitGallerySizes` and `kitGalleryScaledSizes`, has a golden named `…text2…` at `textScale: 2` and one named `…_ar_…` with `Locale('ar')`; for a scene, dark and light golden names |
| test | TEST-15, NAME-1 | parts, scopes | `test/kit/<snake>_test.dart` exists |
| docRow | KIT-14 | parts, scopes, scenes, openers | a `/// \|` row of the `kit.dart` table names `[<Name>]` |
| motion | TEST-15 (G8) | drawn parts | the code of `test/kit_motion_test.dart` names the class or its opener, or calls `readKitManifest(` |
| keyboard | TEST-15 (G14) | modal parts and rows | the same test against `test/kit/kit_keyboard_test.dart` |
| overflow | TEST-15 (G6) | drawn parts | the same test against `test/text_scale_overflow_test.dart` |
| openerReturn | KIT-11 | openers | `Future<…>`: exactly `Future<T?>` / `Future<bool>` / `Future<String?>` for showKitSheet / showKitConfirm / showKitInputDialog; `void` only for showKitUndo; a missing return type fails |
| openerKey | KIT-10 | openers except showKitUndo | an optional (not `required`) `Key? …Key` parameter |
| harness | LAY-4, TEST-9 | `kit_gallery.dart` | `kitGallerySizes` holds all six LAY-4 gallery sizes, `kitGalleryScaledSizes` both TEST-9 sizes |

KIT-3, KIT-13, KIT-27, LAY-13 and LOOK-23 are checked only to the extent that each part needs a gallery, tests and its matrix entries. What those galleries show stays with the reviewer (§17) and the part's own G9 tests.

The allowlist only shrinks. The test enforces three rules:

- A violation not on the allowlist fails.
- An allowlist entry that now passes (stale) fails. The message prints the smaller JSON; `KIT_MANIFEST_WRITE=1` writes it and never adds.
- An entry outside `_creationAllowlist`, the frozen set written into the test, fails. This includes a name for a part that does not exist yet.

The consumers (G5, G6, G8x, G14x) can `import 'kit_manifest_test.dart' show readKitManifest, KitManifestPart;` and iterate `readKitManifest().parts`. A consumer counts as covering every part when its comment-stripped code calls `readKitManifest(`. `KitManifestPart.exported` tells them which parts are unexported.

### Baseline (allowlist) at creation

Manifest: 41 drawn parts, 1 scope (`KitEffectsScope`), 24 scenes (1 exported, `KitPortalScene`; 23 unexported) and 2 openers (`showKitSheet`, `showKitConfirm`). The allowlist, and the frozen `_creationAllowlist`, hold **338** entries:

| Check | Entries |
|---|---|
| exported | 25 (23 scenes, TerminalKeyBar, LiquidGlassFilter) |
| name | 49 |
| states | 41 (no part declares states yet) |
| stateScenes | 0 |
| gallery | 63 (only KitSheet and KitConfirmSheet have galleries) |
| test | 39 |
| docRow | 38 |
| motion | 38 |
| keyboard | 3 (KitRow, KitSwitchRow, KitExpandRow) |
| overflow | 41 |
| openerReturn | 0 |
| openerKey | 0 |
| harness | 1 (`kitGallerySizes 915x412`) |

The three predating parts that §18.2 names (KitIconButton, KitSecretField, KitInset) are on the allowlist, along with every other part that lacks something today.

## 2. Builds

- Branch `gate/G4`, base `9220f070`. The code head is the record commit: the gate's code and this record land together.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

Every probe was throwaway and was removed afterwards; the tree was clean apart from the gate files. Runs 2 to 9 all used today's allowlist.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_manifest_test.dart` on today's code | passes | 2 passed (`run-pass.txt`) | PASS |
| 2 | Probe 1: `lib/ui/kit/kit_zz_probe.dart` (KitZzProbe with no states, gallery, test or row; `void showKitZzProbe(context)`), exported from `kit.dart` | fails, naming each missing item | failed with 10 violations (`run-fail-probe1.txt`) | PASS |
| 3 | Probe 2: the same file with an unknown state (`sparkly`), a declared `loading` that has no golden, a part in the wrong file, a non-`Kit` name, a well-formed opener and an opener whose only key is `required` | fails on each; the well-formed opener passes | failed with 26 violations; `showKitZzProbe` (optional `Key? probeKey`, `Future<void>`) not listed (`run-fail-probe2.txt`) | PASS |
| 4 | Probe 3: unexported `kit_zz_hidden.dart` (a widget with `States: none — …`, plus openers with no return type, a record return, a function-typed return and a return type on the line above); `kit_zz_quoted.dart` exported by `export "…";`; a commented-out `// export 'kit_zz_hidden.dart';` | fails `exported` for the hidden file and its 4 openers, not for the double-quoted export; fails `openerReturn` for the bare and function-typed openers; the record and line-above openers are read and pass | exactly that, 23 violations (`run-fail-probe3.txt`) | PASS |
| 5 | Probe 4 (KIT-12 and substring checks): KitZzSend (`States: none — …` with `Future<List<String>>`, `VoidCallback? onPressed`, `bool working`); KitZzBare (`States: none.`); KitZzLoaded (`States: loading.`, whose gallery names every needle only in comments); scene KitZzScene, whose gallery has only `Brightness.dark`/`darkTheme`/`lightTheme`; a comment `// kit_manifest_test.dart: readKitManifest() … KitZzSend …` appended to `kit_motion_test.dart` | fails on each | KitZzSend: "declares none but needs loading, empty, error, disabled, working"; KitZzBare: "none without a reason"; KitZzLoaded: gallery lacks all four and stateScenes has no 412×915 dark/light golden; KitZzScene: no dark or light golden; motion fails for all three (`run-fail-probe4.txt`) | PASS |
| 6 | Grow: `KitFuture` (a part that does not exist) added to `test` and `KitRow` to `stateScenes` in the allowlist | fails | failed with "grew past the allowlist the gate was made with: stateScenes · KitRow, test · KitFuture" (`run-fail-grow.txt`) | PASS |
| 7 | Stale: `/// States: loading, disabled.` added to KitSheet | `states · KitSheet` is stale and fails; the stateScenes matcher accepts `kit_sheet_loading_$mode` / `kit_sheet_disabled_$mode` at `phone` | failed with "1 allowlist entry now passes … states · KitSheet" and the smaller JSON; no stateScenes violation (`run-fail-stale.txt`) | PASS |
| 8 | `KIT_MANIFEST_WRITE=1` with the same stale entry | writes the smaller list and passes; never adds | passed; the diff removes only `KitSheet` from `states` (`run-write.txt`) | PASS |
| 9 | KitSheet declares `loading, disabled, empty` | fails for the missing `empty` golden | "stateScenes · KitSheet: no 412x915 golden kit_sheet_empty_…dark, kit_sheet_empty_…light" (`run-fail-statescene.txt`) | PASS |
| 10 | Unreadable opener `showKitZzOdd<T extends Map<(int, int), int>>(…)` | the first test fails loudly instead of skipping it | "lib/ui/kit/kit_zz_odd.dart:4 showKitZzOdd: a top-level showKit… the scan could not read" (`run-fail-unreadable.txt`) | PASS |
| 11 | `flutter analyze test/kit/kit_manifest_test.dart` | no issues, no `// ignore:` | No issues found (`run-analyze.txt`) | PASS |

## 5. Evidence

- Outputs of runs 1–11: `run-pass.txt`, `run-fail-probe1.txt`, `run-fail-probe2.txt`, `run-fail-probe3.txt`, `run-fail-probe4.txt`, `run-fail-grow.txt`, `run-fail-stale.txt`, `run-write.txt`, `run-fail-statescene.txt`, `run-fail-unreadable.txt`, `run-analyze.txt`. The first version's `run-shrink.txt`, where a stale entry passed, is removed because that behaviour is gone.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) | Output |
  |---|---|---|
  | NAME-1, KIT-10–KIT-14, TEST-9, TEST-14, TEST-15, LAY-4 | `test/kit/kit_manifest_test.dart` "G4: every kit part and opener meets the manifest (allowlist only shrinks)" | `run-pass.txt`, `run-fail-probe1.txt` – `run-fail-probe4.txt`, `run-fail-grow.txt`, `run-fail-stale.txt`, `run-fail-statescene.txt` |
  | (loud failure on an empty or unreadable scan) | `test/kit/kit_manifest_test.dart` "G4: the manifest reads the kit library and every kit file" | `run-pass.txt`, `run-fail-unreadable.txt` |

- Changed test expectations (TEST-19): none.
- Goldens changed: none.
- Accessibility: n/a, a source scan.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed. For golden names, see contract problem 3 (KitConfirmSheet).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/kit/kit_manifest_test.dart
# shrink the allowlist after a part is fixed (never adds entries):
KIT_MANIFEST_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/kit/kit_manifest_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/kit/kit_manifest_test.dart
```

## 7. NOT proven

- Not run on a device or emulator; a source scan needs neither.
- **Across commits, only the frozen ceiling protects the allowlist.** `kit_manifest_allowlist.json` is missing from PROC-13's baseline list and from G31's inputs (contract problem 5), and adding it needs a STANDARDS.md and G31 change outside this gate's write set. Until then, a commit can raise the ceiling by editing `_creationAllowlist` in the test. That edit is visible as a gate change, but no tool rejects it.
- The scan is textual. It does not see a class whose superclass lives outside `lib/` and outside the Flutter widget catalogue. A kit widget declared outside `lib/ui/kit/` and not exported by `kit.dart` is invisible; `exported` covers only `lib/ui/kit/**`. A consumer that calls `readKitManifest(` counts as covering every part, whatever its loop asserts.
- The KIT-12 structural check is heuristic (contract problem 2). It reads only `final` fields of the widget class. It does not see a single server object (for example `final Session session;`) or a `List<String>` of server values, both of which count as UI types. It also exempts `onDismiss`/`onClose`.
- The gallery check reads golden names and arguments from source. It does not prove that every shot renders or that the PNGs exist (G23), nor the TEST-9 device pixel ratio of 3.0 (the harness pumps at 1.0; G23 owns that). It does not check the default state at every gallery size in both modes beyond the use of `kitGallerySizes`. Mode detection accepts `$mode` whenever the file holds both `'dark'` and `'light'` literals; it does not trace which variable carries them. Golden names built without a string literal (from a variable) are not read.
- Non-widget exports (KitTokens, KitMotion, KitLayout, KitTechnicalValue, enums) do not need doc rows; this gate reads KIT-14 as covering widget parts, scenes and openers.
- `_creationAllowlist` was written from this run's violations, including the 25 unexported entries and the two new widgets' rows. Nothing proves those predate the gate other than this record and the branch diff.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G4` |
| Enabled | Yes | runs with `flutter test` |
| Verified | tests only | this record |
| Committed | Yes | `gate/G4` |
| Deployed | No | |
| Released | No | |
