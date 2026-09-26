# revamp-kit-KitScenes-v2: Kit scenes and illustration on theme roles (2026-09-26)

## 1. Scope

- Unit: `kit-KitScenes-v2` (wave 1, tier 1a, kind `kit-change`). Finish line: every
  colour a scene or `KitIllustration` paints comes from `ThemeRoles` via one
  mapping (`KitPalette.fromRoles`), no scene reaches for the attention amber or a
  failure red, and a scene that shows progress along a line mirrors under RTL.
  Non-goal: no new scene, no redrawn geometry, no host changes (widths,
  placement, which states get a drawing stay with the hosts' own units).
- Files changed:
  - `lib/ui/kit/kit_illustration.dart` — `KitPalette.fromRoles(ThemeRoles)` (the
    one mapping), `KitPalette.of` delegates to it, `KitScene.mirrorsInRtl`
    (default false), `KitDraw.wash`, `KitIllustration`/`_ScenePainter` flip a
    mirrored scene horizontally under RTL.
  - `lib/ui/kit/scenes/setup_unplugged_scene.dart` — the gap's marks paint
    `muted`, not `warning`.
  - `lib/ui/kit/scenes/setup_steps_scene.dart`,
    `lib/ui/kit/scenes/servers_link_scene.dart`,
    `lib/ui/kit/scenes/team_discover_scenes.dart` — `mirrorsInRtl => true`
    (the step strip, the phone-to-computer link, the relay).
  - `test/kit/kit_scenes_test.dart` (new).
  - `test/goldens/kit/kit_scenes_golden_test.dart` (new) + 30 PNGs.
  - Regenerated (looked at, listed in §5): `test/goldens/kit_setup_*.png`,
    `test/goldens/kit_folders_open_*.png`, `test/goldens/servers_scene_*.png`,
    `test/goldens/states_*.png`, `test/goldens/team_scene_*.png`,
    `test/goldens/team_discover_scene_*.png`.
  - `lib/ui/kit/scenes/{folders_open_scene,portal_scene,servers_cast,
    setup_cast,setup_phone_scene,setup_ready_scene,states_parts,
    states_scenes,states_working_scene,team_scenes,servers_welcome_scene}.dart`
    are unchanged (their drawing reads only `frame.palette`; the recount
    behind the mapping change already covers them).
- Pages (map ids): none — this is a kit-only part change with no host page in
  its own write set (KitScenes.md "Map element (not built here)").
- Specs followed: `docs/ux-system/kit-api/KitScenes.md` (frozen, wave 0);
  design-standard §10; visual-language §7; STANDARDS.md rules LOOK-1, LOOK-2,
  LOOK-4, LOOK-5, LOOK-6, LOOK-35–38, KIT-9, KIT-43, MOT-6, MOT-7, MOT-9,
  TEST-14, LAY-8; cut review C19 (recount) and C21 (e) (radius exemption).
- Contract problems (PROC-20): none — the frozen spec's recount (39
  `BorderRadius`/`Radius.circular`, 1 `colorScheme`, 0 literal colours) matched
  the current `feat/phone-setup-v2` source exactly before any edit (verified
  with `grep -oE` counts per file, §6).
- New kit parts (KIT-3): none — `KitDraw.wash` and `KitScene.mirrorsInRtl` are
  additive members of the existing `KitIllustration`/`KitScene` API (KIT-43),
  not a new part.
- Map items (EVID-11): none — KitScenes.md's one map element
  (`termux-setup-connect-termux#guide-illustrations`) is "not built here";
  it belongs to the slice that builds `phone-setup-progress`.
- States per page (STATE-20): n/a — no host page in this unit's write set.
  `KitIllustration`'s own states (entrance, finished, ambient, reduced) are
  documented on the class (KIT-12) and covered by `test/kit_illustration_test.dart`
  and `test/kit/kit_scenes_test.dart` §6.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitScenes-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (tip of `feat/phone-setup-v2` at branch time), code head
  `0da979619eb177a9487a594223bbc33b1ddc252e`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Recount `BorderRadius`/`Radius.circular`/`colorScheme`/`Color(0x`/`Colors.` in `lib/ui/kit/kit_illustration.dart` + `lib/ui/kit/scenes/*.dart` before editing | 39 / 1 / 0 / 0 (the frozen spec's numbers) | 39 / 1 / 0 / 0 | PASS |
| 2 | `flutter analyze lib/ui/kit` after the production edits | no issues | no issues found | PASS |
| 3 | `flutter test -j 1 test/kit_illustration_test.dart` (unowned, shares `KitPalette`) | passes unchanged (portal scene reads only `accent`, unchanged by the mapping) | 12 passed | PASS |
| 4 | `flutter test -j 1 test/servers_scenes_test.dart test/setup_scenes_test.dart test/kit_states_scenes_test.dart` before regenerating goldens | only golden pixel-diff failures, no logic failures | 5 pass / 36 fail (servers+setup), 6 pass / 14 fail (states) — every failure a `Golden … Pixel test failed` diff, zero other failures | PASS (expected) |
| 5 | Same three files with `--update-goldens`, looked at every changed PNG (§5) | all pass | 61 passed | PASS |
| 6 | `flutter test -j 1 --update-goldens test/goldens/team_scenes_golden_test.dart test/goldens/team_discover_scenes_golden_test.dart`, looked at every changed PNG | all pass | 18 passed | PASS |
| 7 | `flutter test -j 1 --update-goldens test/goldens/folder_browser_golden_test.dart`, looked at every changed PNG, then `git checkout` the screen-owned pair | `kit_folders_open_*` regenerated; `folder_browser_empty_*` reverted | 14 passed on the update run; `folder_browser_empty_dark.png`/`_light.png` reverted (§5, §7) | PASS (kit_folders_open); known gap (folder_browser_empty, §7) |
| 8 | `flutter test -j 1 test/goldens/folder_browser_golden_test.dart` (no update) after the revert | only `folder_browser_empty_{dark,light}` fail | 12 passed / 2 failed, exactly those two | PASS (confirms the gap is isolated) |
| 9 | `flutter test -j 1 test/kit/kit_scenes_test.dart` (new) | all pass | 163 passed | PASS |
| 10 | `flutter test -j 1 --update-goldens test/goldens/kit/kit_scenes_golden_test.dart` (new), looked at every PNG | 30 PNGs, all pass | 30 passed | PASS |
| 11 | `flutter test -j 1 test/golden_harness_test.dart` (G23: TEST-7/8/9/20, ARCH-11) | passes for the new kit gallery file | 8 passed | PASS |
| 12 | `flutter test -j 1 test/goldens/kit/kit_gallery_g5_test.dart` (G5 harness self-test) | unaffected | 15 passed | PASS |
| 13 | `flutter test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart` | unaffected (kit dir is out of scope for G1/G16; MOT-9 scene-timing check already covers `lib/ui/kit/scenes`) | 47 passed | PASS |
| 14 | `flutter test -j 1 test/motion_setup_test.dart test/motion_states_test.dart test/team_motion_test.dart test/phone_setup_ready_screen_test.dart` | unaffected (no colour/palette assertions) | 54 passed | PASS |
| 15 | `flutter analyze` (whole repo) | no issues | no issues found (27.6 s) | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) | Result |
  |---|---|---|
  | LOOK-1, LOOK-2 | `test/kit/kit_scenes_test.dart` "4. Theme only: …" | zero `Color(0x`, `Colors.`, `colorScheme` in `kit_illustration.dart` + `lib/ui/kit/scenes/**` |
  | LOOK-4 | `test/kit/kit_scenes_test.dart` group "2. No red, no amber …", allowlist test | allowlist empty; no scene paints `roles.attention`'s hue |
  | LOOK-5 | same group, `ServersLinkScene(failed)` and `SetupStepsScene(halted: failed)` variants | no scene paints `roles.danger`'s hue |
  | LOOK-36 | `test/kit/kit_scenes_test.dart` group "3. Flat, light fills …" | every accent-hue fill's alpha ≤ `KitTokens.sceneWashAlpha` (0.12); no Shader/MaskFilter/ImageFilter/shadow |
  | LAY-8 | `test/kit/kit_scenes_test.dart` group "5. Mirror …" | `SetupStepsScene`, `ServersLinkScene`, `TeamDiscoverRelayScene` under RTL match their LTR render flipped horizontally (≤ 2% pixel diff, anti-aliasing only); `KitPortalScene`/`TeamBoardScene` render identically under both |
  | MOT-6, MOT-7 | `test/kit/kit_scenes_test.dart` group "6. Still …" | every one of the 24 scenes settles after one `pump()` under reduced motion; none loops when `KitMotion.loops` is false |
  | KIT-43 | `test/kit/kit_scenes_test.dart` group "1. Mapping …" | `KitPalette.fromRoles`/`.of` match the frozen table in `graphiteDark`, `graphiteLight` and Catppuccin dark |
  | TEST-14 | `test/goldens/kit/kit_scenes_golden_test.dart` | 30 new PNGs: 7 contact-sheet groups × dark/light, the default page state × 5 sizes × dark/light, the mirrored-scenes sheet + default page in Arabic, the default page at 2.0 text |
  | G23 (TEST-7/8/9/20, ARCH-11) | `test/golden_harness_test.dart` | 8 passed against the new gallery file |

- Changed test expectations (TEST-19): none — no test's *assertions* encoded the
  old colours; every affected file only needed its golden PNGs regenerated
  (the palette values changed, not what the tests check).
- Goldens changed (each opened and looked at before committing):
  - `test/goldens/kit_setup_*.png` (14 pairs: fresh, starting, termux,
    phone_ready, stopped, ready, unplugged, steps_download/unpack/install/
    start/paused/failed): `surface`/`line`/`accentSoft` moved onto
    `ThemeRoles.surface3`/`text3`/`accent@.12`; `steps_failed` no longer paints
    red (LOOK-5) and `unplugged` no longer paints amber (LOOK-4).
  - `test/goldens/kit_folders_open_{dark,light}.png`: the front folder's fill
    (`palette.surface`) is a touch darker/lighter (was
    `colorScheme.surfaceContainerHigh`, now `roles.surface3` directly).
  - `test/goldens/servers_scene_link_*.png`, `servers_scene_welcome_*.png`:
    `line`/`surface`/`accentSoft` shift as above; `link_failed` no longer
    paints red.
  - `test/goldens/states_*.png` (8 scenes × 2 modes minus `working`, which is
    `accent`-only and did not change): `line`/`surface` shift as above.
  - `test/goldens/team_scene_*.png`, `team_discover_scene_*.png`: `line`/
    `surface`/`accentSoft` shift as above; no colour-role misuse in this
    group.
  - No approved VL canvas render exists for any of these shots (EVID-12: n/a).
- Before and after: n/a — these are kit-only scene renders, not a host page
  (EVID-10 applies to a page's before/after; none of this unit's PNGs are a
  host page).
- Accessibility: `KitIllustration` stays `ExcludeSemantics` by default
  (unchanged); the new gallery's contact sheets are all-decorative (no
  semantics nodes) and its default-page shots run the full G5 check
  (`androidTapTargetGuideline`, `labeledTapTargetGuideline`,
  `textContrastGuideline`, reading order) inside `kitGalleryPart` — all 30
  shots passed with no new entry needed in `test/goldens/kit/kit_gallery_g5_baseline.json`
  (confirmed unchanged by this unit, `git status` clean on that path).
- Privacy and security: n/a — no credentials, stored data, links or
  notifications changed.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
for f in lib/ui/kit/kit_illustration.dart lib/ui/kit/scenes/*.dart; do
  echo "$(grep -oE 'BorderRadius|Radius\.circular' "$f" | wc -l) $f"
done   # recount before editing: sums to 39; colorScheme count: grep -n colorScheme … = 1
$F test -j 1 test/kit/kit_scenes_test.dart
$F test -j 1 --update-goldens test/goldens/kit/kit_scenes_golden_test.dart
$F test -j 1 test/golden_harness_test.dart test/goldens/kit/kit_gallery_g5_test.dart
$F test -j 1 test/kit_illustration_test.dart test/kit_ratchet_test.dart test/design_standard_test.dart
$F test -j 1 test/servers_scenes_test.dart test/setup_scenes_test.dart test/kit_states_scenes_test.dart
$F test -j 1 test/goldens/team_scenes_golden_test.dart test/goldens/team_discover_scenes_golden_test.dart
$F test -j 1 test/goldens/folder_browser_golden_test.dart
$F test -j 1 test/motion_setup_test.dart test/motion_states_test.dart test/team_motion_test.dart test/phone_setup_ready_screen_test.dart
$F analyze
```

## 7. NOT proven

- Not run on a device or emulator (kit-only unit; on-device proof is
  coordinator work, R19/R20).
- `test/goldens/folder_browser_empty_dark.png` and `_light.png`
  (`test/goldens/folder_browser_golden_test.dart`) are stale: `KitFoldersOpenScene`'s
  fill shifted with the rest of the mapping (see §5), so these two screen-level
  PNGs (the folder browser's empty state, `lib/ui/widgets/folder_browser.dart`,
  outside this unit's write set) now mismatch by a small, expected amount.
  They are deliberately **not** regenerated here (R07: a shared golden with a
  scene inside a screen outside the write set goes to the integrator,
  PROC-10) — reverted with `git checkout` after being looked at. Listed in
  `sharedTestsBroken` for the coordinator to regenerate once this unit merges.
  Every other screen-level golden elsewhere in the suite (phone setup, Work,
  the AI Team, "Servers", etc.) that embeds one of these 24 scenes will need
  the same treatment at merge time; this unit's write set has no such files
  to check them from here.
- Arabic string coverage: n/a — `KitScenes.md` states "Kit copy: none. Scenes
  have no words."; the gallery's own fixture strings ("Connecting to your
  server", "Cancel") are test-only page-state dressing, not shipped copy, so
  no `.arb` change or `gen-l10n` run was needed.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitScenes-v2` |
| Enabled | Yes — no flag; `KitPalette.of`/`KitIllustration` are used wherever a host already draws a scene | |
| Verified | Tests and goldens only (§4) | this record |
| Committed | Yes | code head `0da979619eb177a9487a594223bbc33b1ddc252e` |
| Deployed | No | |
