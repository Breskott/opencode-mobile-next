# gate-G26: analyzer suppressions, no new ignores (2026-09-26)

## 1. Scope

- Gate `G26` (wave 1, gate). Finish line: a new analyzer suppression comment or `analysis_options.yaml` suppression fails `flutter test`. Non-goal: removing today's suppressions (the baseline records them; later units lower it).
- Finish line (unchanged), extended by the review: any new suppression token, changed include or unlisted options file fails too.
- Files: `test/analyzer_suppressions_test.dart`, `test/analyzer_suppressions_baseline.json`, this folder.
- Rules enforced: PROC-3 (STANDARDS.md §2; gate row §18.1 G26, detail §18.2 G26). PROC-13 lists the G26 baseline as a shared-merge file that may only shrink; G31 checks that across a branch.
- What it checks (ratchet):
  1. Suppression comments in every Dart file `git ls-files --cached --others --exclude-standard` lists (so a new top-level directory such as `integration_test/` is covered), except the generated SDK under `packages/opencode_sdk/`. Per file it keeps the count of `//\s*ignore(_for_file)?:` comments **and the multiset of suppression tokens** `(ignore|ignore_for_file):<code>`, comma lists split into one token per code and `type=lint` its own code. A file fails when its count rises or when it holds any token its baseline multiset does not: widening a line `ignore` to `ignore_for_file`, adding a code (`, type=lint`) to an existing comment, or swapping one ignore for another all fail although the count is unchanged. The message lists every matching line.
  2. Analyzer options files: every `analysis_options.yaml` and `analysis_options.mustache` in the repo must be on the baseline's allowlist (today the root file, `packages/opencode_sdk/analysis_options.yaml` and its template `tool/sdk/templates/analysis_options.mustache`); any other, at any depth, fails. For each allowed file the top-level `include:` must equal the baseline (removing or changing `package:flutter_lints/flutter.yaml` fails; deleting a file whose baseline has an include fails too), and `analyzer: exclude:`, `analyzer: errors:` entries set to `ignore` and `linter: rules:` entries set to `false` may not gain an entry.
  3. The options reader fails closed: under `include:`, `analyzer:` or `linter:`, a flow mapping (`{`), an anchor, alias, tag or merge key (`&`, `*`, `!`, `<<`), a block scalar, a complex key, a multi-line or misplaced flow list, an inline value on a mapping key, or a line that is not a key or list item is reported as a problem; so is a second YAML document (`---` after content, or `...`) or a directive anywhere in the file.
  4. When a count drops or an entry disappears and nothing fails, the test passes and prints the smaller baseline to commit, computed as the per-entry minimum of the baseline and today, so a printed baseline never raises an entry. `ANALYZER_SUPPRESSIONS_WRITE=1` rewrites the baseline (to lower it only).
- Beyond the §18.2 text: all Dart files outside the generated SDK are scanned, not only `lib/` and `test/` (`flutter analyze` covers them and PROC-3 has no directory limit); the include, errors and rules settings are tracked with `exclude:`, since each is another way to silence a diagnostic; every options file in the repo is tracked. The test prints with `stdout.writeln`, so it carries no suppression of its own.
- Review fix-up (same day): the first version counted comments only, read only the root options file's exclude/errors/rules in a parser that skipped YAML it did not understand, and looked for nested options files only under `lib/`, `test/` and `tool/`. All three review findings were checked and accepted: count-neutral widening passed, a removed `include:` and `analyzer: {exclude: [lib/**]}` passed, and an options file in `integration_test/` or `packages/<new>/`, or an exclude added to the SDK template, passed. Runs 1 to 3 below prove each now fails.
- Contract problems (PROC-20): none.
- New kit parts, map items, states: n/a (a gate, no UI).

## 2. Builds

- Branch `gate/G26`, base `9220f070`, first code head `02276e59`; review fix-up: the commit that follows it (this record).
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Gate on today's code (`pass-on-today.txt`) | passes | 2 passed | PASS |
| 2 | Run 1 in `fail-on-violation.txt`: new file with `ignore_for_file`; `kit_ratchet_test.dart` `ignore: avoid_print` widened to `ignore_for_file: type=lint` and to `ignore: type=lint`; `, type=lint` added to `chat_states_standard_test.dart:10`; `search_index_test.dart` ignore swapped to another code; a second ignore in `l10n_coverage_test.dart` | comments test fails, naming each | failed, 5 files named with their new tokens; probes removed | PASS |
| 3 | Run 2: root `include:` removed, `lib/g26_probe/**` excluded, `errors: {avoid_print: ignore}`, `avoid_print: false`, `prefer_const_constructors: *off`, a second document with `exclude: [lib/**]` | options test fails, naming each | failed, 7 problems named; probe removed | PASS |
| 4 | Run 3: `integration_test/analysis_options.yaml` = `analyzer: {exclude: [lib/**]}`, `packages/g26probe/analysis_options.yaml`, `test/analysis_options.yaml`, root include changed to `package:lints/core.yaml`, `lib/**` excluded in the SDK template, `unused_element: ignore` in the SDK options | options test fails, naming each | failed, 7 problems named; probes removed | PASS |
| 5 | One ignore removed from `l10n_coverage_test.dart` (`shrink-prints-baseline.txt`) | passes and prints the smaller baseline | passed, printed baseline with that file at 1 | PASS |
| 6 | `flutter analyze test/analyzer_suppressions_test.dart` | no issues | no issues | PASS |
| 7 | `dart format --language-version=3.10 --set-exit-if-changed` | unchanged | 0 changed | PASS |

## 5. Evidence

- `pass-on-today.txt`, `fail-on-violation.txt`, `shrink-prints-baseline.txt` in this folder.
- Baseline at creation (`test/analyzer_suppressions_baseline.json`): 29 suppression comments carrying 32 tokens in 25 files, and 3 allowlisted options files. Baseline shape: `suppressionComments` (file to count), `suppressionTokens` (file to sorted token list, a multiset) and `analysisOptions` (options file to `include`, `analyzer.exclude`, `analyzer.errors.ignore`, `linter.rules.disabled`).
  - `lib/`: `lib/api/opencode_api.dart` 1; generated `lib/l10n/app_localizations.dart` 1, `app_localizations_ar.dart` 2, `app_localizations_en.dart` 2.
  - `test/`: `chat_states_standard_test.dart` 1, `goldens/chat_states_golden_test.dart` 1, `kit_ratchet_test.dart` 2, `l10n_coverage_test.dart` 2, `search_index_test.dart` 1.
  - `tool/`: 16 files with 1 each (`tool/capture/**` capture and census harnesses, `tool/qa/oc2_live_proof_test.dart`, `tool/qa/paseo_live_proof_test.dart`).
  - Tokens: `ignore_for_file:type=lint` in the 3 generated l10n files and `ignore:unused_import` in the two locale files; `ignore:deprecated_member_use` in `opencode_api.dart`; `ignore:avoid_print` twice in `kit_ratchet_test.dart` and `l10n_coverage_test.dart`, once in `search_index_test.dart`; `ignore_for_file:avoid_print` in the two live-proof tests; `ignore_for_file:invalid_use_of_protected_member` and/or `invalid_use_of_visible_for_testing_member` in the other 16 files (3 of them carry both).
  - `analysis_options.yaml`: include `package:flutter_lints/flutter.yaml`; `exclude:` `android/**`, `build/**`, `ios/**`, `linux/**`, `macos/**`, `tool/sdk/runtime/**`, `web/**`, `windows/**`; `errors: ignore` none; disabled lint rules none.
  - `packages/opencode_sdk/analysis_options.yaml` and `tool/sdk/templates/analysis_options.mustache` (identical): no include; `exclude:` `lib/src/model/*.g.dart`, `test/*.dart`; `errors: ignore` `deprecated_member_use_from_same_package`, `strict_raw_type`, `unused_import`; disabled rules none.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test --no-pub -j 1 test/analyzer_suppressions_test.dart
# lower the baseline after removing suppressions:
ANALYZER_SUPPRESSIONS_WRITE=1 tool/qa/machine_lock.sh test -- $F test --no-pub -j 1 test/analyzer_suppressions_test.dart
```

## 7. NOT proven

- The generated `lib/l10n/app_localizations*.dart` counts come from `flutter gen-l10n`; if a Flutter upgrade changes their header, the integrator must adjust those entries (a rise needs a `ratchet-tighten`-style note, G31).
- The pattern also counts `// ignore:` text inside string literals or doc comments; none exist today.
- The YAML reader is a small indentation parser for block YAML (flow lists on one line for `include:`, `exclude:` and `rules:`). It fails closed on the YAML it does not read (item 3 above) rather than parsing it; a mustache tag (`{{`) added under `analyzer:` in the SDK template would also be reported, which is intended.
- Options-file discovery uses `git ls-files --cached --others --exclude-standard`, so an options file inside a gitignored path is not seen (it cannot be committed either). Without git the test walks the tree, skipping hidden directories, `build/` and symlinks.
- The Dart sources of `packages/opencode_sdk/` (generated) are not scanned for comments; its options file and template are.
- Other analyzer settings that change which diagnostics appear (`analyzer: language:` strict flags, `errors:` severities other than `ignore`, `plugins:`) are not tracked.
- Changing the baseline shape means a baseline in the old shape (section to list under `analysisOptions`) makes the test fail to load; G31 must read the new shape.
- No device run (not applicable to this gate).

## State

| State | Value |
|---|---|
| Implemented | yes |
| Enabled | yes (runs in `flutter test`) |
| Verified | yes (runs 1 to 5) |
| Committed | yes (`gate/G26`) |
| Deployed | no |
| Released | no |
