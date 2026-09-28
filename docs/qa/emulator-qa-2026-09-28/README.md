# Android emulator exploratory QA — 2026-09-28

## Result

Partial exploratory pass of release APK `1.0.44 (2058)`, built from
`ef405759`. The clean install and first-run screens work, and the offline demo
completes its sample approval flow. I could not reach the normal Work shell or
test server-backed journeys: the built-in server setup is disabled on the
requested 2 GB emulator, and neither host OpenCode CLI can start because its
package postinstall was not run.

No application source was changed. The numbered PNGs in this directory are the
screens captured during the pass, in capture order. I reviewed each against
`docs/design/visual-language-2026-09-26.md` and the repository UI/security rules.

## Environment

| Item | Value |
| --- | --- |
| Branch / source | `codex/qa`, HEAD `ef4057591b70b29838f4e409ddd51064b5a8abfd` |
| APK | `/home/eslam/Storage/tmp/oc-apk-share/opencode-mobile-2058.apk` |
| App | `io.github.eslamasabry.opencode_mobile`, version `1.0.44`, code `2058` |
| APK SHA-256 | `3a80b6424070be2c2af9d63aefbee1bd6266b2078715f745916cf49da814a8ef` |
| Device | `OC_API35`, Android 15 / API 35, x86_64, emulator 36.2.12 |
| Emulator limits | 2048 MB, 2 cores; 1080×2400 at 420 dpi |
| Boot | Cold, headless, `swiftshader_indirect`; boot completed in about 21 s |
| Install | An older package with a different signer was present; uninstalled on the emulator, then APK install succeeded |

All device commands used `adb -s emulator-5554`. No physical device was queried
or changed. The emulator's own-phone setup screen reports 1972 MB and requires
at least 2048 MB, despite the emulator being launched with the requested
2048 MB limit.

## Timings

`am start -W -n io.github.eslamasabry.opencode_mobile/.MainActivity` returned
`LaunchState: COLD` for each run:

| Run | TotalTime | WaitTime |
| --- | ---: | ---: |
| First launch | 2376 ms | 2410 ms |
| Cold relaunch 1 | 2014 ms | 2030 ms |
| Cold relaunch 2 | 1542 ms | 1544 ms |
| Cold relaunch 3 | 2160 ms | 2194 ms |

The relaunch content was the first-run choice screen, not a restored workspace;
no real server or saved project/session had been added.

## Findings

| ID | Screenshot file(s) | Page | What's wrong | Severity | Steps to reproduce |
| --- | --- | --- | --- | --- | --- |
| QA-01 | [04-phone-mode.png](04-phone-mode.png), [05-phone-other-ways.png](05-phone-other-ways.png) | This phone setup | On the required 2048 MB emulator, setup says it needs at least 2048 MB but detects only 1972 MB. The setup button is disabled, so the requested first-run in-app Ubuntu/OpenCode install cannot start. | P1 — broken flow | Fresh install → **On this phone** → observe the memory message and disabled setup button. |
| QA-02 | [51-demo-relaunch.png](51-demo-relaunch.png), [52-relaunch-settled.png](52-relaunch-settled.png), [53-relaunch-after-touch.png](53-relaunch-after-touch.png) | App relaunch | A thin bright green outline appears around the entire app viewport after cold relaunch. It remains after waiting and touching the screen; the rest of the screen is usable. The initial first launch did not show the outline. Cause is unknown. | P2 — visual/UX | Open the demo, force-stop the app, relaunch with `am start -W`, then inspect the app edge. |

The external-server connection attempt at `http://10.0.2.2:4123` was rejected
with the app's explicit validation message: HTTP is allowed only for
`localhost`, `127.0.0.1`, or `[::1]`. This is consistent with the wizard's
HTTPS guidance for other computers; it prevented this emulator-to-host HTTP
test and is recorded as a coverage blocker, not an app defect. See
[18-server-connect-attempt.png](18-server-connect-attempt.png).

## What worked well

- The first-run screen clearly distinguishes a computer server, this phone,
  and an offline simulation. The setup wizard identifies its steps and offers
  a close action.
- The wizard's unsaved-server confirmation names the consequence and offers
  **Discard** / **Keep editing**. Discard returned to onboarding without saving
  the attempted server. See [21-onboarding.png](21-onboarding.png) and
  [26-discard-setup.png](26-discard-setup.png).
- The offline demo says that it is simulated, nothing is saved, and no server,
  provider, or files are accessed. Its sample prompt produced an assistant
  response and an amber “Needs your decision” card with **Reject** and
  **Allow once** actions. Allow once completed the simulation with clear
  wording that no real file changed. See [07-demo-home.png](07-demo-home.png),
  [09-demo-result.png](09-demo-result.png), and
  [10-demo-allow-once.png](10-demo-allow-once.png).
- External-agent setup explains that only sent text reaches the external
  agent. **Check agent** stays disabled until an address is entered and says
  what is missing. See [35-external-agents.png](35-external-agents.png) and
  [36-add-agent.png](36-add-agent.png).
- The Tailscale flow says its server password is separate from the Tailscale
  login, asks for the full HTTPS Serve origin, and gives a plain validation
  message for an empty connection check. See [41-tailscale-entry.png](41-tailscale-entry.png),
  [42-tailscale-address.png](42-tailscale-address.png), and
  [45-tailscale-empty-test.png](45-tailscale-empty-test.png).
- At system font scale 1.3, all three first-run choices remain visible. At
  2.0, content extends below the initial viewport. See
  [27-onboarding-font-1.3.png](27-onboarding-font-1.3.png) and
  [28-onboarding-font-2.0.png](28-onboarding-font-2.0.png).
- Forced landscape and return to portrait did not crash the app. In landscape,
  the lower first-run choices extend below the initial viewport. See
  [31-landscape.png](31-landscape.png) and [32-portrait.png](32-portrait.png).

## Coverage limits

The host `opencode serve --port 4123 --hostname 0.0.0.0` could not start:
`opencode` reports that `opencode-ai`'s postinstall script was not run.
`opencode2` was present but likewise reports that `@opencode-ai/cli`'s
postinstall script was not run. Both commands exited before binding a port;
no test server PID was created. I did not repair/install either CLI during this
app-only QA pass.

Because no server could be connected and phone setup is disabled, these areas
were not reachable and are **not verified**: Work lists/statuses and last-known
content, a real chat/send/stream/stop, conversation Go to/Do menu, slash command
sheet, Inbox including another server, Project, Settings pages (Appearance and
theme packs, AI setup, MCP catalogue), notification permission prompt, Termux
move entry, real disconnected/server-stopped status, airplane-mode recovery,
and restored real session content after relaunch. The offline demo is a
simulation and does not verify those flows. System light/dark toggles left the
first-run screen dark; the in-app appearance page was unreachable. Tailscale
was not installed, so its app handoff was not followed.

No credential or provider configuration response was requested, logged, or
captured. No model-authenticated reply was attempted.
