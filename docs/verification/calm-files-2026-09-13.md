# Files progressive disclosure — 2026-09-13

Finish line: default browsing emphasizes names and opening files; symbol search and numeric diff details are available on deliberate selection, while changed-file review remains one clear action away.

Non-goals: new file operations, changes to server access, ordering/persistence, controllers, shared viewers, text scaling or hidden errors.

## Implemented

- Replaced the permanent Files/Symbols tab row with a checked menu on the search icon. Its dropdown arrow indicates more choices; the field hint and icon identify the active mode. The existing workspace-symbol capability still controls availability.
- Kept the changed-file count and review entry visible. Addition/deletion totals and per-file counts remain in the existing Changes sheet, reached with one tap.
- Kept file/folder names, dirty status labels, descendant dirty counts, search-result paths, folder breadcrumbs and all existing context actions. The source-first sort menu, empty states and failure notices were already disclosed appropriately and remain unchanged.
- Reused existing localized English/Arabic strings; no new localization keys, storage formats, data collection or credentials.

## Verification

Before editing, inspected actual-widget deterministic captures: dark normal/enlarged populated, plus dark empty, under `/tmp/oc-calm-ui-20260913/before-files/`. These use synthetic fixtures and are not live-server proof.

Affected regression coverage checks the now-hidden mode is reachable, symbol search works, version-control status stays visible, and the Changes sheet retains aggregate/per-file totals and review/staging actions. Existing folder/search restoration and failure recovery checks are included in the requested focused run.

The new `tool/capture/calm_files_test.dart` captures light/dark, normal/2x text, populated/empty/folder views and opened mode/changes controls to `docs/qa/calm-files/after/`.

Coordinator ran pinned Dart formatting and `flutter test --concurrency=1 test/product_ui_regression_test.dart test/files_screen_recovery_test.dart tool/capture/calm_files_test.dart`: 41 passed. Menu text finders emitted hit-test warnings because checked menu entries receive taps in their parent. Updated those finders to target the actual menu entry, then coordinator reran `flutter test --concurrency=1 test/product_ui_regression_test.dart tool/capture/calm_files_test.dart`: 35 passed with no hit-test warnings. Application source was unchanged between these runs; the six recovery checks retain their first-run coverage.

Logs: `/tmp/oc-calm-ui-20260913/files-check.log` and `files-check-2.log`. `git diff --check` passes. Analyzer remains an integration checkpoint. This worker did not launch Flutter/Dart/native processes.

Reviewed normal dark/light populated captures, enlarged search options and Changes sheet, enlarged light folder and enlarged dark empty state. Names and status remain readable, disclosed choices/totals are visible, and the captured 2x layouts show no overflow. Twenty deterministic captures are committed in `docs/qa/calm-files/after/`.

## Accessibility and limits

Search choices use checked Material menu items and localized tooltips. The active mode is also conveyed in text rather than color alone. Names, dirty labels and errors remain text; text scaling is not clamped. The changed-file review target retains its 48dp minimum height. Normal/enlarged captures were reviewed as described above; the coordinator independently reviews them during integration. No Android/browser runtime or release claim is made by this slice.
