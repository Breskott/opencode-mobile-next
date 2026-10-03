# revamp-kit-KitScenes-v2: Kit scenes and illustration on theme roles (2026-09-26)

Build round (code head `0da97961`) plus one review-fix round (code head
`0c53fc8d`, 2026-09-27 local). The fix round reuses this folder (EVID-1).

## 1. Scope

- Unit: `kit-KitScenes-v2` (wave 1, tier 1a, kind `kit-change`). Finish line: every
  colour a scene or `KitIllustration` paints comes from `ThemeRoles` via one
  mapping (`KitPalette.fromRoles`), no scene reaches for the attention amber or a
  failure red, every wash stays at or under `KitTokens.sceneWashAlpha`, and a
  scene that shows progress along a line mirrors under RTL.
  Non-goal: no new scene, no redrawn geometry, no host changes (widths,
  placement, which states get a drawing stay with the hosts' own units).
- Files changed (build round, `b67e3276..0da97961`):
  - `lib/ui/kit/kit_illustration.dart`: `KitPalette.fromRoles(ThemeRoles)` (the
    one mapping); `KitPalette.of` delegates to it; `KitScene.mirrorsInRtl`
    (default false); `KitDraw.wash`; `KitIllustration`/`_ScenePainter` flip a
    mirrored scene horizontally under RTL.
  - `lib/ui/kit/scenes/setup_unplugged_scene.dart`: the gap's marks paint
    `muted`, not `warning`.
  - `lib/ui/kit/scenes/setup_steps_scene.dart`,
    `lib/ui/kit/scenes/servers_link_scene.dart`,
    `lib/ui/kit/scenes/team_discover_scenes.dart`: `mirrorsInRtl => true`.
  - `test/kit/kit_scenes_test.dart` (new).
  - `test/goldens/kit/kit_scenes_golden_test.dart` (new), plus 30 PNGs.
  - Regenerated: `test/goldens/kit_setup_*.png`, `kit_folders_open_*.png`,
    `servers_scene_*.png`, `states_*.png`, `team_scene_*.png`,
    `team_discover_scene_*.png`.
- Files changed (fix round, `bd49124e..0c53fc8d`):
  - `lib/ui/kit/scenes/setup_steps_scene.dart:107`,
    `lib/ui/kit/scenes/setup_unplugged_scene.dart:49`,
    `lib/ui/kit/scenes/setup_phone_scene.dart:79`: the three neutral washes
    (halted step strip, unplugged portal, stopped phone) fill with
    `KitDraw.fade(line, KitTokens.sceneWashAlpha * t)`. They were `line` at
    50 %, 35 % and 35 %. No geometry changed.
  - `lib/ui/kit/kit_illustration.dart`: `this.width = KitTokens.illustrationPage`
    (same value, 160).
  - `test/kit/kit_scenes_test.dart`:
    - `_sameHue` compares 8-bit channels. Before, it compared exact 64-bit
      channels, and a `Paint` keeps its colour in 32-bit floats, so it never
      matched a painted colour and groups 2 and 3 could not fail
      (`failing-first.txt` §B).
    - Group 3 holds every translucent fill larger than a mark, in any role,
      at or under `sceneWashAlpha`. A mark fits in a square of four strokes
      (20 scene units): dots, sparkles, the moon.
    - Group 3 now runs at the finished frame and at two points of the breath.
    - Groups 2 and 3 now also scan the failed, halted and stopped variants,
      including `SetupStepsScene(install, halted: failed)` and
      `SetupPhoneScene(stopped)`.
    - Adds a test that the hue check matches a painted role.
  - `test/goldens/kit/kit_scenes_golden_test.dart`:
    - The default page is built from `KitText` and `KitButton.primary`, with
      `KitTokens` spacing (`gutter`, `space2`/`space5`/`space6`).
    - It is laid out from the start edge.
    - It has an en/ar `_Copy` pair.
    - The contact sheets' gap is `KitTokens.space4`.
  - Regenerated (looked at, §5):
    - `kit_setup_{steps_failed,steps_paused,stopped,unplugged}_{dark,light}`;
    - `kit/kit_scenes_setup_{dark,light}`;
    - the 14 `kit/kit_scenes_default_*` shots;
    - `folder_browser_empty_{dark,light}`.
- Mirrors (KitScenes.md "mirrorsInRtl", all 24 reviewed):
  - mirrors: `SetupStepsScene`, `ServersLinkScene`, `TeamDiscoverRelayScene`;
  - no mirror (pictures): the other 21.
- Pages (map ids): none. This is a kit-only part change with no host page
  in its write set (KitScenes.md "Map element (not built here)").
- Specs followed:
  - `docs/ux-system/kit-api/KitScenes.md` (frozen, wave 0);
  - design-standard §10; visual-language §7;
  - STANDARDS.md rules LOOK-1, LOOK-2, LOOK-4, LOOK-5, LOOK-6, LOOK-35–38,
    KIT-9, KIT-43, MOT-6, MOT-7, MOT-9, TEST-14, LAY-8, PROC-10, R07;
  - cut review C19 (recount) and C21 (e) (radius exemption).
- Contract problems (PROC-20). None of them blocks.
  1. **KitScenes.md, "Galleries required", Default sizes.**
     - The spec says "at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000".
     - Why it is wrong: 915×412 is a landscape phone. The shared helper
       `kitGallerySizes` (`test/goldens/kit/kit_gallery.dart:105`, LAY-4)
       renders 412×915, and every kit gallery uses that helper.
     - What the unit did: rendered 412×915 (`kit_scenes_default_{dark,light}.png`,
       size left out of the name per TEST-20). The 30-PNG count still holds.
     - Proposed text: "at 360×800, 412×915, 800×1280, 1280×800 and 1600×1000".
     - Blocks: false.
  2. **KitScenes.md, "Tests required" 3.**
     - The spec says "every fill in the accent hue has alpha ≤ 0.12 (LOOK-36)".
     - Why it is wrong, point 1: read literally, the rule also catches the
       drawings' half-toned accent marks. These are detail, not washes:
       - sparkles at 55–80 % in `SetupPhoneScene` and `SetupReadyScene`;
       - dots at 35–55 % in `StatesSheetScene` and `StatesFolderScene`;
       - dots at 45 % in `SetupPhoneScene(starting)`, while looping;
       - a 25–50 % dot in `SetupUnpluggedScene`, while looping.
     - Why it is wrong, point 2: it misses neutral washes, which is what the
       review found.
     - Why it is wrong, point 3: the build round's test passed only because
       its hue check never matched a painted colour.
     - What the unit did: implemented the reviewer's reading. Every
       translucent fill larger than a mark, in any role, is at or under
       `KitTokens.sceneWashAlpha`. A mark fits inside a square of
       4 × `KitDraw.stroke` (20 scene units) and may be half-toned.
       See `test/kit/kit_scenes_test.dart:200`, group 3 at :355.
     - Proposed text: "every translucent fill larger than a mark (a square
       of four strokes), in any role, has alpha ≤ `KitTokens.sceneWashAlpha`;
       marks (dots, sparkles) may be half-toned like a faded stroke (LOOK-36)".
     - Blocks: false.
  3. **KitScenes.md, Tokens table, `line` row.**
     - The spec says "hairlines and quiet detail, opaque; faded only by
       `KitDraw.fade` in strokes".
     - Why it is wrong: three scenes use `line` as a neutral wash fill.
       Solid `line` dots already exist at `team_discover_scenes.dart:142`,
       `states_scenes.dart:373` and `servers_link_scene.dart:127`.
     - What the unit did: v2 keeps the three washes and fades them only
       through `KitDraw.fade`, to `sceneWashAlpha`.
     - Proposed text: "…; faded only by `KitDraw.fade`: in strokes, or as a
       neutral wash at no more than `KitTokens.sceneWashAlpha`".
     - Blocks: false.
  4. **Harness task text vs STANDARDS.md EVID-1.**
     - The task names `docs/qa/revamp-<unit id>/README.md`.
     - EVID-1, and STANDARDS.md's conflict table row 14 ("owner rule wins"),
       name `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`, which the fix round
       must reuse.
     - What the unit did: followed STANDARDS.md and reused this folder.
     - Blocks: false.
- New kit parts (KIT-3): none.
  - `KitDraw.wash` and `KitScene.mirrorsInRtl` are the spec's NEW members
    (KIT-43).
  - The fix round adds no API. The neutral washes use the existing
    `KitDraw.fade` with the existing `KitTokens.sceneWashAlpha`.
- Map items (EVID-11): none. KitScenes.md's one map element
  (`termux-setup-connect-termux#guide-illustrations`) is "not built here".
- States per page (STATE-20): n/a, because this write set has no host page.
  - `KitIllustration`'s own states (entrance, finished, ambient, reduced) are
    documented on the class (KIT-12).
  - They are covered by `test/kit_illustration_test.dart` and
    `test/kit/kit_scenes_test.dart` group 6.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitScenes-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`.
- Code head: `0c53fc8dae2470dfb90a34c625c8fe93190dee2b` (fix round). The build
  round's code head was `0da979619eb177a9487a594223bbc33b1ddc252e`, and its
  record commit was `bd49124e`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

All runs used the pinned Flutter 3.47.1, `-j 1`, through `tool/qa/machine_lock.sh`.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Recount `BorderRadius`/`Radius.circular`/`colorScheme`/`Color(0x`/`Colors.` in `kit_illustration.dart` + `lib/ui/kit/scenes/*.dart` on the base | 39 / 1 / 0 / 0 (the frozen spec) | 39 / 1 / 0 / 0 | PASS |
| 2 | Same recount at `0c53fc8d` | 39 radius lines (drawing geometry, exempt C21 (e)) / 0 / 0 / 0 | 39 / 0 / 0 / 0 | PASS |
| 3 | Build round: `test/servers_scenes_test.dart test/setup_scenes_test.dart test/kit_states_scenes_test.dart` before regenerating | only golden pixel diffs | only `Pixel test failed` diffs | PASS (expected) |
| 4 | Build round: `test/kit/kit_scenes_test.dart` | passes | 163 passed (groups 2 and 3 vacuous, see row 5) | PASS at the time; superseded by row 7 |
| 5 | Fix round, fix first: the new `test/kit/kit_scenes_test.dart` on `bd49124e`, before the scene fix | group 3 fails on the three neutral washes | 170 passed / 15 failed, all group 3 rows: stopped phone, unplugged, steps halted failed/paused/install-failed, × 3 packs (`failing-first.txt` §A) | PASS |
| 6 | Fix round: the old `_sameHue` with the new "not vacuous" test | fails (the old check never matches paint) | failed: `Expected: true, Actual: <false>` (`failing-first.txt` §B) | PASS |
| 7 | `test/kit/kit_scenes_test.dart` after the fix | all pass | 185 passed | PASS |
| 8 | `test/setup_scenes_test.dart` after the fix, no update | only the 4 changed pairs fail | exactly `kit_setup_{steps_failed,steps_paused,stopped,unplugged}_{dark,light}` failed | PASS (expected) |
| 9 | `--update-goldens test/setup_scenes_test.dart`, looked at every changed PNG | all pass | 29 passed | PASS |
| 10 | `--update-goldens test/goldens/kit/kit_scenes_golden_test.dart`, looked at every changed PNG | 30 pass; Arabic default shots differ from LTR | 30 passed; `kit_scenes_default_ar_dark` md5 `4ab997f5…` vs `kit_scenes_default_dark` `26663efa…`; `_ar_1280x800_dark` `a9c56b08…` vs `_1280x800_dark` `db5dd206…` | PASS |
| 11 | `test/goldens/folder_browser_golden_test.dart`, no update | only `folder_browser_empty_*` fail (stale since the build round) | 12 passed / 2 failed, exactly those two | PASS (expected) |
| 12 | `--update-goldens test/goldens/folder_browser_golden_test.dart`, looked at both PNGs | all pass; only the folder's front fill changes | 14 passed; diff bbox (30,609)–(90,634) in both, the front fill only | PASS |
| 13 | `test/motion_setup_test.dart test/kit_illustration_test.dart` | pass | 24 passed | PASS |
| 14 | `test/golden_harness_test.dart test/goldens/kit/kit_gallery_g5_test.dart` (G23, G5) | pass | 23 passed | PASS |
| 15 | `test/kit_ratchet_test.dart test/design_standard_test.dart` | pass | 47 passed | PASS |
| 16 | `test/kit/kit_manifest_test.dart test/phone_setup_ready_screen_test.dart` | pass | 16 passed | PASS |
| 17 | `test/servers_scenes_test.dart test/kit_states_scenes_test.dart` | pass | 32 passed | PASS |
| 18 | `test/goldens/team_scenes_golden_test.dart test/goldens/team_discover_scenes_golden_test.dart` | pass | 18 passed | PASS |
| 19 | `test/motion_states_test.dart test/team_motion_test.dart` | pass | 28 passed | PASS |
| 20 | `flutter analyze lib test` | no issues | No issues found | PASS |
| 21 | Shared screen goldens outside the write set that embed a scene, run on `0c53fc8d` (each file alone, PNGs not updated) | list what this unit breaks for the integrator | 10 files fail, 82 PNGs (listed in §7); `team_agent`, `team_sheets`, `theme_gallery` pass | PASS (list produced) |
| 22 | Base check: `test/goldens/team_board_golden_test.dart test/goldens/chat_states_golden_test.dart` with `lib/ui/kit/kit_illustration.dart` + `lib/ui/kit/scenes/` at base `b67e3276`, then restored to HEAD | pass on the base scenes (so row 21's failures are this unit's) | 46 passed | PASS |

## 5. Evidence

- `failing-first.txt`: rows 5 and 6.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | LOOK-1, LOOK-2 | `test/kit/kit_scenes_test.dart` "4. Theme only" | row 7 |
  | LOOK-4 | `test/kit/kit_scenes_test.dart` "2. No red, no amber"; allowlist test | row 7: no scene or variant paints `roles.attention`'s hue, and the hue check is proven to see paint (row 6) |
  | LOOK-5 | same group, `ServersLinkScene(failed)` and `SetupStepsScene(halted: …)` variants | row 7 |
  | LOOK-36 | `test/kit/kit_scenes_test.dart` "3. Flat, light fills" | row 5 (fails before), row 7 (passes after): no Shader, MaskFilter, ImageFilter or shadow; every translucent fill larger than a mark, in any role, ≤ 0.12 at the finished frame and mid-breath |
  | LAY-8 | `test/kit/kit_scenes_test.dart` "5. Mirror"; `kit_scenes_mirrored_ar*`, `kit_scenes_default_ar*` goldens | rows 7, 10 |
  | MOT-6, MOT-7 | `test/kit/kit_scenes_test.dart` "6. Still" | row 7 |
  | KIT-43 | `test/kit/kit_scenes_test.dart` "1. Mapping" | row 7 |
  | TEST-14 | `test/goldens/kit/kit_scenes_golden_test.dart` | row 10 |
  | G23 (TEST-7/8/9/20, ARCH-11), G5 | `test/golden_harness_test.dart`, `test/goldens/kit/kit_gallery_g5_test.dart` | row 14 |

- Changed test expectations (TEST-19):
  - `test/kit/kit_scenes_test.dart` group 3 changed in two ways:
    - old: accent-hue fills below 1.0 alpha must be ≤ 0.12, over the 24
      default scenes, at the finished frame;
    - new: every translucent fill larger than a mark, in any role, must be
      ≤ `sceneWashAlpha`, over the scenes plus the failed, halted and stopped
      variants, at the finished frame and two points of the breath (LOOK-36).
  - `_sameHue` changed from exact 64-bit equality to 8-bit channel equality
    (LOOK-4, LOOK-5, LOOK-36). The old check could not fail.
- Goldens changed in the fix round (each opened and looked at):
  - `test/goldens/kit_setup_{steps_failed,steps_paused,stopped,unplugged}_{dark,light}.png`:
    - the neutral wash disc (and the halted strip's screen wash) is quiet
      again;
    - measured disc colours are below;
    - `wash-before-after-{dark,light}.png` shows each shot in three columns:
      base (pre-v2) | v2 as reviewed | fixed.

    | Shot | base | reviewed | fixed |
    |---|---|---|---|
    | `steps_failed_dark` / `steps_paused_dark` | (24,25,27) | (74,76,81) | (26,27,30) |
    | `steps_failed_light` / `steps_paused_light` | (239,239,238) | (171,172,175) | (226,226,225) |
    | `stopped_dark` / `unplugged_dark` | (20,21,23) | (55,57,61) | (26,27,30) |
    | `stopped_light` / `unplugged_light` | (240,240,239) | (192,193,194) | (226,226,225) |

  - `test/goldens/kit/kit_scenes_setup_{dark,light}.png`: the unplugged
    portal's disc and the halted strip's cloud disc are the quiet neutral
    wash.
  - `test/goldens/kit/kit_scenes_default_*` (the 14 default-page shots):
    - `KitPortalScene` sits at the start edge, above a `KitText.title`
      ("No projects yet"), a secondary `KitText` line and a full-width
      `KitButton.primary` ("Open a project"), spaced with `KitTokens`;
    - the Arabic shots show the page mirrored, with Arabic words and
      `studio-pc` kept in order inside the Arabic line
      (`default-page-en-ar.png`);
    - the portal itself does not mirror (`mirrorsInRtl` false);
    - at 2.0 text the body wraps to three lines and the button stays on
      screen.
  - `test/goldens/folder_browser_empty_{dark,light}.png`:
    - only the open folder's front fill changed: surface3 under the
      accent at 12 %, where it was `surfaceContainerHigh` under the primary
      at 16 %;
    - dark (37,64,54) → (41,62,56); light (215,235,225) → (206,220,210);
    - `folder-browser-empty-before-after.png`.

    The build round left these two stale for the integrator. The golden-owner
    table (`docs/ux-system/revamp/work-units.json` →
    `goldenOwners.byTest["test/goldens/folder_browser_golden_test.dart"]` =
    `{"wave 1 tier 1": "kit-KitScenes-v2", "wave 2a": "shared-work-1"}`)
    makes this file this unit's golden in wave 1 tier 1. So R07 and PROC-10
    ("a golden is its own when its golden test file is its own") let the
    unit regenerate them, and it did.
  - No approved VL canvas render exists for any of these shots (EVID-12: n/a).
- Before and after: n/a for a host page (EVID-10), because no host page is
  in this unit. For the scene-level fixes, the three-column
  `wash-before-after-*.png` and `folder-browser-empty-before-after.png`
  serve.
- Accessibility:
  - `KitIllustration` stays `ExcludeSemantics` by default (unchanged).
  - The default page's shots run the full G5 check inside `kitGalleryPart`:
    tap targets, labelled targets, text contrast and reading order, in both
    themes and in Arabic. All 30 passed with no new baseline entry.
  - `KitButton.primary` keeps its kit target size at 2.0 text.
- Privacy and security: n/a, because no credentials, stored data, links or
  notifications changed.
- Migration: n/a, because no stored format changed.
- Copy: the gallery's en/ar strings are test-only dressing inside the
  gallery file (like `kit_foundation_golden_test.dart`'s `_Copy`). Scenes
  have no words ("Kit copy: none"), so there is no `.arb` change and no
  gen-l10n run.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
L="tool/qa/machine_lock.sh test --"
for f in lib/ui/kit/kit_illustration.dart lib/ui/kit/scenes/*.dart; do
  grep -cE 'BorderRadius|Radius\.circular' "$f"; done | awk '{s+=$1} END {print s}'   # 39
grep -c colorScheme lib/ui/kit/kit_illustration.dart lib/ui/kit/scenes/*.dart   # all 0
$L $F test -j 1 test/kit/kit_scenes_test.dart
$L $F test -j 1 test/setup_scenes_test.dart test/goldens/folder_browser_golden_test.dart
$L $F test -j 1 test/goldens/kit/kit_scenes_golden_test.dart
$L $F test -j 1 test/golden_harness_test.dart test/goldens/kit/kit_gallery_g5_test.dart
$L $F test -j 1 test/kit_illustration_test.dart test/motion_setup_test.dart
$L $F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart
$L $F test -j 1 test/servers_scenes_test.dart test/kit_states_scenes_test.dart
$L $F test -j 1 test/goldens/team_scenes_golden_test.dart test/goldens/team_discover_scenes_golden_test.dart
$L $F test -j 1 test/motion_states_test.dart test/team_motion_test.dart
$L $F test -j 1 test/kit/kit_manifest_test.dart test/phone_setup_ready_screen_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator (kit-only unit; on-device proof is
  coordinator work, R19/R20).
- The full serial suite was not run (PROC-6). Only the files in §4 were run.
- **Shared screen goldens this unit breaks.** The integrator regenerates
  these after the merge (R07, PROC-10).
  - All are pixel diffs where a scene sits inside a screen outside this
    write set.
  - Row 22 shows two of the files passing on the base scenes.
  - The screen census PNGs under `docs/qa/screen-census/` that show a scene
    will shift the same way (integrator-owned).

  | Test file | Failing goldens |
  |---|---|
  | `test/goldens/phone_setup_golden_test.dart` | 20: `setup_customize`, `setup_progress_failed`, `setup_progress_log`, `setup_progress_running`, `setup_ready`, `setup_start`, `setup_start_progress`, `setup_start_ready`, `setup_start_stopped`, `setup_start_termux`, each `_dark`/`_light` |
  | `test/goldens/servers_motion_golden_test.dart` | 16: `add_server_codex`, `add_server_failed`, `add_server_manual`, `add_server_paired`, `add_server_paseo`, `add_server_testing`, `first_run_connect`, `servers_welcome`, each `_dark`/`_light` |
  | `test/goldens/team_golden_test.dart` | 14: `team_card_idle`, `team_home_empty`, `team_home_loaded`, `team_home_loaded_phone`, `team_home_starting`, `team_run_merged`, `team_run_overview`, each `_dark`/`_light` |
  | `test/goldens/work_tab_golden_test.dart` | 10: `connection_not_answering`, `connection_starting`, `connection_stopped`, `work_chooser`, `work_empty`, each `_dark`/`_light` |
  | `test/goldens/team_discover_golden_test.dart` | 6: `team_discover_work`, `team_intro_computer`, `team_intro_phone`, each `_dark`/`_light` |
  | `test/goldens/phone_server_screens_golden_test.dart` | 4: `phone_running`, `phone_stopped`, each `_dark`/`_light` |
  | `test/goldens/settings_golden_test.dart` | 4: `servers_add`, `servers_add_failed`, each `_dark`/`_light` |
  | `test/goldens/chat_states_golden_test.dart` | 4: `chat_empty`, `chat_load_error`, each `_dark`/`_light` |
  | `test/goldens/team_board_golden_test.dart` | 2: `team_board_empty_dark`, `team_board_empty_light` |
  | `test/goldens/work_parts_golden_test.dart` | 2: `shell_reconnecting_dark`, `shell_reconnecting_light` |

- Golden tests that embed no scene, or were not run: `kit_foundation`,
  `kit_confirm_sheet` and `kit_sheet` (no scenes). Any other test file
  outside this list that renders a scene was not found by
  `grep -l matchesGoldenFile` plus a scene/host filter.
- The mark threshold (20 scene units) is a test-side definition that
  PROC-20 item 2 proposes for the spec. Until the spec adopts it, a
  reviewer may read LOOK-36's "accent fills" more strictly.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitScenes-v2` |
| Enabled | Yes: no flag; `KitPalette.of`/`KitIllustration` are used wherever a host already draws a scene | |
| Verified | Tests and goldens only (§4); not the full suite | this record |
| Committed | Yes | code head `0c53fc8dae2470dfb90a34c625c8fe93190dee2b` |
| Deployed | No | |
| Released | No | |
