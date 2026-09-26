# revamp-kit-KitNeedsYou: KitNeedsYou (2026-09-27)

## 1. Scope

- Unit: `kit-KitNeedsYou` (wave 1, tier 2, kind `kit-part`). Finish line: `KitNeedsYou` exists in `lib/ui/kit/kit_needs_you.dart` with its four builders (`mark`, `span`, `badge`, `row`) and `reasonWord`, matching the frozen API in `docs/ux-system/kit-api/KitNeedsYou.md`, with its behaviour tests and galleries. Non-goal: no call site outside this unit's own tests changes; `lib/ui/kit/kit.dart` is not touched (the integrator adds the export) and no screen migrates to it.
- Files changed: `lib/ui/kit/kit_needs_you.dart` (new), `test/kit/kit_needs_you_test.dart` (new), `test/goldens/kit/kit_needs_you_golden_test.dart` (new) plus its 16 PNGs, and `lib/l10n/app_en.arb` (new `kitNeedsYou*` keys). The generated `lib/l10n/app_localizations*.dart` files are **not** committed (PROC-5/11/13: the integrator owns and regenerates them); they are unchanged from the branch base (`dcf05c5e`), so the branch compiles only after the integrator's `gen-l10n` (locally this unit ran `gen-l10n` into the working tree to test and left the output unstaged).
- Pages (map ids): none — this unit builds the kit part only; the map's `KitNeedsYou` call sites (`activity`, `chat`, `embedded-profile-monitor-inbox`, `home-shell`, `profile-monitor`) are wave-2 migration work per the spec's "Replaces" section.
- Specs followed: `docs/ux-system/kit-api/KitNeedsYou.md` (frozen API); `docs/ux-system/kit-v2.md` §1.21, §4.5, §8.2; `docs/design/visual-language-2026-09-26.md` §3–§7 (tokens only, via `KitTokens`/`ThemeRoles`); STANDARDS.md §1, §15, §16, §17, §18 so far as a wave-1 kit-part builder reads them (§11 applies to this part per §0.4's table).
- Contract problems (PROC-20):
  1. **Arabic/RTL dropped vs. the frozen spec.** `KitNeedsYou.md`'s "Tests required" #2 and #6 and its "Galleries required" section ask for Arabic plural forms, an Arabic-locale bidi golden, and Arabic/RTL variants at every size. The owner decision of 2026-09-27 relayed in this unit's task ("Arabic is DROPPED — no Arabic/RTL galleries, no Arabic ARB entries for new copy, no RTL review") outranks the spec under R15 ("owner decisions dated later win"). Followed the owner decision: `app_ar.arb` was not touched (the generated `AppLocalizationsAr` falls back to the English string for every new key, which `flutter pub get`'s l10n codegen reported as "8 untranslated message(s)" without error); the test file keeps only the direction-neutral half of test #6 (who/server are still bidi-isolated via `KitBidi.auto`, checked without an Arabic locale); test #2 and the galleries are English-only.
  2. **Gallery grid narrowed vs. the frozen spec.** The spec's "Galleries required" section asks for the full kit-v2 §8.4 grid (five sizes, a landscape phone, 2.0 text, Arabic). This unit's task instead says "Galleries: phone 412x915 and one wide size (1280x800) only, light and dark." Followed the task's narrower grid (16 shots: 4 declared-state scenes × 2 sizes × 2 themes) and recorded the gap here rather than silently building the larger grid or silently dropping to the narrow one without saying so.
  3. **QA folder name vs. EVID-1.** STANDARDS.md EVID-1 names the folder `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`; this unit's own task instructions say "Write docs/qa/revamp-<unit id>/README.md" (no date). Followed the literal task instruction (this file's path has no date suffix) and record the mismatch here per the task's own "stop and report; do not work around it" rule. UTC date of the first build commit: 2026-09-26 (local clock read 2026-09-27; `date -u` on the build machine read 2026-09-26).
  4. **Badge at count 0 (review fix, recorded for PROC-20).** The spec says `count <= 0 returns [child] unchanged` and also asks for a fade-out on `KitMotion.standard` when the badge disappears; the two conflict for the few frames of the fade. Resolution, within the spec: at `count <= 0` with no fade-out running the build is `child` alone, in a `KeyedSubtree` with a `GlobalKey` (no render object, no semantics node, and the host's element and state survive the badge coming and going). The `MergeSemantics`/`Stack`/`PositionedDirectional` wrapper exists only while a count is shown or fading out. Proposed spec text: "count <= 0 returns [child] unchanged once any fade-out has finished; during the fade the host's semantics already lack the count suffix."
- New kit parts (KIT-3): `KitNeedsYou` (abstract final class of static builders) and `KitNeedsYouReason` (enum) in `lib/ui/kit/kit_needs_you.dart`. Depends on `KitTaskMark`/`KitTaskState` (already carries the `needsYou` state and its "Needs you" word), `KitRow`, `KitSince`, `KitBidi`, `KitText`, `KitTokens` (all already merged on `feat/phone-setup-v2`).
- Map items (EVID-11): none — no page's map record is touched by this unit.
- States per page: n/a — no page. The part's own states (per its "States" table): `mark` (one state), `span` (count 1 / count > 1), `badge` (hidden / a number / "99+"), `row` (waiting, with `since` age; pressed/hovered via `KitRow`; no answered/disabled state — see the spec) are each covered by a behaviour test (see §4).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitNeedsYou`, base `e60218d50d17aa47223e5f12bbfabb1f5c94d911` (`feat/phone-setup-v2`), code head: this unit's own commit on top of base (see `git log revamp/kit-KitNeedsYou`).
- No APK (unit agents do not build; R19/R20 reserve on-device proof for the coordinator).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `$F analyze lib/ui/kit/kit_needs_you.dart test/kit/kit_needs_you_test.dart test/goldens/kit/kit_needs_you_golden_test.dart` | no errors; the one pre-existing `clock`-package info (same pattern as `kit_since_golden_test.dart`/`kit_since.dart`) only | exactly that one info, no other issues | PASS |
| 2 | `$F analyze lib/ui/kit` (whole kit directory) | no new errors/warnings | clean except the same pre-existing `clock` info in `kit_since.dart` | PASS |
| 3 | `$F test -j 1 test/kit/kit_needs_you_test.dart` | all pass | 18 passed (after the review fixes; the 4 new tests — count 0 unchanged, fade-out then bare child, 2.0 text pill, spoken age — were run against the pre-fix source first and all 4 failed) | PASS |
| 4 | `$F test -j 1 test/goldens/kit/kit_needs_you_golden_test.dart` | all pass, G5 accessibility checks included | 16 passed; badges and row shots regenerated after the review fixes (KitDivider, KitIcon/KitRowIcon hosts, " · "-joined age) | PASS |
| 5 | Every changed golden opened and looked at | matches the intended look | looked at `kit_needs_you_marks_dark.png`, `kit_needs_you_badges_dark.png`, `kit_needs_you_badges_1280x800_light.png`, `kit_needs_you_row_dark.png`, `kit_needs_you_row_light.png`, `kit_needs_you_reasons_dark.png` — all as intended (see §5) | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + name) | Result |
  |---|---|---|
  | §2.9/K2 §1.21 (`mark`) | `kit_needs_you_test.dart` "mark(): KitTaskMark(state: needsYou), semantics \"Needs you\"" | PASS |
  | K2 §1.21 (`span`), COPY-1 plural | `kit_needs_you_test.dart` "span(): \"Needs you · \" at 1, \"3 need you · \" at 3, attention tone" | PASS |
  | K2 §1.21 (`badge`), A11Y-8 clamp | `kit_needs_you_test.dart` "badge() count 0/5/120 …" (3 tests) | PASS |
  | §1.21 host label merge | `kit_needs_you_test.dart` "badge() count 5: shows \"5\", host label ends \", 5 need you\"" | PASS |
  | MOT-2 (never scales) | `kit_needs_you_test.dart` "a count change cross-fades on quick, never scales" | PASS |
  | G8/MOT-7 (reduced motion) | `kit_needs_you_test.dart` "under reduced motion a badge change settles after one pump" | PASS |
  | LOOK-24/AUTO-17 (`row` never answers) | `kit_needs_you_test.dart` "row() tapping calls onOpen once; no answer actions or menu" | PASS |
  | A11Y-1 one button node | `kit_needs_you_test.dart` "row() semantics: one button node with the reason word and ifIgnored" | PASS |
  | COPY-30 bidi isolation (English-only, see contract problem 1) | `kit_needs_you_test.dart` "row() who and server are bidi-isolated in the composed text" | PASS |
  | G37 (`ifIgnored` required, non-empty) | `kit_needs_you_test.dart` "row() an empty ifIgnored asserts (G37)" | PASS |
  | LOOK-24 (no row menu) | `kit_needs_you_test.dart` "row() right-click opens no menu and is not an open" (no `KitRowMenu`, no `KitMenuPanel`, no route pushed, `onOpen` not called) and "row() long-press opens no menu" | PASS |
  | K2 §1.21 badge `count <= 0` returns the child | `kit_needs_you_test.dart` "badge() count 0: the child unchanged, no badge in the tree" (semantics label/flags/actions and rect equal the bare host's) and "badge() dropping to 0 fades out, then leaves the child alone and keeps its element" | PASS |
  | A11Y-8 clamp, "the badge pill grows to fit" at 200 % text | `kit_needs_you_test.dart` "badge() at text scale 2.0 the pill grows to its clamped text" | PASS |
  | Accessibility "waiting 4 minutes" (unabbreviated), no "min." run-on | `kit_needs_you_test.dart` "row() the age: \"waiting 4 minutes\" spoken, \"· \" joined on screen" | PASS |
  | G14x keyboard | `kit_needs_you_test.dart` "row() keyboard: Tab reaches the row, Enter calls onOpen" | PASS |
  | `reasonWord` wording | `kit_needs_you_test.dart` "reasonWord() the three reason words" | PASS |
  | G4/G5 galleries | `kit_needs_you_golden_test.dart` (16 shots) | PASS |

- Changed test expectations (TEST-19): none — every test in this unit's write set is new.
- Goldens changed (each opened and looked at):
  - `test/goldens/kit/kit_needs_you_marks_{dark,light}.png` (+1280×800 variants): the mark and the span together in a short `KitRow` list. No approved VL canvas render exists for this new part (EVID-12: none).
  - `test/goldens/kit/kit_needs_you_badges_{dark,light}.png` (+1280×800): the badge at 0/3/99+ on a dock-tab stub, a top-bar pill stub and a server row. None.
  - `test/goldens/kit/kit_needs_you_row_{dark,light}.png` (+1280×800): the pointing row, a short row and a 2-line-title row, plus a third row demonstrating the `since` "waiting …" clause (first render was regenerated once after the first pass showed the first sample's supporting line ellipsizing before `ifIgnored` — the sample was shortened to a realistic length rather than the part being changed; see the "Changed test expectations" note above does not apply since this is a fixture change, not a test-expectation change). None.
  - `test/goldens/kit/kit_needs_you_reasons_{dark,light}.png` (+1280×800): the three reason words beside their enum name. None.
- Before and after: n/a — this is a new part with no prior golden or census page (EVID-10 "no before render", page id: none, since no page is touched).
- Accessibility: every gallery shot runs G5 (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`, reading-order) in both themes via `kitGalleryPart`, with zero baseline entries added to `test/goldens/kit/kit_gallery_g5_baseline.json` (that file was not touched). The row's tap target is `KitTokens.rowHeightTwoLine` (60), above the 48 dp minimum. 200%-text and Arabic-locale galleries were not built for this wave (see contract problem 1); the badge's clamp at `KitTokens.badgeTextScaleMax` with a pill that grows to fit is covered by a behaviour test at text scale 2.0 (no golden). The row's spoken label uses the unabbreviated age (`kitNeedsYouWaitingSpoken`, ICU plural: "waiting 4 minutes"); the visible line keeps KitSince's "4 min" and joins every run with " · ".
- Privacy and security: n/a — no credentials, stored data, external links or notifications are touched.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_needs_you_test.dart
$F test -j 1 test/goldens/kit/kit_needs_you_golden_test.dart
$F analyze lib/ui/kit/kit_needs_you.dart test/kit/kit_needs_you_test.dart test/goldens/kit/kit_needs_you_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: on-device proof is coordinator work).
- Arabic and RTL are not proven for this part this wave (owner decision 2026-09-27; contract problem 1).
- The 2.0-text and the landscape-phone/tablet/large-PC galleries the frozen spec's §8.4 grid asks for are not built this wave (contract problem 2); only 412×915 and 1280×800, light and dark, are.
- No call site was migrated (the map's `KitNeedsYou` pages listed in the spec's "Replaces" section are wave-2/3 work); this unit only proves the part in isolation.
- `test/kit_ratchet_test.dart`, `test/design_standard_test.dart`, `test/l10n_coverage_test.dart` and the full `flutter test` suite were not run for this record (STANDARDS.md §0.4 wave-1 kit-part scope plus this unit's own timebox); nothing in this unit's write set should affect them since `kit.dart`, the ratchet baseline and the l10n coverage baseline were not touched.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitNeedsYou` |
| Enabled | No: not exported from `kit.dart` yet (integrator work, R06) | |
| Verified | Partial: unit tests and galleries only, no device run | |
| Committed | Yes (local, this branch) | |
| Deployed | No | |
| Released | No | |
