# P10.4 Automatic voice setup — backend feasibility

Date: 2026-09-27. Branch: `codex/p104`. Inspected base: `d97420b8`.

Status: **blocked at feasibility; no implementation added**.

## Scope

Finish line: expose a Dart controller for first-mic setup that selects an existing
pack using total physical RAM, exposes download size and mobile-data consent,
downloads with progress and a notification, and starts listening when ready.

Non-goals: new packs, UI implementation, native Kotlin changes, releases.

Read set: `AGENTS.md`; revamp `STANDARDS.md` sections 2, 3, 13 and 15;
`lib/voice/`; `lib/background/live_background.dart`; the existing Android voice,
network-policy and coding-notification handlers; relevant existing tests;
read-only `lib/ui/kit/kit_redact.dart`; P10.4's work-unit entry.

Planned write set: a voice setup service/controller, its behavior tests, and this
record. Actual write set: this record only (plus root `COMMIT_MSG.txt` if Git
metadata is not writable). No UI, single-owner or Kotlin file was changed.

Acceptance: gate on `totalMemoryMb`, never `memoryClassMb`; expose byte counts
and semantic state to the UI, leaving technical model names and MiB to Details.
Focused checks after implementation would cover selection thresholds, unknown
RAM, consent, progress, cancellation/disposal, failure/retry, and listening only
after verified installation. Implementation did not start.

## Feasibility and blockers

The user explicitly requires stopping when a slice's feasibility check fails.
The following notification dependency prevents this slice's finish line within
the authorized write set:

- [STANDARDS.md §3, ARCH-10](../../ux-system/revamp/STANDARDS.md#3-architecture-boundaries)
  requires notifications through `NotificationRouter` after P6.7; before it
  lands, existing native services own notifications and “no unit adds another
  path.” `rg -n 'class\s+NotificationRouter' lib` finds no implementation in
  this candidate. The architecture test also encodes this transition in
  [architecture_boundaries_test.dart](../../../test/architecture_boundaries_test.dart).
- [live_background.dart](../../../lib/background/live_background.dart),
  `CodingAlertKind` and `showCodingAlert`, exposes coding alerts with session
  destinations, and requires live-background enablement and notification
  permission. It has no voice-download kind, byte progress or Voice-settings
  destination. Using a coding completion alert would show incorrect copy and
  navigate to the wrong feature.
- [BackgroundConnectionService.kt](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/BackgroundConnectionService.kt),
  `showCodingAlert` (line 250 onward), owns the fixed coding-event copy. The
  existing connection-status progress indicator represents running sessions,
  not a voice-model download. The user prohibits changing all Kotlin files.

Required dependency: the notification owner must land the permitted router and
a native voice-download notification contract (start/update/complete/fail/cancel,
Voice-settings destination, and truthful notification permission/delivery
results). Then this slice can call that public API. No speculative adapter or
no-op notification callback was added. Contract problem: ARCH-10's prerequisite
is absent; **blocks: true**. No standards change is requested.

Other inspected prerequisites:

- Total RAM is already callable: `AndroidVoiceDevicePlatform.getDeviceInfo()`
  reads `totalMemoryMb`. `MainActivity.voiceDeviceInfo()` derives it from
  `ActivityManager.MemoryInfo.totalMem`. `memoryClassMb` is diagnostic only.
- `VoiceModelManager.supportFor()` already gates known total RAM against the
  existing manifest thresholds (tiny 1024, base 1536, small 3400 MB). It allows
  unknown RAM for manual selection; an automatic selection policy still needs
  explicit unknown-RAM handling. No automatic selection was implemented here.
- The downloader has pinned HTTPS URLs, SHA-256 verification and progress.
  Public model downloads do not use server/provider credentials. No remote
  download or live device verification was performed.
- `BackgroundLiveController.monitorWifiAvailable()` exposes Wi-Fi presence,
  not cellular/metered/offline classification. A future setup flow can ask
  conservatively for all non-Wi-Fi/unknown results; precise mobile-data copy
  needs a richer network contract. This is a limitation, not the primary stop.

## UI hook-up

**There is no new automatic-setup API to wire in this change.** Keep the existing
manual flow until the notification dependency and setup controller land. These
existing public APIs can be reused by the later UI/controller unit:

| Need | Existing Dart API | Boundary |
|---|---|---|
| Shared pack state | `VoiceModelManager.shared()`; `ChangeNotifier` listeners | Shared manager is not owned by an individual screen. |
| Device support | `manager.deviceInfo.totalMemoryMb`; `manager.supportFor(pack)` | Never select using `memoryClassMb`; unknown RAM is not a measured capacity. |
| Packs and size | `voiceModelPacks`; `pack.downloadBytes`; `manager.isInstalled(pack)` | Localize display labels and format ordinary size outside Details; do not reuse technical file names or `formatModelBytes` above Details. |
| Pack settings | `manager.selectPack(pack)`; `setLanguage(language)`; `deletePack(pack)` | Existing manager owns pack/language preferences and model files. |
| Download | `manager.downloadSelected()`; `state`; `progress.received/total/fraction`; `cancelDownload()` | No notification or mobile-data consent is currently part of this API; `ready` follows verification. |
| Recording | `VoiceComposerController.create()`; `startListening()`; `state` | Currently returns `modelRequired` when no pack is ready; does not download automatically. Preserve permission handling and cancel pending auto-start when the user leaves. |
| System voices | `ReadAloudController.voices()` → `ReadAloudVoice(id, label, locale)` | Separate from recognition packs; playback requires existing explicit consent. This change adds no voice preference persistence. |

After the prerequisite lands, the intended small controller should publish
typed setup state, selected pack/byte size, consent-needed state, download
progress, notification availability and recoverable failure. Its public actions
should cover first-mic request, consent continuation and cancellation. Freeze
that API against the actual router contract before implementation; these are
requirements, not callable methods delivered here.

Settings › Voice and the first-mic surface remain the UI unit's work. No visual,
localization, accessibility or first-recording acceptance is claimed. Any future
persisted diagnostics or text must pass through `KitRedact`; this change writes
no application data, preferences, credentials or diagnostics.

## Verification and shipping state

- Initial working tree: clean. Source evidence inspected at `d97420b8`.
- Documentation-only checks: all four local Markdown links resolve;
  `git diff --no-index --check /dev/null <README path>` passes.
- No Dart was added or modified, so formatting, behavior tests and analyzer
  runs are not applicable (PROC-28). Existing tests were not rerun. No Flutter
  pass, device proof or full-suite pass is claimed.
- Implemented: no; feasibility record only. Enabled: no. Verified: source
  feasibility only. Deployed/released: no.
- Committed: no. `git add` failed: the shared worktree Git metadata is on a
  read-only filesystem, so Git could not create `index.lock`. Changes remain
  in this worktree; the exact intended message is in root `COMMIT_MSG.txt`.
