# Journeys QA, build 2064 (1.0.44+2064), 2026-09-29

Tester: agent, by hand (adb input + uiautomator + screenshots, every screenshot viewed).
Device: emulator Pixel_6 (Android 14, x86_64, 1080x2400, 420 dpi = 2.625 px/dp), `emulator-5554` only.
Host server: pinned OpenCode 1.18.32 (sha256 verified before extract) on 127.0.0.1:4123 via `adb reverse`, scratch git repo.
Build: `opencode-mobile-2064.apk`. No code changed. No key entered, nothing pushed.
Screenshots sit beside this file, named `J<journey>-<nn>-<what>.png`. Companion critique: `CRITIQUE.md`.

Limits stated honestly:
- Anthropic/Google were already "Connected" on the host (it read the owner's provider store), so the "Add an API key" path was exercised on another provider (Alibaba Coding Plan) and cancelled; the Anthropic/Google leads could not be reached.
- The app was already in Dark; I never saw Light before the crash below.
- J10 airplane mode cannot cut an `adb reverse` loopback link, so no offline state was observable.
- uiautomator dumps lag ~2 s behind navigation; where it mattered I used the screenshot.

## Summary

| Journey | Result | Key finding |
|---|---|---|
| J1 First run + demo | PASS (with P2s) | All 3 welcome options and demo work end to end. Same options repeated in 3 places (welcome, Add server, Setup guide). |
| J2 Add host by address, Work, search | PASS | Connects first try. After "Open 127.0.0.1" it lands in a bare New conversation, not Work. Time formats mixed; 4 identical "New conversation" rows. |
| J3 Chat | PASS with P1/P2 bugs | Stream, Stop, resend, all 11 menu items, "/" sheet, model picker, code copy work. Model-picker search with keyboard open hides its own result (P1). First Send tap only closes keyboard. Raw ISO title on fork. |
| J4 Inbox / Project / back | PASS | Fine. Duplicate search entry points; mixed project naming. |
| J5 Settings, every page | PASS with P1/P2 | Every page opens. "Providers: Connected, 19 models" contradicts the picker banner "could not load those sign-ins". "Plugins" page holds one row. Three places for background running. |
| J6 This phone setup | PASS | 4 min 48 s, ~208 MB, live log, reply in ~3 s, 3x force-stop relaunch reconnects each time, deliberate Stop stays stopped with clear Start. Status text contradictory while stopped. |
| J7 AI Team on this phone | **FAIL (dead loop reproduced)** | "Set up AI Team" > Add tools > Add returns to "Off": no install, no progress, no error, no process. Twice. |
| J8 Add tools (Python, Voice) | **FAIL** | Every Add from This phone fails at once with "Could not finish: OpenCode is unreachable" while the card says Running. Python already installed; Voice never starts so cancel is untestable. |
| J9 Manage space | PARTIAL | Android's Storage page shows Clear storage / Clear cache only (no "Manage space" button) although the manifest declares it. The app's own page opened by direct launch is good; cache-only clear works. |
| J10 Resilience | PASS with P0 | Server kill: plain banner in 6 s, auto-reconnect in <20 s on restart. Landscape and font 1.3/2.0 usable. **Switching Appearance to Light killed the emulator process** (matches the known crash). |

## Findings

### P0
- **P0-1 Light theme kills the emulator.** Repro: Settings > Appearance > Light (glass on). The whole emulator process died 5 s later (`adb devices` empty; emulator log ends with "bad color buffer handle" repeated). No light screenshot possible. Owner already knows; still ship-blocking for anyone on a similar GPU. Evidence: `J10-14-light-appearance.png` (last screen before) and the log text above.

### P1
- **P1-1 AI Team dead loop (the owner's bug), reproduced twice.** Repro: Settings > AI Team (`J7-01`) > "Set up AI Team on this phone" > Add tools sheet with AI Team pre-on (`J7-03`) > Add. Sheet closes, page still says "AI Team, Off" (`J7-04`, `J7-05-after-60s`, `J7-06-second-try`). Watched 90 s+: no progress UI, no error, `ps -A | grep -iE "gc|dolt|team"` empty. Root cause visible in P1-2: the failure is swallowed on this page.
- **P1-2 Add tools fails for every item with an unexplained error, and contradicts the status card.** Repro: Settings > This phone > Add tools > toggle AI Team or Voice > Add. Modal "Could not finish. That did not work: OpenCode is unreachable. Try again." (`J7-09-after-add-direct`, `J8-02-voice-after`, `J8-05-voice-*`) while the card above says "Connected . Running". Repeated after a fresh Stop/Start of the server. "Try again" cannot work; no Details, no other way forward.
- **P1-3 Model picker search hides its own result while the keyboard is open.** Repro: chat > model chip > tap search > type "pickle". Header says 1 result but the list area collapses to zero height (`J3-04-model-search`); result appears only after closing the keyboard (`J3-05-pickle-result`).
- **P1-4 Provider status contradicts itself.** Settings > Providers shows Anthropic and Google "Connected . 19/39 models" (`J5-providers-01`) while the model picker banner says the server could not load those sign-ins (`J3-03-model-picker`). Tapping a connected provider gives a menu whose first entry ("Manage accounts") is disabled with "This server can't list saved accounts from the app" (`J5-anthropic-01`): a dead end. Tapping "Reload providers" spins and returns the same banner.
- **P1-5 First Send tap does nothing visible.** With text typed and keyboard up, the green Send only dismisses the keyboard; message sends on the second tap (`J3-10-streaming`). Repro: type, tap Send immediately.
- **P1-6 Manage-space not reachable from Android.** See J9 (app page only by direct launch on this emulator).

### P2
- Status contradictions while the phone server is stopped: banner "Reconnecting to This phone..." or "isn't answering [Restart]" + card "Connected . 1.18.32 . Stopped" + "Up to date" (`J6-12-stopped`, `x`-series described in J8). Restart also pops "Keep the server running?" every time.
- Interrupted turn is silent: after the host was killed mid-reply the prompt stays with no reply and no "interrupted, send again" note (`J10-04-restarted`). While offline the transcript keeps an animated "Thinking..." and the composer keeps the Stop square (`J10-03-killed-26s`).
- Raw server title on Fork and in Work: "New session - 2026-09-28T22:00:33.345Z (fork #1)" (`J3-30`, `J3-31`). Other conversation stays "New conversation" after three turns on the host (`J3-17`), but is renamed "Okay" on the phone server.
- Compact context runs at once with no confirmation or progress and inserts a long summary whose card header shows the model's raw reasoning ("We need answer exact structure, ...") (`J3-28`, `J3-29`).
- Model picker banner truncated mid-sentence so the way forward ("Sign in another way under Providers") is unreadable; banner + search + tabs + chips leave ~3 rows visible; refresh icon misaligned with the search field (`J3-03`, `J3-05`).
- Two search entry points (header magnifier > "Command launcher" sheet, and Settings "Find settings, tools, and help"); launcher icon set differs from the tab bar.
- "Plugins" page contains one row (AI Team) that duplicates Settings > AI Team (`J5-plugins`).
- One concept, three homes: background running = Settings > Notifications "Stay connected in the background", Settings > "Keep running in the background", per-server "Monitor this server", This phone > "Keep running in the background".
- Names mismatch: Settings row "Saved servers" opens a page titled "OpenCode"; "Providers and accounts" opens "Providers"; "Available on this server" is vague.
- Setup guide (Settings) shows the first-run "Three steps" page to a connected user; Add server says "Step 1 of 4", guide says 3 steps; the connect screen jumps 2 to 4.
- Notifications page has a row titled just "Off" (status posing as a title); descriptions truncate mid-sentence throughout ("when one nee...", "VPN or unav...").
- Report a problem page carries a developer Performance dump ("prompt.turn 144307ms", "http oc1 POST /session/:id/summarize").
- Conversation details: three unexplained token figures (33,638 used / 15 latest input / 98,615 conversation), label "Accumulated cost . reported by server" collides with its value (`J3-23`).
- "What runs by itself" shows "The question closed before you answered ... Not answered" for a question I never saw (`J5-runs-itself`).
- Default shell sheet lists duplicates (/bin/bash and /usr/bin/bash, sh, dash, rbash: 11 rows).
- MCP catalogue: bare toggles for random public third-party servers with no confirmation or trust cue; descriptions truncated (`J5-mcp-catalogue2`). Tools tab lists internals ("invalid: Do not use").
- Code block clips long lines with no scroll cue; at font 2.0 shows ~14 characters per line (`J3-35`, `J10-10`).
- Demo: card 8 dp from screen edge, "Reset demo" text ~8 dp from right edge (`J1-14`, `J1-15`); completion view leaves a big void between banner and transcript and drops the edit row (`J1-16`).
- Landscape chat: header + composer leave ~1 message of transcript (`J10-07`); Work landscape row clipped behind the button (`J10-08`).
- Font 2.0: header search circle does not scale; back arrow drops to mid-height beside a 2-line title (`J10-10`); dock labels touch the dock border (`J10-09`, `J10-11`).
- Visual language: green radial glow behind Work/Inbox/Project/Settings (not flat graphite); visible rectangular seam behind the server pill and search; header search jumps to mid-screen when Settings is scrolled; scrolled rows show through above the sticky search field (`J2-05`, `J5-settings-bottom`, `J10-14-light-appearance`).
- Stale first-connect message "Reconnected by itself . 19m ago" on Inbox for a connection that never dropped (`J4-01`).
- Connect success screen states the same fact three times and shows the raw IP as the server name (`J2-03`).

### P3
- "Stop the server" is grey, not red (red = stop); Delete-everything warning ("cannot be undone") sits above the harmless cache-only option (`J9-03`).
- Copy after a deliberate Stop says "It stops when the app is closed for a while or updated" (`J6-13`).
- Setup estimate "~3 min left" stayed for ~3.5 minutes then jumped to "~1 min" (`J6-02` and poll log).
- Estimate "About a minute . ~375 MB" for Voice is implausible.
- Sheet cards inset ~36 dp while page gutters are 16 dp (`J3-01`).
- Convo menu: first item shows a green focus ring that reads as selected; "Go to" rows have no subtitles, "Do" rows do (`J3-18`).
- Timeline mixes "OpenCode" and model name as speaker and 12h clock vs "ago" vs ISO dates (`J3-20`, `J2-08`).
- Both a leading icon tile and an X on every sheet.

## Journey step lists

Format: action > expected > actual > screenshot. "OK" = matched expectation.

### J1 First run (fresh install, 4 taps to finish the demo)
1. Launch > welcome with 3 options > OK; already Dark > `J1-01-welcome`
2. "On my computer" > Add server step 1 > list of 6 ways; intro "They run side by side..." has no antecedent > `J1-02-on-my-computer`
3. "OpenCode on a computer" > pair step > jumps straight to step 2; command `opencode2 pair` (pinned server binary is `opencode`) > `J1-03-opencode-selected`
4. Save & connect empty > inline error > "Enter a server URL." plus auto-expanded address field; OK > `J1-04-save-empty`
5. Back, Codex, Paseo > forms > long forms, command line truncated, fields have no label in the tree > `J1-06-codex`, `J1-07-paseo`
6. Close (X) > welcome; More menu > Report a problem / Setup guide; guide 3 steps > OK > `J1-09-more-menu`, `J1-10-setup-guide`
7. "On this phone" > setup offer (~4 min, 208 MB) > OK; "Choose what to install" sheet OK; "Other ways": Termux, by address > `J1-11`, `J1-12`, `J1-13`
8. "Just show me" > demo with prefilled prompt > OK; Send > amber permission card; Allow once > completion banner; Review changes > diff viewer > OK, edge/gutter issues > `J1-14` to `J1-17`
9. Leave demo > welcome; About > OK > `J1-18`, `J1-19`. PASS.

### J2 Host server (6 taps + typing to connect)
1. On my computer > OpenCode > Enter address instead > type URL > Save & connect > connected on first try > `J2-01` to `J2-03`
2. Open 127.0.0.1 > expected Work > landed in a bare New conversation with keyboard > `J2-04-work`
3. Back x2 > Work > empty-state good copy, foreign projects listed > `J2-05-work-home`
4. Settings top > two search affordances; Appearance is Dark > `J2-06`, `J2-07`, `J5-appearance-01`
5. Search all conversations > grouped list, mixed time formats, identical titles; search "Paseo" 3 hits; filter menu; Archived empty state > `J2-08` to `J2-14`. PASS.

### J3 Chat
1. New conversation > chooser Solo/Team/Separate copy > OK > `J3-01`; Solo > composer > `J3-02`
2. Model chip > picker; scroll all rows (35 OpenAI rows; banner problems) > `J3-03`, `J3-04`, `J3-05`; Thinking sheet (Default) and Agent sheet (Build, Plan) > OK > `J3-06`, `J3-07`
3. Select Big Pickle > Use for this conversation > chip updates > `J3-08`
4. Type, Send > first tap only hid keyboard (P1-5) > `J3-09`, `J3-10`; second tap sends > `J3-11`
5. ~2 min of "Thinking..." then reply; 22 kB essay > `J3-12` to `J3-14`
6. Send, Stop mid-reply > "You stopped this reply." > OK > `J3-16`; send again > reply > `J3-17`
7. Menu > Go to: Changes (empty), Timeline, Find (bar above composer), Subagents (empty), Details; Do: Share (confirms), Compact (no confirm), Fork (raw title), Rename (Cancel), Continue on computer, Open on another phone (QR) > `J3-18` to `J3-30`
8. "/" > inline list (agents, approvals, connect, copy, debug...) > `J3-32`, `J3-33`; /connect > Providers page > `J3-34`
9. Code block reply > Copy code > tick + clipboard preview > `J3-35`, `J3-36`. PASS with bugs above.

### J4 Inbox, Project (Inbox 1 tap, Project 6 rows, all back keys behaved)
1. Inbox > empty state + "Done by itself" row; row tap > only Dismiss > `J4-01`, `J4-02`
2. Header magnifier > Command launcher > `J4-03`
3. Project > Changes, Files, Terminal (real host shell, key rows), Project health (20+ "Disabled" formatters), Worktrees, Cloud environments, "..." (Switch project, Copy path), file viewer > `J4-04` to `J4-09`. PASS.

### J5 Settings (every page opened)
Server settings, AI setup (review-only), Model, Providers (+ API-key sheet cancelled), Tools (MCP list, Add > catalogue > Load the list consent > list; Commands & tools 4 tabs; Plugins; External agents), AI Team, What runs by itself (+ Always allowed, Watch in background), Default shell, Voice, Notifications, Keep running, Appearance, Privacy and data, Usage (needs a collector, not installed), Setup guide, Report a problem (not sent), Available on this server, About and Bundled components, Saved servers. Screenshots `J5-*`. All open, none crash. PASS with findings.

### J6 This phone (taps: 3 to start setup)
1. On my computer > On this phone > Set up OpenCode on this phone > 6-step live list, "You can leave the app", red Stop setup > `J6-01`, `J6-02`
2. Timing: 02:25:19 to 02:30:07 = 4 min 48 s; substep text ("Installing packages . 27%", "Still waiting after 8 s") OK
3. "OpenCode is ready, name your first project" > Create and open > chat with "free model" banner > `J6-03`, `J6-04`
4. Chat briefly "Reconnecting to This phone..." then recovered; sent "okay" > reply, title "Okay" > `J6-06` to `J6-08`
5. This phone page: Reply speed row present (first words 2.8 s, finished 3.1 s), Add tools, Installed, Storage 1.1 GB > `J6-09`
6. Force-stop + relaunch x3 > each reconnected within ~15 s with honest banner > `J6-10-relaunch1..3`
7. Stop the server > confirm sheet > Stopped > force-stop, relaunch > full-page "OpenCode inside the app is stopped" + Start and connect (stays stopped, PASS) > `J6-11` to `J6-13`; Start > running > `J6-14`. PASS.

### J7 AI Team dead loop
1. Settings > AI Team > `J7-01` (clear pitch, sticky CTA)
2. Set up AI Team on this phone > Add tools sheet > `J7-02`, `J7-03` (Checking..., then AI Team pre-on)
3. Add > sheet closes > page "Off", no progress > `J7-04`; 4 polls over 60 s unchanged, no processes, `J7-05-after-60s`
4. Second attempt identical > `J7-06-second-try`
5. This phone > Add tools > AI Team > Add > modal "Could not finish ... unreachable" > `J7-07`, `J7-08`, `J7-09`, `J7-10-retry`. FAIL.

### J8 Add tools
1. Python listed "Installed" (cannot be re-added)
2. Voice typing selected ("About a minute . ~375 MB") > Add > same modal within 1 s, repeated 6x over 30 s and after restart > `J8-01`, `J8-02`, `J8-05-voice-1..6`. Cancel/stop untestable. FAIL.

### J9 Manage space
1. Android App info > Storage & cache > buttons Clear storage / Clear cache only > `J9-01`, `J9-02`
2. Direct launch of `ManageSpaceActivity`: page "Clear this app's storage" with export first, cache-only, red Delete everything, sizes (in-app server 1.1 GB, my-app 25.6 KB) > `J9-03`
3. "Clear the app's cache only" > "Cache cleared. 160.0 KB freed." > `J9-04`. Delete everything not pressed. PARTIAL.

### J10 Resilience
1. Kill host PID mid-reply > banner "127.0.0.1 isn't answering [Reconnect to 127.0.0.1]" in 6 s; stale Thinking/Stop > `J10-02`, `J10-03`
2. Restart server (new PID) > auto reconnect <20 s, interrupted turn silent > `J10-04`
3. Airplane on/off > no change (loopback) > `J10-05`, `J10-06`
4. Landscape chat and Work > `J10-07`, `J10-08`
5. Font 2.0 Work, chat, Settings; 1.3 Work; animations scale 0 > `J10-09` to `J10-13`
6. Light theme > emulator died > `J10-14`. Font scale, animator scales and rotation were reset to 1.0 / portrait before the crash.
