# FactsBook F7: the review fixes, proven on an emulator (2026-10-12)

Evidence record. Release APK (build numbers 9201 to 9203, `--dart-define=OC_FACTSBOOK=true`) from `feat/factsbook-ui` on the emulator AVD `FB_F6` (x86_64, `-no-window`, wiped data, serial `emulator-5570`; never the owner's phone). The real `factsbook-node` (x86_64 build recorded in `docs/qa/factsbook-f6-2026-10-11/README.md`, sha256 `0cdafd50...`) ran inside the app's built-in Linux. One screen per image, 1080 x 2400. Before images are in `docs/qa/factsbook-f4-2026-10-11/` and `docs/qa/factsbook-f6-2026-10-11/`.

How it was driven: onboarding "On my computer" against a local OpenCode 1 server (clean config), then Memory on the Chats home from a fresh install: set up the built-in Linux, tap Set up Memory, one button, landed in Add something.

| Image | Fix | What it shows |
| --- | --- | --- |
| 01 | 1 | First run: the Memory row says "Set up Memory", not the node's pairing form. |
| 02 | 1 | It opens "Use memory on this phone" with a plain "What is this?" line; the built-in Linux is not set up yet, so the one action is "Set up this phone". |
| 03 | 1 | After the Linux is ready: one action. |
| 04, 04b | 1, 5 | One tap installed, started and paired the memory, and landed in Add something. 04b: the groups are spaced (04 shows the first build, where they touched). |
| 05 | 5 | After Save: one result line, "Saved. Memory will check it for changes for you to review." |
| 06 | 2 | The app was force-closed and reopened: the memory started by itself, no tap. |
| 07 | 3 | About you: Needs you, Reminders, When something new comes in, Areas as rows; no tabs, no Map or Watching, no "Last saved"; Status and Memory settings in a footer group. |
| 08, 13 | 9 | Status: one line ("Everything is working"), one Backup row, the module list under Details; 13 adds the "Use memory on this phone" row (Stop, Start). |
| 09 | 10 | Needs you, the merged page, empty. |
| 10 | 10 | Reminders: no banner about alarms; empty text points to the note option. |
| 11 | 8 | Reminder check: a one-off ("Never"), the date line above the detail rows, tall sheet. |
| 12 | 2 | Chats home with the memory running. |
| 14 | 1 | Use memory on this phone, running: Stop and Restart; Remove, the log and "Connect to my own server" are under Details. |
| 15 | 2 | The person pressed Stop, then the app was updated: still stopped (not started against their wish); the row says "Memory is stopped" with Start. |
| 16 | 2 | About you while stopped (still says "Memory did not answer": see gaps). |

## Not shown here, and why

Memory care cards (claim as title, source, Approve and Reject, Edit and Skip on tap), the Thing page actions and the thing picker on Add something need data. The node on the emulator held one note and no things, and there was no way to seed one from outside the app (the node's data sits in the app's private Linux). They are covered by widget tests against the fake node (`test/factsbook/factsbook_f7_test.dart`, `factsbook_pages_test.dart`).

## Findings

1. Pairing is kept per server profile. After the in-app Linux setup the active profile changed, so a memory paired under the earlier profile showed "Set up Memory" again; Start re-paired it. Not changed here.
2. A failed read keeps the last copy, so the Chats home showed old numbers after Stop. Fixed (commit 211fb9431) and re-checked (image 15).
3. About you still shows "Memory did not answer / Try again" when the memory is stopped (image 16). The Chats home row says stopped with Start; the About you page does not yet.
4. The device PIN prompt (approvals) was not exercised.
