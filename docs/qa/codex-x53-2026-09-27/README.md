# P5.3 Running on this phone — x53 feasibility (2026-09-27)

Status: **blocked; no Dart implementation added**. The requested inventory and
measured foreground budget cannot be supplied by the current callable contracts
within the allowed write set. Per the owner's instruction, “If a slice's
feasibility check fails, stop and write why in the README,” implementation stops
here. This is not an unblocked or completed P5.3 slice.

Candidate: `9e33392cd470296b69f2b6a3fc9b5b5bd724182f`, branch `codex/x53`, initially
clean. Read AGENTS.md and only sections 2, 3, 13 and 15 of the revamp standards
(heading search followed by bounded sed ranges), plus the
[previous feasibility record](../codex-p53-2026-09-27/README.md).

Finish line: expose a truthful local process inventory with state, available
CPU/memory/uptime, measured Android dataSync budget, and controller-routed stop
and restart operations. Non-goals: UI, native bridges, arbitrary shell-based
process discovery or killing, releases, and invented resource estimates.

Read set: existing domain/state, built-in, Termux and background contracts and
their native implementations. Write set after feasibility failure: this record
and root `COMMIT_MSG.txt`. Dependency: native inventory and budget telemetry.
Acceptance: all requested populations have an explicit coverage result;
unavailable measurements remain unknown; controls preserve ownership and
recovery policy. Focused checks for this documentation-only outcome: relative
links and `git diff --check`. No parallel implementation slices were started.

## Current evidence and blockers

| Contract | What exists | Missing prerequisite |
| --- | --- | --- |
| [BuiltinLinuxStatus / status](../../../lib/builtin/builtin_linux.dart) | Built-in server boolean and registered service names | Built-in agents/dev-service inventory, process identity, start time and measurement availability. `bytesUsed` is storage, not process memory. |
| [TermuxProcesses](../../../lib/termux/processes.dart) | Termux-only scan and stop; CPU/RSS/elapsed fields | Does not cover the app-owned built-in host. Missing numeric values parse as zero, so the adapter cannot distinguish denied readings from measured zero. PID-only stop is not a host-neutral identity-checked restart contract. |
| [PhoneHost](../../../lib/state/phone_host.dart), [LocalServerControls](../../../lib/state/local_server_controls.dart) | Existing server refresh/start/stop and Termux restart; recovery and disconnect handling | No process measurements or Android budget accounting. These are usable server controls, but do not cover all requested inventory items. |
| [BuiltinTeam](../../../lib/builtin/team/builtin_team.dart) | Managed team lifecycle; `turnOff()` disables recovery durably | `stop()` alone allows recovery to restart the team. Agent/dev-service process identity and restart descriptors are not provided by this lifecycle contract. |
| [BackgroundLiveController](../../../lib/background/live_background.dart) | `active`, `enabled`, timeout signal, `refreshStatus()` | No consumed duration, accounting window, reset epoch, complete history, or resume time. Timing Dart polling would lose background/dead-process intervals. |
| [Native background status](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/MainActivity.kt), `backgroundStatus()` | Enabled/active and policy booleans | No budget telemetry returned to Dart. Native changes are explicitly outside this job's scope. |

The existing [background service](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/BackgroundConnectionService.kt)
handles `onTimeout` and stops. This signal proves exhaustion occurred; it does
not provide usage history or a future resume timestamp. The
[built-in service](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/BuiltinServerService.kt)
uses `FOREGROUND_SERVICE_TYPE_SPECIAL_USE`, whereas background live mode uses
`dataSync`. Do not charge built-in or Termux server uptime against the app's
dataSync allowance.

Android's [foreground service timeout documentation](https://developer.android.com/develop/background-work/services/fgs/timeout)
(checked 2026-09-27) describes six background hours within a 24-hour period,
shared by an app's services of that type, with a timer reset when the user brings
the app to the foreground. Thus “used today” is not a calendar-midnight countdown
or a sum of all phone-process uptime. The contract must distinguish any calendar
usage statistic from the platform enforcement allowance. It must also identify
whether a reading is locally accounted or platform-authoritative; missing
history must never display zero used or six hours remaining.

Contract problems: PROC-17 and ARCH-4 cannot be satisfied for the requested
measured budget and complete inventory using current Dart callables.
`blocks: true`; dependency/outside-write-set: native bridge owner. Required
changes are below. No shell workaround, synthetic timer, placeholder controller,
or callbacks with no production provider were added.

## UI hook-up

**No new Dart API is implemented in this branch.** Keep P5.3 unavailable until
the dependency lands. Existing server controls remain the authority. Do not
present Termux-only results as a complete phone inventory or unavailable
measurements as zero.

Minimum contract for the native/controller owner, before the Dart/UI unit:

1. Inventory readings with host scope, covered populations, observation time,
   stable instance identity (including process start identity), registered
   controller/service association, state, and nullable RSS bytes, CPU percentage
   and elapsed duration. Each unavailable reading needs a reason. Never expose
   command lines, environment variables or credentials to presentation code.
2. Typed stop/restart capabilities referencing the existing owning controller.
   Revalidate target identity at execution, refuse protected/replaced targets,
   and preserve recovery policy. Restart is unavailable where no managed launch
   descriptor exists; never replay captured process command lines. User stop of
   built-in AI Team must use durable `turnOff()`, with the coordinator handling
   the existing profile/orchestration synchronization contract.
3. A native dataSync accounting snapshot and change signal: applicability,
   service/app scope, observed usage, coverage start/end, reset epoch, source,
   timeout/exhaustion state and nullable remaining/resume values. Account for
   foreground transitions, multiple services, service termination and app
   restart. Persist only safe numeric/enum accounting data if needed; any
   profile-specific key must follow `oc.<what>.<profileId>`. A per-profile timer
   must not masquerade as the shared app budget. Do not claim Android exposes an
   authoritative usage getter without verifying one.

After those providers exist, implement a `RunningOnPhoneController` with an
immutable `snapshot`, `refresh()`, controller-routed `stop(itemIdentity)` /
`restart(itemIdentity)` and `dispose()`. Expose loading, partial coverage,
stale/error, unsupported measurement, and operation outcomes explicitly. The
future UI should subscribe only while visible and stop polling when backgrounded.
Invalidate outstanding refreshes and actions on profile deletion/change and
disposal. This paragraph describes the follow-up API, not a callable API today.

Future focused flutter_test coverage: partial inventory and unknown readings;
stop/restart routing and replaced/protected targets; refresh failure/disposal;
budget exhaustion, resets, missing history and service scope. Fixtures must use
fake credentials only. If technical text is ever persisted, pass it through
`KitRedact`; this change persists no runtime data and adds no storage keys.

## Verification and delivery

Implemented: no. Enabled: no. Verified: source feasibility only. No Flutter,
analyzer, device, emulator, signing or release commands run, as instructed.
No Dart changed, so behavior tests and Dart formatting are not applicable.
No UI, single-owner Dart files, or Kotlin files edited. No push or release.

The intended conventional commit message, including both requested attribution
trailers and `[skip ci]`, is in root `COMMIT_MSG.txt`. Committed locally; no push.

Documentation checks: all 10 relative links resolve; both new files have no
trailing whitespace; `git diff --check` passed. `COMMIT_MSG.txt` is ignored by
the repository and retained locally as requested.
