# Notifications: emulator proof (2026-10-14)

Slice: one status notification, grouped moments (docs/design/notifications-2026-10-14.md).

**Setup.** Release APK `--build-number=2299` with `ocPreview=true` (package `...opencode_mobile.preview`, signed with a throwaway key, never shipped), installed on `emulator-5554` only. A real OpenCode 1.0.193 server on `127.0.0.1:4150` (own XDG dirs, no user config or keys) with the deterministic model in `mock_llm.py`; the emulator reached it as `http://10.0.2.2:4150`. Background mode on, app sent to the home screen, chats started through the server API. No credentials appear in any capture.

| Image | What it shows |
|---|---|
| `n1_working.png` | One chat working: "Running the tests", `chat title · 5 of 6 tasks`, project beside the app name, a real progress bar (83%), Open and Stop the reply. Silent row. |
| `n2_several.png` | Two chats working (inbox lines). |
| `n3_needs_you.png` | "1 needs you · 1 still working" row and a separate permission alert showing the (masked) command and chat name. |
| `n3b_permission_actions.png` | The alert's buttons: Allow once and Deny only, no "Always allow". Finished replies are one group with a count of 4 above. |
| `n4_finished_summary.png` | Finished replies grouped under one summary, each "<chat> finished" with the first line of the reply. |
| `n6_idle.png` | After the last chat stopped: "Ready · nothing running", "Last reply just now · <chat>", finished group (5). |

**Also observed (dumpsys).** Row ID 4747 is the only ongoing row; its channel is low importance (silent); lock-screen visibility PRIVATE with a public version; tapping Deny on the alert resolved the request in the chat.

**Not proven on the device.** Waiting (retry), Paused (Android limit, heat, idle), Reconnecting and Setup rows, quiet-hours silent alerts, the shared ID with the phone server running (needs the in-app Ubuntu), and the 1 hour timeout. These are covered by unit tests (Dart model and controller, Kotlin owner set and throttle).
