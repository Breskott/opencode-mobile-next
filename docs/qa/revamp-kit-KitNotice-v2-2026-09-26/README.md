# revamp-kit-KitNotice-v2: KitNotice v2, cost line, offer, error defaults, KitReportHook (2026-09-26)

## 1. Scope

- Unit: `kit-KitNotice-v2` (wave 1, kit-change). Finish line: KitNotice matches its frozen spec (`docs/ux-system/kit-api/KitNotice.md`), K2 §2.4 and VL (look, API, states, adaptive), with its gallery rendered and reviewed. The change is additive: every call site still compiles with unchanged behaviour, and `flutter analyze` on the whole tree stays clean (KIT-43). Non-goal: no screen is restyled or adopts the new forms, and no public name is renamed or removed (KIT-43).
- Files changed:
  - `lib/ui/kit/kit_notice.dart` (the part; `KitErrorKind`, `KitReport`, `KitReportHandler`, `KitReportHook` in the same file, as the spec says);
  - `lib/ui/widgets/nudge_card.dart` (thin wrapper over `KitNotice.offer`);
  - `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` (two keys added);
  - `test/kit/kit_notice_test.dart` (new);
  - `test/kit/kit_notice_live_region_test.dart` (new, review fix 1: the live region counted on the semantics updates sent to the engine);
  - `test/goldens/kit/kit_notice_golden_test.dart` and 52 `test/goldens/kit/kit_notice_*.png` (new);
  - this record.
- Pages (map ids): none (`pages: []` in `work-units.json`).
- Specs followed:
  - `docs/ux-system/kit-api/KitNotice.md` (frozen API);
  - kit-v2 §2.4;
  - STANDARDS rules KIT-12, KIT-23, KIT-37, KIT-43, STATE-3, STATE-13, STATE-20, SEC-2, SEC-11, LOOK-4, LOOK-5, LOOK-21, LOOK-24, COPY-7, TEST-5, TEST-7, TEST-9, TEST-15, TEST-19, TEST-20, EVID-1 to EVID-12.
- Contract problems (PROC-20). Each one was settled by §0.2 (STANDARDS wins), and none blocks the unit.
  1. **KIT-12 doc line.**
     - What it says: KitNotice.md §States says "KIT-12 doc comment: States: neutral, working, ok, warning, error, cost, offer".
     - Why it is wrong: STANDARDS KIT-12 and gate G4 (`test/kit/kit_manifest_test.dart` `kitManifestStates`) accept only {loading, empty, error, disabled, working, answered}, and reject any other name.
     - Followed: `/// States: error, working.` The tones and forms are listed in a doc sentence of their own.
     - Proposed text: "States: error, working. (Tones and forms: neutral, working, ok, warning, error, cost, offer.)"
     - blocks: false.
  2. **The tone map.**
     - What it says: KitNotice.md §Tokens names "the pre-wave `KitTokens.toneFor` / `toneColor(AppStatusTone)`".
     - Why it is wrong: that token does not exist. `docs/ux-system/kit-api/_new-tokens.md:120` lists it under "Not added here".
     - Followed: the spec's own role table, as a private `_tintFor` in `kit_notice.dart`: neutral `text2`, working `accent`, ok `success`, warning and failure `text1`. This is what LOOK-4 and LOOK-5 require.
     - Proposed text: "KitNotice maps tones privately until a token unit adds `KitTokens.toneFor`".
     - blocks: false.
  3. **`@Deprecated`.**
     - What it says: the unit acceptance and R11 say that `nudge_card.dart` "becomes a @Deprecated wrapper".
     - Why it is wrong: STANDARDS KIT-43 says a kit change "never uses `@Deprecated`" and marks the old API `/// Retired by <unit>: use …` instead. KitNotice.md §Replaces agrees with KIT-43. `@Deprecated` would also put `deprecated_member_use` infos into the two callers.
     - Followed: KIT-43.
     - blocks: false.
  4. **The report action's words.**
     - What it says: the acceptance calls the action "Report this".
     - Why it is wrong: STATE-3, SEC-11 and the spec name it "Report a problem" (`kitReportProblem`).
     - Followed: "Report a problem".
     - Also: the acceptance says Copy details shows "always", but the spec shows it "when [details] is given", since there is nothing to copy otherwise. Followed the spec.
     - blocks: false.
  5. **G2 retired rows.**
     - What it says: KIT-43 and KitNotice.md §Replaces add `KitNotice.card(` and `NudgeCard(` as G2 retired-API ratchet rows.
     - Why it is wrong: the rows live in `_retiredApis` in `test/kit_ratchet_test.dart:476`, and their baseline in `test/kit_ratchet_baseline.json`. Both are outside this unit's write set (R05, R08).
     - Requested change: the integrator appends `'KitNotice.card': 'kit-KitNotice-v2', 'NudgeCard': 'kit-KitNotice-v2'` to `_retiredApis`, with KIT-44 baseline rows, and checks that `_uses('KitNotice.card')` counts a named constructor.
     - blocks: false.
  6. **G4 cannot read `kitGalleryPart` galleries.**
     - What it says: TEST-9 wants galleries for every part, and the gallery harness offers `kitGalleryPart` for parts that are not modal.
     - Why it is wrong: G4's gallery reader (`test/kit/kit_manifest_test.dart:1320`, `_Gallery`) recognises only `kitGalleryShot(` calls and `matchesGoldenFile` literals. A non-modal part's gallery written with `kitGalleryPart` therefore fails `stateScenes` and `gallery`.
     - What this unit did: the gallery uses the harness's `kitGalleryShot`, whose `open` pushes the section as a page framed exactly as `kitGalleryPart` frames a part. The renders are pixel-identical to the first `kitGalleryPart` renders, so nothing in them was worked around.
     - Proposed: `_Gallery` also parses `kitGalleryPart(`.
     - blocks: false.
  7. **The record's folder name.**
     - What it says: the task text and PLAN §5 name the record `docs/qa/revamp-<unit id>/README.md`.
     - Why it is wrong: EVID-1 adds the date of the first build commit.
     - Followed: EVID-1, `revamp-kit-KitNotice-v2-2026-09-26`. The first build commit is `06dba627`, at 2026-09-26T19:45Z.
     - blocks: false.
  8. **A change of tone alone is not announced.**
     - What it says: KitNotice.md §Accessibility line 226 says the live region is "announced once per change of tone or message", and test 9 (line 273) says "once per tone or message change".
     - Why it is wrong: a live region announces its text. The tone has no words: the glyph is decorative, and the spec defines no spoken tone word and no copy key for one. A notice whose tone changes while its words stay the same sends the same label, so the platform says nothing. Announcing it would need new copy (for example "Done: …" / "Failed: …") that the spec does not define, which would be a third behaviour.
     - Followed: today's behaviour. The notice is announced once per change of its words. `test/kit/kit_notice_live_region_test.dart` "a change of tone alone, with the same words, is not announced" pins this, so a fix shows up there.
     - Proposed text: "announced once per change of message (A11Y-3). A caller whose verdict changes without new words gives the new message (\"The server answered\", not only a new tone)." Or, if the owner wants tone spoken, the spec adds a tone word per tone with its copy keys.
     - blocks: false.
- New kit parts (KIT-3): none.
  - `KitErrorKind`, `KitReport` and `KitReportHook` are the spec's non-widget classes, in `kit_notice.dart`.
  - `kit.dart` already exports that file. Its doc-table row should name them (the integrator, R06).
- Map items (EVID-11): n/a, because the unit has no pages. The 20 map elements assigned to KitNotice, `_Notice` and `_FileStatusNotice` are adopted by their wave-2 screen units (spec non-goal "No screen adoption").
- States (KIT-12): KitNotice declares error and working.
  - They are rendered as `kit_notice_error_network`, `kit_notice_error_other` and `kit_notice_working` (dark and light, 412×915).
  - Its other forms are rendered too: default (neutral with title and notes), ok, warning, cost, offer, and offer at 2 lines.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitNotice-v2`, base `b67e3276`, code head `06dba627`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new behaviour, no fix | n/a | n/a |
| 2 | `test/kit/kit_notice_test.dart` + `test/nudge_moments_test.dart` | pass | 56 passed (`run-2-kit-notice-and-nudges.txt`) | PASS |
| 3 | `test/goldens/kit/kit_notice_golden_test.dart` (52 shots, G5 in both themes) | pass | 52 passed (`run-3-gallery.txt`) | PASS |
| 4 | `test/kit_ratchet_test.dart` + `test/design_standard_test.dart` | pass | 47 passed (`run-4-ratchet-design-standard.txt`); `kit_notice.dart` G21 counts 2 + 3 + 1 → 0 | PASS |
| 5 | `test/l10n_coverage_test.dart` + `test/ui_glossary_test.dart` | pass | 23 passed (`run-5-l10n-glossary.txt`) | PASS |
| 6 | `test/kit/kit_manifest_test.dart` + `test/ui_ledger_coverage_test.dart` | the ledger passes; G4 reports only stale allowlist entries | 3 passed, 1 failed: "3 allowlist entries now pass: states, gallery, test · KitNotice" (`run-6-manifest-ledger.txt`); the integrator shrinks the allowlist (sharedTestsBroken) | PASS (expected stale) |
| 7 | `flutter analyze --no-pub lib test` | no issues | No issues found (`run-7-analyze.txt`) | PASS |
| 8 | Other gates and suites run once (only the broken one saved, 8a-8d): `kit_motion_test`, `kit_motion_app_test`, `text_scale_overflow_test`, `accessibility_guidelines_test`, `golden_harness_test`, `kit_gallery_g5_test`, `kit_map_gate_test`, `kit/kit_keyboard_test`, `kit/kit_sheet_test`, `kit/kit_confirm_sheet_test`, `team_run_screen_test`, `thermal_guard_test`, `app_exit_recovery_test`, and the 49 widget-test files that pump a screen holding a KitNotice (listed below) | pass | all passed except `test/termux_setup_screen_test.dart` --plain-name "missing prior profile refuses switch without mutating setup": the finder for "Try OpenCode 2" found no widget (`run-8a-termux-setup-branch.txt`). It passes with the base notice (`run-8b`). Cause and proposed fix in §5 "Shared test broken" (`run-8c`, `run-8d`) | PASS with 1 shared break (layout, not behaviour) |
| 9 | Every golden file under `test/goldens/` (one or two per command) | own goldens pass; shared ones show only the intended look change | 23 shared PNGs differ, listed in §5, each opened and looked at; the rest pass | PASS (shared goldens for the integrator) |
| 10 | After review: `test/kit/kit_notice_live_region_test.dart` + `test/kit/kit_notice_test.dart` | pass | 37 passed (`run-10-kit-notice-after-review.txt`) | PASS |
| 11 | Mutation: `kit_notice.dart` patched so the live region is a new node on every build (`key: UniqueKey()`), then restored | the live-region tests fail | both fail: "rebuild 0 re-sent the live region" (Expected 0, Actual 1) (`run-11-live-region-mutation.txt`) | PASS (the test sees a re-announcing notice) |

The 49 widget-test files in run 8 are:
`about_alpha_notice`, `add_server_flow`, `agent_account_widget`, `app_diagnostics`, `app_lifecycle`, `desktop_platform_gating`, `e7_setup_layout`, `first_run_auto_test`, `first_run_computer_path`, `first_run_landing`, `first_run_welcome`, `ios_remote_platform_gating`, `launch_session_shortcut_routing`, `launch_shortcut_routing`, `local_agent_onboarding`, `oc2_server_discovery`, `phone_server_card`, `phone_setup_start_screen`, `phone_setup_welcome_entry`, `phone_termux_discovery`, `plugin_display_name`, `product_ui_regression`, `profile_secure_storage`, `release_blockers`, `server_codex_connect_flow`, `server_pairing_paste`, `server_profile_editor`, `server_profile_reentry`, `server_switcher`, `server_v2_connect_flow`, `session_link_routing`, `team_agent_chat_render`, `team_agent_chat`, `team_agent_screen`, `team_controls`, `team_cycle`, `team_discover`, `team_gate_answer`, `team_now`, `team_phone_onboarding`, `team_plugin_off`, `team_plugins_layout`, `team_usage`, `termux_running_server`, `termux_setup_screen`, `workspace_stable_layout`, `nudge_registry`, `work_tab_status_line` and `e7_workspace_capture`.

## 5. Evidence

- Rule evidence (PROC-31). Every test below is in `test/kit/kit_notice_test.dart` unless it names another file.

  | Rule | Test (`--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-37 | "joins the items with a dot and is not a live region"; golden `kit_notice_cost_*` | `run-2`, `run-3` |
  | K2 §2.4 offer | "one action and one close, by the keys passed in" (the action by its words "Turn on", one `KitButton`, one `KitIconButton`, nothing else to tap); "at 2.0 text the action and the close share the row under the sentence (en/ar)"; "a short sentence keeps its controls on its line" | `run-2` |
  | TEST-5, NudgeCard keys | "keeps its keys, and each control calls once"; `test/nudge_moments_test.dart` "card layout …" | `run-2` |
  | STATE-3 network | "TimeoutException offers Try again and Switch server, no report"; "SocketException offers …" | `run-2` |
  | STATE-3, STATE-13, SEC-2 | "another failure offers Report a problem when a handler is set; one tap sends a redacted report"; "without a handler there is no Report a problem" | `run-2` |
  | SEC-11, P8.3 (two taps) | "the report is reached in two taps from the error (P8.3)" | `run-2` |
  | KIT-23, SEC-2 | "copies the redacted details, says Copied once, no SnackBar" | `run-2` |
  | classifier | "timeouts and IO types by name are network"; "anything else, and null, is other"; "errorKind overrides the classifier" | `run-2` |
  | LOOK-4, LOOK-5 | "warning and failure paint text1, never amber or danger (dark/light)"; "the error form paints its glyph in text1" | `run-2` |
  | A11Y-3 (KitNotice.md test 9) | `test/kit/kit_notice_live_region_test.dart`: "a rebuild with the same words sends the live region nothing; each new message is announced exactly once" (counts the `updateNode` calls a spy `SemanticsUpdateBuilder` receives for the live-region node; a same-words rebuild sends it 0 times, each new message changes its sent label exactly once) and "a change of tone alone, with the same words, is not announced" (contract problem 8) | `run-10`, `run-11` |
  | MOT-7, G8 | "KitNotice (MOT-7) cost / offer / error / the verdict turns …" | `run-2` |
  | LAY-9 | "shows at most two actions and a labelled dismiss" (48 dp close) | `run-2` |
  | TEST-9, G5 | `test/goldens/kit/kit_notice_golden_test.dart` | `run-3` |
  | LOOK-21, G21 | `test/kit_ratchet_test.dart` | `run-4` |

- Changed test expectations (TEST-19): none. No shared test was edited.
- Shared test broken (`sharedTestsBroken`), `test/termux_setup_screen_test.dart` --plain-name "missing prior profile refuses switch without mutating setup":
  - Failure (`run-8a`): `The finder "Found 0 widgets with text "Try OpenCode 2": []" (used in a call to "tap()") could not find any matching widgets.` at `test/termux_setup_screen_test.dart:845`. The other 53 cases in the file pass, including the text-scale 2.0 layout cases.
  - Cause (`run-8c`, traced with temporary prints): in this case the screen shows a failure KitNotice ("A local server exists, but its saved credential is unavailable. …") above the "Other OpenCode versions" row. Its message moved from bodyMedium 14/20 to KitText body 16/24 (KitNotice.md §Tokens line 210; LOOK-12), so its four lines grow from 88 to 104 dp. In the test's 800 × 600 view the row was 1 dp inside the fold (top 599) and is now below it (top 615). The helper `openOtherVersions` (line 452) looks the row up with the default onstage finder and returns silently when it is not found (line 454), so the fold never opens. The screen throws nothing and does not overflow; the row is reachable by scrolling, as before.
  - Verdict: an intended consequence of the spec's type role, TEST-19 case (1). The test depends on where the row falls on a fixed 600 dp view, not on what the person can reach. It is not a regression the notice must avoid, and nothing changes in `kit_notice.dart`.
  - Fix for the integrator (the file is outside this unit's write set, PROC-10): in `openOtherVersions`, `find.byKey(const Key('other-runtime-versions'), skipOffstage: false)`, so the existing `ensureVisible` scrolls the row in. Tried temporarily: all 54 cases pass (`run-8d`). Record it as a TEST-19 (1) change with rule LOOK-12.
- Goldens added (all opened and looked at, 52 PNGs, 1.2 MB):
  - `kit_notice_{default,ok,warning,working,error_network,error_other,cost,offer,offer_wrapped}_{dark,light}`;
  - `kit_notice_default_{360x800,800x1280,1280x800,1600x1000,915x412}_{dark,light}`;
  - `kit_notice_{default,error_other,offer}_{text2,ar}[_1280x800]_{dark,light}`.

  There is no approved VL canvas render for KitNotice (EVID-12: none).
- Shared goldens that now differ. They were not regenerated (PROC-10) and are listed in `sharedTestsBroken`. Each was opened; the change is what the spec asks for:
  - `test/goldens/kit/kit_confirm_failed_{dark,light}`: the error glyph turns from `danger` to `text1` (LOOK-5), and the message moves from bodyMedium 14/20 to KitText body 16/24. See `before-after-kit_confirm-failed_light.png`.
  - `test/goldens/kit/kit_foundation_work_{,1280x800_,text2_,ar_}{dark,light}` (8 PNGs): the retired `KitNotice.card` border is now `KitTokens.hairlineWidth(context)`. That is one physical pixel, as `width: 0` was on a device, but the capture draws it fainter. See `before-after-kit_foundation-work_dark.png`.
  - `test/goldens/work_nudge_{dark,light}`: the pin tip is now `KitNotice.offer`, with body text, a `text2` glyph and no status-line hairline. "Got it" and the close stay on one row. See `before-after-work-nudge_light.png`.
  - `test/goldens/settings_notifications_{dark,light}`, `settings_about_dark` and `servers_add_failed_{dark,light}`: body-role message, `rowTitle` title and a `text1` failure glyph. See `before-after-settings-about_dark.png` and `before-after-servers-add_failed_dark.png`.
  - `test/goldens/team_board_refused_{dark,light}`: the warning glyph turns from amber to `text1` (LOOK-4), with a `rowTitle` title. See `before-after-team_board-refused_dark.png`.
  - `test/goldens/add_server_paired_{dark,light}` and `add_server_failed_{dark,light}` (servers_motion): an ok or failure notice in the body role. See `before-after-add_server-paired_dark.png`.
- Before and after:
  - `before-after-*.png` put the base golden on the left and this branch's render on the right, cropped to the changed rows.
  - `after-kit_notice-{default,error_other,offer_wrapped,cost}.png` come from the new gallery.
  - KitNotice had no gallery before this unit, so there is no before render for `kit_notice`.
- Accessibility:
  - Every icon-only control is a 48 dp `KitIconButton` whose label is also its tooltip: "Copy details", and "Dismiss" or the caller's label.
  - The tertiary actions are at least 48 dp tall.
  - There is one live region per notice; `.cost` has none.
  - G5 (tap targets, labels, text contrast, reading order) passes in both themes for all 52 shots.
  - At 200 % text and 2.5 × (nudges) nothing truncates, and the offer's controls stay together.
  - In Arabic the icon sits at the start and close and copy sit at the end.
- Privacy and security:
  - Copy details and Report both pass `details` through `KitReportHook.redact`, which is `KitRedact.text`. Tests assert that a fake `sk-ant-…` key and a `Bearer` token reach neither the clipboard nor the `KitReport`.
  - `KitReport` carries only the type name of the error, never `toString()`.
  - Report appears only while a handler is registered. The app registers none yet (coord-main, C32).
- Migration: n/a, because no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/kit/kit_notice_test.dart test/kit/kit_notice_live_region_test.dart test/nudge_moments_test.dart
$F test -j 1 test/goldens/kit/kit_notice_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart
$F test -j 1 test/l10n_coverage_test.dart test/ui_glossary_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- "Report a problem" is not reachable in the app: no `KitReportHook.handler` is registered until coord-main wires `openBugReport` with its preview (C26, C32). The two-tap path is proven only against a test handler.
- No screen uses `.cost`, `.offer` or `.error` yet. The model picker's `_Notice`, `_FileStatusNotice`, the first-run tips and the discovery cards are adopted by their wave-2 units.
- The spec's optional medium-and-up rule, that a plain or error notice's actions "may sit on the message's last line when they fit", is not built. Plain notices keep their actions under the words at every width, because a LayoutBuilder there would fail inside hosts that size by intrinsics. The offer does move its controls onto its line when they fit.
- Copy details uses the v1 `KitIconButton(label:)`. It switches to `tooltip:` or `KitIconButton.copy` once kit-KitIconButton-v2 merges.
- A tone change with identical words is not announced again: a live region announces its text, and the tone has no words (contract problem 8). The live-region tests count the updates the framework sends to the engine; what TalkBack then says was not heard on a device.
- The full serial suite was not run; only the files in §4 were.
- On the base, `test/goldens/failures/team_agent_*` PNGs are tracked (a TEST-12 breach that predates this unit). This unit left them as they were.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitNotice-v2` |
| Enabled | Yes for the new constructors; "Report a problem" is off until the app registers `KitReportHook.handler` | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `06dba627` |
| Deployed | No | |
| Released | No | |
