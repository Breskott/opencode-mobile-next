# slice-cred-status: a saved password the phone can no longer read

Branch `revamp/slice-cred-status`, base `83c64539` (feat/phone-setup-v2).
Fixes follow-up 1 of `docs/qa/slice-fix-servers-2026-09-28/README.md`.

## The bug

When the phone's secure storage can no longer open a saved server password
(`ProfileStore._restoreSecret` catches the Keystore failure and sets
`requiresPasswordReentry`, e.g. after a device restore or a lock-screen
change), the one connection status line said "‹server› isn't answering ·
Reconnect to ‹server›". Nothing had been tried and Reconnect could not help.
The Servers page also repeated the problem in a second notice under the line.

## What changed

- `lib/domain/connection_status.dart`: new phase `credentialsUnreadable`.
- `lib/state/connection.dart` (`connectionStatus` only): an owner whose saved
  password (or, for token backends, token) could not be read is
  `credentialsUnreadable`, ahead of `passwordRejected` and every transport
  phase (P4.4: credentials first). The rejected-password path is unchanged.
- `lib/ui/widgets/connection_status_banner.dart`: the line says
  "Can't read the saved password for ‹server›" with the action
  "Enter the password" (opens `/servers` `edit-active`, which opens that
  server's edit form with the password field focused). More → Details opens a
  sheet in plain words: the phone's secure storage couldn't open the saved
  password, e.g. after a restore or a screen-lock change, and the password
  itself was not changed. No platform exception text is shown anywhere (the
  store never keeps it). Token backends get the same with "token".
- Servers page: the second notice ("A saved server credential can no longer
  be read…") is removed; the line says it once. The server row (and the
  server switcher, which uses the same word) now says "Can't read the saved
  password" / "Can't read the saved token" instead of "Password re-entry
  required".
- Connecting page card: not changed. The root never shows the card in this
  state: `main.dart` sends a profile needing re-entry to the Servers page
  without connecting, which is what the images show.
- Copy: new `connectionPasswordUnreadable`, `connectionTokenUnreadable`,
  `connectionEnterPassword`, `connectionEnterToken`,
  `connectionPasswordUnreadableDetails`, `connectionTokenUnreadableDetails`;
  changed `e7SetupPasswordRequired`, `e7SetupTokenRequired`; deleted (en and
  ar) `connectionCredentialUnavailable`, `e7SetupPasswordBanner`,
  `e7SetupTokenBanner` (now unused) and the unused `iosAppTitle` (also taken
  off the ui_glossary allowlist).

## Tests

- New `test/credential_unreadable_status_test.dart`, written first and failing
  on the base ("Workstation isn't answering" was found, phase
  `notAnswering`): a real `ProfileStore.load` with the
  `plugins.it_nomads.com/flutter_secure_storage` channel mocked to throw a
  Keystore exception on read → the line and action above, no "isn't
  answering", no "Reconnect", no second notice, no exception text on screen
  or in Details, and "Enter the password" opens the edit form with the
  obscured password field focused, with no connect attempt. A second test
  keeps the rejected-password line ("Server password changed — reconnect." ·
  "Update password").
- New `test/revamp/cred_status_golden_test.dart` (4 goldens).
- Updated `test/server_profile_reentry_test.dart` (new words, no notice).
- Passed: the new files, `server_profile_reentry`, `connection_status`,
  `launch_shortcut_routing`, `session_link_routing`, `server_switcher`,
  `revamp/shared_servers_1`, `revamp/screen_servers_1` (123 tests); gates
  `kit_ratchet`, `redaction`, `ui_glossary`, `no_raw_error_text`,
  `kit/kit_manifest`, `kit/kit_draft_manifest`, `architecture_boundaries`,
  `l10n_coverage` (123 tests). `flutter analyze`: no issues.
- Goldens compared with the base in a temporary worktree
  (`settings_golden`, `shared_servers_1_golden`, `screen_settings_1_golden`,
  `sessionlink_ui_golden`): 28 failures on the base are pixel diffs that were
  already there and are left for the reviewed refresh. The only new failures
  were `server_switcher_sheet_light` and `_1280x800_light` (the row's new
  words); those two are refreshed. The dark switcher goldens already fail on
  the base and were not touched.

## Images

- `before_servers_dark.png`, `before_servers_light.png`,
  `before_servers_1280x800_dark.png`: "isn't answering · Reconnect", plus the
  second notice, rows "Password re-entry required".
- `after_servers_dark.png`, `after_servers_light.png`,
  `after_servers_1280x800_dark.png`: one line "Can't read the saved password
  for Workstation · Enter the password"; rows say the same.
- `after_details_light.png`: the Details sheet.
- `before_switcher_light.png` / `after_switcher_light.png`: server switcher row.

## Still needs a device

A real Keystore invalidation (restore or screen-lock change on Android) to
check the whole path end to end, and TalkBack reading the line.
