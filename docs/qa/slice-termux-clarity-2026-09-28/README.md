# slice-termux-clarity: one truthful Termux state (2026-09-28)

Branch `revamp/slice-termux-clarity` from `feat/phone-setup-v2` @ `bf5b8b24`.
Owner report on build 2061 ("Still too much confusion?"), screenshots in
[`owner/`](owner/). The owner had reset the app's storage on a phone whose
OpenCode 1 runs in Termux, so this is the first run of every existing
Termux user.

Finish line: after a storage reset, the first screen says OpenCode was found
in Termux and offers one act, "Allow access to Termux", which asks Android
directly and then connects on its own; This phone says the same cause with
the same fix, and hides what cannot work.
Non-goal: phone setup screens (another agent's), the migration flow itself.

## What a storage reset clears (Android)

| Kept or lost | What |
| --- | --- |
| Lost | Saved servers, preferences, secure storage (the app's copy of the server password) |
| Lost | Runtime permissions the app held, including Termux's `com.termux.permission.RUN_COMMAND` (clearing app data resets them) |
| Kept (Termux's side) | `allow-external-apps=true` in `~/.termux/termux.properties`, `~/.oc/server.password`, the running server |
| Not stored | The Termux observation was never persisted (read on mount/resume only) |

So the usual state is: permission missing, allow-external-apps still set,
server running with a password the app no longer has. The app takes the
password back from the phone after access (existing `managedServerPassword`).
Both branches are tested: permission revoked with allow-external-apps set
(connects), and with it gone (the next cause, "Allow other apps in Termux").

## Cause matrix (one typed cause: `TermuxProblem`, `lib/termux/termux_reach.dart`)

| Cause | Detected by | Words (first screen / row / This phone) | One act |
| --- | --- | --- | --- |
| `accessNeeded` | capabilities `permissionGranted=false`; `permission_denied` | "This app can't reach Termux yet. Allow access so it can find OpenCode there and connect." (lead, when OpenCode answered on loopback: heading "OpenCode is running in Termux", line "This app can't reach Termux yet. Allow access and it connects to your conversations.") | **Allow access to Termux**: Android's permission dialog (new `requestRunCommandAccess`); granted → re-read → connect automatically |
| `accessBlocked` | request answered `permanentlyDenied` (`!shouldShowRequestPermissionRationale`) | "Android blocked Termux access for this app. In this app's permissions, turn on "Run commands in Termux environment"." | **Open this app's permissions** (the same tap opens settings at once when Android no longer shows the dialog) |
| `otherAppsOff` | Termux's result `errmsg` mentions `allow-external-apps` | "Termux doesn't take commands from other apps yet. One line in Termux allows it." | **Allow other apps in Termux**: sheet with the exact line (copyable) and Open Termux (copies it) |
| `asleep` | `command_timeout` / `missing_result` / discovery timeout | "Termux didn't answer. Android may have put it to sleep. Open Termux to wake it." | **Open Termux** |
| `notAnswering` | Termux says ready, loopback probe fails | "{OpenCode 1} is set up in Termux but isn't answering. A restart usually brings it back." | **Restart {OpenCode 1} in Termux** |
| `notInstalled` | capabilities `installed=false` (shown only with a saved Termux server) | "Termux isn't on this phone. Install it again, or set up the in-app server instead." | **Get Termux** (F-Droid, through `openExternalLink`) |
| `outdated` | no RunCommandService / old protocol | "This Termux is too old for the app to use. Install the current Termux from F-Droid." | **Get the current Termux** |
| `unknown` | anything else | "This phone couldn't check on {runtime} in Termux. Try again in a moment." | **Try again** (the only cause that offers it) |

Before access, the app looks once at its own loopback address
(`127.0.0.1:4096`, never another) so it can say "OpenCode is running" rather
than "maybe"; no Termux command is sent. Technical text stays under Details.

## What the owner now sees

| Place | Before (build 2061) | After |
| --- | --- | --- |
| First screen, nothing saved, Termux found | Truncated row "Allow Termux access in phone setup to check f…" above the full welcome hero and "Where does your coding agent run?" | Heading "OpenCode is running in Termux" (or "Termux is on this phone" when nothing answered), one line, primary **Allow access to Termux**; then "Set up the in-app server instead"; then "Other ways": On my computer, Just show me. No hero, no question, nothing truncated |
| Servers row / server switcher (saved server) | "Allow Termux access in phone setup…" one line, cut | "Needs you ·" inline + the cause, whole (wraps), a named fix button; the row's tap does the fix ("unknown" keeps opening the saved server) |
| This phone | "OpenCode 1 / In Termux / couldn't check… Try again" with a floating "Needs you", plus Update, Switch, Add tools, Claude Code, Installed, Storage | Title "OpenCode" (not a guessed "OpenCode 1"), "Needs you · In Termux" inline, the cause, primary = its fix; Termux-only acts hidden; "Set up the in-app server instead" (says projects move once access is fixed); Keep running; Details. After the fix it reads Termux again and connects |
| This phone, any "needs you" state | "Needs you" floating at the row's end | Inline span at the start of the line (kit `KitNeedsYou.span`) |
| Keep running row | "…doesn't clos…" | Wraps to two lines |
| About | Bundled components legal text with raw file paths on the page | A "Bundled components" row under Open source opens the notices in the viewer; About stays short |

## Images

Phone 412x915 and wide 1280x800, dark, rendered by
`tool/capture/termux_clarity_test.dart` (`--dart-define=CAPTURE_STAGE=before`
on `bf5b8b24`, `after` on this branch), the storage-reset phone from
`test/support/termux_reset_phone.dart`:

- First screen: `before_first-screen_412x915.png` → `after_first-screen_412x915.png`, `…_1280x800.png`
- This phone: `before_this-phone_412x915.png` → `after_this-phone_412x915.png`, `…_1280x800.png`
- About: `before_about_412x915.png` → `after_about_412x915.png`, `…_1280x800.png`
- Golden before/after (left old, right new): `golden_before_after_needs_you_inline.png`, `golden_before_after_keep_running_wraps.png`

## Native (both halves of `oc/termux`)

`MainActivity.requestRunCommandAccess` answers `granted` / `denied` /
`permanentlyDenied` / `missing`; the old boolean `requestRunCommandPermission`
stays for phone setup, and the two never overlap a pending request.
`TermuxBridge.requestRunCommandAccess` + `TermuxAccess.request` on the Dart side.

## Tests

New `test/termux_clarity_test.dart` (13): capabilities → cause, bridge
errors → cause, the observation carries the cause (reset, other apps off,
asleep, not answering, not installed), words + one fix per cause and
"Try again" only for `unknown`; the permission request (granted, permanent
no → app settings), the row fixes in one tap and connects; the other-apps
sheet (line + Open Termux); first screen after a reset (lead, order, compact
other ways), Allow access → password restored from the phone → connected →
Work; allow-external-apps gone → names that next; no Termux → welcome
unchanged; This phone (cause, fix, gating, in-app row, title not guessed,
fix → acts back).

Updated for the intended change: `termux_running_server_test.dart` (denied
now looks once at the loopback; lead keys), `this_phone_plain_failures_test`
(inline Needs you), `about_alpha_notice_test`, `release_blockers_test`
(notices behind the row). `oc2_server_discovery_test` guards that an
unknown cause still opens the saved server.

Run (serial lock, `-j 4`): the files above plus kit_ratchet, ui_glossary,
redaction, no_raw_error_text, kit/kit_manifest, kit/kit_draft_manifest,
architecture_boundaries, golden_harness, design_standard, server_switcher,
phone_server_screens, termux_migration_ui, first_run_*, phone_termux_discovery,
this_phone_* and ~45 other files that mount Servers/This phone/About: all pass
except `server_pairing_paste_test.dart: a cleartext LAN address is explained`,
which fails identically on the base commit (pre-existing).
`flutter analyze`: clean.

Goldens refreshed (reviewed, only the intended changes: inline Needs you,
Keep running wraps, About's new row): 24 files in `test/goldens/this_phone_remove_*`,
`test/revamp/goldens/{close_servers_this_phone_*, phone_this_phone_*,
system_about_*, p310_about_loaded_dark, team_v2_this_phone_installed_light,
termux_v2_this_phone_light}`.

## Still needs a device

- The real Android dialog for `com.termux.permission.RUN_COMMAND`, and the
  `permanentlyDenied` path after two refusals, on the owner's phone.
- Termux's exact `errmsg` for allow-external-apps off (matched on the
  property name).
- That a storage reset revokes the permission on the owner's Android build
  (expected; the flow works either way).
