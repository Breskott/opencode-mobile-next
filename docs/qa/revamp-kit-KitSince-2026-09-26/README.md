# revamp-kit-KitSince: KitSince, the kit's one wait timer (2026-09-26)

## 1. Scope

- Unit: `kit-KitSince` (wave 1, tier 1, `kit-part`). Finish line: `KitSince`
  exists in its own file under `lib/ui/kit/`, matches its frozen API,
  states, motion, haptics, a11y, RTL and data-safety sections, has galleries
  at the kit-v2.md §8.4 sizes at DPR 3 with a fake clock, and its behaviour
  tests pass with the pinned Flutter. Non-goal: no call site (`grace_timer.dart`,
  `chat_screen.dart`, `agent_output_screen.dart`, …) moves to it, and
  `lib/ui/kit/kit.dart` is not touched. The frozen spec gives both to the
  integrator and to later screen units.
- Files changed: `lib/ui/kit/kit_since.dart` (new); `lib/l10n/app_en.arb`
  and `lib/l10n/app_ar.arb` (three new keys, en and ar together);
  `test/kit/kit_since_test.dart` (new); `test/goldens/kit/kit_since_golden_test.dart`
  (new) and its 22 golden PNGs; this QA folder. The generated
  `lib/l10n/app_localizations*.dart` files are not in the diff (PROC-11,
  PROC-13, G30): `flutter gen-l10n` was run locally so the tests compile,
  and those files were restored to the base before committing. Full list:
  `git diff b67e3276...8cf54c63 --stat`.
- Pages (map ids): none. `KitSince` is a kit part, not a screen, so it has
  no page record in `docs/ux-system/map/all.json`.
- Specs followed: `docs/ux-system/kit-api/KitSince.md` (the frozen API, in
  full); `docs/ux-system/revamp/STANDARDS.md` §1, §15, §16 (TEST-2, PROC-13,
  COPY-30, EVID-1 to EVID-8); `docs/ux-system/kit-v2.md` §4.9, §8.2, §8.4.
- Contract problems (PROC-20):
  1. **`clock` is not a direct `pubspec.yaml` dependency.** KitSince.md
     names this in its own "Open questions". The part reads time through
     `package:clock`, as its Purpose section requires, and "Tests required"
     says every test runs "under `testWidgets`, whose `FakeAsync` fakes
     `clock.now()`". `clock` resolves today only as a transitive dependency
     (`pubspec.lock`, 1.1.2, through `flutter_test` and `fake_async`), and
     `pubspec.yaml` is outside this write set. Evidence: `flutter analyze`
     on the three unit files reports one info per file,
     `depend_on_referenced_packages` on `package:clock/clock.dart`, and
     nothing else. Proposed text: add `clock: ^1.1.2` under `dependencies:`
     in `pubspec.yaml`. It blocks a clean whole-tree `flutter analyze` until
     the coordinator adds the line. The spec's fallback, a
     `@visibleForTesting static DateTime Function() now` seam, was not used:
     the spec calls it the weaker option ("two clocks to keep in step").
  2. **`test/kit/kit_manifest_test.dart` (gate G4) still reports four
     violations for `KitSince`.** None is a defect in this unit; each is an
     integrator step or a checker gap:
     - `exported` and `docRow`: `KitSince` is not reachable from
       `lib/ui/kit/kit.dart` and has no `[KitSince]` row in its doc table.
       `kit.dart` is a shared file that units never stage (R06); the
       integrator adds the export line and the row (PROC-13).
     - `states`: the checker requires a `disabled` state for every nullable
       `on[A-Z]…` field, and that heuristic fires on `onEscalated`. That field
       is a log or telemetry callback on a part that draws nothing, not an
       interaction handler, so the part has no disabled look. The frozen API
       names `onEscalated` verbatim, so it was not renamed to avoid the check.
     - `gallery`: "lacks a …text2… golden at textScale: 2, an …_ar_… golden
       in Locale('ar')". The checker's `_Gallery` class finds shots only in
       `kitGalleryShot(...)` and `matchesGoldenFile(...)` calls. This gallery
       renders through the shared `kitGalleryPart(...)` helper, which
       `test/goldens/kit/kit_foundation_golden_test.dart` also uses, so the
       checker sees no shots. The `_text2` and `_ar` shots exist at 412×915
       and 1280×800 in both themes (see §5). The fix is to teach `_Gallery`
       to read `kitGalleryPart` calls the way it reads `kitGalleryShot`.
     The `kitGallerySizes` sweep that the first round's G4 run also flagged
     was fixable in this unit and is fixed: the slow state now loops over
     `kitGallerySizes`, and the checker no longer reports it.
     `test/kit/kit_manifest_allowlist.json` is a kit-wide shrink-only
     registry owned by the integrator, the same pattern as
     `test/kit_ratchet_baseline.json` (R05), so this unit did not edit it.
     Every other G4 check (`name`, `test`, `motion`, `keyboard`, `overflow`)
     passes for `KitSince`.
- New kit parts (KIT-3): `KitSince` (this unit).
- Map items (EVID-11): n/a, because there is no page record.
- States per page (STATE-20): n/a, because there is no page. See "States" in
  KitSince.md (none: it draws nothing) and the doc comment in `kit_since.dart`.
- Deferred states (STATE-21): none.

### Review fixes (round 2)

| # | Finding | Resolution |
|---|---|---|
| 1 | Generated `lib/l10n/app_localizations*.dart` committed | Restored to the base `b67e3276`; the branch history was rewritten so no commit carries them. Only the two `.arb` files carry the keys. |
| 2 | Galleries missed the §8.4 sizes 800×1280 and 1600×1000 | The slow state loops over `kitGallerySizes` (5 sizes × 2 themes); four new PNGs, each looked at. `kitGalleryScaledSizes` still drives the `_text2` and `_ar` shots. |
| 3 | A `ticks`-only change rescheduled from a stale `_status.elapsed` | `didUpdateWidget` calls `_resync()` for a `ticks` change as well as a `since` change, so the status is recomputed from `since` before the one timer is scheduled. `_fire` shares the same path. New test "changing only ticks mid-wait still turns slow at exactly 8 s"; it fails with the fix reverted (`failing-first.txt`). |
| 4 | Placeholders were interpolated without intl number formatting | `seconds` and both `minutes` placeholders now declare `"format": "decimalPattern"`, so gen-l10n formats them with `NumberFormat.decimalPattern(localeName)` (COPY-30, B17). New test "the labels format their numbers with intl for the locale" (1234 → "1,234"); it fails with the fix reverted (`failing-first.txt`). The `ar` locale's decimal pattern keeps Latin digits, so the Arabic test strings and goldens are unchanged. |
| 5 | QA record misstated the G4 evidence | §1 "Contract problems" now lists only the genuine gaps; the claim that `kit_sheet_golden_test.dart` uses `kitGalleryPart` is gone (it does not); the generated files are gone from "Files changed". |
| 6 | Test 5 did not cover "once per since value" | "onEscalated fires exactly once per since value" now pumps a new `since` after the first escalation and expects a second escalation at 8 s, and no third after 5 more minutes. This covers existing behaviour, so there is no failing-first run. |

## 2. Builds

- Branch `revamp/kit-KitSince`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (the `feat/phone-setup-v2` tip, unchanged since branch time), code head
  `8cf54c63`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof belongs to the
coordinator's wave checkpoint (R19, R20).

## 4. Runs

Every run used the pinned Flutter through `tool/qa/machine_lock.sh`, with
`flutter gen-l10n` run locally first (its output is not committed).

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: "changing only ticks mid-wait still turns slow at exactly 8 s" with `kit_since.dart` at the round-1 head (fix reverted) | fails with an assertion | failed: `Expected: KitSincePhase.slow, Actual: KitSincePhase.waiting` at 8.0 s (`failing-first.txt`) | PASS |
| 2 | Fixes only: "the labels format their numbers with intl for the locale" with the round-1 ARB placeholders (no `format`, gen-l10n rerun) | fails with an assertion | failed: `Expected: 'Waiting 1,234 min', Actual: 'Waiting 1234 min'` (`failing-first.txt`) | PASS |
| 3 | `test/kit/kit_since_test.dart` (17 tests covering the spec's 11 items) | passes | 17 passed | PASS |
| 4 | `test/goldens/kit/kit_since_golden_test.dart` against the committed goldens, before regenerating | the 18 round-1 shots pass; the 4 new sizes have no golden yet | 18 passed, 4 failed (no `slow_800x1280` or `slow_1600x1000` file) | PASS |
| 5 | The same file with `--update-goldens --name 'slow · (800x1280\|1600x1000)'`, then a clean re-run of the whole file | 4 new PNGs are written and looked at; all 22 shots pass | 4 written and reviewed; 22 passed | PASS |
| 6 | `test/l10n_coverage_test.dart` and `test/kit_ratchet_test.dart` (G16 and the §18 ratchets) | pass | 34 passed | PASS |
| 7 | `test/design_standard_test.dart` and `test/golden_harness_test.dart` (G23 golden names) | pass | 23 passed | PASS |
| 8 | `test/kit/kit_manifest_test.dart` (gate G4) | only the integrator's steps and checker gaps remain | 4 violations: `exported`, `docRow`, `states` (onEscalated heuristic) and `gallery` (text2 and ar shots made with `kitGalleryPart` are not detected); `kitGallerySizes` is no longer among the gallery's missing items | FAIL, reported (§1 Contract problems 2) |
| 9 | `flutter analyze` on the three unit files | clean except the flagged `clock` dependency | 3 infos, one per file, all `depend_on_referenced_packages` on `package:clock` | PASS, reported (§1 Contract problems 1) |
| 10 | `dart format --language-version=3.10` on every changed `.dart` file | no diff after formatting | 0 files changed | PASS |

## 5. Evidence

- `failing-first.txt`: the output of runs 1 and 2 (TEST-2), with the
  worktree path stripped.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | Escalation boundary, exactly one rebuild | `test/kit/kit_since_test.dart` "escalates to slow at exactly 8 s, rebuilding once" | run 3, PASS |
  | One timer for `escalateAfter − elapsed`, also after a `ticks` change | `test/kit/kit_since_test.dart` "changing only ticks mid-wait still turns slow at exactly 8 s" | run 1 (fails without the fix), run 3 PASS |
  | A new wait starts over | `test/kit/kit_since_test.dart` "a new since value restarts the wait" | run 3, PASS |
  | `onEscalated` once per `since` value, never for idle | `test/kit/kit_since_test.dart` "onEscalated fires exactly once per since value" and "onEscalated never fires for an idle wait" | run 3, PASS |
  | Minute ticks at 8 s, 60 s and 120 s, and the en and ar labels | `test/kit/kit_since_test.dart` "ticks: minutes rebuilds at 8 s, 60 s and 120 s", "waitingLabel and ageLabel on whole minutes (en)" and "waitingLabel covers the Arabic zero, one, two, few and many forms" | run 3, PASS |
  | Digits from intl for the locale (COPY-30, B17) | `test/kit/kit_since_test.dart` "the labels format their numbers with intl for the locale" | run 2 (fails without the fix), run 3 PASS |
  | Disposal cancels the timer | `test/kit/kit_since_test.dart` "disposing mid-wait leaves no pending timer" | run 3, PASS |
  | Reduced motion, no ticker (G8) | `test/kit/kit_since_test.dart` "reduced motion and Animations: Off keep the same timing, with no ticker (G8)" | run 3, PASS |
  | Resuming recomputes from wall time | `test/kit/kit_since_test.dart` "resuming after backgrounded time recomputes the phase even with the timer suppressed" | run 3, PASS |
  | Galleries at the §8.4 sizes, DPR 3, fake clock | `test/goldens/kit/kit_since_golden_test.dart` (22 shots) | run 5, PASS |

- Changed test expectations (TEST-19): none. No existing test outside this
  unit was touched; this unit's own test 5 gained assertions.
- Goldens (all new to the branch; each opened and looked at):
  - `kit_since_connecting_{dark,light}.png`: waiting, "Connecting…", 412×915.
  - `kit_since_slow_{dark,light}.png` and the `_360x800`, `_800x1280`,
    `_1280x800` and `_1600x1000` sizes: slow, "Still waiting after 8 s",
    `KitText` secondary, centred in the gallery's 720 dp column. The four
    round-2 images (`_800x1280` and `_1600x1000`, both themes) show the same
    line as the other sizes, with no clipping and correct contrast in each
    theme.
  - `kit_since_minutes_{dark,light}.png`, `_text2_…` (2.0 text, "Waiting 4 min",
    no overflow) and `_ar_…` (Arabic, right-aligned Noto Sans Arabic,
    "جارٍ الانتظار منذ 4 دقائق", the "few" plural form), at 412×915 and
    1280×800. These are unchanged from round 1 (run 4 matched them before
    any regeneration): the intl format keeps Latin digits for `ar`.
  - No approved VL canvas render exists for this part (EVID-12: none,
    because KitSince.md is the frozen spec and predates canvas renders).
- Before and after: n/a. This is a new part with no earlier golden or census
  page (EVID-10).
- Accessibility: no semantics added. The spec says the part "adds no
  semantics and announces nothing"; the host's live region announces the
  slow transition. There are no touch targets because the part draws
  nothing. The gallery's G5 checks in `kitGalleryPart` (tap-target, labelled
  tap-target, text-contrast and reading-order guidelines) ran and passed
  for all 22 shots in both themes.
- Privacy and security: n/a. No credentials, stored data, external links or
  notifications are involved.
- Migration: n/a. No stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n   # local only; never commit lib/l10n/app_localizations*.dart
$F test -j 1 test/kit/kit_since_test.dart
$F test -j 1 test/goldens/kit/kit_since_golden_test.dart
$F test -j 1 test/l10n_coverage_test.dart test/kit_ratchet_test.dart
$F test -j 1 test/design_standard_test.dart test/golden_harness_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart   # expected: the 4 reported G4 violations
$F analyze lib/ui/kit/kit_since.dart test/kit/kit_since_test.dart test/goldens/kit/kit_since_golden_test.dart
git checkout b67e3276 -- lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_ar.dart
```

## 7. NOT proven

- Not run on a device or emulator. No screen or call site uses `KitSince`
  yet, so the running app cannot reach it until a later unit adds a call
  site.
- `flutter analyze` was not run on the whole `lib/` and `test/` tree from
  this worktree. It was run on this unit's three files, which carry the
  expected `clock` info, one per file.
- `test/kit/kit_manifest_test.dart` (gate G4) does not pass for `KitSince`;
  see §1 Contract problems 2. The failures were not worked around.
- Without a local `flutter gen-l10n`, this branch does not compile, because
  the generated l10n output is deliberately not committed. The integrator
  regenerates it after the merge (PROC-13).
- No approved visual-language canvas render exists to compare the goldens
  against.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitSince` |
| Enabled | No: not exported from `lib/ui/kit/kit.dart`, and no call site uses it yet | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `8cf54c63` |
| Deployed | No | |
| Released | No | |
