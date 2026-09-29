# Journeys QA, build 2065 (1.0.44+2065, d9e3e9c6), 2026-09-29

Second full walk, same method as 2064 (`../journeys-2064-2026-09-29/README.md`): emulator-5554 only (Pixel_6, Android 14, 2.625 px/dp), pinned OpenCode 1.18.32 host on 127.0.0.1:4123, adb input + uiautomator + a viewed screenshot per step, shared emulator lock held for the session. No code changed, no key entered, nothing pushed. Screenshots sit beside this file (`J<journey>-<nn>-<what>.png`). Companion: `CRITIQUE.md`.

Limits: the host reads the owner's provider store (Anthropic/Google are "signed in but unloaded", paid providers exist), so the picker's "free-only note" could not appear. Airplane mode cannot cut an `adb reverse` link. Voice model was downloaded in full (375 MB) rather than cancelled.

## Summary

| Journey | 2064 | 2065 | Fixed since 2064 / still open |
|---|---|---|---|
| J1 First run, demo | PASS | PASS | Unchanged: demo gutters (card ~8 dp from edge), void after completion. |
| J2 Host by address, Work, search | PASS | PASS | Work empty state redesigned (illustration, "Opened <project>, the project worked on most recently" + Choose another project); header seam gone. Still lands in a bare New conversation after connect; mixed time formats; raw ISO fork title. |
| J3 Chat | PASS w/ bugs | PASS w/ 1 P1 | FIXED: picker search stays visible with keyboard up; banner readable in full; "Add an API key for Anthropic/Google" rows and "Connect a provider" row at the list bottom; errors show "The agent stopped because of an error" + Send again + Error details. STILL BROKEN: first Send tap with keyboard up only hides the keyboard (reproduced twice). Fork title still raw ISO; Compact still no confirm. |
| J4 Inbox, Project | PASS | PASS | Unchanged; Switch project now lists the same project twice. |
| J5 Settings, every page | PASS w/ P1 | PASS | FIXED: Anthropic/Google now "Signed in, but this server can't use it . Add an API key" with a chevron into the key sheet; the dead disabled "Manage accounts" entry is gone (menu is Details + red Disconnect). Open: two different wordings for the same state ("...not loaded by this server yet"), Plugins page, triple background settings. |
| J6 This phone | PASS | PASS | Setup 4 min 38 s (was 4 min 48 s). Reply, relaunch x3 and deliberate Stop all fine. Open: banner claims "starting again" after a deliberate Stop. |
| J7 AI Team on this phone | FAIL (dead loop) | **PARTIAL** | FIXED: AI Team now installs and turns On (second try ended "AI Team is running on this phone", AI Team page "On this phone", 5 agents, gc + dolt running). STILL OPEN: the first attempt via Add tools failed at the last step with a raw Dart error and a no-op "Continue setup" (P1 below). |
| J8 Add tools, Voice | FAIL | **PARTIAL** | FIXED: no more "OpenCode is unreachable"; real progress screens; Voice downloaded 375 MB and finished ("Installed: ... AI Team and Voice typing"). STILL OPEN: first attempt after an install fails at "Start OpenCode" until the app is force-stopped and reopened. |
| J9 Manage space | PARTIAL | **PASS** | Android's "Clear storage" opens our page (my 2064 finding was a misread). Cache-only clear works ("172.0 KB freed"). |
| J10 Resilience, a11y | PASS w/ P0 | PASS | FIXED P0: Light + glass stays up (no crash), light screenshots taken. Open: interrupted turn still silent; Stop square stays while offline; font 2.0 dock label touches the dock edge. |

## Findings (2065)

### P0
None. Light theme with glass no longer kills the emulator (`J10-15-light-appearance`, `J10-16-light-work`, `J10-18-light-chat`, `J10-19-light-picker`, `J9-03-clear-storage` all rendered in Light).

### P1
1. **Add tools failure path is still a dead end, with a raw error.** Repro: fresh phone setup done > Settings > This phone > Add tools > toggle AI Team > Add (or Voice) right after the app has been running a while, or via AI Team > "Set up AI Team on this phone". The install steps run (AI Team 1.4.1 downloaded, "Done") but step "Start OpenCode" fails: "Setup didn't finish. Stopped during: Starting OpenCode". Details show raw developer text: "Bad state: Using ref when a widget is unmounted... Ref relies on BuildContext, and BuildContext is unsafe to use when the widget is deactivated..." (`J7-11-failed`, `J7-12-details`, `J8-02-voice-started`, `J8-03-details`). "Continue setup" does nothing on repeated taps (`J7-13-continue`, `J7-15-continue`, `J8-04-continue-noop`). The failure is transient: force-stop + reopen, then retry, and the install ran to "On" (AI Team, ~8 min) and Voice completed (~2 min). Also "Report this failure" works (opens a prefilled report).
2. **First Send tap only hides the keyboard** (`J3-09-typed`, `J3-10-after-first-send`), reproduced in two conversations. Second tap sends.
3. **Stale state after a failed install:** after `J7-11-failed`, the This phone page lists AI Team as Installed and Storage 1.4 GB, but the Settings AI Team page says "Off" with "About 125 MB to download" (`J7-17`, `J7-18`).

### P2 (new or still open)
- The phone-server banner says "they're starting again" after a deliberate Stop and after relaunch while another server is active; the server stayed stopped (0 processes) and the Servers sheet shows "Stopped" with Start OpenCode (`J6-13`, `J6-15`, `J6-16`).
- "Run as a Linux service" and "Copy update commands... in a terminal on the server's computer" appear on the in-app server's settings.
- Providers uses two wordings for the same state.
- Estimates: setup "~3 min left" stays until 93%; Voice "Less than a minute" while 52 of 375 MB.
- After a deliberate Add tools sheet: the This phone page loses the "Reply speed" row until the next reply.
- Still open from 2064: interrupted turn silent (`J10-04-restarted`); raw ISO fork title (`J3-30`); Compact without confirm and raw reasoning in its header (`J3-29`); code block clips without cue (`J3-19`); Cancel is green like the primary (`J3-04`); Notify banner reappears; Files/Plugins/Available-on-this-server pages; Switch project duplicates (`J4-07`); demo gutter; font 2.0 dock label touching (`J10-09`).

## Checks the coordinator asked for

| Item | Result |
|---|---|
| J7/J8 install to On / Voice download | AI Team reached On (`J7-20-result`, `J7-21-aiteam-on`) with real progress (`J7-19`); Voice finished (`J8-06`/`J8-09-voice-end`). First attempts failed (P1-1). |
| Light + glass | No crash. Contrast in Light (sampled): secondary text 6.3 to 7.6:1, placeholder 5.8:1, green button label 5.1:1, status bar text 4.4:1 (system bar, not app). |
| Picker search, keyboard up | Fixed (`J3-05-search-keyboard`). |
| First Send tap | Not fixed. |
| "Connect a provider", per-provider "Add an API key", free-only note | Rows present at the end of the model list (`J3-03b-picker-bottom`); Anthropic sheet opens with "Get a key from Anthropic" (`J3-04-anthropic-key`, cancelled). Free-only note not shown on this host (paid providers loaded). |
| Providers "Signed in, but this server can't use it" | Fixed (`J5-providers-01`). "Manage accounts" no longer offered at all (removed, not enabled). |
| Clear storage opens our page | Yes (`J9-03-clear-storage`). |
| "That didn't work. Details show what happened" wording | Not seen in these paths; the classified upstream error used "The agent stopped because of an error / Error details" (`J3-13-error-details`), with a sheet showing "Bad Request" and Copy all. |

## Step lists

Same journeys and order as 2064; only deltas are listed. Screenshot names are unchanged from 2064 where the step is the same.

- J1: steps 1-9 identical. `J1-01` to `J1-19`.
- J2: connect `J2-03`; Work `J2-04`/`J2-05-work-home` (new empty state); Search all `J2-08`; Settings top `J2-06`.
- J3: New conversation `J3-01`; picker `J3-03`, bottom `J3-03b`, key sheet `J3-04`; search `J3-05`; thinking/agent `J3-06`, `J3-07`; type/send `J3-09`, `J3-10`, `J3-11`; reply `J3-12`; error `J3-13`; Nemotron free model used because Big Pickle returned 400 upstream; stream/Stop `J3-15` to `J3-17`; code reply/copy `J3-19`, `J3-20`; menu `J3-21` and each item (changes, timeline `J3-23`, find `J3-24`, subagents `J3-25`, details `J3-26`, share `J3-27`, rename, continue, other phone, compact `J3-28`/`J3-29`, fork `J3-30`); slash `J3-32`; /connect opens Providers `J5-providers-01`.
- J4: `J4-01`, `J4-04`, `J4-05-*`, `J4-07-switch-project`.
- J5: `J5-*` (server, providers, tools, AI Team, runs by itself, default shell, notifications, keep running, appearance).
- J6: `J6-02` to `J6-16` (setup, ready, reply `J6-06`, page `J6-09`, relaunch x3 `J6-10-relaunch1..3`, stop confirm `J6-11`, stopped `J6-12`, relaunch `J6-13`).
- J7: `J7-01`..`J7-21`. J8: `J8-01`..`J8-09`. J9: `J9-02`..`J9-04`. J10: `J10-01`..`J10-19`.
