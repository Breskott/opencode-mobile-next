# gate-kit-ratchet: G2, G7, G15x, G17, G21 and G48 in the kit ratchet (2026-09-26)

## 1. Scope

- Unit: gates G2, G7, G15x, G17, G21 and G48 from STANDARDS.md §18 (pre-wave §0.5 step 3, when "W1"). Finish line: each gate is a named test in `test/kit_ratchet_test.dart` that passes on today's code and fails on a new violation. Non-goal: changing any `lib/` code to lower a count.
- Files changed: `test/kit_ratchet_test.dart`, `test/kit_ratchet_baseline.json`, and this folder.
- Pages (map ids): n/a, this is a gate, not a page.
- Specs followed: STANDARDS.md §18.1 rows and §18.2 paragraphs for G2, G7, G15x, G17, G21 and G48; KIT-4, KIT-5, KIT-43, KIT-44, PROC-13.
- Contract problems (PROC-20): none that block. Interpretations are listed under "How each pattern was read" below.
- New kit parts (KIT-3): none.
- Map items (EVID-11), states (STATE-20, STATE-21): n/a, no pages.

### What the gate checks

All six gates are one data-driven table, `_rules`, in `test/kit_ratchet_test.dart`. Each row has a gate, a pattern name (its baseline key), the rule ids, the roots it scans, the scope (outside the kit, inside it, or both), a per-file allowlist with reasons, and whether it is absolute. Full-line comments are stripped before counting, the same as G1, G15 and G16.

- **Ratchet row:** per-file counts in `test/kit_ratchet_baseline.json` under the gate. The test fails when a count rises or a file or pattern the baseline lacks appears. When a count drops, the test passes and prints the entries to lower plus the command to rewrite them.
- **Absolute row:** never written to the baseline, even by `KIT_RATCHET_WRITE=1`, so any hit outside its allowlist fails.
- **Rewriting one gate:** `KIT_RATCHET_WRITE=1 KIT_RATCHET_GATES=G17,G21` rewrites only those gates and keeps every other gate's baseline as committed. This is the integrator's step after the visual-language branch lands its tokens: the patterns stay the same and only the G17 and G21 baselines are regenerated. A regeneration that raises or adds entries needs `ratchet-tighten: <gate> <pattern>` lines in the commit body (KIT-44). This commit carries one line for each of its 47 ratchet patterns.
- G17 and G21 skip `app_theme.dart`, `theme_packs*.dart` and `theme_roles.dart` wherever they sit under `lib/ui/`. They match by file name, so a `theme_roles.dart` the VL branch adds is excluded too.

| Gate | Rules | Rows (A = absolute, R = ratchet) |
|---|---|---|
| G2 | KIT-23, KIT-38, KIT-43, MOT-1, MOT-5, MOT-11, SEC-1, STATE-1 | In `lib/` outside the kit, R: `Clipboard.setData(`, `HapticFeedback.`, `launchUrl(`/`launchUrlString(` (allowlist: `external_link.dart`), `AnimatedSize(`, `ProductErrorState(`, `ProductEmptyState(`, `ProductInlineEmpty(`, `showConfirmSheet(`, `KitSecretField(`, plus one row per `_retiredApis` entry (KIT-43; empty today). In `lib/ui/` outside the kit, R: `duration:`/`reverseDuration:` given a `Duration(` literal, and `Curves.`. Inside the kit, A: `Clipboard.setData(` only in `kit_copy.dart`, `duration: Duration(` only in `kit_motion.dart`, `AnimatedSize(` only in `kit_buttons.dart` (the spinner slot). Inside the kit, R (the rulebook says absolute, but today's code breaks it): `HapticFeedback.` only in `kit_haptics.dart`, `Curves.` only in `kit_motion.dart`. |
| G7 | LAY-8, COPY-30 | In `lib/`, kit included, R: `EdgeInsets.only` with a `left:`/`right:` argument, `EdgeInsets.fromLTRB` where a ≠ c, `Alignment.centerLeft`, `Alignment.centerRight`, `TextAlign.left`, `TextAlign.right`, `Positioned(`/`Positioned.fill(` with a `left:`/`right:` argument. The forced-LTR kit files (`kit_technical_value.dart`, `kit_code_block.dart`, `kit_log_panel.dart`, `kit_diff_view.dart`) are allowlisted for the two `Left` rows only. Outside the kit, R: bidi literals U+2066–U+2069 and U+200E, as raw characters or `\u` escapes. |
| G15x | LAY-2 | Inside the kit except `kit_layout.dart`, R until §0.5 step 2: the G15 width comparisons (minus `> 0` guards), numeric `maxWidth:`, and numeric `width:` of at least 100. |
| G17 | LOOK-1–LOOK-4, LOOK-6, LOOK-24 | In `lib/ui/` minus the theme files, kit included, R: `Color(0x`, `Color.fromARGB(`/`fromRGBO(`, `Colors.*` except `transparent`, `hairline….withValues(`. Outside the kit, R: `.colorScheme`, `.textTheme`, `.accent`, and the attention roles (`.attention`, `.attentionFill`, `.onAttentionFill`, `.attentionSurface`, `.attentionLine`). |
| G21 | KIT-9, KIT-42, LOOK-9, LOOK-12–LOOK-15, LOOK-19–LOOK-22, LOOK-27, LOOK-32, LOOK-33, LOOK-35, LOOK-37, LAY-6, LAY-7, MOT-2, MOT-3, MOT-5, MOT-8, MOT-12, A11Y-8 | In `lib/ui/` minus the theme files, outside the kit, R: `fontSize:`, `TextStyle(`, `BoxShadow(`, `boxShadow:`, `shadows: [`, `ImageFilter.blur`, `BackdropFilter(`, `Border.all(`, `thickness:`, `.toUpperCase()`, gradients, `Image.asset/network/memory/file(`, icon `size:`/`iconSize:` other than 20/22/24, `PageRouteBuilder(`, `transitionsBuilder:`, `KitEffects.of(`, the text-scale clamps, `.withOpacity(`, `Opacity(` wrapping text, `text1-3….withValues(`. In and out of the kit, except `kit_tokens.dart` and `kit_text.dart`, R: `BorderRadius.circular(<n>`, `Radius.circular(<n>`, numeric `EdgeInsets…(`, numeric `SizedBox` width or height, `BorderSide(width:` not read from `KitTokens`. Inside the kit, R: `fontSize: <n>`. A: `KitSurfaceLevel.glass/raised/tonal`. R (the rulebook says absolute, but today's code breaks it): `KitGlass(`/`GlassSurface(` outside the LOOK-27 allowlist, `disableAnimationsOf` outside `kit_motion.dart`, `Transform.scale`/`ScaleTransition` in the kit, `metal`/`chrome` identifiers or asset names in `lib/`, `shaders/` and `assets/`. |
| G48 | DATA-2 | In `lib/`, R: a file that calls `showKitSheet(`, has a multiline field (`KitFieldKind.multiline`, `maxLines: null`, `minLines:`) and has no `draft:`. It counts that file's multiline fields. |

### How each pattern was read

These are interpretations, not contract problems:

- Class and function patterns (`ProductEmptyState(`, `showConfirmSheet(`, `KitGlass(`, `showKitSheet(`) skip their own declaration, so a count reaches zero when the last caller goes, as KIT-43 needs.
- `.colorScheme`/`.textTheme` match with `\b`, not `\.`. This also catches `final cs = Theme.of(context).colorScheme;`, which LOOK-2 forbids.
- `Color.fromARGB(`/`fromRGBO(` are added under LOOK-1. They are the same literal colour written another way.
- "Numeric `EdgeInsets…(\d`" is read as any numeric literal among the arguments of `EdgeInsets`/`EdgeInsetsDirectional` `.all/.only/.symmetric/.fromLTRB/.fromSTEB`. `SizedBox` counts a numeric `width:` or `height:` in any argument position.
- "Icon `size:`" means a numeric `size:` on `Icon(`/`ImageIcon(`, plus a numeric `iconSize:`. Sizes given by variables are not counted.
- "`Opacity(` around text" means an `Opacity(` whose arguments contain `Text`, `RichText`, `SelectableText` or `KitText`. `.withOpacity(` is counted everywhere. `text1-3….withValues(` covers LOOK-14's "no `withValues(alpha:)` on a text colour".
- G15x layout width: `maxWidth:` numeric, and `width:` numeric of at least 100 dp. Smaller widths are gaps and strokes, which G21 already counts. `minWidth: 48` (a tap target) is not a layout width. A G15 comparison against `0` is a guard, not a breakpoint.
- "Transform.scale nowhere in kit transitions" is scanned over all of `lib/ui/kit/`. The one hit is `KitTabSwitcher`, which MOT-2 names.
- `AppStatusTone.attention` (103 uses in 50 files) is counted under "attention roles". It is the tone that paints the attention look outside the kit, which is what LOOK-4 and LOOK-24 forbid.
- LOOK-27 nav-layer kit file names are allowlisted in advance (`kit_composer.dart`, `kit_floating_tab_bar.dart`, `kit_nav_rail.dart`, `kit_top_controls.dart`, `kit_desktop_sidebar.dart`). A unit whose part uses another file name appends it to `_glassFiles`.

### Baseline counts (ratchet rows, today)

| Gate | Files | Pattern: hits in files |
|---|---|---|
| G2 | 97 | showConfirmSheet( 66/35 · Clipboard.setData( 47/37 · Curves. in kit 45/12 · duration: Duration( 32/20 · Curves. 25/13 · ProductErrorState( 18/17 · ProductEmptyState( 16/12 · ProductInlineEmpty( 8/5 · AnimatedSize( 4/3 · launchUrl( 4/4 · HapticFeedback. 1/1 · HapticFeedback. in kit 1/1 · KitSecretField( 1/1 |
| G7 | 24 | EdgeInsets.fromLTRB asymmetric 19/10 · EdgeInsets.only(left\|right:) 11/6 · bidi literal 8/3 · Positioned(left\|right:) 5/5 · TextAlign.right 5/5 · Alignment.centerLeft 2/2 · TextAlign.left 2/1 · Alignment.centerRight 1/1 |
| G15x | 4 | numeric maxWidth: 3/3 · width-literal 1/1 |
| G17 | 171 | .textTheme 805/142 · .colorScheme 532/118 · attention roles 98/50 · Colors.* 41/12 · Color(0x 2/1 |
| G21 | 199 | SizedBox numeric 1042/137 · EdgeInsets numeric 914/168 · icon size not 20/22/24 211/68 · TextStyle( 156/78 · BorderRadius.circular(<n> 104/47 · fontSize: 50/33 · Border.all( 40/27 · Radius.circular(<n> 38/18 · disableAnimationsOf 32/14 · BorderSide(width: not KitTokens 10/5 · .toUpperCase() 6/4 · metal\|chrome 5/2 · Opacity( around text 5/5 · gradient( 4/3 · Image.asset\|network\|memory\|file( 4/4 · text scale clamp 4/3 · KitGlass(/GlassSurface( 3/1 · Transform.scale\|ScaleTransition in kit 1/1 · boxShadow: 1/1 |
| G48 | 0 | none. Nothing calls `showKitSheet(` yet, so the gate is effectively absolute today. |

At zero today, so any new hit fails: `.accent`, `hairline.withValues(`, `Color.fromARGB(`, `BoxShadow(` outside the kit, `shadows: [`, `ImageFilter.blur`, `BackdropFilter(` outside the kit, `thickness:`, `PageRouteBuilder(`, `transitionsBuilder:`, `KitEffects.of(` outside the kit, `.withOpacity(`, `text role withValues(`, `fontSize: <n> in kit`, `numeric layout width:`. Absolute and clean: G2 `Clipboard.setData( in kit`, `duration: Duration( in kit`, `AnimatedSize( in kit`; G21 `KitSurfaceLevel.glass|raised|tonal`.

The G1, G15 and G16 sections of the baseline are byte-for-byte unchanged (checked with a JSON comparison against the base).

## 2. Builds

- Branch `gate/kit-ratchet`, base `9220f070`, code head `cdafb5a6`.
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `KIT_RATCHET_WRITE=1 KIT_RATCHET_GATES=G2,G7,G15x,G17,G21,G48` on the base code | writes only the six new sections | wrote them; G1/G15/G16 unchanged | PASS |
| 2 | `test/kit_ratchet_test.dart` on today's code | all pass | 25 passed (`pass-on-today.txt`) | PASS |
| 3 | Throwaway `lib/ui/screens/zz_gate_violation.dart` + `lib/ui/kit/zz_gate_violation.dart` (one violation per gate, including the absolute `KitSurfaceLevel.glass`) | G2, G7, G15x, G17, G21 and G48 each fail and name the file, pattern, fix and rule id | 6 failed as expected (`fail-on-violation.txt`); files deleted | PASS |
| 4 | Throwaway `TextAlign.right` appended to `lib/ui/widgets/markdown.dart` (baselined at 1) and one `Alignment.centerRight` removed from `review_workspace.dart` | G7 fails with "rose from 1 to 2" | failed (`fail-on-rise.txt`); files restored with `git checkout` | PASS |
| 5 | Only the `Alignment.centerRight` removal | G7 passes and prints the dropped entry and the rewrite command | printed `review_workspace.dart "Alignment.centerRight" 1 -> 0` (`drop-prints-baseline.txt`); restored | PASS |
| 6 | `flutter analyze test/kit_ratchet_test.dart` | no issues | No issues found | PASS |

## 5. Evidence

- `pass-on-today.txt`: step 2.
- `fail-on-violation.txt`: step 3.
- `fail-on-rise.txt`: step 4.
- `drop-prints-baseline.txt`: step 5.
- Rule evidence (PROC-31): the group "G2/G7/G15x/G17/G21/G48 rows on fixture strings" in `test/kit_ratchet_test.dart` tests each counter on fixture strings. It covers declarations skipped, directional forms not counted, `Colors.transparent` exempt, `BorderRadius` not double-counted as `Radius`, icon sizes 20/22/24 allowed, `KitTokens` border widths allowed, `monochrome` not counted as chrome, G48 with and without `draft:`, and the theme-file, allowlist and scope resolution.
- Changed test expectations (TEST-19): none. The G1, G15 and G16 tests are unchanged. The write-mode message now goes through `stdout.writeln`, which removes one `// ignore: avoid_print`. The G26 count for this file drops by one.
- Goldens, before and after, accessibility: n/a, no UI change.
- Privacy and security: n/a. SEC-1's `launchUrl` is now counted, and the 4 existing direct launches (`bug_report.dart`, `host_management_screen.dart`, `integrations_screen.dart`, `termux_setup_screen.dart`) are baselined, not allowlisted.
- Migration: n/a.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/kit_ratchet_test.dart
# rewrite only some gates' baselines (integrator, after a count drops or after VL tokens land):
KIT_RATCHET_WRITE=1 KIT_RATCHET_GATES=G17,G21 tool/qa/machine_lock.sh test -- $F test -j 1 test/kit_ratchet_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/kit_ratchet_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (not needed for a source scan).
- The full suite was not run. Only `test/kit_ratchet_test.dart` was run.
- The VL-branch baseline regeneration for G17/G21 has not happened. `ThemeRoles`, `KitText`, `KitCopy`, `KitBidi` and the `KitLayout` named widths do not exist on this base, so rows that key on them (`.accent`, `hairline.withValues(`, `text role withValues(`, the absolute `Clipboard.setData( in kit`) read zero today and are proven only on fixtures.
- G3x (copying these patterns into `_forbidden`) and G31 (checking `ratchet-tighten` lines against the merge base) are other gates and are not built here.
- The switch to absolute at slice-P9.10 (G17/G21 inside the kit) and after §0.5 step 2 (G15x) is not automated. It means setting `absolute: true` on those rows, with the note on each row saying why it is a ratchet today.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/kit-ratchet` |
| Enabled | Yes | runs in `test/kit_ratchet_test.dart` |
| Verified | tests only | this record |
| Committed | Yes | code head `cdafb5a6` |
| Deployed | No | |
| Released | No | |
