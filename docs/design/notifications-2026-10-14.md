# Notifications: one status, separate moments (2026-10-14)

**Owner request:** customise the phone notifications, and think through several chats running, a paused agent, approvals and the other notifications.

Inventory of today's notifications: see "Today" at the end.

## Principles

1. **One status notification.** There is one ongoing notification for everything OpenCode is doing. The background connection service (`BackgroundConnectionService`, dataSync) and the phone server service (`BuiltinServerService`, specialUse) both use the same notification ID and content, so they never show two "always on" rows. It changes with the situation and never contradicts itself.
2. **Moments are separate and temporary.**
   - "Needs you" (an approval or a question) gets its own high-priority alert.
   - "Finished", "Stopped" and quota are default-priority, clear on their own, and are grouped under one summary.
3. **Each fact once.** The status counts what needs you ("1 needs you"); the alert asks the question. The status never repeats the question, and a moment never repeats the status.
4. **Name the server only when it matters.** With one live connection, no server name appears. With several, add "on In-app Ubuntu", "on PC", and so on.
5. **The lock screen stays private.** The public version shows only counts ("OpenCode · 2 need you"), never a command, file or chat title.
6. **Safe actions:**
   - Allow once needs the phone unlocked (it already does).
   - Reject does not.
   - "Always allow" is never offered from a notification.
   - Stop asks for nothing but names what it stops.

## The status notification, by situation (highest wins)

| Situation | Title | Text | Progress | Actions |
|---|---|---|---|---|
| **Needs you** (any request pending) | "1 needs you" or "2 need you" | the first chat title · project | none | Open |
| **One chat working** | what it is doing now ("Running the tests", from the live tool line or the current task) | chat title · tasks "5 of 6" or elapsed "4 min" | a bar when tasks exist; none otherwise (no endless spinner) | Open · Stop the reply |
| **Several chats working** | "3 chats working" | inbox lines, one per chat: "IPTV_King · Running the tests"; then "+1 more" | none | Open (the chats list) |
| **Waiting: rate-limited or retrying** | "Waiting · <provider> limit" | "Tries again at 1:12 · <chat title>" | none | Open · Stop the reply |
| **Paused by Android** (dataSync 6 h cap) | "Paused · Android's background limit" | "Open OpenCode to keep going" | none | Open |
| **Paused: phone hot** (thermal) | "Paused · the phone is hot" | "Resumes when it cools down" | none | Open |
| **Paused while idle** (idle policy) | "Paused · nothing was running" | "Tap to start OpenCode again" | none | Start |
| **Reconnecting** | "Reconnecting to <server>" | the last thing it was doing | none | Open |
| **Idle, connected** | "Ready · nothing running" | "Last reply 12 min ago · <chat title>" | none | New chat · Stop OpenCode (in-app server only) |
| **Setting up** | "Setting up OpenCode · step 4 of 5" | the step name | percent | Open |

**Combinations.** "Needs you" overrides "working" in the title. The text adds "· 2 still working" when others run.

**Updates:** at most one update every 2 seconds (Android rate-limits 5/s and drops beyond), and only when the text or the progress changes. `setOnlyAlertOnce(true)` throughout.

## Moments

| Moment | Channel | Content | Actions | Clears when |
|---|---|---|---|---|
| **Permission request** | action (high) | "Run this command?" · the command (mono) · chat title | Allow once (unlock) · Reject · Open | answered anywhere, or the chat is opened |
| **Question / form** | action (high) | the question · chat title | Reply (RemoteInput) for free text; the first 2–3 options as buttons when there are 3 or fewer short options; otherwise Open | answered, or opened |
| **Several requests** | action (high) | one alert per request (keyed by request), plus a group summary "3 need you" | per alert | each one separately |
| **Finished** | status (default) | "<chat title> finished" · first line of the reply | Open | the chat is opened, or 1 h passes (`setTimeoutAfter`) |
| **Several finished** | status | a summary "3 replies finished" with inbox lines | Open (the chats list) | opened |
| **Stopped with an error** | action (high) | "<chat title> stopped" · plain reason ("The provider rejected the key", "Rate limit") per the no-raw-errors rule | Open | opened |
| **Quota threshold / reset** | status | as today | Open Usage | tapped, or the next refresh |
| **AI Team** | as today, grouped under its own summary | | | |
| **Voice download** | as today | | | |

## Fixes from today's inventory

1. **The "ready on this phone" notification** (setup result, ID 4099) is cancelled as soon as the phone server starts or the status notification shows. The setup finished state is then part of the status ("Ready · nothing running").
2. **Idle return** no longer reuses the "running" title (see "Paused while idle").
3. **The ID 4098 collision:** setup progress and idle return get distinct IDs.
4. **Status with nobody listening:** when only the phone server runs and live mode is off, the status still follows the server: Ready / Paused / Stop OpenCode.
5. **Retry gets a state:** the `retry` status (`session_events.dart:257`) feeds "Waiting · … tries again at …" instead of counting as busy.
6. **Thermal** goes into the status (no separate notification).
7. **Quiet hours:**
   - The status is always silent.
   - During quiet hours, high-priority moments post silently (no sound or vibration), but they still post.

## Not in this slice

- Android 16 live updates (the status bar chip): already wired for API 36. The owner's phone runs Android 15, so nothing new here.
- Per-chat notification settings.

## Today (inventory, 2026-10-14)

| # | Notification | Notes |
|---|---|---|
| 1 | Live connection ongoing (4747, `BackgroundConnectionService`) | |
| 2 | Phone server running (4097, `BuiltinServerService`) | |
| 3 | Setup progress (4098) | |
| 4 | Setup result "ready" (4099) | never auto-cleared |
| 5 | Idle return (4098, collides with #3) | title says "running" |
| 6 | Coding alerts, high | permission, question, error; Allow once / Deny / Reply exist (`CodingActionReceiver`) |
| 7 | Coding alerts, status | complete, check-in, quota, team |
| 8 | Team decision / run failed | |
| 9 | Team progress | |
| 10 | Thermal | |
| 11 | Voice | |
| 12 | QA update-recovery service | |

Alerts already share a group with no summary. Other saved servers are polled every 5 minutes, without actions.
