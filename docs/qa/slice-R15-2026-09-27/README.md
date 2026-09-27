# slice-R15: Servers, server settings, Linux service, guide and Tailscale pages (2026-09-27)

Definition: `docs/ux-system/revamp/leftover-units.json`, id `slice-R15` (no sliceAdditions). It builds on R14's `PhoneServerCard.row(...)` and on P3.9's Add server flow, which shows the same Tailscale steps.

## What changed

| Page / file | Change |
|---|---|
| Servers (`servers_screen.dart`) | "This phone" (OpenCode inside the app) is now a `PhoneServerCard.row` inside the one `servers-list` group. It used to be a separate card above the list. It is ranked with `_byUrgency` like every saved server: a server that needs you or has work running goes above it, and when nothing is urgent it comes first (first among equals, like before). Its row menu now has "Disconnect from this phone" while it is the server in use. The row keeps the key `phone-server-card-<id>`. The removal flow (`_delete`) was not touched. |
| `local_server_row.dart` | A new `mark` (default: the phone) gives each agent its own glyph. Claude Code on this phone passes `AppIconography.agent`, a robot, so the two phone agents no longer share the phone icon. The ⋮ `KitRowMenu` and the failure text were already there. The failure stays in LOOK-5's failure tone (`text1`, never `danger`), and a test now checks that. |
| `local_agent_server_entry.dart` (outside the write set, 2 lines) | Passes `mark: AppIconography.agent` at both `LocalServerRow` call sites. |
| Server settings (`server_settings_screen.dart`) | When updates are handled outside the app, the row reads "Copy update commands for {server}" and copies when tapped. Its line then changes from "Run them in a terminal on the server's computer; this app can't update it." to "Copied. Run them…". The trailing `KitIconButton.copy` is gone, and so is the trailing download mark on the "Update to {version}" row. `e7SettingsUi66` now reads "Keep OpenCode running after you close the terminal." The `KitDivider` and the extra `SizedBox` above Disconnect are removed, leaving one `sectionGap`. |
| Run as a Linux service (`host_management_screen.dart`) | The "This server" group (name, address, version and instructions) is deleted: the server's own page already shows them. One line under the bar now reads "These commands run on {server}'s computer; copy each into a terminal there." The page title names the server: "Linux service for {server}". |
| Guide (`guide_screen.dart`) | Step two reads "Tap Add server, then Scan code and point the camera at the QR, or Paste code." Without a camera it reads "Copy the printed code, then tap Add server and Paste code." The "Open Servers" instruction is gone, and the Add server button stays. The private `_Chevron` became `KitChevron`. |
| Tailscale (`tailscale_setup_screen.dart`; also used by the Tailscale step of Add server) | The steps are now one `KitRowGroup` ("1. Open your private network") of `KitRow`s. Each row has a `KitStatusMark`, and a step the person still has to do reads "To do · …" with the neutral to-do ring, never "Needs you". Each button sits under its words. "Check Tailscale again" is the panel's last row, and it also shows after a failed check. The one caveat line is the field helper, "Paste the HTTPS address Tailscale Serve printed." The device-list note and the review note moved into "Tailscale setup and recovery". The intro is one sentence. `_SectionLabel` became `KitSectionLabel`. `KitChecklist` is no longer used here. |
| `app_en.arb` | New: `serverSettingsUpdateCommandsDetail`, `serverSettingsUpdateCommandsCopied`, `hostServiceTitle`, `hostServiceIntro`, `tailscaleSetupToDo`, `tailscaleSetupNoDeviceList`. Changed: `serverSettingsCopyUpdateCommands` (now takes `{server}`), `e7SettingsUi66`, `guideStepTwoScan`, `guideStepTwoPaste`, `tailscaleCheckAgain`, `tailscaleSetupAddressHelper`, `tailscaleIntro`. Deleted as unused, also from `app_ar.arb`: `e7SettingsUi54`, `e7SettingsUi55`, `e7SetupThisServer`, `e7SetupNotConnected`, `e7SetupServerVersion`. gen-l10n was rerun. |

### Deviations from the acceptance text (the gates win)

- The acceptance asked for the Linux service page to be titled "Run {server} as a Linux service". G28 (`ui_glossary_test`) allows at most four words in a title, and that title has six, so the title is "Linux service for {server}".
- The acceptance asked for the intro "…the computer that hosts {server}…". G28 rejects "hosts" (a glossary noun), so the intro reads "…run on {server}'s computer…".
- The row copy uses `KitCopy` with redaction on. `redaction_test` rejects a new `redact: false`, and the commands hold no secrets, so they copy unchanged.

## Images (dark; before = the base regenerated, after = this branch)

- `servers-inapp-phone-{before,after}-dark.png` and `servers-inapp-phone-wide-{before,after}-dark.png` show the in-app phone moving from a card above the list to a row in it. Golden: `test/revamp/slice_r15_golden_test.dart`.
- `server-settings-{phone,wide}-{before,after}-dark.png`
- `linux-service-{phone,wide}-{before,after}-dark.png`
- `guide-{phone,wide}-{before,after}-dark.png`
- `tailscale-missing-phone-{before,after}-dark.png` and `tailscale-installed-wide-{before,after}-dark.png`
- `local-agent-row-{phone,wide}-{before,after}-dark.png` show the robot mark for Claude Code.

Goldens: `phone_server_screens`, `screen_servers_1/2/3` and `shared_servers_1` were regenerated both here and on the base (a473c04a). Only the images that differ from the base's own regeneration were kept, and the rest were reverted.

## Tests

New:
- `test/revamp/slice_r15_test.dart` checks `LocalServerRow`: each agent's mark, filled when the row is in use; its own ⋮ menu with its actions; and the failure text in `text1`, not `danger`.
- `test/revamp/slice_r15_golden_test.dart` renders Servers with the in-app phone as a row of `servers-list` (phone and 1280×800, dark and light).
- `test/phone_server_card_test.dart`:
  - "Servers lists the card…" now also checks that the phone row is inside `servers-list`, that no `phone-server-card` panel is left, and that the phone row is above Work.
  - New "a working server ranks above This phone in the one list".
- `test/tailscale_setup_test.dart`:
  - The steps are one panel of 3 rows, with To do and no Needs you.
  - Each button sits under its words.
  - Check Tailscale again is a row in the panel.
  - There are 2 `KitSectionLabel`s.
  - There is one caveat line, and the rest is in the fold.
- `test/revamp/screen_servers_2_test.dart`:
  - Step two's wording, with no "Open Servers".
  - The update row has no trailing download mark.
  - The new `e7SettingsUi66` text.
  - The row copies when tapped and then says "Copied…".

Updated expectations: `settings_hub_test` (no disconnect divider), `settings_server_updates_test` (the copy row's words) and `host_management_screen_test` (title, intro, no "This server").

Run once:
- Slice tests: servers_scenes, host_management_screen, tailscale_setup, tailscale_profile, profile_monitor_phone_servers.
- Gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text, kit/kit_manifest.
- Other affected files: screen_servers_1/2, settings_hub, settings_server_updates, phone_server_card, add_server_steps, first_run_computer_path, local_agent_onboarding, shared_servers_1, shared_phone_1, phone_server_screens, termux_running_server.

All the gates pass. Every failure that remains also fails on the base commit a473c04a, checked in a temporary base worktree:
- `servers_scenes` goldens (5)
- `tailscale_setup`: the external-link sheet's host text (2)
- `host_management`: "Copied. Run it on the server's computer." (1)
- `settings_server_updates`: shell, privacy and service timeout (5)
- `first_run_computer_path` (9)
- `local_agent_onboarding` (1)
- `phone_server_screens` (2)
- `termux_running_server` (8)

`flutter analyze lib test` is clean.

## Still needs a device

- A phone with OpenCode in the app, plus a remote server with running work: check the order of the list, and that TalkBack reads the phone row as one row of the list.
- Claude Code in Termux next to OpenCode: the robot mark versus the phone mark.
- Tailscale on a real phone: Get Tailscale → Play Store → back → the auto-recheck, and the To do rows.
- Tapping "Copy update commands for {server}" gives a light haptic and a single "Copied" announcement.

Not done here: Claude Code's "Start Claude Code" repeats the row's name (`local_agent_server_entry.dart` `startLabel`, which is not in this write set).
