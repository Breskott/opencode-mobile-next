# Startup measurement and bounded deferral

Finish line: paint the opening state before starting storage/bootstrap and persisted-report work, retaining every prerequisite before exposing the shell and connecting. Non-goals: changing draft ownership/recovery, privacy/consent defaults, automatic reconnect policy, or connection transport behavior.

## Measurement method

`test/perf_startup_test.dart` pumps the real `AppBootstrapGate` with a stalled loader and a render-object paint counter. It records whether paint completed before calling the loader and the scheduler phase in which the loader starts. This is a deterministic first-frame work-placement measurement. Widget tests do not measure release-mode engine startup or device GPU raster time.

`test/perf_startup_connection_test.dart` uses the real gate, app root, profile store, migrations and `ConnectionController`. Transport/operations are fakes, supplied through the gate's optional test controller factory; platform capabilities select a mobile shell without native bridges. The script holds profile loading for 40 ms of widget-test clock time, health for 60 ms, and stream connection for another 20 ms. It checks the real `app.first_connected` trace mark and that one initial health request, the existing second Settings health read, and one event channel start. Those durations are chosen test inputs, not observed network latency. The fixture uses an empty transcript and has no credentials.

The coordinator's pre-fix run recorded `loader_calls=1`, `paints_before_loader=0`, and `phase=SchedulerPhase.persistentCallbacks`; the new ordering assertion failed as intended. The command output is `/tmp/oc-perf-startup-before.log` (local run artifact, not committed). The corrected connected baseline passed (`/tmp/oc-perf-connected-baseline-pass.log`): first frame at scripted 0 ms, first health request at 40 ms, connected at 120 ms, two health reads and one event channel. Earlier fixture attempts used an invalid HTTP remote URL and an incorrect one-health-read assumption; those failed attempts are not verification evidence. Final before/after results are also recorded in the parent [performance report](README.md). No device cold-start speedup or connected latency improvement is claimed from these tests.

## Dependency decisions

| Work | Ordering and reason |
| --- | --- |
| Error capture | Remains synchronous before `runApp`, so bootstrap/frame failures enter the in-memory controller. |
| Persisted P8.1 problem report | Safe to open after the first frame: the existing capture imports buffered diagnostics and timings when attached. It still starts before the gate's post-frame bootstrap work. A process dying before report open has no new durable report, the same limitation as its existing asynchronous open. |
| Preferences/profile load and credential registration | Starts after opening-state paint; must finish before constructing the connection controller. The gate already renders independently of profiles. |
| P3.2 older-draft migration | Stays awaited before shell exposure. An early chat must not read an unmigrated/unattributed draft or compete with its move into Saved prompts. |
| Photo recovery | Stays after older-draft migration and before shell exposure on supported platforms. Restored photo destination must be established before a chat consumes its draft. |
| Notification preferences migration | Stays awaited before shell exposure; preserves shared quiet-hours and Wi-Fi rules plus legacy fallback on failure. No overlap/reordering is introduced. |
| Policy/consent owners | No eager additional loads or defaults introduced. `AutomationPolicyController.forProfile` reads synchronously from loaded preferences; `ConsentOwners` memoizes per-profile in-flight loads. They must remain consulted at their current execution/consent boundaries. |
| Capability flows | `registerCapabilityFlows` stays before shell render. It installs handlers, not network discovery; deferral could briefly expose missing actions. |
| Profile/quota monitor constructors | Existing controller construction starts these monitors; unchanged and now necessarily after opening paint. Further scheduling changes require the connection/policy owner and evidence that alert/consent ordering remains intact. |
| Intent capture and automatic connection | Remain in shell initialization/post-shell-frame order. Incoming links/shares retain their current readiness checks. Managed phone-server recovery and thermal protection are not postponed independently. |
| Dynamic colors | Existing asynchronous shell initialization remains unchanged to avoid an extra first-shell theme change. |

## Traces for release-device verification

Existing content-free `app.main`, `app.first_frame`, `app.shell_frame` and `app.first_connected` marks remain authoritative for process-relative measurement. The connected mark is emitted by the real event-stream `StreamStatus.connected` handler, not by profile load or a healthy HTTP response. Measure a release build on the target phone with both warm filesystem caches and force-stopped cold launches, and distinguish remote connection from managed local-server startup. Report medians and tails with server/network conditions; this slice does not invent device numbers from widget pumps.

## Preservation checks

The after run records `loader_calls=1`, `paints_before_loader=1`, and
`phase=SchedulerPhase.postFrameCallbacks`: the opening state now paints before
the loader starts. The real-controller fixture still records scripted first
frame at 0 ms, health start at 40 ms, connected at 120 ms, two health reads and
one event channel. The optimization changes first-frame work placement, not the
connection sequence or the fake transport's prescribed latency.

Both performance tests passed with the existing `report_problem_startup_test.dart`,
`saved_prompts_migration_test.dart`, `saved_prompts_photo_recovery_test.dart`, and
`capability_flows_test.dart` in the 112-test final focused/gate run. All four
`app_diagnostics_test.dart` cases passed separately after the scheduling change,
including bootstrap failure/retry. Buffered capture tests passed in the
79-test memory/diagnostics manifest. See the parent report for commands and
scope. No raw error body, credential logging, storage format or localization
changes are introduced.

## Additional measured startup work retained

The connected harness observed two health calls before the first connected stream, not one. The second comes from `SettingsScreen.initState` → `_checkHealth` (`lib/ui/screens/settings_screen.dart:131`, health read at `:157`), because `HomeScreen` supplies every tab to `KitTabSwitcher` (`lib/ui/screens/home_screen.dart:339`, `:443`) and the switcher builds all of them under `Offstage` (`lib/ui/kit/motion/kit_tab_switcher.dart:480`, `:504`). The first health response makes the transport usable and mounts Home before the event stream says connected. This slice keeps that behavior; any lazy first-visit mounting change belongs in the non-chat kit switcher with tests proving selected-tab startup, visited-tab state retention, navigation semantics and transition behavior. It must not defer consent/security owners with a tab that merely displays them.
