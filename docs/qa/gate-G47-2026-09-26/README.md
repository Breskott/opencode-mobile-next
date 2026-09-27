# gate-G47: permission presentation copy (2026-09-26)

## 1. Scope

- Gate: `G47` (STANDARDS.md §18.1, due W1). Finish line: `test/permission_presentation_test.dart` makes COPY-15 mechanical for `permissionRequestTitle` in English and Arabic. Non-goal: changing `lib/ui/permission_presentation.dart` or any caller (that is product code, owned elsewhere).
- Files changed: `test/permission_presentation_test.dart`, `test/permission_presentation_baseline.json`, this folder.
- Pages (map ids): n/a: a gate, no page changed.
- Specs followed: STANDARDS.md COPY-15; §18.2 G47 paragraph; KIT-4/KIT-5 ratchet conventions (baseline only shrinks, reason longer than 10 characters, prints the smaller baseline when a count drops).
- Contract problems (PROC-20): §18.2 calls G47 **absolute**, but today's code does not comply for unknown ids: `permissionRequestTitle('webfetch')` returns "Use webfetch" (`e7PermissionAction7`), not "Permission needed". Per the gate brief this part is therefore a ratchet (see below). The known-id and empty-id parts are absolute and pass today. Proposed fix (product code, not in this gate's write set): in `lib/ui/permission_presentation.dart` change the fallback arm to `_ => strings.e7PermissionAction6,`, show the id behind Details in the permission sheet, then lower the baseline to 0 and make the ratchet absolute.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a.

### What the gate checks

| Check | Kind | Rule |
|---|---|---|
| `e7PermissionAction6` reads "Permission needed" in English; non-empty in Arabic | absolute | COPY-15 |
| Each known id (`bash`, `edit`, `read`, `external_directory`, `doom_loop`) is titled with its own getter (`e7PermissionAction1`–`5`) in `AppLocalizationsEn` and `AppLocalizationsAr`; the title is non-empty, not the generic title, does not contain the raw id, and the five titles are distinct | absolute | COPY-15 |
| English titles equal the words COPY-15 names ("Run a shell command", "Edit a file", "Read a file", "Access an external directory", "Continue after repeated failures"); without `l10n` the function falls back to English | absolute | COPY-15 |
| An empty or whitespace-only id (`""`, `" "`, `"   "`, `"\t"`, `"\n"`) is titled "Permission needed" in both locales and without `l10n` | absolute | COPY-15 |
| Unknown ids (`unknown_permission`, `future.permission`, `mcp__some_server__tool`, `BASH`) are titled "Permission needed" | ratchet, per locale | COPY-15 |

### Baseline (ratchet)

`test/permission_presentation_baseline.json`, key `unknownIdNotGeneric`: `{"ar": 4, "en": 4}` (all four unknown-id probes, in each locale, are titled "Use <id>" today). A count above the baseline fails; a count below it passes and prints the smaller baseline to commit. Regenerate after the fix with `PERMISSION_PRESENTATION_WRITE=1`.

## 2. Builds

- Branch `gate/G47`, base `9220f070`, code head: the gate commit (tests only; no lib change).
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/permission_presentation_test.dart` on today's code | passes | 7 passed (`pass-today.txt`) | PASS |
| 2 | Throwaway lib violation: `bash` mapped to `e7PermissionAction2` and the empty-id arm deleted | fails | 5 of 7 failed, naming `"bash" -> "Edit a file"` and `"" -> "Use "` in en and ar (`fail-lib-violation.txt`) | PASS |
| 3 | Throwaway baseline violation: `en` baseline lowered to 3 (one more unknown id than allowed) | ratchet fails | failed: `en: 4 unknown ids not titled "Permission needed" (baseline 3)` with each id listed (`fail-ratchet-above-baseline.txt`) | PASS |
| 4 | Throwaway fix: fallback arm returns `e7PermissionAction6` | passes and prints the smaller baseline | 7 passed, printed `{"ar": 0, "en": 0}` (`pass-ratchet-dropped.txt`) | PASS |
| 5 | `flutter analyze test/permission_presentation_test.dart` | no issues | No issues found | PASS |

Each throwaway change was reverted with `git checkout -- lib/ui/permission_presentation.dart` or by restoring the baseline file; `git status` afterwards showed only the gate's new files.

## 5. Evidence

- `pass-today.txt`: run 1.
- `fail-lib-violation.txt`: run 2.
- `fail-ratchet-above-baseline.txt`: run 3.
- `pass-ratchet-dropped.txt`: run 4.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) | Output |
  |---|---|---|
  | COPY-15 | `test/permission_presentation_test.dart` "each known id is titled with its own plain-action getter" | `pass-today.txt`, `fail-lib-violation.txt` |
  | COPY-15 | `test/permission_presentation_test.dart` "an empty id is titled" | `pass-today.txt`, `fail-lib-violation.txt` |
  | COPY-15 | `test/permission_presentation_test.dart` "COPY-15 ratchet" | `fail-ratchet-above-baseline.txt`, `pass-ratchet-dropped.txt` |

- Changed test expectations (TEST-19): none (new test).
- Accessibility: n/a: no UI changed.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/permission_presentation_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/permission_presentation_test.dart
# after the product fix lands:
PERMISSION_PRESENTATION_WRITE=1 $F test -j 1 test/permission_presentation_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- COPY-15's "with the id behind Details" is not checked: it is a property of the permission sheet, not of `permissionRequestTitle`, and G47's §18.2 paragraph does not cover it.
- Callers are not checked to route every permission title through `permissionRequestTitle` (e.g. `nudge_slot.dart` passes `active.detail`); a caller building its own title would not be caught.
- The unknown-id part is a ratchet, not absolute, until the product fix lands.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes (unknown-id part as a ratchet) | `gate/G47` |
| Enabled | Yes: runs in the normal `flutter test` suite | |
| Verified | tests only | this record |
| Committed | Yes | `gate/G47` |
| Deployed | No | |
