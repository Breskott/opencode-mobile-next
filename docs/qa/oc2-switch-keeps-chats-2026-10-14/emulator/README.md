# Emulator proof: switching OpenCode 1 -> 2 -> 1 keeps the chats (2026-10-14)

APK 2313 (int/ui-batch-2026-10-14), emulator-5554 (x86_64, 1080x2400), app data cleared first. No model key; the free model (Big Pickle) answered. `ui.sh` is the dump/tap/screenshot helper used.

| Step | What happened | Screenshot |
|---|---|---|
| First run | Fresh app, "On this phone" | 00-first-run.png, 01-this-phone.png, 02-choose.png |
| Set up OpenCode 1 | Setup through the UI, about 10 min including download; Linux base 24.04.5, OpenCode 1.19.0 | 03-setup-progress.png, 04-setup-end.png |
| Two conversations | "Say hello one" (title stayed "New conversation") and "Name three fruits" (titled "Three fruits"), both answered | 05..07, 08-chats-list-oc1.png |
| This phone page, OC1 | Connected 1.19.0, "Switch to OpenCode 2" | 09-this-phone-oc1.png |
| Switch confirm | Dialog "Switch to OpenCode 2?" | 10-switch-confirm.png |
| Switching | Downloaded OpenCode 2.0.28, started, Connected. The "Bringing your earlier conversations across" line was not caught: it is polled every few seconds and the migration finished before a dump saw it (11-switch-*.png) | 11-switch-1..6.png |
| After OC2 | Chats list for the phone server shows both: "Three fruits" and "New conversation". Opening "Three fruits" shows the prompt and the answer "Apple, banana, cherry." | 12-chats-list-oc2.png, 13-oc2-open-chat.png |
| Switch back | Confirm, then OpenCode 1.19.0 Connected; both chats still listed under my-app | 14-switch-back-confirm.png, 15-chats-list-back-on-oc1.png |

## Findings
- Survived the switch: yes, both conversations with their messages.
- Switching back: both still present (the copy did not move them).
- Quirk: on OpenCode 2 the list row's project label read "projects", while OpenCode 1 and the open chat's header read "my-app". Unexplained; not investigated.
- Not checked: the progress line text, a large history, hot restart (Android killing the app), the OC2 -> new chat creation after switch.
