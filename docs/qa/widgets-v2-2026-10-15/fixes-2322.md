# Widget fixes following APK 2322

Branch `codex/widgets-v2-fixes`, based on integration revision `f8259bdfb`.
The starting evidence is [the owner's 2321/2322 emulator report](emulator-2320.md).
This follow-up is local source/check evidence, not another emulator run.

Owner placement fixes `3c12a0e43` and `21b606ff1` remain intact:
`WidgetRouteActivity`, `WidgetOverlayActivity`, and `WidgetV2Style` are unchanged.
The bridge now also routes button taps to the service; its profile-independent
configure/style behavior is preserved.

## B3: tap-owned, bounded background connection

A direct immutable `PendingIntent.getForegroundService` starts the existing
`BackgroundConnectionService` from **Allow once / Reject / Stop / Approve plan /
Resume**. There is no activity trampoline. When the permanent service and its
Dart channel are available, the existing live gateway handles the action.
Otherwise a temporary Flutter engine executes `widgetActionMain`, loads the
saved profile, reconciles the exact target through the domain gateway, submits
once, returns a safe result, closes the transport and destroys the engine.

The temporary lease includes engine initialization and lasts at most 30 seconds.
Repeated taps do not extend it. Completion, failure, deadline, Android timeout
and service destruction clean up temporary work. A permanent live owner that
was already active, or is explicitly enabled during the action, survives the
one-shot cleanup. The path never writes the Stay connected preference, starts a
server/runtime, schedules a job/alarm, polls, or retries a mutation. Only a
widget tap can enter this path. The notification contains generic working copy.

On Android 14+ the temporary foreground type is **shortService alone**, not
shortService combined with dataSync. Android 13 and older use the existing
dataSync type with the same application watchdog. Persistent live mode remains
dataSync and keeps its normal Android 15 six-hour budget handling.

Platform rules checked against Android's documentation:

- [Background-start exceptions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
  include interaction with an app widget. The PendingIntent targets the service
  directly so the start is tied to that user interaction.
- [shortService rules](https://developer.android.com/develop/background-work/services/fgs/service-types#short-service):
  approximately three minutes maximum, no sticky restart, no starting another
  foreground service, and prompt shutdown on timeout. Combining it with another
  foreground type makes Android ignore shortService. Our 30-second watchdog is
  stricter; both timeout callback signatures are implemented. Changing from
  shortService to persistent dataSync requires a new foreground-start eligibility
  condition, such as the owner's explicit foreground settings interaction.
- [dataSync timeout](https://developer.android.com/develop/background-work/services/fgs/timeout):
  Android 15+ permits six background hours per 24-hour period. The temporary
  API34+ path does not declare dataSync at runtime or reset its pause receipt.

No platform rule prevented implementing the direct tap path. Some **gateway** targets cannot
safely be reconstructed: socket-agent transport-local approvals/runs, transient
transport credentials, or a Stop without an observed server user-message marker.
These retain **Background settings** recovery. Saved OC1/OC2 permissions are
re-fetched by exact request and session IDs. Stop requires the same latest server
user-message ID and fresh busy/retry status. OC1/OC2 abort is session-scoped:
the server has no atomic expected-turn compare-and-stop, so a competing remote
controller can still replace a run between the final read and abort. Phone-engine
AI Team actions require
real workspace data and the exact project revision; no engine is bootstrapped.
Steer and Voice still use their existing live-engine overlay paths.

Suspending the app preserves its private cached action target with
`connected=false`; the widget says **Connects when you tap**, without a live
timer/ring. The runner rechecks durable profile/scope/target ownership before
mutation. Profile switching/deletion or a replaced request/run fails closed.
A durable per-profile claim prevents duplicate dispatch after process death.
An unknown outcome remains uncertain and is never automatically retried. A
confirmed rejection releases its claim for a deliberate retry; network failures
before dispatch keep supported controls available. Pending controls stay tappable
so an abrupt kill cannot strand disabled launcher views; overlap remains blocked.
Accepted results remove the header receipt and patch only safe status fields.

The fallback opens `NotificationsSettingsScreen(page: NotificationsPage.background,
initialSection: 'background')` through `oc.shortcut = background_settings`.
It does not enable the preference. The original fallback-only implementation is
superseded by this on-demand path.

## B4–B6

- **B4:** when the terminal accepted result arrives, native removes its stored
  display receipt and the renderer restores the normal status header. Already
  persisted `accepted` receipts from older versions are ignored too. Rejected
  and uncertain outcomes retain their safe explanation; an uncertain action is
  never relabelled successful just because time elapsed. Dart may retain its
  receipt for deduplication without making it a permanent header banner.
- **B5:** session snapshots use `presentedSessionTitleText` with the selected app
  language, then the existing redaction and length limits. Default timestamped
  session titles and blank titles become **New conversation** / **محادثة جديدة**.
  Custom titles use the same presentation as the app.
- **B6:** the 2×2 card's step allows two lines. Its timer/step row grows with the
  content instead of clipping the second line at a fixed 18dp height. Actual
  launcher sizing, large text and Arabic wrapping still require visual retest.

## Usage placement

Both widgets already use `WidgetConfigureActivity`, and that route explicitly
accepts `UsageWidgetProvider`. No separate broken Usage configure branch was
found, and no configuration ownership checks were relaxed.

Usage metadata requested **3×2 / 180×110dp**, while Conversations requested
2×2. The picker screenshot confirms the larger footprint; the failed-drop
screenshot shows limited contiguous launcher space. A footprint rejection is
consistent with this evidence, but the screenshots do not contain the launcher's
rejection reason, so this is not a reproduced root-cause claim.

Usage now requests **2×2 / 120×110dp**, with explicit matching minimum resize
bounds. Below 180dp it displays the tightest remaining window in one full-width
column. At 180dp and above it retains the two preferred windows. API31+
responsive maps and the older Android orientation-aware size fallback cover
both widths. The picker preview reflects compact placement. Row-height fitting
and urgency ordering remain in use.

## Local verification

- `tool/qa/machine_lock.sh build -- python3 tool/qa/widgets_v2_native_check.py`:
  **41 JVM tests passed**, plus AAPT2 resource compile/link and focused Kotlin
  API compilation. Coverage includes the 30-second lease, single settlement,
  direct immutable FGS routing, receipt sanitization, cold-action eligibility,
  retryable temporary failure, pending controls and the earlier B4–B6/Usage fixes.
- Pinned Dart SDK `dart analyze` for the runner, entrypoint, snapshot, profile
  store, controller, app entrypoint, phone Team gateway and four test files:
  **No issues found**.
- `git diff --check` and localization completeness: passed. New detached native copy is present in English and
  Arabic; app-side recovery reuses the existing localized settings page.

The expanded native harness compiles the **full actual service lifecycle and
headless engine bridge**, with MainActivity, unrelated notification ownership,
receiver dependencies and AppCompat base theme stubbed. The JVM tests exercise
pure policy; these checks are not a full APK/Gradle build, launcher test, or
Android runtime lifecycle qualification. No Flutter commands/tests, emulator,
provider connection, signing, release, push, or home-directory package
modifications were performed.

Dart tests to run with the pinned Flutter toolchain (not run here):

```bash
flutter test --concurrency=1 \
  test/widget_action_runner_test.dart \
  test/phone_project_engine_gateway_test.dart \
  test/widget_snapshot_test.dart \
  test/widget_v2_contract_test.dart \
  test/app_lifecycle_test.dart \
  test/connection_v2_lifecycle_test.dart \
  test/background_live_test.dart \
  test/profile_deletion_test.dart \
  test/launch_shortcut_test.dart \
  test/launch_shortcut_native_contract_test.dart \
  test/launch_shortcut_routing_test.dart \
  test/usage_widget_snapshot_test.dart \
  test/notifications_settings_screen_test.dart
```

The new runner file supplies **21 cases** covering exact permission ownership,
Stop run proof, confirmed/uncertain replies, duplicate taps, deadline/cancellation,
profile deletion and same-scope target replacement, suspension preservation,
Team revision checks and target-only secret restoration without preference
writes. The Team gateway test verifies the deadline guard after the health read,
before command POST. Existing follow-up regressions cover presented titles,
settings routing and compact usage layout. Full Flutter suite and emulator
qualification remain owed.

## Focused emulator retest owed

1. With background mode **off**, run a conversation, leave/close the app and
   tap Allow once, Reject and Stop separately. Repeat after process termination
   without Android force-stop. Verify exactly one mutation, no full-app launch,
   receipt cleared on acknowledgement, and no service/engine/network left after
   settlement or 30 seconds. Verify the preference remains off. Repeat Resume
   and Approve plan with a real saved phone-engine Team endpoint already running.
   Test rapid taps, delayed startup, unavailable server, network loss after send,
   process death mid-action, profile deletion/switch, replacement request/run and
   changed Team revision. Unknown outcomes must not replay. Check Android 14 and
   15+: `dumpsys activity services` must show shortService only for the temporary
   action; an exhausted dataSync budget must remain exhausted. Check ordinary
   long-lived mode still works and a foreground opt-in during a pending action
   is not stopped by temporary cleanup. Verify unsupported targets open the exact
   Background setting with its value unchanged; deny notification permission too.
2. Stop or allow a request: once the result returns, the header must return to
   normal counts without persistent “Action sent”. Test a restored old receipt,
   failure, and uncertain delivery separately.
3. Verify default timestamped titles become **New conversation** in the list;
   check custom titles and Arabic. At 2×2, check the command step with a ticking
   timer and both permission buttons, including large font size.
4. Place Usage into a genuinely free 2×2 area on the previously crowded page,
   then on an empty page. Save, Cancel, and reconfigure with no profile and with
   a changed snapshot scope. Check 2×2 one-window presentation, then widen to
   restore both windows. If a drop still fails, capture launcher/app-widget logs
   and `dumpsys appwidget` to distinguish cell-allocation rejection from activity
   cancellation; do not call the placement journey verified until it stays.

## Merged-branch privacy regression follow-up

The on-demand descriptor previously copied directory/workspace into the widget
snapshot, violating its opaque project scope contract. Only `{fingerprint}` now
enters the snapshot. Routing lives separately in app-private
`oc.widgetTarget.<profileID>`, bound to that fingerprint and scope. The runner
rejects missing/stale targets; deletion removes the key, and suspension migrates
legacy snapshots without retaining their paths. Both null-aware collection
analyzer infos in `connection/widgets.dart` are fixed.

Regression coverage added to `widget_snapshot_test.dart`,
`widget_action_runner_test.dart`, and the original `widget_v2_contract_test.dart`
privacy case. Run these three Dart test files with the pinned Flutter toolchain;
Flutter tests were not executed here.

Follow-up checks: focused pinned Dart analysis (including the connection part
file and all three test files) reports no issues; the native harness passes
41 JVM tests plus resource/API compilation; `git diff --check` passes.
