# fix-preexisting-test-failures: six tests that already failed on feat/phone-setup-v2 (2026-09-26)

## 1. Scope

- Unit: `fix/preexisting-test-failures` (coordinator follow-up, not a wave unit). Finish line: the six failing cases pass, and each one records its cause, its decision (product bug or stale test) and the evidence. Non-goal: no product behaviour change unless a failure turns out to be a product bug; no other test is touched.
- Files changed (code head `a85c9d34`):
  - `test/support/voice_device_channel.dart` (new): `answerVoiceDeviceProbe()`.
  - `test/support/phone_setup_scenes.dart`: `_start` passes `deviceProbe`.
  - `test/first_run_welcome_test.dart`, `test/oc2_server_discovery_test.dart`, `test/phone_setup_welcome_entry_test.dart`: call `answerVoiceDeviceProbe()`.
  - `test/team_run_screen_test.dart`: one test follows P0.3's route to the run detail.
  - No `lib/` file changed.
- Pages (map ids): n/a. No page changed.
- Specs followed: STANDARDS.md TEST-1, TEST-2, TEST-11, TEST-19, PROC-1, PROC-2, PROC-5, PROC-10, PROC-14; AGENTS.md "Testing traps".
- Contract problems (PROC-20): none.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a. No page in scope.
- States per page (STATE-20): n/a.
- Deferred states (STATE-21): none.

### Per test: cause, decision, evidence

| # | Test (`file`: name) | Failure on base | Broken by | Decision | Change |
|---|---|---|---|---|---|
| 1 | `test/motion_setup_test.dart`: "setup start leads with the phone drawing at the top of the page" | `A Timer is still pending even after the widget tree was disposed`. The pending timer is the 5 s `.timeout` in `AndroidVoiceDevicePlatform.getDeviceInfo` (`lib/voice/device.dart:95`), called from `_PhoneSetupStartScreenState._probeDevice` (`phone_setup_start_screen.dart:123`) | `361bbb77` fix(setup): pre-flight the CPU, RAM and free space before phone setup downloads (P0.8) | **Stale test fixture.** P0.8 is a done programme slice (`docs/ux-system/revamp/build_units.py:737`, `DONE`). It added a third probe to the start screen, but the shared scene fixture only injected the first two (`termuxProbe`, `inAppProbe`). The fixture exists to keep scenes deterministic (TEST-11). | `phone_setup_scenes.dart` `_start` passes `deviceProbe: () async => _sceneDevice` (healthy arm64 phone, 8 GB RAM, 20 GB free). |
| 2 | `test/motion_setup_test.dart`: "setup start a running setup draws its journey" | same pending timer | `361bbb77` | Stale test fixture, same as row 1 | same fixture change |
| 3 | `test/first_run_welcome_test.dart`: "the phone choice and the demo open their destinations" | same pending timer | `361bbb77` | **Stale test harness.** The test opens the start screen through the welcome's real route, so there is no `deviceProbe` to pass. `361bbb77` saw exactly this and mocked `oc/voice` in its own `test/phone_setup_start_screen_test.dart` `setUp` ("a few tests build PhoneSetupStartScreen straight from its route … the unmocked oc/voice channel must answer at once"), but not in the other files that reach the screen. The test asserts navigation, and navigation still works. | Calls `answerVoiceDeviceProbe()` before pumping. |
| 4 | `test/oc2_server_discovery_test.dart`: "known OC1 user reaches phone setup with no runtime forced" | same pending timer | `361bbb77` | Stale test harness, same as row 3 | Calls `answerVoiceDeviceProbe()` at the top of the test. |
| 5 | `test/phone_setup_welcome_entry_test.dart`: "coming back from phone setup reads the job again" | same pending timer | `361bbb77` | Stale test harness, same as row 3 | `setUp` calls `answerVoiceDeviceProbe()`. |
| 6 | `test/team_run_screen_test.dart`: "the home's run row pushes the run detail" | `Expected: exactly one matching candidate / Actual: Found 0 widgets with key [<'team-run'>]` at line 1326 | `9dde3f24` fix(team): a team task opens one page from every door (P0.3, P0.4) | **Stale test: intended product change.** P0.3's acceptance (`docs/ux-system/programmes.json`, id `P0.3`) says `TeamHomeScreen._openRun` falls back to `TeamConversation.open` instead of RunScreen, with the widget test "tapping a team-home row pushes the conversation, not RunScreen" (`test/team_one_page_test.dart`). RunScreen stays as the conversation's Task details (P3.5). This test was not updated when P0.3 landed. | Renamed "the home's run row opens the task, whose Task details pushes the run detail". It follows the new route: row, then conversation (`team-run` absent), then menu, then `team-conversation-details`, then `team-run`. The title and Technical details assertions are unchanged. This also covers a gap: until now no test tapped Task details (`team_one_page_test.dart` only checks the menu item exists). |

No product bug was found. Two causes explain all six failures. Neither is a regression in what the person sees, what is sent or what is stored:

- Rows 1–5 fail on a test-binding invariant (a pending fake timer), not on an assertion about behaviour. The probe helper answers `getDeviceInfo` with `{}`. That is an "unknown" reading, which `checkSetupPreflight` never blocks on (`lib/builtin/setup/preflight.dart`, "An unknown reading … never blocks"). So these screens render exactly as they did before the probe existed.
- Row 6 encodes navigation that P0.3 deliberately replaced.

Observation, not changed: a real `oc/voice` probe that never answers keeps its 5 s deadline alive after the start screen closes. The Termux look on the same screen is cancelled on dispose (`_discovery`). On a device the channel answers, and `_probeDevice` checks `mounted`, so nothing visible goes wrong. Cancelling it would mean changing the shared voice platform API, which is outside this fix.

## 2. Builds

- Branch `fix/preexisting-test-failures`, base `c255daf4` (feat/phone-setup-v2), code head `a85c9d34`.
- No APK (no build was run).

## 3. Devices

None: tests and goldens only.

## 4. Runs

All runs used the pinned Flutter 3.47.1, `-j 2`.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | The five files on base `c255daf4`, before the change | the six named cases fail with assertions | 66 passed, 6 failed: 5 × `!timersPending` assertion, 1 × `TestFailure` on `team-run`. See `failing-first.txt` | PASS |
| 2 | The same five files after the change | all pass | 72 passed. See `run-after.txt` | PASS |
| 3 | Other users of the changed scene fixture and P0.3's own test: `test/design_standard_setup_test.dart`, `test/goldens/phone_setup_golden_test.dart` (compared, not updated), `test/team_one_page_test.dart` | pass, no golden changes | 41 passed, no PNG changed (`git status` clean under `test/goldens`). See `run-fixture-consumers.txt` | PASS |
| 4 | `test/repository_hygiene_test.dart`, `test/kit_ratchet_test.dart`, `test/design_standard_test.dart`, `test/l10n_coverage_test.dart` | pass | 25 passed. See `run-gates.txt` | PASS |
| 5 | `flutter analyze lib test` | no issues | No issues found. See `analyze.txt` | PASS |

## 5. Evidence

- `failing-first.txt`: output of run 1 (TEST-2). All six failures are assertion failures, not compile errors.
- `run-after.txt`, `run-fixture-consumers.txt`, `run-gates.txt`, `analyze.txt`: outputs of runs 2 to 5.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | TEST-19 (2): what is reachable is unchanged | `test/first_run_welcome_test.dart` "the phone choice and the demo open their destinations"; `test/oc2_server_discovery_test.dart` "known OC1 user reaches phone setup with no runtime forced"; `test/phone_setup_welcome_entry_test.dart` "coming back from phone setup reads the job again" | `run-after.txt` |
  | TEST-11: scenes are deterministic | `test/motion_setup_test.dart` "leads with the phone drawing at the top of the page", "a running setup draws its journey"; `test/goldens/phone_setup_golden_test.dart` | `run-after.txt`, `run-fixture-consumers.txt` |
  | P0.3 acceptance | `test/team_run_screen_test.dart` "the home’s run row opens the task, whose Task details pushes the run detail" | `run-after.txt` |

- Changed test expectations (TEST-19):
  - `team_run_screen_test.dart`: the home row → `team-run` (RunScreen) became the home row → `TeamConversationScreen`, with `team-run` absent, and then Task details → `team-run`. Reason: P0.3 finish line and acceptance, an owner-approved programme slice (`docs/ux-system/programmes.json`). The test also changed its name and the file's header comment.
  - Rows 1–5: no expectation changed. Only the harness changed, so the device probe answers.
- Goldens changed: none.
- Before and after: n/a. No UI changed.
- Accessibility: n/a. No UI changed.
- Privacy and security: n/a. No credentials, stored data, links or notifications changed. The mock answers with an empty map, with no real device data.
- Migration: n/a. No stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
# failing first: on the base
git switch --detach c255daf4
$F test -j 2 test/first_run_welcome_test.dart test/motion_setup_test.dart \
  test/oc2_server_discovery_test.dart test/phone_setup_welcome_entry_test.dart \
  test/team_run_screen_test.dart
# after
git switch fix/preexisting-test-failures
$F test -j 2 test/first_run_welcome_test.dart test/motion_setup_test.dart \
  test/oc2_server_discovery_test.dart test/phone_setup_welcome_entry_test.dart \
  test/team_run_screen_test.dart
$F test -j 2 test/design_standard_setup_test.dart test/goldens/phone_setup_golden_test.dart test/team_one_page_test.dart
$F test -j 2 test/repository_hygiene_test.dart test/kit_ratchet_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- The full suite was not run. Only the files above were. Other tests that reach `PhoneSetupStartScreen` through a real route without answering `oc/voice` may still hide the same pending timer. These were not searched for beyond the six named failures.
- That the six cases also failed on `d4f7bdbc` comes from the task statement. It was not re-run here: the failing-first run is on `c255daf4`.
- `tool/capture/` tests that import `phone_setup_scenes.dart` (`tool/capture/motion_setup_test.dart`, `tool/capture/design_standard_setup_test.dart`, `tool/capture/census/areas/h_termux.dart`) were not run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `fix/preexisting-test-failures` |
| Enabled | n/a: test-only change | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `a85c9d34` |
| Deployed | No | |
| Released | No | |
