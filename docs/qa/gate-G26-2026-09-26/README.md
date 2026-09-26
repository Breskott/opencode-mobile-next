# gate-G26: analyzer suppressions, no new ignores (2026-09-26)

## 1. Scope

- Gate `G26` (wave 1, gate). Finish line: a new analyzer suppression comment or `analysis_options.yaml` suppression fails `flutter test`. Non-goal: removing today's suppressions (the baseline records them; later units lower it).
- Files: `test/analyzer_suppressions_test.dart`, `test/analyzer_suppressions_baseline.json`, this folder.
- Rules enforced: PROC-3 (STANDARDS.md §2; gate row §18.1 G26, detail §18.2 G26). PROC-13 lists the G26 baseline as a shared-merge file that may only shrink; G31 checks that across a branch.
- What it checks (ratchet):
  1. Per file, the count of `//\s*ignore(_for_file)?:` in `lib/`, `test/` and `tool/`. A file above its baseline count, or a file with no entry that has any, fails; the message lists every matching line.
  2. `analysis_options.yaml`: the `analyzer: exclude:` list, plus `analyzer: errors:` entries set to `ignore` and `linter: rules:` entries set to `false` (the other ways to silence a diagnostic). Any entry not in the baseline fails.
  3. Absolute: no `analysis_options.yaml` under `lib/`, `test/` or `tool/` (a nested options file can silence a directory).
  4. When a count drops or an entry disappears, the test passes and prints the smaller baseline to commit. `ANALYZER_SUPPRESSIONS_WRITE=1` rewrites the baseline (to lower it only).
- Beyond the §18.2 text: `tool/` is scanned as well as `lib/` and `test/` (`flutter analyze` covers it and PROC-3 has no directory limit), and the errors/rules settings are tracked with `exclude:`. The test prints with `stdout.writeln`, so it carries no suppression of its own.
- Contract problems (PROC-20): none.
- New kit parts, map items, states: n/a (a gate, no UI).

## 2. Builds

- Branch `gate/G26`, base `9220f070`, code head: the commit that adds this record.
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Gate on today's code (`pass-on-today.txt`) | passes | 2 passed | PASS |
| 2 | Throwaway violations (`fail-on-violation.txt`): new `lib/g26_violation_probe.dart` with `ignore_for_file`, a second `ignore` added to `test/search_index_test.dart`, `lib/g26_probe/**` added to `exclude:`, `avoid_print: false` under `linter: rules:`, a nested `test/analysis_options.yaml` | both tests fail, naming each violation | 2 failed, all 5 violations named; probes then removed | PASS |
| 3 | Baseline entry raised above today's count (`shrink-prints-baseline.txt`) | passes and prints the smaller baseline | passed, printed baseline | PASS |
| 4 | `flutter analyze test/analyzer_suppressions_test.dart` | no issues | no issues | PASS |
| 5 | `dart format --language-version=3.10 --set-exit-if-changed` | unchanged | 0 changed | PASS |

## 5. Evidence

- `pass-on-today.txt`, `fail-on-violation.txt`, `shrink-prints-baseline.txt` in this folder.
- Baseline counts at creation (`test/analyzer_suppressions_baseline.json`): 29 suppression comments in 25 files.
  - `lib/`: `lib/api/opencode_api.dart` 1; generated `lib/l10n/app_localizations.dart` 1, `app_localizations_ar.dart` 2, `app_localizations_en.dart` 2.
  - `test/`: `chat_states_standard_test.dart` 1, `goldens/chat_states_golden_test.dart` 1, `kit_ratchet_test.dart` 2, `l10n_coverage_test.dart` 2, `search_index_test.dart` 1.
  - `tool/`: 16 files with 1 each (`tool/capture/**` capture and census harnesses, `tool/qa/oc2_live_proof_test.dart`, `tool/qa/paseo_live_proof_test.dart`).
  - `analysis_options.yaml` `exclude:`: `android/**`, `build/**`, `ios/**`, `linux/**`, `macos/**`, `tool/sdk/runtime/**`, `web/**`, `windows/**`. `errors: ignore`: none. Disabled lint rules: none.

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
- The YAML reader is a small indentation parser for block YAML (and flow lists for `exclude:`), not a full YAML parser; anchors or multi-document files are not handled.
- `packages/opencode_sdk/` (generated, own analysis options) is not scanned.
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
