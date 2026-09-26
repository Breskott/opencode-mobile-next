# revamp-kit-KitQr: KitQr, the handoff QR code (2026-09-27)

## 1. Scope

- Unit: `kit-KitQr` (wave 1, tier 1a, kit-part). Finish line: `KitQr` exists in its own file under `lib/ui/kit/`, has its frozen API, every declared state, its galleries, its contract tests and its structural asserts. Non-goal: no call site outside the kit changes (`session_handoff_sheets.dart` is not touched; its wave-2 unit adopts the part).
- Files changed: `lib/ui/kit/kit_qr.dart` (new), `test/kit/kit_qr_test.dart` (new), `test/goldens/kit/kit_qr_golden_test.dart` (new, 8 PNGs), `lib/l10n/app_en.arb` (+`kitQrTooLong`), `lib/l10n/app_localizations*.dart` (regenerated — see Contract problems).
- Pages (map ids): none. `kit-KitQr` is a kit-part unit with no assigned map pages; `docs/ux-system/kit-v2.md` §5/§9.2 lists KitQr as a one-off surface, not a screen.
- Specs followed: `docs/ux-system/kit-api/KitQr.md` (frozen API, states, tokens, adaptive, a11y, RTL, motion, data safety); STANDARDS.md rules LOOK-1, LOOK-21, LOOK-35, KIT-9, KIT-12, KIT-32, STATE-2, STATE-8, A11Y-1, A11Y-8, SEC-2, SEC-5, TEST-11 (named by the spec header), plus TEST-9/TEST-15/TEST-20 (galleries and contract tests) and the §1 definition-of-done checklist; `docs/ux-system/kit-v2.md` §5 ("the handoff QR"), §8.2 (adaptive), §8.4 (gallery sizes), §9.1/§9.2 (kit-only allowlist and Surfaces).
- Contract problems (PROC-20):
  1. **Arabic/gallery-size scope changed after the spec froze.** `docs/ux-system/kit-api/KitQr.md` (wave 0) asks for Arabic copy in `app_ar.arb`, an RTL-mirroring concern, and a 22-shot gallery (5 LAY-4 sizes, plus 2.0-text and Arabic variants). Commit `97975859` on `feat/phone-setup-v2` (2026-09-27, after this unit's branch point `b67e3276`) adds to STANDARDS.md: "**Owner decision 2026-09-27: Arabic is dropped from the revamp.** Builders do not render Arabic or RTL galleries, do not add Arabic translations for new copy (new ARB keys go only in `app_en.arb`)... Galleries: phone 412x915 and one wide size (1280x800) only, light and dark." R15 ("owner decisions dated later win") makes this later, dated decision win over the wave-0 frozen spec. Applied: `kitQrTooLong` is English-only (no `app_ar.arb` entry; Arabic falls back to the English string, confirmed in `lib/l10n/app_localizations_ar.dart`); the gallery is 2 states × {412×915, 1280×800} × {dark, light} = 8 PNGs, no Arabic or 2.0-text shots. Kept: the frozen spec's Tests-required item 6 (the painted module pattern is identical under `TextDirection.rtl` and `.ltr`) as a plain behaviour test, not a gallery — it proves a real scanning-correctness property (a mirrored QR code does not scan), carries no Arabic copy, and is not a "gallery" or "RTL review" the decision suspends. Reported per PROC-20 rather than silently deviating from either document; the coordinator should confirm this reading covers wave-1 kit-part units the same as it plainly covers screen units.
  2. **Generated `app_localizations*.dart` vs. G27 ("units never commit them").** STANDARDS §18.2 G27 says the integrator runs `flutter gen-l10n` and commits the generated Dart files after merging a wave's ARB changes, to avoid many units colliding on the same generated file. But §1's definition of done requires `flutter analyze`/`flutter test` clean on the whole worktree, and `kit_qr.dart`/`kit_qr_test.dart` call `AppLocalizations.kitQrTooLong`, which does not exist until `flutter gen-l10n` runs. Reverting the generated files (tested) breaks `flutter analyze` on this branch. Resolved in favour of a working, self-testable branch: `flutter gen-l10n` was run and its three output files are committed in `code head` below. The diff is additive-only (one new getter, in the same alphabetical position gen-l10n always places it), so it should merge or regenerate cleanly at integration; the coordinator's post-merge `flutter gen-l10n` pass is unaffected either way.
- New kit parts (KIT-3): `KitQr` (`lib/ui/kit/kit_qr.dart`).
- Map items (EVID-11): n/a — no map pages assigned to this unit.
- States per page (STATE-20): n/a — not a page. `KitQr`'s own declared states (KIT-12 doc comment: "States: default, error (too long)"): `default` → `test/kit/kit_qr_test.dart` tests 1–3, 6 and `test/goldens/kit/kit_qr_golden_test.dart` (`kit_qr_default_*`); `too long` → tests 4, 5, 7 and `kit_qr_too_long_*` goldens.
- Deferred states (STATE-21): none — KitQr has no loading/empty/disabled/working/answered state per its own spec ("Loading is not possible... There is no disabled, working or answered state").

## 2. Builds

- Branch `revamp/kit-KitQr`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4` (`feat/phone-setup-v2` at branch time), code head `10314e0dddfd57e86cc870c47d106f9065eeb85b`.
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at the wave checkpoint.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | New code, no prior fix to prove failing-first (TEST-2: "New code that fixes nothing needs no failing-first run") | n/a | n/a | n/a |
| 2 | `test/kit/kit_qr_test.dart` | passes | 12 passed (`run-behaviour-tests.txt`) | PASS |
| 3 | `test/goldens/kit/kit_qr_golden_test.dart` (against the committed PNGs, no `--update-goldens`) | passes | 8 passed (`run-galleries.txt`) | PASS |
| 4 | `test/kit_ratchet_test.dart`, `test/l10n_coverage_test.dart`, `test/ui_glossary_test.dart`, `test/design_standard_test.dart` | pass | 70 passed, 0 failed (`run-shared-gates.txt`) | PASS |
| 5 | `flutter analyze lib test` (whole worktree) | no errors, no new issues | "No issues found!" (`run-analyze.txt`) | PASS |

## 5. Evidence

- `run-behaviour-tests.txt`: output of step 2.
- `run-galleries.txt`: output of step 3.
- `run-shared-gates.txt`: output of step 4 (ratchet, l10n coverage, glossary, design-standard — none of them touched or newly failing).
- `run-analyze.txt`: output of step 5.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | LOOK-21 (module snapping, physical pixels) | `test/kit/kit_qr_test.dart` "1. module snapping..." | `run-behaviour-tests.txt` |
  | KIT-32 / TEST-11 (deterministic pattern, module-for-module) | `test/kit/kit_qr_test.dart` "2. pattern..." | `run-behaviour-tests.txt` |
  | LOOK-1 (fixed graphiteLight ink/paper whatever the theme, incl. a non-Graphite pack) | `test/kit/kit_qr_test.dart` "3. theme-proof..." | `run-behaviour-tests.txt` |
  | STATE-2 / STATE-8 (too long says so, no blank) | `test/kit/kit_qr_test.dart` "4. too long..." | `run-behaviour-tests.txt` |
  | SEC-2 / A11Y-1 (one image node, data never in semantics) | `test/kit/kit_qr_test.dart` "5. semantics..." | `run-behaviour-tests.txt` |
  | RTL (module pattern never mirrored) | `test/kit/kit_qr_test.dart` "6. direction..." | `run-behaviour-tests.txt` |
  | KIT-37 (empty asserted away) | `test/kit/kit_qr_test.dart` "7. empty..." | `run-behaviour-tests.txt` |
  | A11Y-8 / LAY-4 (no overflow at 320/412dp, 1.0/1.3/2.0 text, LTR/RTL, both states) | `test/kit/kit_qr_test.dart` "8. overflow..." | `run-behaviour-tests.txt` |
  | MOT-7 / G8x (settles after one pump, system and Effects Off) | `test/kit/kit_qr_test.dart` "KitQr (MOT-7) ..." (via `kitMotionStillTests`) | `run-behaviour-tests.txt` |
  | TEST-9 / G4 (galleries at DPR 3, declared states, both themes, reduced sizes per the 2026-09-27 decision) | `test/goldens/kit/kit_qr_golden_test.dart` | `run-galleries.txt` |
  | G16/G21 (kit-only ratchet: `kit_qr.dart` adds zero new hits) | `test/kit_ratchet_test.dart` | `run-shared-gates.txt` |

- Changed test expectations (TEST-19): none — no shared test was touched or broke.
- Goldens changed (all new, each opened and looked at): `kit_qr_default_dark.png`, `kit_qr_default_light.png`, `kit_qr_default_1280x800_dark.png`, `kit_qr_default_1280x800_light.png`, `kit_qr_too_long_dark.png`, `kit_qr_too_long_light.png`, `kit_qr_too_long_1280x800_dark.png`, `kit_qr_too_long_1280x800_light.png` — a sharp white paper with the QR pattern on the app surface (dark) or a light gray sheet (light), a hairline edge visible on light, the caption row (link + copy icon) below; `too_long` shows the error glyph and message with no paper. No approved VL canvas render exists for this part yet (EVID-12: none).
- Before and after: n/a — new part, no prior render of this page/element exists (EVID-10: "no before render", no page id — KitQr is not a screen).
- Accessibility: one `Semantics(image: true, label: semanticsLabel)` node in the default state, module pattern excluded from semantics (test 5); the too-long line is `liveRegion: true`; the code never scales with text (it is drawn, not text) and the too-long line wraps at every checked scale (test 8); the QR paper keeps an 18:1 (ink/paper) contrast and a hairline edge for visibility on a light sheet (LOOK-21, checked visually in the light goldens).
- Privacy and security: `data` is never rendered as text, logged, or exposed in semantics (SEC-2, test 5, with a secret-shaped fixture `.../super-secret-token-abc123` never found anywhere in the tree); no real secret in any fixture or golden (SEC-5 — fixtures are `https://example.invalid/...` and `opencode://s/shopfront/9c2f`); no network, no clipboard use by the part itself.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_qr_test.dart test/goldens/kit/kit_qr_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart test/ui_glossary_test.dart test/design_standard_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator (coordinator work, R19/R20).
- Not exported from `lib/ui/kit/kit.dart` (integrator's job, R06) — so the shared `test/kit/kit_manifest_test.dart` and `test/kit_motion_test.dart` manifests do not see `KitQr` yet, and its `kitMotionStillTests` registration in `test/kit/kit_qr_test.dart` is not yet cross-checked by `test/kit_motion_baseline.json`.
- `session_handoff_sheets.dart` still has its own `SessionLinkQr`/`_QrPainter` (unchanged, out of this unit's write set); the wave-2 unit that owns that file adopts `KitQr` and removes them.
- No approved visual-language canvas render exists for KitQr to diff the goldens against (EVID-12: none available).
- Contract problems 1 and 2 above are unresolved pending coordinator confirmation; this record states the reading applied.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitQr` |
| Enabled | No: not exported from `kit.dart`, not adopted by any screen yet (by design, R14/R13) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `10314e0dddfd57e86cc870c47d106f9065eeb85b` |
| Deployed | No | |
| Released | No | |
