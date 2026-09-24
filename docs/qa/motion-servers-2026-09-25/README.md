# Add server and Servers: rebuilt, with drawings that move (2026-09-25)

## Scope

Slice B of [`docs/design/motion-and-illustration-2026-09-25.md`](../../design/motion-and-illustration-2026-09-25.md)
on the foundation of design standard §10 (`KitMotion`, `KitScene`, `KitIllustration`).
The owner, on build 2052/2053: "be more creative — add animations, cool graphics…", and
on the Add server form: "This bs?"
(`../design-regressions-2026-09-24/phone-6-add-server.jpg`, ledger row 15).

### What changed

| Where | Before (`before-*`) | After (`after-*`) |
|---|---|---|
| **Add server** | Three chips of different sizes over two lines with "(experimental)" and "Paseo:"; "On your computer run \`opencode2 pair\`…" with raw backticks; a filled "Paste pairing code" pill beside a plain "Scan"; URL and password first; two big buttons (Test connection, Save & connect); a large gap above the pinned Save. | A drawing of this phone and the computer at the head. **Connect to** is one choice of three rows, each with a line: *OpenCode on a computer* (Pair with a code, or enter its address), *Codex* (The Codex app-server on your computer), *Claude Code or Pi* (Through Paseo on your computer). Then the chosen type's command in a copyable box (`opencode2 pair`, `paseo start --no-relay`, the Codex line). For OpenCode, pairing is the main path: "It shows a code. Scan it, or copy it and paste it here." with **Scan code** and **Paste code** as two equal buttons side by side (just Paste pairing code where there is no camera). The address, password and Test connection wait folded under **Enter the address instead**; name, username and AI Team under **More options**. Save & connect follows the form, so a short form has no gap above it, and stays in view above the keyboard. |
| **Save & connect** | Saved and connected without checking; a server that did not answer was saved anyway and reported "was saved, but it could not connect". | **Checks the connection by itself first** (unless a check since the last edit already answered): the button says "Checking the connection…", the drawing links up and its line says "Checking build.example.net…". Not answering: the verdict says what failed (refused, timed out, wrong password, TLS, not OpenCode) with *Open the setup guide* and **Save anyway**, and nothing is stored. Answering: saved with the detected OpenCode generation and version, then connected. Codex and Claude Code/Pi check with their own probe the same way. Test connection is a tertiary text button inside the fold. |
| **The connection moment** | A spinner in the Test connection button. | `ServersLinkScene`: idle, the phone and the laptop (the portal on its screen) with a dotted gap; **linking** while pairing, checking or connecting, the link draws itself across and (ambient, only while waiting) a dot travels from the phone to the computer; **linked** when paired or answered, a solid link, the spark landing with an overshoot, rays thrown out once, the laptop screen lit and the phone's lines in the accent; **failed**, the link breaks in the middle, the halves pull apart and the portal goes quiet. The verdicts sit under the drawing and every check and save scrolls back to it. |
| **Servers welcome** (nothing saved) | The value title floating mid-screen. | `ServersWelcomeScene` hero: the computer with the portal on its screen, this phone in front, a dotted path from the phone to it, a spark landing in the portal and two small sparkles. Drawn in once; a resting screen, so it never loops. |
| **Copy** | Raw backticks in pairing messages. | The pairing failures, empty clipboard hint, the adb bridge hint and the "servers started with opencode serve" line quote commands with “ ” (Arabic « »); no backticks left in what Add server shows. |

### Drawings (`lib/ui/kit/scenes/`, new files; the kit itself is untouched)

- `servers_cast.dart`: the recurring cast in the brand's stroke: a phone with a rounded
  screen (three conversation lines), a laptop (screen, base, hinge), the portal mark at
  any size (the mark's own geometry, `assets/branding/open-portal/mark.svg`), a sparkle.
  Paths are built once.
- `servers_link_scene.dart`: `ServersLinkScene(state, intro:)`, box 200 × 84. Each state
  has its own entrance (the widget is keyed by state), so a check that starts or ends
  never redraws the devices; `intro: false` keeps them when the link returns to idle.
- `servers_welcome_scene.dart`: `ServersWelcomeScene`, box 200 × 120.
- One accent (`primary`) for what matters, `muted`/`line` for the devices, `accentSoft`
  washes; `failure` only for the two torn ends. Paint and transforms only; the one
  ambient loop is on the screen where the person waits, and stops when the wait ends.
  Decorative (excluded from semantics); the verdicts and the caption carry the words
  (the caption is a live region).

### Behaviour kept

Every pairing format and path (paste, scan, a code pasted into the address or the
password field, per-address verdicts, the password never rendered), Codex and Paseo fields
and validation, the Tailscale editor, re-entering a password or token, the phone's own
server, the first-run auto-test after a pause, the AI Team host, credential storage
(unchanged: `ProfileStore`, per-profile `oc.<what>.<profileId>` keys) and
`openExternalLink` (no new links). No password or token is logged or put in copy.

## Builds

- Branch `ds/motion-servers` from `cf1d7464` (`feat/phone-setup-v2`, the foundation).
  Code commits `37e48ad5` (scenes) and `2b185c91` (Add server, welcome, tests, goldens).
- No APK built. No emulator or phone.

## Devices

None. Widget tests and rendered images only (pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | `test/add_server_flow_test.dart` (9: three type rows, no "experimental"/"Paseo:", no backticks; pairing first with equal Scan/Paste and the address folded, Test connection a text button; Save checks first and a refused server is explained, not saved, then Save anyway saves; Save saves what the check found (v2, version) and connects, with "Checking …" and the linking drawing while it waits; a paired code shows the linked drawing and Save does not check again; an empty address opens the fold at its error; Codex and Paseo show their own fields and their Save checks with their own probe; the welcome's hero sits above the title and nothing loops) | pass | PASS (9) |
| 2 | The same file on `cf1d7464` (old code) | fails | FAIL 8/9 (`behaviour-tests-on-cf1d7464.txt`); the empty-address test passes there too, as it should |
| 3 | The same file with only the pre-save check disabled (`if (false && …)`) | the Save tests fail on the check itself | FAIL 4/9: "Expected ['https://build.example.net'] Actual []", "Checking build.example.net…" not found, Codex/Paseo "Expected [codex] Actual []" (`behaviour-tests-save-check-reverted.txt`); restored |
| 4 | `test/servers_scenes_test.dart`: scene goldens (link idle/linking/linked/failed, welcome × dark/light), the link loops only while linking and never under reduced motion, a changed state repaints | pass | PASS (12) |
| 5 | Goldens `test/goldens/servers_motion_golden_test.dart` (16) and `settings_golden_test.dart` (`servers_add`, `servers_add_failed` updated; the rest unchanged) | match | PASS |
| 6 | Every test file that covers the server form (see *Test changes*), `design_standard_test`, `ui_ledger_coverage_test`, `l10n_coverage_test`, `ui_glossary_test`, `setup_ui_messages_test`, `kit_illustration_test` | pass | PASS |
| 7 | `flutter analyze lib test` | clean | clean |

### Test changes (the UI changed; each keeps its intent)

| File | Change |
|---|---|
| `support/server_editor.dart` | `openServerMoreOptions` taps the kit fold's header; new `openServerManualAddress` opens "Enter the address instead" (does nothing where the fields show). |
| `server_profile_editor_test`, `server_pairing_paste_test`, `first_run_welcome_test`, `first_run_auto_test_test`, `first_run_computer_path_test`, `server_v2_connect_flow_test`, `oc2_server_discovery_test`, `e7_setup_layout_test`, `profile_secure_storage_test`, `product_ui_regression_test`, `server_codex_connect_flow_test`, `server_switcher_test` | Open the address fold before using the URL or password field. |
| `server_profile_editor_test`, `profile_secure_storage_test`, `server_profile_reentry_test`, `server_codex_connect_flow_test` | Save & connect now checks first: these tests stub the check to answer, so what they watch (auto-connect, a keyring failure, a store failure, the Codex save and freeze) is unchanged. |
| `first_run_computer_path_test`, `server_codex_connect_flow_test`, `oc2_server_discovery_test` | The type rows (`server-backend-opencode/codex/paseo`) instead of chips; Add server now shows the chosen type's command (it switches with the type). |
| `server_v2_connect_flow_test` | A check scrolls the form back to the drawing: the pending-verdict test lets that scroll finish, and looks as the stale answer lands (before the first-run auto-test's pause could run a fresh check). |
| `first_run_welcome_test`, `phone_setup_welcome_entry_test` | On the default 800×600 test surface the hero puts "On this phone" below the fold: scroll to it first. |

## Evidence

- `before-N-*.png` / `after-N-*.png` (and `after-N-*-light.png`): the same scene rendered by
  `tool/capture/motion_servers_test.dart` (scenes in `test/support/servers_motion_scenes.dart`)
  on `cf1d7464` and on this branch, 412×915, real fonts: 1 Servers welcome, 2 Add server
  (OpenCode), 3 the address unfolded, 4 Codex, 5 Claude Code or Pi, 6 checking (the old form:
  Test connection pressed), 7 paired, 8 failed, 9 the first-run connect screen. Drawings show
  their finished frame (`KitMotion.loops = false`), the checking dot at rest midway.
- `behaviour-tests-on-cf1d7464.txt`, `behaviour-tests-save-check-reverted.txt`: runs 2 and 3.
- Goldens: `test/goldens/servers_scene_{link_idle,link_linking,link_linked,link_failed,welcome}_{dark,light}.png`,
  `test/goldens/{servers_welcome,add_server_manual,add_server_codex,add_server_paseo,add_server_testing,add_server_paired,add_server_failed,first_run_connect}_{dark,light}.png`,
  and the updated `servers_add_*`, `servers_add_failed_*`.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 2 test/add_server_flow_test.dart test/servers_scenes_test.dart \
  test/goldens/servers_motion_golden_test.dart test/goldens/settings_golden_test.dart \
  test/design_standard_test.dart test/server_profile_editor_test.dart \
  test/server_pairing_paste_test.dart test/first_run_welcome_test.dart \
  test/first_run_auto_test_test.dart test/first_run_computer_path_test.dart \
  test/server_v2_connect_flow_test.dart test/server_codex_connect_flow_test.dart \
  test/oc2_server_discovery_test.dart test/profile_secure_storage_test.dart \
  test/server_profile_reentry_test.dart test/server_switcher_test.dart \
  test/e7_setup_layout_test.dart test/product_ui_regression_test.dart
# Renders (after):
$F test --concurrency=1 tool/capture/motion_servers_test.dart
# Renders and the behaviour tests on the old code:
mkdir /tmp/old && git archive cf1d7464 | tar -x -C /tmp/old
cp test/support/servers_motion_scenes.dart /tmp/old/test/support/
cp tool/capture/motion_servers_test.dart /tmp/old/tool/capture/
cp test/add_server_flow_test.dart /tmp/old/test/
(cd /tmp/old && $F pub get && $F test test/add_server_flow_test.dart; \
  $F test --concurrency=1 --dart-define=MOTION_SERVERS_CAPTURE=before \
  tool/capture/motion_servers_test.dart)
# Goldens, deliberately:
$F test --update-goldens test/servers_scenes_test.dart test/goldens/servers_motion_golden_test.dart
```

## NOT proven

- **On a device.** Nothing here ran on the emulator or the owner's phone: not the look at
  phone density, not the motion (entrance timing, the travelling dot, the spark), not
  `gfxinfo` frame times, not the camera scan path.
- Not seen with the system's "remove animations" on a device (a test shows the loop does
  not run under reduced motion).
- Arabic copy for the new strings is a first translation, unreviewed by a native speaker.
- Pairing scanner, connection help and Tailscale setup screens were not changed (no drawing
  planned there; they are not yet on the kit).
- The whole suite was not run; only the files listed in run 6.
