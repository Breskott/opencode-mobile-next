# slice-P1.3 + slice-P1.5: the old phone pages merged into phone setup v2 (2026-09-27)

Owner question: "I thought this will be merged in v2 installation experience?"
The Termux wizard (`termux_setup_screen.dart`, 3265 lines) and the built-in
server page (`builtin_server_screen.dart`) are deleted. Setting up goes through
phone setup v2 (screen A, then the checklist — `PhoneSetupTermuxScreen` is the
Termux host of the same checklist). Managing goes through one page, This phone
(`lib/ui/screens/this_phone_screen.dart`, route `/this-phone`), for both hosts.

## Former entry points and where they land now (from source)

| Entry point | Before | Now |
|---|---|---|
| Root, connecting to the phone's Termux server (stopped) | `/termux-setup` | This phone (Termux), Start is there |
| Root, connecting to another server on this phone | `/termux-setup` | phone setup start |
| Root, the in-app server failed to start | `BuiltinServerScreen` | phone setup start |
| Home shell / server switcher, the phone's Manage | `/termux-setup` | This phone (Termux) |
| Servers, the Termux row | `/termux-setup` | This phone (Termux) |
| Server settings, managed updates | `/termux-setup` | This phone (Termux) |
| Running now, a protected row / server controls | `TermuxSetupScreen` | This phone (Termux) |
| AI Team intro, "Set up on this phone" | `/termux-setup` | This phone (Termux), Add tools |
| AI Team "On this phone" section, Open setup | `/termux-setup` | This phone (Termux) |
| Claude Code page, Open phone setup | `/termux-setup` | Termux host checklist |
| Phone setup start, Other ways › Use Termux | `/termux-setup` | Termux host checklist (its cost said on the row) |
| The "This phone" card menu | (none) | Manage This phone |
| Settings search "On this phone" | phone setup start | This phone once OpenCode is saved on the phone, else phone setup start |
| Plugins, the one-time AI Team re-offer card | `/termux-setup` | removed (marked for removal in slice-P3.4); the team is added from This phone › Add tools |

`test/this_phone_screen_test.dart` fails if any `lib/` file pushes
`'/termux-setup'` again or either deleted page comes back.

## This phone (P1.5)

One list ordered by what is likely needed: the status row with the one act it
needs now (Set up / Start / Connect to this phone, with Stop the server on
this phone), then Update, Switch to OpenCode 1/2, Add tools, Installed,
Storage, Running now (Termux), Restart after a crash (Termux), Keep running,
Open a terminal (in app), Remove (in app), and **Details last and collapsed**
holding the server log in the one `KitLogPanel`, titled by the server
("OpenCode 1.18.29") so "Server log" is not said twice (sliceAdditions item).

Remove opens the remove-from-phone sheet: the default keeps projects and says
the measured space that comes back; "Delete everything" asks for the typed
name. The measurement waits at most 3 s, then the question shows without a size.

## Images

- `after-this-phone-inapp.png`, `after-this-phone-inapp-scrolled.png`,
  `after-this-phone-termux.png` — the same page for both hosts (dark).
- `after-phone-setup-start*.png`, `after-phone-setup-termux.png` — the ways in.
- `before-builtin-server-setup.png` — the deleted in-app page.
- Light goldens: `docs/qa/revamp-screen-phone-1-2026-09-27/after-this-phone-*.png`
  next to `before-termux-setup-installed.png` and `before-this-phone-log-sheet.png`.

## Not proven

- Emulator walk of every former entry point (slice proof) — not done in this
  session; the table above is from source and widget tests.
- The Termux checklist has no kit cost line of its own: its cost is said on
  the "Use Termux instead" row before anything installs. `KitChecklist` hides
  its cost line while a step needs the person (Get Termux, Allow Termux).
