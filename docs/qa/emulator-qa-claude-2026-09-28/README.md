# Emulator QA: build 2062 (2026-09-28)

A manual pass over OpenCode Mobile 1.0.44+2062 on an Android emulator. No app code was changed, and the owner's phone was not touched.

## Environment

| | |
|---|---|
| APK | `opencode-mobile-2062.apk`, 1.0.44+2062, release-signed, `io.github.eslamasabry.opencode_mobile`, fresh install |
| Emulator | AVD `Pixel_6`: Android 14 (API 34), `google_apis` x86_64, 1080×2400 at 420 dpi. Started with `-memory 4096 -cores 4 -no-snapshot-load -no-snapshot-save -no-window`. |
| Renderer | `-gpu swiftshader_indirect`; Flutter reports "Impeller (OpenGLES)" |
| Host server | OpenCode **1.18.32** (`opencode-linux-x64-baseline.tar.gz`, SHA-256 `763af386…6adce` verified before extracting), serving a scratch git project `qa2-project` on `0.0.0.0:4123` |
| Connection | `adb reverse tcp:4123 tcp:4123`; server added in the app as `http://127.0.0.1:4123` |
| Model for replies | Big Pickle (OpenCode Zen, free) |
| This phone | In-app Ubuntu 24.04.5 + OpenCode 1.18.32 set up on the emulator at 4 GB RAM |

### Emulator stability: what I tried

The emulator's QEMU process died with **exit 139 (SIGSEGV)** five times. No core dump or crashpad report was written. I narrowed the trigger down to **the app in Light theme with Glass effects on**:

| Try | Flags / app state | Result |
|---|---|---|
| 1 | swiftshader_indirect; switched Appearance to **Light** (glass on by default) | QEMU exit 139 about 20 s later |
| 2 | swiftshader_indirect; app relaunched (Light + glass) | exit 139 about 30 s after launch |
| 3 | `-gpu guest` (Light + glass) | exit 139 |
| 4 | swiftshader_indirect `-feature -Vulkan` (Light + glass) | exit 139 about 8 s after "Using the Impeller rendering backend (OpenGLES)" |
| 5 | `-gpu host` | emulator failed to start OpenGLES (host driver), unrelated |
| 6 | Dark set through prefs, but a stale `.bak` restored Light | exit 139 |
| 7 | **Dark + glass off**, then **Dark + glass on** | stable for 3+ min each, including a relaunch |
| 7b | same boot, switched to **Light + glass on** | **exit 139 in 26 s** |
| 8 | **Light + glass off** | stable |
| 8 → end | Dark + glass on for the rest of the pass (about 35 min, including This phone setup) | stable |

The earlier `OC_API35` crashes "2–3 s after connecting" match this pattern if that AVD was in Light. See F1.

## What I covered

1. **First run:** welcome, then Add server (4 steps), a Save attempt with the URL empty, the URL entered, connected, and Work (01–09).
2. **Inbox:** empty (10), then with a stopped reply and reconnect history (57, 71). **Project tab** (11): no file changes happened, because the prompts asked for no edits, so live change and terminal lines were not exercised.
3. **Settings, one level deep:** top/mid/bottom (12–14), About with the Bundled components sheet (15–16), Usage (17), Privacy (18), Appearance in dark, light, glass off and glass on (19–23), Keep running (25), Notifications (26), Voice (27), What runs by itself (28), Tools (29), MCP, Add, the catalogue consent screen and the catalogue list (30–33), Commands & tools (34), Plugins (35), Providers and one provider's menu (36–37), Model picker (38), This server (39), AI setup (40), Saved servers (41), AI Team (42).
4. **Chat:**
   - New conversation sheet (43), model search and choice (44), typing and sending (45–46).
   - A long code-block reply (47) and the full-screen Code reader (48).
   - A reply while it was still coming in (49), then Stop (50).
   - Conversation menu with Go to and Do (51), Timeline (52), the `/` command list (53).
   - Font scale 2.0 in chat, Work and Settings (54–56), and landscape (60–62).
5. **Reconnect:**
   - Killed the server PID: "Reconnecting" at 4 s (63), then "isn't answering / Offline" at 25 s (64).
   - Restarted the server with a new PID: it reconnected by itself within about 10 s (65).
   - Airplane mode on and off (66–67).
6. **Android Settings › Apps › Storage** (68): "Clear storage" opens the app's own **Clear this app's storage** page (69). "Clear the app's cache only" worked: "Cache cleared. 172.0 KB freed." (70). I did not press Delete everything.
7. **This phone setup at 4 GB** (72–75):
   - Finished in about 5 min 20 s: Linux, then Git and SSH, Python, Node, OpenCode 1.18.32, and Start.
   - It created and opened the first project.
   - Relaunched 3× with force-stop (76–79): **it reconnected every time within 5–10 s and never showed the stopped page**.
   - This phone page (80–81).
   - Log tail: `this-phone-setup-log-tail.txt`.

### Coordinator question: "Getting the model list" / npm allowScripts

On **x86_64 this did not fail.** npm 11.19.0 printed the same warning (`install scripts not yet covered by allowScripts: opencode-ai@1.18.32 (postinstall: node ./postinstall.mjs)`). The postinstall still ran: `> opencode-ai@1.18.32 postinstall` appears first. `opencode --version` then printed 1.18.32, "Getting the model list" completed, and setup state was `done` with no error (`setup.json`). The owner's arm64 phone may differ, since that is where the postinstall picks the platform binary. **No OCTRACE lines appear in the setup job log** (`setup.json` logTail). OCTRACE lines appear only in logcat and in `diagnostics/report_problem.json` (256 lines).

## Findings

Severity: P0 crash/data loss/security · P1 broken flow · P2 visual/UX · P3 polish.

| ID | Screenshot(s) | Page | Problem | Sev | Repro |
|---|---|---|---|---|---|
| F1 | 20, 22, 23, 24 (no shot of the crash itself) | Any page, Light theme | **Light theme with Glass effects on kills the emulator's QEMU process (SIGSEGV, exit 139) within 8–30 s, every time (5/5).** Dark + glass and Light without glass are stable. Probably the glass shader under light-theme settings in Impeller/GLES on swiftshader. It is emulator-only so far, but it blocks any emulator proof in Light, and a GPU driver crash on some real devices can't be ruled out. | P1 | Pixel_6 API 34, swiftshader_indirect: Settings › Appearance › Light, wait 30 s |
| F2 | 58, 59 | Work / conversation | **Relaunching the app aborts a reply that is running on the server.** On each cold start, `catalog.load` sees "unloaded" providers (Anthropic and Google are signed in but not loaded) and calls `refreshProviderRuntime()`, which runs `POST /instance/dispose` for the project directory. The server log shows `disposing instance … process session … error=Aborted`. The reply is cut off, and the transcript says "**You stopped this reply.**" although the user did nothing. (`lib/state/connection.dart` ~2735 → `lib/api/product_repository.dart` ~2026.) | P1 (lost work) | Send a long prompt, force-stop the app within 5 s, relaunch. `/session/status` goes busy → idle, and the last assistant message has `MessageAbortedError`. |
| F3 | 57, 71 | Inbox | The reply I stopped shows as **"Failed"**, with a red-style ✕ and an **amber "1 need you" badge**. Nothing needs the user, so amber is misused and the label is wrong. The conversation title is the raw `New session - 2026-09-28T19:15:50.446Z`, while Work shows "New conversation". | P2 | Send a prompt, press Stop, open Inbox |
| F4 | 57, 71 | Inbox | "Done by itself · 127.0.0.1 · Reconnected by itself" gets one row for every reconnect: 5+ identical rows within 40 min, two of them "Just now". This is noise in a list meant for things that need attention. | P2 | Reconnect a few times (a server restart or an emulator reboot) |
| F5 | 63, 64 | Work, server offline | While the server is down, Work shows the status banner **and** a second error panel, "Could not load your conversations. Try again / Report a problem". The row's "as of" time keeps changing to the current time. Two messages for one cause; the second offers "Report a problem" for an expected outage. | P2 | Kill the server while Work is open |
| F6 | 38, 44 | Model picker | "Reload providers: Signed in to Anthropic and Google, but the server has not loaded them yet" shows on every open, even right after the automatic heal. This is the state that drives F2. | P3 | Open the model picker (depends on the host's auth.json) |
| F7 | 69, 70 | Manage space (from Android) | The warning and success icons sit at **x = 0 with no 16 px gutter**, and the warning text runs to the right edge. The page renders **light** although the app is set to Dark. It says "Export your projects first" but offers no Export button here (Export lives on Settings › This phone, 81). | P2 | Android Settings › Apps › OpenCode Mobile › Storage › Clear storage |
| F8 | 55, 56 | Work / Settings at font scale 2.0 | The server pill truncates to "127.…"; "Every project on this s…" is cut off; the project title wraps to "qa2-/project"; the tab labels "Project" and "Settings" nearly touch the dock edge. Usable, but tight. | P3 | `settings put system font_scale 2.0` |
| F9 | 61, 62 | Work, landscape | The glass top bar (server pill + search) is a narrow, clipped strip. In 62 the search button overlaps the pill's right end and the glass rim draws a notch. | P2 | Rotate to landscape on Work and scroll |
| F10 | 76–79, 81 | Work / This phone after a force-stop | The banner says "**Android closed** OpenCode Mobile… **it's starting again**" while the pill already says Connected. The exit was a user force-stop (`kind=forceStop`), not Android. The banner stays on every tab until dismissed. | P3 | Force-stop and relaunch with This phone as the server |
| F11 | 73 | This phone setup | The time estimate says "Less than a minute" at 30 %, then "~5 min left" a minute later. | P3 | Start This phone setup |
| F12 | 80 | This phone › Switch to OpenCode 2 | The sheet's primary button says "Switch version" rather than naming the target ("Switch to OpenCode 2"). Per the "actions name their target" rule, it stops the server and running tasks. | P3 | Settings › This phone › Switch to OpenCode 2 |
| F13 | 81 | This phone | The "Running" label is flush against the panel's right edge, with no inner padding. | P3 | Settings › This phone |
| F14 | 71, 41 | Server switcher / Saved servers | A loopback host server (127.0.0.1 through adb reverse) gets the green **phone** tile, the same as This phone. | P3 | Add `http://127.0.0.1:<port>` |
| F15 | 57, 76 | Inbox vs banner | Time formats are mixed: "as of 9/28/2026 23:22" (24 h, US date) in Inbox and "11:36 PM" in the banner. | P3 | Compare the two |
| F16 | 47 | Chat | After the first send, "Notify you when the agent needs you? Not now / Notify me" appears inline above the composer. Fine, but it pushes the answer's actions up. Noted only. | P3 | First prompt on a fresh install |

## What worked

- **First run and pairing:**
  - Fresh-install welcome and the 4-step Add server flow are clear.
  - An empty URL gives a plain inline error ("Enter a server URL.").
  - It connected over loopback on the first try.
- **Settings:**
  - Every page listed opened with plain copy and no raw errors.
  - The MCP catalogue asks for consent before contacting the registry.
  - Provider and Disconnect actions name their target ("Disconnect OpenCode Go", "Disconnect from 127.0.0.1").
  - No API keys appeared on screen, in logcat or in diagnostics (grep for key/token patterns: 0 hits).
- **Chat:**
  - Send, streaming, Stop ("You stopped this reply.") and the syntax-highlighted code block with Copy, Wrap and "Open full output" all worked.
  - The Code reader has line numbers.
  - Timeline, the Go to/Do menu and the `/` list work.
  - Chat stays readable at font scale 2.0 and in landscape.
- **Reconnect:**
  - Killing the server gives "Reconnecting…", then "127.0.0.1 isn't answering", with a "Reconnect to 127.0.0.1" action.
  - After the restart it came back by itself within 10 s.
  - Airplane mode correctly doesn't affect a loopback server.
- **Storage:**
  - Android's "Clear storage" now opens the app's own page.
  - Clearing the cache only worked and reported what it freed.
  - The page lists what is deleted and what stays.
- **This phone:**
  - Full in-app setup at 4 GB on x86_64 finished in about 5 min.
  - It created and opened the first project.
  - Three force-stop relaunches all reconnected within 10 s, never the stopped page.
- **Theme:** Dark theme and glass looked crisp. Amber appeared only on the Inbox badge (F3 aside).

## Not covered

- Permission and question cards: no prompt in this pass made the agent ask.
- Terminal and live file-change lines on the Project tab.
- Arabic/RTL.
- The Light theme beyond two screenshots (see F1).
