# Emulator proof, widgets v2 (APK 2320 / 2321 / 2322, Pixel_6 Android 14), 2026-10-15

Screenshots of the style window, steer box and voice box are blank (FLAG_SECURE), so those steps were read from uiautomator dumps.
Setup notes: the emulator ran headless (-no-window) and boot-looped while a gradle build ran on the host. Its data partition is temporary, so the app starts in first-run state.
Server: a throwaway OpenCode 1.0.193 on the PC (4199) with a local mock model that calls bash (`sleep 45`); the free cloud models refused the request (403 "only from within OpenCode"). The server, mock and scratch dir are removed.
2320 never booted in time; 2321 and 2322 were tested.

| Step | Result | Image |
| --- | --- | --- |
| Widget in picker | Pass: "OpenCode Mobile, 2 widgets" | w-03-picker-opencode.png |
| Place Conversations, fresh app (2321) | Style window opens, no crash. Save failed (B1) | none (secure) |
| Same after force-stop (2321) | Save failed (B1) | none |
| Cancel on placement (2321) | Pass: widget removed | none |
| Place, Tinted + Teal, Save (2322) | Pass: widget stays, redrawn | w-08-home-saved.png |
| Reconfigure via pencil (2322) | Pass: opens with saved style, Cancel keeps widget | w-17-longpress-widget.png |
| 1. Style window | Pass (with 2322) | none |
| 2. Layouts | 1x1 pass: dot and counts. Wide 1 row: counts line only. 2x2 card and wide list pass | w-18-resized-small.png, w-19-wide-1row.png, w-20-wide-2row.png |
| 3. Live run | Pass: spinner turns, timer ticks 00:18 to 00:29, green. Stop from widget ends the run, "0 running" | w-09, w-10, w-15 |
| 4. Permission | Pass only with "Stay connected in the background" on (B3): amber Allow once / Reject; Allow once proceeds without opening the app; state returns to green | w-12-permission-widget.png, w-13-after-allow.png |
| 5. Steer | Pass: the OpenCode 1 button reads "Send after reply"; the box opens over the home screen; typed text reached the server as a user message | none (secure) |
| 6. Mic | Pass: Voice opened the system recognizer (Google speech, "Tap to stop listening"); after BACK the "New message" box with Dictate and Send showed. No permission prompt appeared | none |
| 7. Two running, card slides | NOT RUN | |
| 8. Tap opens the conversation | Pass: tapping the widget opened the right conversation (OpenCode 1 chat "New conversation") | none |
| 9. Usage widget | NOT RUN: two drag attempts did not place it; it is in the picker (Codex 5h 62% left, Week 85% left preview) | w-21-picker-usage.png, w-22-usage-drop-failed.png |
| 10. Light and dark, Material You | NOT RUN | |

## Bugs

- B1 (high, fixed in 2322): Save style returned staleRequest when a snapshot with a blank profile existed. Confirmed fixed.
- B2 (low, fixed in 2322): swatch labels ended in "Sending…".
- B3 (medium): with "Stay connected in the background" Off (the default) and the app closed, the widget drops to "Open the app to connect" and shows no Allow once / Reject or Stop, with no hint of the setting. Also POST_NOTIFICATIONS was not granted on this emulator; I granted it by adb, and that alone did not change the widget.
- B4 (low): "Action sent" stays in the header for minutes after an action.
- B5 (low): in the list layout, idle conversations show the raw default title "New session - 2026-10-15T04:39:03.218Z".
- B6 (low): the "Running a c…" step is truncated at 2x2 width.
