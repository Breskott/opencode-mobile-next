# Add tools "OpenCode is unreachable" (P1) - 2026-09-29

## Root cause
Not a server, port or password problem. `ChannelSetupEngine._start`
(`lib/builtin/setup/setup_engine.dart`) sets `_jobComponents = job` and then
awaits the job's checks (about 2 s in Ubuntu). During that wait a status read
of the PREVIOUS finished job (poll, `restore()`, the This phone screen) went
through `_show`, which overwrote `_jobComponents` with the old job's rows.
`_emitLocal` then did `components[component.id]!` over those rows: a null check
(`_TypeError`) whenever the old job had a tool the new one lacks (first setup
had Python; Add tools AI Team/Voice does not re-run it). Device stack trace
(build 2065 with a diagnostic print):
`_emitLocal (setup_engine.dart:485) <- _start:277 <- run <- runPhoneServerAction.install`.
The unclassified `TypeError` renders as "OpenCode is unreachable" in
`productErrorText`; from Settings > AI Team `_runJob` had no catch, so the
error vanished and the page stayed Off.

## Fix
- `_emitLocal` takes the job being started (`job:`) and never indexes with `!`.
- `_startingJobId`: `_show` and `_refresh` ignore records of any other job
  until the runner has this one.
- Any exception in `_start` now ends as a failed job (`_failStart`), with the
  redacted technical text as the job error, so every entry point lands on the
  progress screen with plain words and Details instead of a throw nobody shows.

## Tests (test/builtin/add_tools_run_test.dart)
Fail first (3 x "Null check operator used on a null value" without the fix),
pass with it; plus a start that throws is a failed job with its text.
`test/setup_*` files (80 tests) pass; `flutter analyze` clean.

## Device proof (emulator-5554, release build 2065, dark theme)
- `00-before-2064-could-not-finish.png` build 2064 failure.
- `01`/`02` Settings > AI Team (Off) > Set up AI Team on this phone > Add tools.
- `03` progress "Adding AI Team" (steps 1-4 done, AI Team working) - was blank before.
- `04` "Turning on AI Team", `05` "AI Team is running on this phone",
  `06` AI Team page: On. Processes `gc` and `dolt` running.
- `07` Settings > This phone > Add tools > Voice typing: "Adding Voice typing",
  downloading 59 of 375 MB (was the instant error). Still downloading when
  the emulator was stopped; not waited to completion.
Python was already installed on the emulator image, so it could not be added
again; the same code path is covered by the Python test.
