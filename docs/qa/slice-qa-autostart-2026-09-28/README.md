# slice-qa-autostart — cold relaunch on the in-app server (2026-09-28)

Backlog items B1, B7 and B8 from [the emulator QA of build 2058](../emulator-qa-2026-09-28/BACKLOG.md).

Finish line: opening the app on "OpenCode inside the app" starts a stopped server by itself every time (one retry after a fast failure), never flashes a verdict page first, and says why in plain words when it truly cannot start. Non-goal: changing the crash-healing budget, the native service, phone setup or the status slot.

## B1 — root cause (reproduced on the emulator)

The launch start was not a launch start any more. Since `6ed0ec26` (phone-server healing), main.dart's `_autoStartThenConnect` only asked the crash-healing owner (`BuiltinServerRecovery.check`). That owner has a durable budget: at most 3 automatic restarts between confirmed *manual* starts, retry times 15/30/45 s, and a confirmed automatic restart **never gives its attempt back**. So every cold relaunch that restarted the server spent one attempt:

- launch 1 after a manual Start: attempt 1, works;
- a relaunch inside the 15/30/45 s window: `waiting`, no start, the page says "stopped" until the 5 s timer dispatches (the QA's "stopped → Starting…" pair, 133 → 134);
- the fourth launch: `exhausted` — no start at all, and the generic "OpenCode inside the app is stopped" page waits for a tap (136/137). Nothing said why.

Proof on `emulator-5554` (the QA AVD, build 2058, 4096 MB): its saved budget was `{"attempts":2,…}` after the QA session; the next launch spent attempt 3, the one after read `attempts:3` and went straight from one `linux.status` to a refused connect (logcat: `OCTRACE linux.status` then `connect.health outcome=error`, no start). Screenshot: [before-device-4th-launch-stopped.png](before-device-4th-launch-stopped.png).

Not the cause: the 90 s ready timeout (never reached), the native restart refusal, or AppExitRecovery (it calls the same `check`).

## Fix

- `PhoneServerHealing.startForLaunch` (lib/builtin/phone_server_healing.dart): once per app process, after the healing check, a stopped server is started through the starter's explicit path — opening the app on it is the person's own act, like Start, so it neither spends nor is blocked by the crash budget (a confirmed launch start resets it, as a manual Start always did). It leaves alone: an explicit Stop (native intent cleared), "Restart the phone server" turned off, a running server, another start in flight. A fast failure (process exited, phone refused, password file not written) gets **one** more try after 2 s; a timeout, a withdrawn start or a missing password does not. If the healing restart already failed during that check, the launch start is the one more try. Foreground only: it waits for Android's first resume and never runs in the background.
- `BuiltinServerStartFailure` now carries a `BuiltinStartProblem` and `explanation(l10n)`: plain words per cause with the way forward. The connection card shows it as the body of "OpenCode inside the app did not start"; the technical line stays under Details. A native refusal after the start was withdrawn is now classed as interrupted, not "the phone said no".
- B7: while the launch start is pending, `_RootState` suppresses the connection error, the start failure and "not answering" — the page stays on "Connecting to This phone" / "Starting…", so no faded stopped (or "Nothing answered") page flashes first.
- B8: `connectionFailureLoopbackBody` → "The app looked for a server running on this phone and got no answer. Start that server, or reconnect the tunnel that brings one here, then try again."; title `e7ConnectionFailure24` → "Nothing answered on this phone".

New copy (app_en.arb): `inAppServerStartExitedBody`, `inAppServerStartTimedOutBody`, `inAppServerStartInterruptedBody`, `inAppServerStartPasswordBody`, `inAppServerStartRefusedBody`.

## Images (light, phone 412×915 and wide 1280×800)

| | Before | After |
|---|---|---|
| Cold launch, start pending (B1/B7) | [phone](before-b1-b7-launch-phone.png) · [wide](before-b1-b7-launch-wide.png) — "stopped" | [phone](after-b1-b7-launch-phone.png) · [wide](after-b1-b7-launch-wide.png) — "Connecting to This phone" |
| Start failed (B1) | [phone](before-b1-start-failed-phone.png) · [wide](before-b1-start-failed-wide.png) — generic | [phone](after-b1-start-failed-phone.png) · [wide](after-b1-start-failed-wide.png) — why + way forward |
| Loopback, nothing answered (B8) | [phone](before-b8-loopback-phone.png) · [wide](before-b8-loopback-wide.png) | [phone](after-b8-loopback-phone.png) · [wide](after-b8-loopback-wide.png) |
| Device, 4th relaunch on 2058 | [before-device-4th-launch-stopped.png](before-device-4th-launch-stopped.png) | needs a device run of the new build |

Rendered with the capture fixtures (`tool/capture/fixtures.dart`) from a throwaway test at the base commit `5decfa8e` and at this change; the test was not committed.

## Tests

Reproduced first: the new widget tests in `test/builtin_server_autostart_test.dart` were run against the base commit in a temporary worktree and failed there — "every cold launch starts a stopped in-app server, also past the crash-restart budget" (launch 2: 1 start, expected 2), "a start that fails is tried once more, then the card says why" and "no stopped or failure page flashes while the launch start is still deciding". All pass now.

New unit tests in `test/phone_server_healing_test.dart` (group "the launch start (QA B1)"): past an exhausted budget it starts, connects and resets the budget; it waits for the first resume; explicit Stop, restart policy off and a running server are left alone; one retry after a fast failure and once per process; a timeout is not retried; a failed healing restart counts as the first try.

Run once, serial (`flutter test --concurrency=1`), all passing:

- builtin_server_autostart, phone_server_healing, builtin_server_recovery, builtin_server, app_exit_recovery, builtin_recovery_bridge
- saved_server_connection_card, connection_failure, server_profile_reentry (title text updated), app_lifecycle, e7_setup_layout, work_tab_cleanup, motion_setup, revamp/slice_p4_4, revamp/coord_main_golden, goldens/work_tab_golden, design_standard
- gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text, kit/kit_manifest, kit/kit_draft_manifest, architecture_boundaries, golden_harness

`flutter analyze` (whole project): no issues.

## Still needs a device

The fixed build was not installed: a release APK signed like 2058/2059 is needed, and replacing the QA install otherwise means losing its 12-minute Ubuntu setup. On the next build, on a phone or `emulator-5554`: Start once, then force-stop and relaunch four or more times (also twice within 15 s); every launch should show "Connecting…" → "Starting OpenCode inside the app…" → connected, with no stopped page in between. Then Stop from the notification and relaunch: it should stay stopped.
