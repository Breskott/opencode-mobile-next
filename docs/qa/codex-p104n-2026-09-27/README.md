# P10.4 Automatic voice setup — backend and native notification

Date: 2026-09-27. Branch: `codex/p104n`. Base: `dcf05c5efbf82781bcfb97b629f5cda86ead2382`.

## Scope

Finish line: a callable first-mic controller chooses an existing pack using
physical RAM, exposes its download size and consent, downloads with progress
and a native notification, and starts the existing recorder after verified
installation.

Non-goals: UI implementation, new packs, background download services, routing
notification taps to Settings, APK builds, signing, publication or pushes.

Read set: `AGENTS.md`; only sections 2, 3, 13 and 15 of revamp `STANDARDS.md`;
the [earlier feasibility record](../codex-p104-2026-09-27/README.md);
`lib/voice/`, Android voice handling and
the affected voice tests. This worktree has no `HANDOFF.md`.

Write/ownership sets:

- Controller owner: `lib/voice/automatic_setup.dart`, the small
  `model_manager.dart` additions, this record and verification logs.
- Native bridge owner: `lib/voice/automatic_setup_platform.dart`, new
  `VoiceDownloadNotifications.kt`, four small hooks in `MainActivity.kt`, and
  `test/voice_automatic_setup_platform_test.dart`.
- Behavior-test owner: `test/voice_automatic_setup_test.dart` only, against the
  controller/platform API agreed before editing. Workers ran no tests/builds.

No file under `lib/ui/` or the prohibited single-owner Dart files was edited.

## Feasibility and contract

The earlier blocker was the absent NotificationRouter and authorization for
Kotlin. The user's explicit P10.4 follow-up authorizes the smallest native
voice-download notification and both MethodChannel halves. That instruction
takes precedence over ARCH-10's interim prohibition on another notification
path. This is a narrow `oc/voice` bridge, not a fabricated NotificationRouter or
a coding/session alert. No remote adapter or credentials are needed. Existing
public, pinned HTTPS downloads and SHA-256 verification remain authoritative.

Device total RAM is already returned through `getDeviceInfo`; no Java heap
class fallback was added. Automatic selection ranks the existing packs by
their manifest minimum RAM: small at 3400 MB, base at 1536 MB, tiny at 1024 MB.
ABI and available-storage checks can reduce the choice. Unknown/nonpositive
total RAM blocks automatic setup and leaves manual settings available. An
already installed, supported selection is preserved instead of upgraded.

Notifications are best effort: denied permission, a disabled channel, a missing
bridge or a failed post is exposed as unavailable while the foreground flow
can continue. Native fixed English/Arabic copy carries no filenames, model
technical names, arbitrary text, or credentials. Notification taps open the app;
the absent router means they do not deep-link to Voice settings. Active notices
expire after 15 minutes without updates so process death cannot leave an
indefinite ongoing notice; a very long stalled download/verification may lose
its notice. This does not keep downloads alive in the background.

## UI hook-up

New public APIs:

- [VoiceAutomaticSetupController](../../../lib/voice/automatic_setup.dart)
  (`ChangeNotifier`): construct with the composer's existing
  `VoiceComposerController`. It does not own/dispose the composer or shared
  manager. Use one active setup controller for that composer/shared manager.
- [VoiceSetupPlatform](../../../lib/voice/automatic_setup_platform.dart): the
  injected platform seam, defaulting to `AndroidVoiceSetupPlatform`.

```dart
final composer = await VoiceComposerController.create();
final setup = VoiceAutomaticSetupController(composer: composer);
// Observe setup with the kit's existing listening/builder arrangements.
await setup.requestMicrophone(); // first mic tap
// When stage == consentRequired, show localized pack name + downloadBytes.
// On affirmative consent only:
await setup.confirmDownload(allowMetered: userApprovedMobileData);
```

`confirmDownload()` on unmetered Wi-Fi still requires the explicit initial
download consent action. `allowMetered: true` must reflect explicit consent to
mobile/metered/unknown-network use, never a default. Cellular is classified as
metered even if Android calls the plan unmetered; VPN and failed probes are
conservatively unknown. Network is checked before and after the notification
permission prompt. A switch to metered/unknown returns to `consentRequired` with
updated `network`; offline becomes `blocked/offline`. These are start-time
checks; this patch does not monitor network handovers during an active HTTP
transfer. Consent is per attempt, never persisted.

| UI need | Public state/action |
|---|---|
| First mic tap/retry | `requestMicrophone()`; duplicate pending calls do not start another operation |
| Pack and download offer | `pack`, `downloadBytes` (integer bytes); localize by pack ID |
| Consent | `stage == consentRequired`, `network`, `confirmDownload(allowMetered: ...)` |
| Progress | `stage == downloading` or `verifying`, `receivedBytes`, `downloadBytes` |
| Recording | `starting` then `listening`; subsequent transcript/stop/draft behavior remains on `composer` |
| Notification limitation | `notificationAvailable`: null until attempted, false unavailable, true accepted posting (not proof of viewing) |
| Recovery | `blocked`/`failed` plus typed `problem`; do not display raw manager/composer exception text |
| Leave, cancel, lifecycle pause | `await setup.cancel()`; revoke pending auto-start and cancel its download, dismiss its notice |
| Teardown | `setup.dispose()` before `composer.dispose()`; it also invalidates delayed callbacks |

Localize stages/problems in the UI unit. The controller exposes no user-facing
error strings. Preserve bytes for ordinary localized MB/GB formatting above
Details; do not use `formatModelBytes` (MiB), filenames, or “Whisper INT8” there.
`pack` retains technical manifest fields solely for the Details surface. In
`listeningFailed`, the UI can use existing typed microphone-permission handling
and `voiceDevicePlatform.openAppSettings()`; do not stringify exceptions.

The UI owner must wire lifecycle cancellation and route teardown. A new attempt
is ignored while a cancelled operation is still unwinding; retry after its
returned Future completes. Setup does not hold the microphone in a background
service and never resumes recording after restart. If a download was already
started elsewhere, including its device preflight, the controller reports
`blocked/busy` and does not take it over.

Settings › Voice can share `composer.models` / `VoiceModelManager.shared()`:
`voiceModelPacks`, `isInstalled`, `supportFor`, `selectPack`, `deletePack`,
`setLanguage`, `state`, and `downloadInProgress` (includes preflight). Use the
new consent flow for automatic setup, rather than calling `downloadSelected`
behind its consent surface. Existing
[`ReadAloudController.voices()`](../../../lib/voice/read_aloud.dart) returns
system voices; `speak(..., voiceID: ...)` uses a chosen voice under its existing
playback consent. This patch adds no TTS preference format or new voice packs.

## Persistence and privacy

No new preference keys, consent history, diagnostics, notification text or
profile data are stored. Pack selection and language keep their existing
unscoped device keys and fixed manifest values (no redaction: they are not
secrets, and masking would break the round trip). Pack deletion and restart
verification continue through the existing manager/downloader. Binary model
files and the existing pinned integrity manifest are unchanged.
There is no schema migration. Downloads have no provider/server credentials.

## Verification and shipping state

Behavior tests are supplied in
[`voice_automatic_setup_test.dart`](../../../test/voice_automatic_setup_test.dart)
and
[`voice_automatic_setup_platform_test.dart`](../../../test/voice_automatic_setup_platform_test.dart).
They cover RAM boundaries/unknown RAM/heap-class rejection, ABI/storage/capture,
consent, network changes, installed-pack reuse, progress and verification,
notification failures, retry, persistence/deletion, duplicate calls,
external-download ownership, cancellation/disposal and delayed completions.
The bridge tests exercise the actual Dart MethodChannel calls with mocked
native replies; they do not execute Kotlin.

Formatting used the pinned SDK's `bin/cache/dart-sdk/bin/dart` with
`--suppress-analytics format --language-version=3.10`. The requested wrapper
cannot start because it tries to write `bin/cache/engine.stamp.tmp.*` and
`bin/cache/engine.realm` on a read-only filesystem. The direct formatter has the
same SDK provenance and completes; the missing worktree package configuration
causes a `flutter_lints` resolution warning.

Required verifier commands (pinned `flutter`, serial):

```sh
flutter pub get
flutter test --concurrency=1 test/voice_automatic_setup_test.dart test/voice_automatic_setup_platform_test.dart test/voice_model_manager_test.dart test/voice_controller_test.dart
flutter analyze
```

The coordinator's release APK build must compile-check the Kotlin hooks. Native
permission denial/channel disabling, EN/AR notification rendering, notification
tap behavior, first-mic UI consent, lifecycle integration, screenshots and
accessibility remain unverified. No full-suite, Android build or device run was
performed by this unit. The full product finish line depends on the later UI
unit's hook-up; the new setup flow is not enabled in existing screens.

Final command results:

- [format.txt](format.txt): exit 0, five Dart files formatted with no remaining
  changes; dependency-resolution warnings described above.
- [tests.txt](tests.txt): exit 1 before the Flutter test runner starts; read-only
  engine cache. **No test pass is claimed.**
- [analyze.txt](analyze.txt): exit 1 before analysis starts; same cache block.
- `git diff --check`: pass; README local links checked. No UI/prohibited-file
  writes appear in the final file inventory.
- [commit.txt](commit.txt): `git add` exit 128, cannot create the worktree's
  `index.lock` in read-only shared Git metadata. No commit created. Exact intended
  message is in root [`COMMIT_MSG.txt`](../../../COMMIT_MSG.txt).

| State | Result |
|---|---|
| Implemented | Backend/controller, native bridge, tests and hook-up contract supplied |
| Enabled | No; UI owner must wire first-mic and Settings surfaces |
| Verified | Formatting, source review and diff/link checks only; execution gates blocked |
| Committed | No; Git metadata read-only, working-tree changes retained |
| Deployed / released | No |

Environment blocker: verifier must run dependency resolution, the four focused
test files and whole-tree analysis with writable pinned Flutter cache/Git
metadata. Coordinator must compile-check Kotlin in the APK build. This record
does not claim that authored-but-unrun tests establish runtime behavior.
