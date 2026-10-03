# Journeys QA, build 2066 (1.0.44+2066, 03a986c1), 2026-09-29

Third walk. Same method and rules as 2064/2065 (emulator-5554 only, shared emulator lock held, pinned OpenCode 1.18.32 host, viewed screenshots, no code changed, no key entered, nothing pushed). Screenshots sit beside this file; `L-*` are Light theme, everything else Dark unless noted. Earlier reports: `../journeys-2064-2026-09-29/`, `../journeys-2065-2026-09-29/`.

Scope of this pass: the three 2065 P1s in full; a faster regression walk of the rest in Dark, plus a Light sweep. J9 (Manage space), J10 landscape/font/airplane, and the per-step screenshots of J1/J4 details were not repeated; they were PASS in 2065 and nothing in this build's notes touches them. Not re-verified: "Continue setup" retry (no install failed, so it never appeared) and the free-only note (host has paid providers).

## The three 2065 P1s

| 2065 P1 | 2066 result | Evidence |
|---|---|---|
| Add tools / AI Team failed on first attempt with raw Dart error | **FIXED.** Phone setup done, then about 10 minutes of use (chats, Settings, Work, four sent prompts), then This phone > Add tools > AI Team > Add: ran straight through and finished on the first attempt in ~1.5 min (06:29:45 to 06:31:10). Then "Turn on AI Team" ran to "AI Team is running on this phone" in ~8 min. Then Voice typing on the first attempt: 375 MB downloaded, "Installed: ... AI Team and Voice typing" in ~2.5 min. No "Setup didn't finish", no raw text. | `J7-09-after-add`, `J7-12-this-phone-installed`, `J7-14-turning-on`, `J7-15-on`, `J7-16-aiteam-on-page`, `J8-02-voice`, `J8-03-installed` |
| First Send tap only hides keyboard | **NOT A BUG. Withdrawn.** With `dumpsys input_method` reporting `mInputShown=true` and a screenshot showing the keyboard up immediately before the tap, one tap on Send sent the message, twice in this build. My 2064/2065 observation was caused by my own `uiautomator dump` between typing and tapping: the dump hides the keyboard, the composer moves down, and my tap at the keyboard-up coordinate hit nothing. The fix agent's suspicion was right. | `J3-09-typed-keyboard-up`, `J3-11-sent-first-tap`, `J3-17-stopped` |
| Stale AI Team state (Settings "Off, About 125 MB to download" after install) | **FIXED.** After the Add tools install and before turning on, Settings > AI Team says "Installed on this phone. It is not turned on yet. Turning it on starts the team for your project; nothing more to download." with the button "Turn on AI Team on this phone". This phone lists AI Team under Installed. After turning on, Settings row reads "On . This phone" and the AI Team page "On this phone". | `J7-13-aiteam-installed`, `J7-12-this-phone-installed`, `J7-16-aiteam-on-page` |

## Summary table

| Journey | 2065 | 2066 | Fixed since 2065 / still open |
|---|---|---|---|
| J1 First run, demo | PASS | not repeated | Unchanged in 2065. Welcome, welcome shot only (`J1-01-welcome`). |
| J2 Host, Work, search | PASS | PASS | Work gained a shortcut row "proj: Active conversation's project" under the project title; empty state with illustration. Connect first landed on the project "eslam" (the home folder), not journeys-project (P2). |
| J3 Chat | PASS with P1 | **PASS** | FIXED: the "first Send" P1 was a test artifact. Picker (banner, search with keyboard, rows), streaming, Stop, and all menu items (changes, timeline, subagents, details) behave. Still open: raw ISO fork title, Compact without confirm. |
| J4 Inbox, Project | PASS | PASS (Light shots) | Project tab in Light `L-Project`. |
| J5 Settings | PASS | PASS | Every page above the fold opened in Dark (`D-*` checked in notes: server, providers, tools, AI Team, what runs, model, notifications, keep running, privacy, usage, report, available, about, setup guide). Providers still says "Signed in, not loaded by this server yet" on this visit (2065 had two wordings). |
| J6 This phone | PASS | PASS | Setup 4 min 37 s (06:18:49 to 06:23:26); reply "okay" and title "Okay confirmation". |
| J7 AI Team | PARTIAL | **PASS** | First-attempt install, On in ~8 min, pages agree. |
| J8 Add tools, Voice | PARTIAL | **PASS** | First-attempt Voice download and install. Continue-setup retry not exercised. |
| J9 Manage space | PASS | not repeated | |
| J10 Resilience, light | PASS | PARTIAL | Light and Dark sweep done (below); kill/restart, landscape, font scale not repeated. |

## Findings (2066)

P0: none. P1: none open.

P2, new or still open:
- Connecting to a host that has no recent project of yours lands on the project "eslam" (the user's home folder), which is a project you would not choose (`J2-05-work-home`).
- Providers wording still varies between visits ("Signed in, not loaded by this server yet" vs "can't use it").
- Withdrawn: 2065 P1-2 (first Send). Everything else from the 2065 P2 list still stands (interrupted-turn silence, raw ISO fork title, Compact confirm, code-block clipping, green Cancel, Plugins page, three background settings, font-2.0 dock label, demo gutters).

## Light and Dark sweep

Dark: Work, chat, picker, keyboard/Send, menu items, and 14 Settings pages opened without crash or layout break.
Light (Appearance > Light, glass on): Appearance, Settings bottom, Work, Inbox, Project all rendered correctly, no crash, emulator stayed up (`L-appearance`, `L-settings-bottom`, `L-Work`, `L-Inbox`, `L-Project`, `L-work-2`, `L-saved-servers`, `L-aiteam-host`). Light chat, picker and storage pages were verified in 2065 (`../journeys-2065-2026-09-29/J10-18-light-chat.png`, `J10-19-light-picker.png`, `J9-03-clear-storage.png`). I did not capture Light shots of the AI Team install screens.
