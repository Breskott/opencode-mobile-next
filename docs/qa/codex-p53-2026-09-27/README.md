# P5.3 Running on this phone — backend feasibility (2026-09-27)

Status: **blocked at feasibility; no implementation added**.

Candidate inspected: `024e97b0d1ef270c83927b438a0843c048adc773`, branch
`codex/p53`, initially clean worktree.

Finish line: expose a host-neutral process controller with six labelled kinds,
activity, memory in MB, a background-process budget and one stop confirmation
per kind. Non-goals: UI changes, conversation management, automatic cleanup,
native bridge changes or release work.

Read set: `AGENTS.md`; revamp `STANDARDS.md` sections 2, 3, 13 and 15;
existing Termux process service, built-in host and local-terminal contracts,
their Android implementations, and process tests. Write set after the failed
feasibility check: this record and, if needed, root `COMMIT_MSG.txt` only.
Dependency: a callable process inventory and stop contract for the built-in
host, owned by the native bridge coordinator. No agents or tests were started.

## Feasibility result

The owner's instruction is: “If a slice's feasibility check fails, stop and
write why in the README.” PROC-17 likewise requires the current callable
contract before building an adapter. This slice stops here.

| Existing contract | Evidence | Gap for P5.3 |
| --- | --- | --- |
| Termux scan and PID/group stop | [processes.dart](../../../lib/termux/processes.dart), lines 180–210 | Runs through `oc/termux` and Termux-owned `~/.oc/tools.sh`; does not inventory the app-owned built-in host. Existing categories also lack Claude Code and terminals. |
| Tool installation and dispatch | [bridge.dart](../../../lib/termux/bridge.dart), lines 278–323 | Installer uses the fixed Termux home and tools path. Reusing the current service does not make its scope host-neutral. |
| Built-in status and service stop | [builtin_linux.dart](../../../lib/builtin/builtin_linux.dart), `BuiltinLinuxStatus`, `status`, `stopServer`, `stopService` | Reports service names/running state, not per-process ownership, CPU or RSS; stops registered services, not arbitrary helper/dev-service inventory targets. |
| Built-in terminal listing | [local_terminal.dart](../../../lib/builtin/local_terminal.dart), `LocalTerminalListing`, `ChannelLocalTerminalBackend.list` | Lists known shells and an aggregate count, not all processes with activity and memory. Shell stop is available, but cannot cover the other kinds. |
| Aggregate process count | [BuiltinLinux.kt](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/BuiltinLinux.kt), lines 644–655 | Counts processes owned by the app UID, including the app itself; returns zero if listing fails. It is not a measured background-process count or a device limit. |

`BuiltinLinux.run` can execute a shell script. That is a possible future
implementation mechanism, not an existing verified inventory/stop contract.
Porting the Termux scanner through it would require proving host ownership,
protected targets, PID identity and resource measurements. Built-in Ubuntu also
substitutes fixed `/proc/stat`, `loadavg` and `uptime` values when Android denies
access ([BuiltinLinux.kt](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/BuiltinLinux.kt),
lines 163–188 and 701 onward), so generic shell-derived CPU calculations cannot
simply be assumed accurate. No such workaround was built.

No inspected callable API supplies the effective background-process limit.
The example “18 of 32” must not be manufactured from an app-UID count and a
hard-coded denominator. If 32 is intended as a product advisory budget, the
contract must identify it as advisory and define the counted population.

Existing access uses app-local method channels and Termux's run-command
permission, not provider credentials. No authentication workaround is needed
or proposed. No credentials, process listings or command lines were captured,
logged or persisted.

## UI hook-up

**There is no new Dart API to wire in this branch.** Keep the new host-neutral
tool unavailable until the missing contract lands; do not treat the existing
Termux-only scan as a complete phone inventory. Existing screens are untouched.

Proposed small API for the follow-up unit (design only, not implemented):

- `RunningOnPhoneController`, a `ChangeNotifier` with an immutable snapshot,
  `refresh()` and `dispose()`. Expose availability, loading, empty, ready,
  stale/error and stopping states explicitly. Poll only while the tool is
  visible, with its interval documented; no background cleanup.
- Snapshot groups keyed by `openCodeServer`, `aiTeam`, `claudeCode`,
  `devServices`, `terminals`, `helpers`. Each process needs a host-scoped
  identity, safe label, activity enum (`busy`, `idle`, `unknown`), nullable
  memory in MB and an explicit stop capability/reason. The UI localizes these
  enums and supplies a labelled mark; colour is supplementary.
- Budget data with a count, scope, nullable limit and source/advisory flag.
  Unknown measurements stay unknown. Define the activity sampling policy and
  MB conversion once in the service instead of separately in screens.
- `prepareStop(kind)` returns one confirmation containing labelled targets
  and consequences for that kind. `confirmStop(plan)` revalidates identity and
  protection, stops only the confirmed targets and returns stopped, remaining
  and refused outcomes. Cancelling sends no stop. New processes are not added
  silently to an old confirmation.

The bridge owner must first provide an app-owned inventory (identity including
start time, parent/owner, service or shell association, real resource readings
or explicit unknowns), identity-checked stopping that protects the app and
control infrastructure, and defined budget semantics. Both halves of that
bridge are a single-owner unit; Kotlin is outside this task's permitted scope.
The follow-up Dart controller can then adapt Termux and built-in hosts without
exposing either transport to UI code.

The later UI unit owns localization, the six labelled marks, 48 dp stop targets
and one confirmation per kind. `running-work-sheet` continues to represent
conversations; this tool represents processes. Any future persisted technical
text must pass through `KitRedact.text`; this unit adds no persistence.

## Verification and delivery

Documentation-only blocker record: no Dart changes, so formatter, behavior
tests and Flutter analyzer are not applicable. No full-suite, runtime,
emulator, screenshot, accessibility or stop-safety pass is claimed. Follow-up
behavior tests must cover grouping/activity/unknown measurements, budget
scope, cancelled and stale confirmations, protected targets, partial stops,
refresh failures, disposal and redacted output.

Implemented: no. Enabled: no. Verified: source feasibility only. Deployed and
released: no. Commit result and documentation checks are recorded below.
