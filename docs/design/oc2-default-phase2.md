# OpenCode 2 defaults — retirement phase 2

Date: 2026-10-15. Base: `7d59288d9`; branch: `codex/oc2-default`.

Finish line: fresh phone and Termux setup and default agent installation choose
OpenCode 2 **2.0.29**, while an existing or explicitly selected OpenCode 1
installation keeps its runtime. Non-goals: automatic migration, a new migration
prompt, removing the OC1 client/installers, publishing host bundles, or a release.

The owner accepted Tier 1 in [the retirement plan](oc1-decommission-plan-2026-10-14.md).
B1/B2 are accepted prerequisites; the latest team evidence is
[run 5 / APK 2319](../qa/aiteam-oc2-emulator-2026-10-14/run5-2319.md).
That evidence qualifies the earlier AI Team implementation, not this new-default
candidate. This candidate still needs the fresh-data emulator run below.

## Changes and runtime handoff

- `TermuxRuntime.defaultForNewInstall` is OC2; its existing pin is 2.0.29.
  `TermuxBridge.defaultOpenCodeVersion` agrees. OC1 remains pinned at 1.19.0.
- In-app `setupComponents`, the standalone install/start script builders, Termux
  bridge installers and genuinely fresh manager setup choose OC2. The engine
  records the chosen runtime explicitly in each new job. Its install, plugin,
  start, readiness and profile creation steps receive that same runtime.
- Setup-engine retries and subsequent jobs preserve the prior runtime. A legacy
  job with no runtime means OC1, including a job interrupted before installation.
  A completed job lends only its runtime to the next run, not stale job facts.
  Failed, timed-out or malformed journal reads stop admission and show a safe
  retryable failure; they cannot be mistaken for a fresh installation. With no
  journal, an already installed in-app rootfs is conservatively treated as OC1
  unless the caller explicitly selects a runtime; only confirmed absent Ubuntu
  receives the fresh default. An unreadable rootfs status also stops setup.
- Both Termux setup entrypoints inspect the installation before choosing. An
  existing rootfs, runtime record or saved managed profile keeps its selection.
  An inventory failure stops setup; the job page offers Continue setup to retry.
  An absent inventory leaves the job engine free to preserve a saved job's runtime.
- The manager distinguishes fresh setup from status/restart. Missing runtime
  fields in existing state still mean OC1. It records a new setup selection under
  its setup lock. The shared Ubuntu installer uses OC2 only when neither an
  explicit selection nor an existing OC1 binary is present.
- Update and Add tools pass the saved phone runtime explicitly. In particular,
  updating an OC1 phone no longer relies on an implicit default. Phone-host
  models distinguish a fresh host from a legacy installed host as well.
- The agent catalog lists OC2 first with its reviewed npm artifacts. The stable
  legacy ID `opencode`, route, OC1 artifact hashes and sign-in recipe remain.
- The existing runtime label is **Older OpenCode** in English and
  **الإصدار الأقدم من OpenCode** in Arabic. The existing runtime switch uses
  these labels; stored profile names are not rewritten. ARBs and their existing
  generated getters were kept consistent without adding keys. Flutter generation
  was not run here.

### Kotlin boundary (correction to the plan's file note)

`components.dart` is Dart, and at this base there is no implicit OC1 Kotlin
launch default to flip. `NativeServerRecipe.fromRequest` requires an explicit
`openCode1` or `openCode2`; `BuiltinLinux.kt` launches the supplied script and
persists that recipe. A missing runtime is rejected. Relaxing that rule would
risk changing an existing phone during cold restoration.

The changed Dart defaults feed this existing strict native boundary. Kotlin
regressions prove a fresh OC2 recipe starts `opencode2` with isolated XDG paths,
while a previously saved OC1 recipe still starts `opencode` and missing-runtime
recipes fail closed. Production Kotlin was deliberately left unchanged after
this source inspection. No Rust engine source or staged engine `.so` changed.
This remains a **new Shorebird release** candidate under the retirement plan,
not an authorized patch/release operation.

## Runtime-dependent integration audit

| Surface | Selection and preservation |
| --- | --- |
| gen-UI plugin | Setup components use the selected runtime; connection/plugin operations use `AgentToolAdapters.forOpenCode` for the selected profile. OC2 receives the v2 plugin; explicit OC1 keeps the v1 plugin. |
| AI Team | Existing capability admission accepts the OC2 profile. Protected setup already passes the selected runtime and its private Basic password; no flavor gate was added. |
| Quota collector | Existing enrollment follows the profile. OC2 reads its isolated auth location; OC1 keeps the legacy auth location. Added OC1 precedence coverage beside the existing OC2 case. |
| Setup engine | Runtime is persisted before dispatch and passed to the install/start components. Legacy restore parsing remains OC1. |
| Agent catalog | OC2 is first; explicit OC1 descriptor IDs and artifact pins are stable. Both server descriptors are excluded from the separate phone-agent tools list. |
| BYO connection | Verified bundle version sets the profile flavor. OC2 client creation and terminal WebSockets preserve the proxy's per-phone Basic identity; direct OC2 still defaults to username `opencode`. Terminal tickets do not bypass proxy revocation. |

## BYO and standalone Ubuntu publication boundary

BYO **source** now targets bundle 2.0.0 containing OC2 2.0.29. It verifies the
same reviewed npm tarball hashes as the phone installer, extracts only the
expected package members, probes authenticated `/api/info`, overrides both
password environment aliases, and supports `/api/pty` upgrades. A new bundle
refuses an existing OC1 state without modifying it. Historic published app
`1.1.0+51` / bundle 1.1.0 / OC1 1.18.32 pins remain intact.

There is **no published current-app OC2 BYO bundle pin** in this checkout.
Current-app BYO setup already failed closed without an exact app-version pin and
continues to do so. No release URL/hash was fabricated. Bundle packaging itself
was not performed here. The owner must build both architectures, review and
publish the bytes, and add the exact app-version hashes before enabling that
path. See [the bundle release instructions](../../scripts/byo-host/README.md).

`scripts/host/ubuntu-opencode.sh` now defaults to OC2; explicit
`OPENCODE_RUNTIME=opencode` selects Older OpenCode. Existing install is retained;
ordinary update refuses an implicit OC1-to-OC2 move. The app's Ubuntu download
command still points at its historical published commit. Publishing the new
script and updating `HostScripts.commit`/checksum is a separate owner action;
until then that public download still has its old behavior. The existing
pending-pin fixture records the new local source hash, not a public pin.

**Termux manager script bytes changed**, including the shared Ubuntu payload and
install wrappers. The owner must regenerate the fixture for
`test/termux_script_hashes_test.dart`; it was intentionally not regenerated here.
The snapshot generator now keeps an explicit OC1 case and adds a separate
fresh-default case.

## Why an existing OC1 phone is untouched

There is no migration at profile load, app start, job restore or server restart.
`ServerProfile`'s legacy flavor default and `TermuxRuntime.parse(null)` remain
OC1. Existing native recipes remain explicit. Existing job records without a
runtime are interpreted as OC1. Update/Add tools retain the selected runtime.
No password, provider credential, history database, saved profile name or runtime
record is rewritten merely by opening the app. Explicit switching remains
available; the owner-visible **Move to OpenCode 2** work belongs to phase 3.
Remote OC1 connections, OC1 client/generated SDK and capability restrictions
remain supported.

## Verification and handoff

Completed locally, without Flutter or any device run:

- Kotlin `NativeServerRecipeTest`: **16 tests passed**, compiled with the cached
  Kotlin/JUnit jars under `tool/qa/machine_lock.sh` (256 MiB compiler heap,
  128 MiB runner heap). Harness: `build/qa/oc2-default-phase2/run_kotlin.py`.
- `python3 -m unittest discover -s test/byo_host -p '*_test.py'`: **37 passed**.
- Isolated shell probes: five Ubuntu install/update scenarios; five manager
  selection scenarios; four shared Ubuntu selection scenarios; four migration
  guards. Shell syntax checks passed. No real host was installed or updated.
- Standalone pinned Dart formatting and `git diff --check`.
- No Flutter analyze/test/gen-l10n, APK build, emulator run, bundle packaging,
  push, publication or signing. No new device qualification is claimed.

Run these Dart/Flutter files with the pinned Flutter 3.47.1, serially, after
regenerating the Termux hash fixture. New files are marked `(new)`:

```text
test/phone_host_runtime_test.dart (new)
test/termux_default_runtime_test.dart (new)
test/api2_terminal_auth_test.dart (new)
test/builtin_linux_test.dart
test/setup_engine_test.dart
test/setup_scripts_test.dart
test/setup_termux_existing_install_test.dart
test/opencode_native_install_test.dart
test/opencode_history_copy_test.dart
test/phone_server_card_test.dart
test/phone_setup_termux_job_screen_test.dart
test/phone_setup_termux_screen_test.dart
test/termux_scripts_test.dart
test/termux_running_server_test.dart
test/termux_script_hashes_test.dart
test/this_phone_screen_test.dart
test/agent_catalog_test.dart
test/quota_collector_host_test.dart
test/gen_ui_install_test.dart
test/agent_tool_adapter_test.dart
test/in_app_quota_enroller_test.dart
test/aiteam_component_test.dart
test/phone_team_setup_test.dart
test/byo_host/controller_test.dart
test/byo_host/bundle_pins_test.dart
test/host_script_install_test.dart
test/host_script_pin_test.dart
test/api2_client_test.dart
test/api2_transport_test.dart
test/connection_v2_gateway_test.dart
```

Also run `flutter analyze` and the localization generation/drift check. Review
phone/runtime goldens that display the changed Older OpenCode label; do not
blindly accept unrelated golden changes. The full integration suite remains an
owner-run gate, not a claimed pass from the focused checks above.

## Emulator acceptance plan

Use a disposable fresh-data emulator, **`adb -s emulator-5554` only**. Do not clear
the owner's phone or the earlier proof state without arranging a disposable AVD.
Install a newly built release APK containing this candidate.

1. With no app data/profile/setup job, run in-app first setup using defaults.
   Verify install 2.0.29, `/api/info` readiness with private Basic auth, saved v2
   profile, and This phone showing OpenCode 2 / Connected. Do not record secrets.
2. Sign in to a working provider; send a chat and receive an answer. Verify the
   chosen-runtime gen-UI plugin and quota enrollment use OC2's isolated context.
3. Turn on AI Team, select a working model, and run a small project through
   planner → worker → checker → merge into dev. Verify the permission boundary
   and resulting task state. Force-stop/reopen and verify OC2 cold restoration.
4. Repeat a truly fresh Termux setup: no manager state/runtime record or Ubuntu
   rootfs. Verify 2.0.29, v2 profile, chat and restart. AI Team's on-phone engine
   admission remains the existing in-app-host contract; this change does not
   claim AI Team support for a Termux host.
5. On a separate fixture with an existing OC1 phone/profile/job, open the app,
   restart, Update, Add tools, and resume an interrupted pre-install job. Verify
   OC1 remains selected and old chats/profile IDs remain. Repeat with Termux
   legacy records lacking runtime fields and with a failed inventory probe.
6. In English and Arabic, confirm Older OpenCode remains selectable through the
   existing runtime switch. Only an explicit switch may move the runtime. Test
   fresh default OC2 again after clearing only the disposable fixture.
7. Once host artifacts are published and repinned, separately qualify the new
   Ubuntu command and BYO bundle: OC2 chat, terminal, proxy token revocation and
   refusal to mutate an existing OC1 host. Local source tests are not this proof.
