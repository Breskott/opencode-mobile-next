# slice-qa-autostart2 — "running but not answering" after relaunch (QA-03, 2026-09-28)

Follow-up to [slice-qa-autostart](../slice-qa-autostart-2026-09-28/README.md) after emulator QA pass 3 on build 2060 ([QA-03](../emulator-qa-2026-09-28/README.md#pass-3--build-2060): 158 Starting → 161 "stopped" → 163 Start and connect still "stopped" → 164 switcher "Running" while the status line says "isn't answering").

Finish line: after any cold relaunch the in-app server either answers and the app connects, or a server that runs but stays silent is replaced through the app's own tracked process; a running server is never called "stopped". Non-goal: the healing budget, phone setup, the status slot.

## What was checked on emulator-5554 (build 2060, then 2061)

- **No survivor after force-stop.** With OpenCode running, `am force-stop` removed the whole tree: before, the app (pid 1655), `libproot.so` and `opencode` all in cgroup `uid_10217/pid_1655`; 3 s after, no proot, no `opencode`, nothing listening on 4097. Android kills the app's process cgroup, so a leftover proot holding the port, a stale password or a stale status file is **not** what QA saw. The native service map lives in the app process and dies with it, so a cold launch never reads "running" from a previous process.
- **What the server really does after launch** ([device-2060-launch-probe.txt](device-2060-launch-probe.txt)): the port listens about 15 s after start, and the first authenticated health probe then **hung 8 s (receiveTimeout)** before later ones answered. On the loaded QA host that first window is longer.

## Root cause

When the connect right after a start failed (the server runs but is still too busy to answer inside the 8 s timeout), nothing ever connected again, and the page said the wrong thing:

1. `PhoneServerHealing.connectIfNeeded` allowed **one connect per start** (`'<profile>:<readyCount>'`). The healing owner's 5 s health poll went on finding the server healthy and publishing `ready`, but each reconnect was deduplicated away, so it never tried again.
2. The diagnosis for the in-app server maps *every* non-auth connect failure (refused, timeout, anything else) to **"OpenCode inside the app is stopped"**, while native status said the process runs (164's "Running").
3. **Start and connect** does restart the process (the start stops the app's tracked process tree first), but on the same loaded device the new process hit the same first-connect timeout, which led to the same dead end (163).

That matches 158 → 161 → 163 → 164. A related gap: a process that really does run but never accepts our password (401), or stays silent long past booting (possible when the Flutter engine restarts inside a live process), was left alone by the launch start, which only started a server that was *not* running.

## Fix

- `connectIfNeeded` (lib/builtin/phone_server_healing.dart): after a failed attempt, the healing owner's foreground health poll connects again once the back-off has passed (10 s, doubling, at most 60 s). It only does this while the server answers its health check, the app is in the foreground and the reconnect policy allows it. **Try again** connects at once, without waiting for the back-off.
- **Stale server at launch** (`_launchStartWanted`): a running tracked process is probed with our password. If it rejects the password (401), it is replaced at once. If it stays silent, the launch waits while the process is younger than 90 s (it may still be booting) and replaces it once it is older. Replacing it goes through the starter's explicit start, whose native `launchService → removeService → stopTree` stops **the app's own tracked `Process` and its descendants by pid**, never by pattern. Native status now reports `serverUptimeMs` (BuiltinLinux.kt `Service.startedAt`, `SystemClock.elapsedRealtime`) for that age. An older APK without it gets a 30 s grace.
- The launch start no longer runs when the healing restart in the same check already brought the server up. If it died since, that counts as a crash for the healing budget, not a second launch.
- **Page**: when the in-app process runs (`BuiltinServerStarter.runningFor`, fed by every status read) and the connect failed, the root page shows "OpenCode on this phone isn't answering" with Restart and Try again, matching the status line, instead of "stopped".

## Tests (reproduced first)

In `test/builtin_server_autostart_test.dart`, both new tests failed on the base `e3805cba` (temporary worktree) and pass now:

- "a running in-app server whose first connect failed is not called stopped, and is connected again while it answers": base showed "OpenCode inside the app is stopped" and made only 1 connect.
- "a running server that rejects our password is replaced at launch": base made 0 starts.

The first test in that file now covers the real "stopped" case (the server died after answering); the new state covers "running".

New in `test/phone_server_healing_test.dart`, group "a running server that does not answer (QA-03)":

- a server that rejects our password is replaced;
- one older than the stale age that stays silent is replaced;
- a young booting one is waited for, not killed;
- a young one that never answers is replaced once it is stale;
- a healthy server whose connect failed is connected again by the health poll, and not again once connected;
- the back-off holds automatic reconnects, while Try again does not wait.

Run serially and passing: builtin_server_autostart, phone_server_healing, builtin_server_recovery, builtin_server, builtin_linux, app_exit_recovery, builtin_recovery_bridge, saved_server_connection_card and app_lifecycle, plus the gates kit_ratchet, redaction, ui_glossary, no_raw_error_text, kit/kit_manifest, kit/kit_draft_manifest, architecture_boundaries and golden_harness. `flutter analyze` over the whole project is clean.

## Device proof — build 2061 on emulator-5554

Built with `tool/qa/machine_lock.sh build -- flutter build apk --release --build-number=2061` and signed with the local release key (`1DE5BF08…D60C`, the same as 2060). Installed with `install -r` over 2060's data (the Ubuntu set up during QA). AVD `OC_API35` with `-memory 4096 -cores 2 -gpu swiftshader_indirect`.

**Emulator limit:** on this host QEMU exits with status 139 about 2–3 s after the app connects to the in-app server. It did so on 2058, 2060 and 2061, with `-gpu guest` as well, and with airplane mode on. Earlier checks ruled out a full disk and the guest network. It looks like the same crash QA saw in pass 3. So every relaunch was force-stopped as soon as the app had connected (its first session list answered 200), before QEMU could die.

| Run | Result | Evidence |
|---|---|---|
| Force-stop → relaunch ×5 in a row (L2–L5 about 12 s apart, so inside the healing back-off) | Each launch started OpenCode and connected, in 25.2 s (first, cold) and then 9.8 / 9.3 / 9.7 / 9.1 s. No stopped page. The healing restart (`linux.restartServer`) and the launch start (`linux.startServer`) alternate as the healing back-off allows. | [device-2061-relaunch-1…5-starting.png](device-2061-relaunch-4-starting.png), [device-2061-relaunch-traces.txt](device-2061-relaunch-traces.txt) |
| Stop (the notification's Stop intent) during a start → force-stop → relaunch | Native intent `wanted=false`. The relaunch made one status read and **no start**, and shows "OpenCode inside the app is stopped" with Start and connect. No OpenCode process runs. | [device-2061-stop-then-relaunch.png](device-2061-stop-then-relaunch.png) |

Not proven on the device: the "running but not answering" page itself and its reconnect, because the emulator cannot be made slow on purpose and dies after a connect. The widget and unit tests above cover them. The emulator was shut down with `emu kill`, and the owner's phone was not touched.

## Images

| Before (QA pass 3, 2060) | After |
|---|---|
| [before-qa03-161-stopped.png](before-qa03-161-stopped.png), [before-qa03-164-running-not-answering.png](before-qa03-164-running-not-answering.png) | [after-qa03-running-silent-phone.png](after-qa03-running-silent-phone.png), [after-qa03-running-silent-wide.png](after-qa03-running-silent-wide.png): the root page for a running server whose connect failed |
