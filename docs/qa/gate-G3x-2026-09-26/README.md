# gate-G3x: design_standard_test forbids every G1/G2/G7/G17/G21 pattern in migrated files (2026-09-26)

## 1. Scope

- Gate: `G3x` (STANDARDS.md §18.1 row G3x, §18.2 "G3x (absolute)"), when W1. Enforces **TEST-10**, and through the shared patterns the rules of G1 (KIT-2, KIT-15, KIT-33, KIT-34, KIT-38), G2 (KIT-23, KIT-38, KIT-43, MOT-1, MOT-5, MOT-11, SEC-1, STATE-1), G7 (LAY-8, COPY-30), G17 (LOOK-1–LOOK-4, LOOK-6, LOOK-24) and G21 (KIT-9, KIT-42, LOOK-9, LOOK-12–LOOK-15, LOOK-19–LOOK-22, LOOK-27, LOOK-32, LOOK-33, LOOK-35, LOOK-37, LAY-6, LAY-7, MOT-2, MOT-3, MOT-5, MOT-8, MOT-12, A11Y-8) inside the migrated files.
- Finish line: every file in `_migrated` and every class in `_migratedClasses` is scanned for every G1, G2, G7, G17 and G21 pattern that applies to its path; a screen migrated on or after 2026-09-26 must be at zero and must have a `<golden>_ar_dark.png`. Non-goal: the whole-`lib/` ratchets of G1/G2/G7/G17/G21 themselves (their gate owners, reading the same pattern file) and G31's check of the baseline across commits.
- Files changed:
  - `test/design_standard_test.dart`: `_forbidden` is now pattern id → `KitPattern` (the four design-standard patterns plus every `kitGatePatterns` entry); four G3x tests and a fixture group replace the two old scans.
  - `test/support/kit_patterns.dart` (new): the shared pattern lists `kitG1Patterns`, `kitG2Patterns`, `kitG7Patterns`, `kitG17Patterns`, `kitG21Patterns`, `kitGatePatterns`, with scopes, exemptions and an `absoluteIn` marker per pattern, and the helpers `kitStripLineComments`, `kitCodeOf`, `kitCallArguments`, `kitSplitArguments`, `kitCountPatterns`.
  - `test/design_standard_baseline.json` (new): counts for the 59 entries migrated before 2026-09-26.
- Pages (map ids): n/a. This gate adds tests only.
- Specs followed: STANDARDS.md §18.2 G1, G2, G7, G17, G21 and G3x; TEST-10; PROC-13 (ratchets only shrink); KIT-44.
- Contract problems (PROC-20):
  1. **G3x says "absolute", but today's migrated files break G1/G2/G7/G17/G21 1,093 times in 51 of the 59 entries.** An absolute gate would fail today, and the task says to use a ratchet when today's code violates the rule. So: the entries migrated before 2026-09-26 are a per-file, per-pattern ratchet (`test/design_standard_baseline.json`, only shrinks, never gains an entry). Entries added later are absolute (any count fails), which is the part of "absolute" that holds now. Proposed text for §18.2: "G3x (absolute for files migrated after 2026-09-26; ratchet for the 59 earlier entries in `test/design_standard_baseline.json`)". Blocks: nothing.
  2. **Some pattern specs are textual, so they are approximate.** "Icon `size:` other than 20/22/24" counts only numeric literals inside `Icon(`. "`withOpacity\(|Opacity\(` around text" counts every `withOpacity(`/`Opacity(`, because a regex cannot see whether the child is text. The "attention roles" count skips `Type.attention` (for example `AppStatusTone.attention`, an enum tone and not a role) but still counts a data field such as `rule.attention`. "`(?i)\b(metal|chrome)\w*`" hits the layout variable `chrome` in `workspace_screen.dart` (3, baselined). "Transform.scale|ScaleTransition nowhere in kit transitions" is scoped to `lib/ui/kit/motion/**` and `kit_motion.dart`. The G21 owner may tighten any of these in `kit_patterns.dart`. Blocks: nothing.
  3. The TEST-10 rule "`_ar_dark` for the loaded state" does not name which golden in an entry is the loaded one. The gate requires at least one of the entry's goldens to have `<name>_ar_dark.png`. Blocks: nothing.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a (no pages).
- States per page (STATE-20): n/a.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `gate/G3x`, base `9220f070` (feat/phone-setup-v2), code head `4afe37b4`.
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `DESIGN_STANDARD_WRITE=1 … test test/design_standard_test.dart` with no baseline file | writes the baseline for every migrated entry | wrote 59 entries; 15 passed | PASS |
| 2 | `… test -j 1 test/design_standard_test.dart` on today's code (`pass-on-today.txt`) | passes, prints no shrink | 15 passed, no "counts fell" block | PASS |
| 3 | Throwaway violation: a temporary `lib/ui/widgets/g3x_throwaway_violation.dart` (`EdgeInsets.only(left: 12)`, `TextAlign.left`, `TextStyle(fontSize: 13, …colorScheme…)`) added to `_migrated`, and the `team_card.dart` `G17 .textTheme.` baseline lowered from 4 to 3 to fake a rise (`fail-on-violation.txt`) | fails: new file absolute, rise caught, missing `_ar_dark` | 2 failed: 6 "must be zero" lines, "rose from 3 to 4", "none of work_loaded_ar_dark.png" | PASS |
| 4 | Same, then the throwaway file removed and both test edits reverted; the `team_card.dart` baseline raised to 5 | passes and prints the smaller baseline | passed; printed `--- G3x: counts fell; commit this …` with `"G17 .textTheme.": 4` | PASS |
| 5 | Baseline restored, `dart format --set-exit-if-changed --language-version=3.10` on both Dart files | no changes | 0 changed | PASS |
| 6 | `machine_lock.sh analyze -- $F analyze test/design_standard_test.dart test/support/kit_patterns.dart` | no issues | No issues found | PASS |

## 5. Evidence

- `pass-on-today.txt`: step 2.
- `fail-on-violation.txt`: step 3.
- Rule evidence (PROC-31):

  | Rule | Test (`test/design_standard_test.dart` + `--plain-name`) | Output |
  |---|---|---|
  | TEST-10 (zero forbidden patterns) | "G3x: migrated screens hold every forbidden pattern at zero (or below their baseline)" | `fail-on-violation.txt` |
  | TEST-10 (mixed files) | "G3x: migrated classes in mixed files use the kit" | `pass-on-today.txt` |
  | TEST-10 (`_ar_dark`) | "G3x: a screen migrated on or after 2026-09-26 has an _ar_dark golden" | `fail-on-violation.txt` |
  | PROC-13 (only shrinks) | "G3x: the baseline only shrinks and names only migrated entries" | step 4 |
  | G1/G2/G7/G17/G21 patterns | "G3x counters on fixture strings (proves the patterns)" (6 tests) | `pass-on-today.txt` |

- How the ratchet works: an entry in `_migrated` or `_migratedClasses` that is missing from `test/design_standard_baseline.json` counts as migrated on or after 2026-09-26, so every pattern must be zero and one `_ar_dark` golden must exist. For an entry in the baseline, a count may fall and never rise. When counts fall, the test prints the smaller baseline. `DESIGN_STANDARD_WRITE=1` writes it: it lowers counts and drops entries that are no longer migrated, and never adds an entry. Scopes come from each `KitPattern`. For example, `.colorScheme.` counts only outside the kit, and a numeric `fontSize:` counts inside the kit except in `kit_tokens.dart` and `kit_text.dart`. The theme files are exempt from G17 and G21.
- Baseline (59 entries, 4 of them classes; 8 already at zero; 1,093 counts):

  | Pattern id | Entries | Count |
  |---|---|---|
  | `G21 SizedBox(width\|height: <n>)` | 29 | 256 |
  | `G21 EdgeInsets(<n>)` | 37 | 217 |
  | `G17 .textTheme.` | 39 | 207 |
  | `G17 .colorScheme.` | 24 | 78 |
  | `G21 Icon size not 20/22/24` | 17 | 47 |
  | `G21 TextStyle(` | 18 | 34 |
  | `G1 SnackBar(` | 15 | 25 |
  | `G1 showSnackBar(` | 15 | 25 |
  | `G2 Curves.` | 8 | 22 |
  | `G1 showConfirmSheet(` | 12 | 21 |
  | `G2 showConfirmSheet(` | 12 | 21 |
  | `G21 BorderRadius.circular(<n>` | 7 | 19 |
  | `G1 showModalBottomSheet(` | 13 | 17 |
  | `G21 fontSize:` | 8 | 12 |
  | `G2 Clipboard.setData(` | 8 | 11 |
  | `G21 withOpacity(\|Opacity(` | 9 | 11 |
  | `G21 Radius.circular(<n>` | 3 | 10 |
  | `G21 disableAnimationsOf` | 6 | 9 |
  | `G2 duration: Duration(` | 6 | 8 |
  | `G7 bidi literal` | 3 | 8 |
  | `G1 AlertDialog(` | 5 | 6 |
  | `G1 showDialog(` | 5 | 6 |
  | `G21 Border.all(` | 4 | 6 |
  | `G17 Colors.*` | 1 | 4 |
  | `G21 .toUpperCase()` | 2 | 3 |
  | `G21 metal\|chrome` | 1 | 3 |
  | `G1 DraggableScrollableSheet(` | 1 | 1 |
  | `G2 AnimatedSize(` | 1 | 1 |
  | `G2 launchUrl(` | 1 | 1 |
  | `G21 Gradient(` | 1 | 1 |
  | `G21 KitGlass(\|GlassSurface(` | 1 | 1 |
  | `G7 EdgeInsets.fromLTRB asymmetric` | 1 | 1 |
  | `G7 Positioned(left\|right:)` | 1 | 1 |

- Changed test expectations (TEST-19): the two old scans ("migrated screens use the kit, not raw progress, cards or buttons", "migrated classes in mixed files use the kit") are now the G3x ratchet tests. The four design-standard patterns (`LinearProgressIndicator`, `CircularProgressIndicator`, `Card(`, `FilledButton`) are zero in every entry, so the baseline has no count for them and they stay absolute. `_allowed` keys are now pattern ids (for example `DS FilledButton`). Rule TEST-10.
- Goldens changed: none.
- Accessibility: n/a: tests only.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/design_standard_test.dart
# after a migration lowers counts:
DESIGN_STANDARD_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/design_standard_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/design_standard_test.dart test/support/kit_patterns.dart
```

## 7. NOT proven

- Not run on a device or emulator (none needed: source scan only).
- G31 does not yet check across commits that `test/design_standard_baseline.json` only shrinks and never gains an entry. Until it does, a `DESIGN_STANDARD_WRITE=1` run after deleting the file would baseline new entries.
- `test/kit_ratchet_test.dart` does not import `test/support/kit_patterns.dart` yet. G1 there still has its own copy of the list. The patterns are identical, and `kitG1Names` equals `_g1PatternNames`.
- The full test suite was not run. Only `test/design_standard_test.dart` changed behaviour.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G3x` |
| Enabled | Yes | runs in the normal `flutter test` suite |
| Verified | tests only | this record |
| Committed | Yes | code head `4afe37b4` |
| Deployed | No | |
| Released | No | |
