# gate-kit-ratchet: G2, G7, G15x, G17, G21 and G48 in the kit ratchet (2026-09-26)

## 1. Scope

- Unit: gates G2, G7, G15x, G17, G21 and G48 from STANDARDS.md §18 (pre-wave §0.5 step 3, when "W1"). Finish line: each gate is a named test in `test/kit_ratchet_test.dart` that passes on today's code and fails on a new violation. Non-goal: changing any `lib/` code to lower a count.
- Files changed: `test/kit_ratchet_test.dart`, `test/kit_ratchet_baseline.json`, and this folder.
- Pages (map ids): n/a, this is a gate, not a page.
- Specs followed: STANDARDS.md §18.1 rows and §18.2 paragraphs for G2, G7, G15x, G17, G21 and G48; KIT-4, KIT-5 (enforced by the test "allowlists never grow (KIT-5)", see below), KIT-43, KIT-44, PROC-13, SEC-1.
- Contract problems (PROC-20): two, neither blocks. See "Contract problems" below.
- New kit parts (KIT-3): none.
- Map items (EVID-11), states (STATE-20, STATE-21): n/a, no pages.

### What the gate checks

All six gates are one data-driven table, `_rules`, in `test/kit_ratchet_test.dart`. Each row has a gate, a pattern name (its baseline key), the rule ids, the roots it scans, the scope (outside the kit, inside it, or both), a per-file allowlist with reasons, and whether it is absolute. Full-line comments are stripped before counting, the same as G1, G15 and G16.

- **Ratchet row:** per-file counts in `test/kit_ratchet_baseline.json` under the gate. The test fails when a count rises or a file or pattern the baseline lacks appears. When a count drops, the test passes and prints only the dropped entries plus the command to rewrite them. A passing run with nothing dropped prints nothing from the gate (the old whole-baseline dump on every G1 pass is gone).
- **Absolute row:** never written to the baseline, even by `KIT_RATCHET_WRITE=1`, so any hit outside its allowlist fails.
- **Frozen allowlists (KIT-5):** every allowlist key in the code (each row's `allow` map, `_glassFiles`, `_forcedLtrFiles`, `_tokenFiles`, the `launchUrl(` allowlist, and `_allowed` of G1/G15/G16) is committed under `"allow"` in `test/kit_ratchet_baseline.json` as gate -> pattern -> [keys], 36 keys today. The test "allowlists never grow (KIT-5)" fails when the code has a key the committed set lacks. Write mode copies that section as committed and never regenerates it, so the only way to add a key is to edit the JSON by hand, with `ratchet-tighten: <gate> <pattern>` in the commit body (KIT-44), which G31 can later check against the merge base. A key dropped from the code passes and prints a reminder to drop it from the JSON.
- **Allowlist keys are exact:** a key is an exact repo-relative path, or a folder ending in `/`. There are no bare file names, so `lib/ui/kit/kit_copy.dart` does not exempt `lib/ui/kit/links/kit_copy.dart`. The test "allowlist keys are exact paths or folders under lib/" checks the form.
- **Rewriting one gate:** `KIT_RATCHET_WRITE=1 KIT_RATCHET_GATES=G17,G21` rewrites only those gates and keeps every other gate's baseline, and the `allow` section, as committed. This is the integrator's step after the visual-language branch lands its tokens. A regeneration that raises or adds entries needs `ratchet-tighten: <gate> <pattern>` lines in the commit body (KIT-44). Code commit `cdafb5a6` carries one line for each of its 47 ratchet patterns. The review-fix commit `5dea435f` carries one for each of the 15 patterns it raised or added.
- **Roots of G17 and G21:** `lib/ui/` plus every `.dart` file under `lib/` outside `lib/ui/` that imports `package:flutter/material.dart`, `widgets.dart` or `cupertino.dart` (`_uiElsewhere`). Today that adds `lib/voice/voice_ui.dart`, `lib/voice/notices.dart`, `lib/diagnostics/app_diagnostics.dart` (the error widget), `lib/main.dart`, `lib/update/*` and `lib/diagnostics/perf_trace.dart`, 15 files in all (the rest import Flutter but have no hits). This is wider than §18.2, see contract problem 2.
- G17 and G21 skip `app_theme.dart`, `theme_packs*.dart` and `theme_roles.dart` wherever they sit. They match by file name, so a `theme_roles.dart` the VL branch adds is excluded too.

| Gate | Rules | Rows (A = absolute, R = ratchet) |
|---|---|---|
| G2 | KIT-23, KIT-38, KIT-43, MOT-1, MOT-5, MOT-11, SEC-1, STATE-1 | In `lib/` outside the kit, R: `Clipboard.setData(`, `HapticFeedback.`, `launchUrl(`/`launchUrlString(` (allowlist: `lib/ui/widgets/external_link.dart`), `AnimatedSize(`, `ProductErrorState(`, `ProductEmptyState(`, `ProductInlineEmpty(`, `showConfirmSheet(`, `KitSecretField(`, plus one row per `_retiredApis` entry (KIT-43; empty today). In `lib/ui/` outside the kit, R: `duration:`/`reverseDuration:` given a `Duration(` literal, and `Curves.`. Inside the kit, A: `launchUrl(`/`launchUrlString(` with **no allowlist** (SEC-1), `Clipboard.setData(` only in `lib/ui/kit/kit_copy.dart`, `duration: Duration(` only in `lib/ui/kit/kit_motion.dart`, `AnimatedSize(` only in `lib/ui/kit/kit_buttons.dart` (the spinner slot). Inside the kit, R (the rulebook says absolute, but today's code breaks it): `HapticFeedback.` only in `lib/ui/kit/motion/kit_haptics.dart`, `Curves.` only in `kit_motion.dart`. |
| G7 | LAY-8, COPY-30 | Seven layout patterns, each as two rows. In `lib/` outside the kit, R. Inside the kit, A ("zero in the kit except the allowlist", §18.2): `EdgeInsets.only` with a `left:`/`right:` argument, `EdgeInsets.fromLTRB` where a ≠ c, `Alignment.centerLeft`, `Alignment.centerRight`, `TextAlign.left`, `TextAlign.right`, `Positioned(`/`Positioned.fill(` with a `left:`/`right:` argument. `only`/`Positioned` calls whose `left:` and `right:` are textually equal are direction-neutral and not counted, the same as a symmetric `fromLTRB`. The forced-LTR kit files (`lib/ui/kit/kit_technical_value.dart`, `kit_code_block.dart`, `kit_log_panel.dart`, `kit_diff_view.dart`) are allowlisted for the two `Left` kit rows only. Outside the kit, R: bidi literals U+2066–U+2069 and U+200E, as raw characters or `\u` escapes. |
| G15x | LAY-2 | Inside the kit except `lib/ui/kit/kit_layout.dart`, R until §0.5 step 2: the G15 width comparisons (minus `> 0` guards), numeric `maxWidth:`, and numeric `width:` of at least 100. |
| G17 | LOOK-1–LOOK-4, LOOK-6, LOOK-24 | In the G17/G21 roots minus the theme files, kit included, R: `Color(0x`, `Color.fromARGB(`/`fromRGBO(`, `Colors.*` except `transparent`, `hairline….withValues(`. Outside the kit, R: `.colorScheme`, `.textTheme`, `.accent`, and the attention roles (`.attention`, `.attentionFill`, `.onAttentionFill`, `.attentionSurface`, `.attentionLine`). |
| G21 | KIT-9, KIT-42, LOOK-9, LOOK-12–LOOK-15, LOOK-19–LOOK-22, LOOK-27, LOOK-32, LOOK-33, LOOK-35, LOOK-37, LAY-6, LAY-7, MOT-2, MOT-3, MOT-5, MOT-8, MOT-12, A11Y-8 | In the G17/G21 roots minus the theme files, outside the kit, R: `fontSize:`, `TextStyle(`, `BoxShadow(`, `boxShadow:`, `shadows: [`, `ImageFilter.blur`, `BackdropFilter(`, `Border.all(`, `thickness:`, `.toUpperCase()`, gradients, `Image.asset/network/memory/file(`, icon `size:`/`iconSize:` other than 20/22/24, `PageRouteBuilder(`, `transitionsBuilder:`, `KitEffects.of(`, the text-scale clamps, `.withOpacity(`, `Opacity(` wrapping text, `text1-3….withValues(`, and `BorderSide(width:` not read from `KitTokens`. In and out of the kit, except `lib/ui/kit/kit_tokens.dart` and `lib/ui/kit/kit_text.dart`, R: `BorderRadius.circular(<n>`, `Radius.circular(<n>`, numeric `EdgeInsets…(`, numeric `SizedBox` width or height. Inside the kit, R: `fontSize: <n>`, and **strokes** (LOOK-21): `Border.all(`/`BorderSide(` whose `width:` is missing or not read from `KitTokens` (not `BorderStyle.none`), plus a numeric `thickness:` other than 0. A: `KitSurfaceLevel.glass/raised/tonal`. R (the rulebook says absolute, but today's code breaks it): `KitGlass(`/`GlassSurface(` outside the LOOK-27 allowlist, `disableAnimationsOf` outside `kit_motion.dart`, `Transform.scale`/`ScaleTransition` in the kit, `metal`/`chrome` identifiers or asset names in `lib/`, `shaders/` and `assets/`. |
| G48 | DATA-2 | In `lib/`, R: a file that calls `showKitSheet(`, `showModalBottomSheet(` or `showConfirmSheet(`, has a multiline field (`KitFieldKind.multiline`, `maxLines: null`, `minLines:`) and has no `draft:`. It counts that file's multiline fields. |

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
- G7: a `left:`/`right:` pair counts only when the two expressions differ after removing whitespace. A lone `left:` or `right:` counts. `Positioned(top: 0, left: 0, right: 0, …)` in `kit_refresh.dart`, `run_screen.dart` and `tool_card.dart` (`left: 8, right: 8`) no longer count, and their three baseline entries were dropped.
- LOOK-21 in the kit: the rule says every stroke is one physical pixel from `KitTokens`. A missing `width:` is Flutter's default of 1.0 logical pixel, so it is counted. So is a `Border.all(width: 1.5)` (`kit_status_mark.dart:51`). `Border(bottom: BorderSide(...))` is counted through its `BorderSide(`. `Border.symmetric(`/`Border.fromBorderSide(` are not counted by name, but the `BorderSide(` inside them is. `Divider(thickness: 0)` is the hairline and passes. A `thickness:` given by a variable is not counted. Today: `kit_glass.dart`, `kit_panel.dart`, `kit_request_card.dart`, `kit_status_line.dart`, `kit_status_mark.dart`, one each.
- G48: the sheet openers are `showKitSheet(`, `showModalBottomSheet(` and `showConfirmSheet(`, the entry points in use today. `showDialog(` is not an opener, because DATA-2 says "in a sheet". So the review's example `lib/ui/widgets/run_command_dialog.dart` (a `showDialog` with `minLines: 1, maxLines: 5`) is not counted. That part of review finding 7 is rejected.
- LOOK-27 allowlist (`_glassFiles`): `lib/ui/kit/glass/`, the composer at its planned path `lib/ui/kit/chat/kit_composer.dart` (`docs/ux-system/revamp/work-units.json`), and outside the kit `home_screen.dart` and `glass_surface.dart`, as LOOK-27 lists. The floating tab bar, rail, top controls and desktop sidebar parts have no planned file path yet. They are not pre-allowlisted, so the unit that lands one adds its exact path to `_glassFiles` and to the committed `allow` set, with a `ratchet-tighten: G21 KitGlass(/GlassSurface(` line. The other planned paths in allowlists (`kit_copy.dart`, `kit_text.dart` from STANDARDS §0.5 and the VL section, and `kit_code_block.dart`, `kit_log_panel.dart`, `kit_diff_view.dart` from work-units.json) are exact paths that the rulebook or the work units name.

### Contract problems (PROC-20)

1. `{rule: "STANDARDS.md §18.2 G21", says: "inside the kit … a BorderSide( with a width: not read from KitTokens fails (LOOK-21)", why wrong: "LOOK-21 says every stroke is one physical pixel from KitTokens. Border.all( and a BorderSide( with no width (the 1.0 logical-pixel default) break it and are not covered by the text. Divider thickness: is covered only outside the kit", evidence: "lib/ui/kit/kit_status_mark.dart:51 Border.all(..., width: 1.5); kit_request_card.dart and glass/kit_glass.dart Border.all with the default width", proposed: "inside the kit, a Border.all( or BorderSide( whose width: is missing or not read from KitTokens, and a numeric thickness: other than 0, is a ratchet baselined at creation until slice-P9.10 (LOOK-21)", blocks: false}`. The gate implements the proposed text as the ratchet row `stroke width not KitTokens in kit`, baselined at 5 files. The old row `BorderSide(width: not KitTokens` now covers only outside the kit.
2. `{rule: "STANDARDS.md §18.2 G17 and G21", says: "It scans lib/ui/ only", why wrong: "LOOK-1 (no Color(0x…)/Colors.* outside the theme files) and the other LOOK rules are not limited to lib/ui/. Widget code under lib/voice, lib/diagnostics, lib/update and lib/main.dart could use any colour, font size or spacing and pass every gate", evidence: "lib/voice/voice_ui.dart (23 .colorScheme, 7 .textTheme, 28 numeric SizedBox, 11 numeric EdgeInsets); lib/diagnostics/app_diagnostics.dart:208 Color(0xFF201A18); lib/main.dart:214 .colorScheme", proposed: "G17 and G21 scan lib/ui/ and every lib/** file that imports package:flutter/material.dart, widgets.dart or cupertino.dart, excluding the theme files. Alternatively, move those files under lib/ui/", blocks: false}`. The gate implements the first proposal as the pseudo-root `_uiElsewhere`, with the new hits baselined (G17: 3 files, G21: 6 files; see the table below). If the coordinator rejects the proposal, dropping `_uiElsewhere` from `_uiRoots` and rewriting G17/G21 restores the §18.2 wording.

### Baseline counts (ratchet rows, today)

| Gate | Files | Pattern: hits in files |
|---|---|---|
| G2 | 97 | showConfirmSheet( 66/35 · Clipboard.setData( 47/37 · Curves. in kit 45/12 · duration: Duration( 32/20 · Curves. 25/13 · ProductErrorState( 18/17 · ProductEmptyState( 16/12 · ProductInlineEmpty( 8/5 · launchUrl( 4/4 · AnimatedSize( 4/3 · HapticFeedback. 1/1 · HapticFeedback. in kit 1/1 · KitSecretField( 1/1 |
| G7 | 21 | EdgeInsets.fromLTRB asymmetric 19/10 · EdgeInsets.only(left\|right:) 11/6 · bidi literal 8/3 · TextAlign.right 5/5 · Positioned(left\|right:) 2/2 · Alignment.centerLeft 2/2 · TextAlign.left 2/1 · Alignment.centerRight 1/1. No kit file is baselined; the kit rows are absolute and clean. |
| G15x | 4 | numeric maxWidth: 3/3 · width-literal 1/1 |
| G17 | 174 | .textTheme 814/144 · .colorScheme 557/120 · attention roles 98/50 · Colors.* 41/12 · Color(0x 4/2 |
| G21 | 206 | SizedBox numeric 1075/140 · EdgeInsets numeric 928/172 · icon size not 20/22/24 214/70 · TextStyle( 162/81 · BorderRadius.circular(<n> 110/48 · fontSize: 51/34 · Border.all( 43/28 · Radius.circular(<n> 38/18 · disableAnimationsOf 33/15 · BorderSide(width: not KitTokens 10/5 · .toUpperCase() 7/5 · text scale clamp 5/4 · stroke width not KitTokens in kit 5/5 · metal\|chrome 5/2 · Opacity( around text 5/5 · Image.asset\|network\|memory\|file( 4/4 · gradient( 4/3 · KitGlass(/GlassSurface( 3/1 · Transform.scale\|ScaleTransition in kit 1/1 · boxShadow: 1/1 |
| G48 | 11 | sheet multiline without draft: 14/11 (`composer.dart` 2, `prompt_editor.dart` 2, `start_run_sheet.dart` 2, and one each in `permission_sheet.dart`, `development_services_screen.dart`, `review_workspace.dart`, `gate_sheet.dart`, `form_renderer.dart`, `team_board_move_sheet.dart`, `team_controls.dart`, `lib/voice/voice_ui.dart`) |

What the review fixes changed in the baseline (commit `5dea435f`, against `cdafb5a6`): G7 lost 3 entries (the symmetric `Positioned`). G17 gained `lib/diagnostics/app_diagnostics.dart`, `lib/main.dart` and `lib/voice/voice_ui.dart` (new root). G21 gained 6 files outside `lib/ui/` (new root: `app_diagnostics.dart`, `perf_trace.dart`, `main.dart`, `shorebird_update_notice.dart`, `notices.dart`, `voice_ui.dart`) and the 5 kit stroke entries. G48 went from 0 to 11 files (new openers). G1, G15, G16, G2 and G15x are byte-for-byte unchanged (checked with a JSON comparison).

At zero today, so any new hit fails: `.accent`, `hairline.withValues(`, `Color.fromARGB(`, `BoxShadow(` outside the kit, `shadows: [`, `ImageFilter.blur`, `BackdropFilter(` outside the kit, `thickness:`, `PageRouteBuilder(`, `transitionsBuilder:`, `KitEffects.of(` outside the kit, `.withOpacity(`, `text role withValues(`, `fontSize: <n> in kit`, `numeric layout width:`. Absolute and clean: G2 `launchUrl( in kit`, `Clipboard.setData( in kit`, `duration: Duration( in kit`, `AnimatedSize( in kit`; the seven G7 `… in kit` rows; G21 `KitSurfaceLevel.glass|raised|tonal`.

## 2. Builds

- Branch `gate/kit-ratchet`, base `9220f070`. Gate code `cdafb5a6`, review fixes `5dea435f`.
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

All runs are on the review-fix code (`5dea435f`), with the command in §6 redirected to the evidence file, unfiltered.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `KIT_RATCHET_WRITE=1 KIT_RATCHET_GATES=G7,G17,G21,G48` after adding the `allow` section by hand | rewrites those four gates; G1/G15/G16/G2/G15x and `allow` unchanged | as expected (JSON comparison) | PASS |
| 2 | `test/kit_ratchet_test.dart` on today's code | all pass | 32 passed (`pass-on-today.txt`) | PASS |
| 3 | Throwaway `lib/ui/screens/zz_gate_violation.dart` (Clipboard, a `showModalBottomSheet` with `maxLines: null`, `EdgeInsets.only(left:)`, `TextStyle(fontSize:)`, `Colors.red`, `KitSurfaceLevel.glass`), `lib/ui/kit/zz_gate_violation.dart` (`launchUrl(`, `Positioned(left: 0)`, `width: 320`, `Border.all(width: 1.5)`), `lib/ui/kit/links/kit_copy.dart` (`Clipboard.setData(` in a same-named subfolder file) and `lib/voice/zz_gate_violation.dart` (`Color(0x`, `TextStyle(fontSize:)`) | G2, G7, G15x, G17, G21 and G48 each fail and name the file, pattern, fix and rule id | 8 failed (G1 and G16 also catch the screen file) (`fail-on-violation.txt`). The absolute rows `launchUrl( in kit`, `Clipboard.setData( in kit` (the subfolder `kit_copy.dart`), `Positioned(left\|right:) in kit` and `KitSurfaceLevel` fire, as do the kit stroke row, the `showModalBottomSheet` G48 opener, and G17/G21 in `lib/voice`. Files deleted. | PASS |
| 4 | Throwaway: `lib/ui/screens/settings/personal_settings_screens.dart` (the one `KitGlass(` offender) added to `_glassFiles` in the test | the G21 row is silenced, but "allowlists never grow (KIT-5)" fails | failed with `KIT-5: G21 "KitGlass(/GlassSurface(" allows lib/ui/screens/settings/personal_settings_screens.dart — not in the committed "allow" set` (`fail-on-allowlist-growth.txt`); test file restored from a copy and compared with `cmp` | PASS |
| 5 | Throwaway `TextAlign.right` appended to `lib/ui/widgets/markdown.dart` (baselined at 1) | G7 fails with "rose from 1 to 2" | failed (`fail-on-rise.txt`); restored with `git checkout` | PASS |
| 6 | Only `Alignment.centerRight` → `AlignmentDirectional.centerEnd` in `review_workspace.dart` | G7 passes and prints the dropped entry and the rewrite command | printed `review_workspace.dart "Alignment.centerRight" 1 -> 0` (`drop-prints-baseline.txt`); restored | PASS |
| 7 | `flutter analyze test/kit_ratchet_test.dart`; `dart format --language-version=3.10 --set-exit-if-changed` | no issues | No issues found; 0 changed | PASS |

## 5. Evidence

- The evidence files are the raw output of `tool/qa/machine_lock.sh test -- $F test -j 1 test/kit_ratchet_test.dart > <file> 2>&1`, not trimmed. They include `pub get`'s "Resolving dependencies" lines. The earlier versions of `pass-on-today.txt` and `fail-on-violation.txt` (commit `32ef0b42`) were filtered: that code printed the whole baseline JSON on every passing G1 run, and the dump was cut from the files without saying so. The code no longer prints it, so nothing has to be cut.
- `pass-on-today.txt`: step 2. It also shows `G16: 6 baseline entries dropped` (`team_conversation_view.dart`, `local_agent_onboarding.dart`). That is G16's own baseline, which this unit does not rewrite. The integrator can run `KIT_RATCHET_WRITE=1 KIT_RATCHET_GATES=G16`.
- `fail-on-violation.txt`: step 3.
- `fail-on-allowlist-growth.txt`: step 4.
- `fail-on-rise.txt`: step 5.
- `drop-prints-baseline.txt`: step 6.
- Rule evidence (PROC-31): the group "G2/G7/G15x/G17/G21/G48 rows on fixture strings" in `test/kit_ratchet_test.dart` tests each counter on fixture strings. It covers declarations skipped, directional forms not counted, symmetric `left:`/`right:` not counted, the G7 kit rows absolute with only the forced-LTR allowlist, `launchUrl( in kit` absolute with no allowlist (SEC-1), `Colors.transparent` exempt, `BorderRadius` not double-counted as `Radius`, icon sizes 20/22/24 allowed, the kit stroke row (`Border.all(width: 1.5)`, `Border.all(color: c)`, `Border(bottom: BorderSide(color: c))` and `Divider(thickness: 1)` count; `KitTokens` widths, `BorderStyle.none`, `thickness: 0` and `thickness: t` do not), `monochrome` not counted as chrome, G48 with and without `draft:` and through `showModalBottomSheet(`/`showConfirmSheet(`, the `_uiElsewhere` root (contains `lib/voice/voice_ui.dart`, `lib/main.dart`, `lib/diagnostics/app_diagnostics.dart`, nothing under `lib/ui/`), exact allowlist keys (the subfolder and bare-name cases do not match), and the KIT-5 diff (a key the committed set lacks is reported).
- Changed test expectations (TEST-19): the fixture "`BorderSide(color: c)` is fine" now holds only outside the kit, because the old row is scoped outside the kit. Inside the kit the new stroke row counts it. The G7 fixture now expects 2 `EdgeInsets.only` hits (one asymmetric pair was added) and still 1 `Positioned` hit (a symmetric one was added). The G1, G15 and G16 tests are unchanged, except that a passing G1 run no longer prints the whole baseline.
- Goldens, before and after, accessibility: n/a, no UI change.
- Privacy and security: SEC-1's `launchUrl` is counted outside the kit (the 4 existing direct launches in `bug_report.dart`, `host_management_screen.dart`, `integrations_screen.dart` and `termux_setup_screen.dart` are baselined, not allowlisted), and it is absolute inside the kit with no allowlist, so no kit part can open a server value directly.
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
- G3x (copying these patterns into `_forbidden`) and G31 (checking `ratchet-tighten` lines, including edits to the `allow` section, against the merge base) are other gates and are not built here. Until G31 exists, KIT-5 stops a key added in the code alone, but not a key added to both the code and the JSON in one commit; that is what the `ratchet-tighten` line is for.
- G48 limits: a file with a `draft:` on any one field passes for every field in it. A sheet whose body is in a different file from its opener call is not counted (the opener's file has no field, and the body's file has no opener). A fixed `maxLines: 5` without `minLines:` is not read as multiline. Dialogs are not counted (see "How each pattern was read").
- LOOK-21 limits: a width given by a variable or a helper other than `KitTokens` is counted, but a `KitTokens` value that is not a stroke width (for example `width: KitTokens.space2`) passes. Strokes outside the kit are still counted only by the `Border.all(`, `thickness:` and `BorderSide(width:` rows, so a default-width `BorderSide(color: c)` outside the kit is not counted.
- The `_uiElsewhere` root finds UI code by its Flutter import. A file that builds widgets through another app file's re-export, without importing Flutter itself, would be missed. There is none today.
- The switch to absolute at slice-P9.10 (G17/G21 inside the kit) and after §0.5 step 2 (G15x) is not automated. It means setting `absolute: true` on those rows, with the note on each row saying why it is a ratchet today.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/kit-ratchet` |
| Enabled | Yes | runs in `test/kit_ratchet_test.dart` |
| Verified | tests only | this record |
| Committed | Yes | code `cdafb5a6`, review fixes `5dea435f` |
| Deployed | No | |
| Released | No | |
