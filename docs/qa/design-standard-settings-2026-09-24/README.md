# Settings on the design kit (2026-09-24)

## Scope

Spec: [`docs/design/design-standard.md`](../../design/design-standard.md), migration
step 6 (Settings), for the owner's "every screen looks different and adhoc". The
Settings structure stays as set in
[`ux-phase2-settings-hub-spec.md`](../../design/ux-phase2-settings-hub-spec.md) and
`lib/ui/search/search_index.dart` (same groups, rows, keys, search and routes); only
the parts they are drawn with changed.

### Files migrated (now in `test/design_standard_test.dart`)

| File | Screen | Goldens |
|---|---|---|
| `lib/ui/screens/settings_screen.dart` | Settings hub | `settings_hub` |
| `lib/ui/screens/settings/default_shell_row.dart` | hub row "Default shell" | `settings_hub` |
| `lib/ui/screens/settings/server_settings_screen.dart` | This server | `settings_this_server` |
| `lib/ui/screens/settings/notifications_settings_screen.dart` | Notifications | `settings_notifications` |
| `lib/ui/screens/settings/personal_settings_screens.dart` | Appearance; Privacy and local data (destructive rows) | `settings_appearance`, `settings_privacy` |
| `lib/ui/screens/app_diagnostics_screen.dart` | App diagnostics | `settings_diagnostics`, `settings_diagnostics_empty` |
| `lib/ui/screens/perf_trace_section.dart` | its Performance section | `settings_diagnostics` |
| `lib/ui/screens/about_screen.dart` | About and open source notices | `settings_about` |
| `lib/ui/screens/servers_screen.dart` | Servers list, add/edit form | `servers_list`, `servers_add`, `servers_add_failed` |
| `lib/ui/screens/termux_setup_screen.dart` | the old Termux setup ("Other ways › Use Termux") | `termux_setup` |

The old code had 32 of the forbidden parts in these files; the migrated files have
none.

| File (old, `dca366f1`) | Forbidden parts the §8 scan finds |
|---|---|
| `settings_screen.dart` | CircularProgressIndicator 1 |
| `default_shell_row.dart` | CircularProgressIndicator 1 |
| `server_settings_screen.dart` | CircularProgressIndicator 3 |
| `notifications_settings_screen.dart` | Card( 1 |
| `app_diagnostics_screen.dart` | CircularProgressIndicator 1, FilledButton 1 |
| `about_screen.dart` | Card( 2 |
| `servers_screen.dart` | LinearProgressIndicator 1, CircularProgressIndicator 2, FilledButton 3 |
| `termux_setup_screen.dart` | CircularProgressIndicator 4, FilledButton 12 |
| total | 32 (now 0) |

### Kit additions

| Part | File | What |
|---|---|---|
| `KitNotice` (new) | `lib/ui/kit/kit_notice.dart`, exported from `kit.dart` | A message that belongs to one part of a form or list: tinted icon, optional title, words, optional note lines, at most two tertiary actions, optional dismiss; no filled block, no card; one live region. Replaces the red/green verdict boxes, `_InlineFailureCard`, the password banner, the About notices and the Android-stopped card. Documented in the standard §3. |
| `KitRow` (additive) | `lib/ui/kit/kit_row.dart` | `supportingMaxLines` (default 1; a setting's explanation or error may take 2), `enabled` (dims and ignores taps; the supporting line says why), `destructive` (error-coloured title; confirms before acting). Defaults keep every existing row as it was. Documented in the standard §6. |

### What changed, screen by screen

| Screen | Change (standard §) |
|---|---|
| Hub | Rows are `KitRow` (icon, one-line title, two-line explanation, muted chevron) and group headers `SectionLabel` announced as headings (§6). The health check of "This server" is the screen's one loading bar, not a spinner in the row (§4). Disconnect is an error-coloured text button, still separated and confirmed (§2). Search, groups, rows, keys and scroll-to-group unchanged. |
| Default shell row | Loading and saving say so in the row and dim it; no spinner (§4). |
| This server | Rows on `KitRow`; the health check and a server update in flight are the loading bar; the refresh button rests while a check runs; the update row dims while its update runs (§4). |
| Notifications | "Android stopped the live connection" is a `KitNotice`, not a red card (§3). Quiet start/end, battery and service-status rows are `KitRow`; the service state is the tinted icon, not a coloured title (§6). Switch rows are unchanged. |
| Appearance | "Light or dark" is a `KitRow`; Language is aligned to the kit row geometry. |
| Privacy | Storage used is a `KitRow`; Clear queued prompts / Clear drafts are destructive rows (error colour, confirmed), dimmed with their reason when there is nothing to clear (§2). The save error is a `KitNotice`. |
| Diagnostics | Send (primary, spinner only while its tap is in flight), Copy (secondary), Clear (tertiary, error colour, confirmed), stacked full width (§2). Empty is an inline `KitStateView` (§3). Performance: Copy report (secondary), Clear (tertiary). |
| About | No cards: the build identity is plain text, the non-affiliation and build notices are `KitNotice` (Report a bug is the notice's action). Loading is the bar plus skeleton rows (§4); a failed load is a page `KitStateView` (§3). |
| Servers list | Saved servers are `KitRow`s, not tinted cards: kind icon (accent when active), name, then state in the row ("Password re-entry required" in the error colour), generation and address. Add server is the one primary, pinned below the list, with Try demo as a text button (§1, §2). A connect or removal in flight is the loading bar (§4). Failures and the credential banner are `KitNotice`s. Connect OpenCode 2, On this phone and More setup options are rows. |
| Add/edit server | Save & connect is the primary (spinner only while its tap is in flight); Test connection the secondary; Paste pairing code and Scan are text buttons. The test verdict, pairing notice/failure, save failure, keyring notice and missing-password notice are `KitNotice`s on the form's rails instead of red/green blocks (§3). "CONNECTION TYPE" is now a sentence-case section label "Connection type". |
| Termux setup | One primary per state: Install & start (or Start installed OpenCode), Verify & continue after the Termux round trip, Continue to app, or the in-app setup when Termux is missing (Download page is then secondary). Connect existing server is a text button here (a page state with it as the primary off Android). Running-server controls: Restart (secondary), Update and Stop (tertiary, Stop in the error colour and confirmed). Spinners in steps and progress lines are gone; the checks and the install show the screen's one loading bar (§4). Errors are `KitNotice`s. |

### Decisions where the standard left a choice

- **Supporting lines of two.** Settings rows explain what they do; one line cut most
  of them. `KitRow` takes `supportingMaxLines`; lists of things keep one line. The
  storage readout on Privacy takes four (a readout, not a door).
- **Switch rows stay `SwitchListTile`.** The kit has no switch row, the switch rows
  already sit on the 16 dp rails, and several tests read their state. A kit switch
  row is a follow-up.
- **Add server is the servers screen's primary.** Rows connect on tap; adding is the
  one thing the screen offers beyond them, like New conversation on Work.
- **Connect existing server on the Termux screen is tertiary.** It is the way out of
  this screen, not its job; a full-width tonal button above the steps competed with
  Install & start.
- **Termux choose view keeps `shrinkWrap`.** Every step stays laid out so a step's
  control is reachable wherever the list is scrolled (as before).

## Builds

- Branch `ds/settings` from `dca366f1` (feat/phone-setup-v2, design kit merged).
- No APK built. No emulator or phone.

## Devices

None. Widget tests and rendered images only (pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | `design_standard_test`: migrated files have no raw progress, `Card(` or `FilledButton`; every golden exists | clean | PASS |
| 2 | Same scan over the old files (`dca366f1`) | fails | 32 forbidden parts in the 10 files (table above) |
| 3 | Goldens: 12 scenes × dark/light at 412×915 (`test/goldens/settings_golden_test.dart`) | match | PASS (24) |
| 4 | Every test file under `test/` that imports a changed file, `home_screen.dart` or `main.dart` (76 files, incl. l10n coverage, the glossary, text scale, both golden files) | pass | PASS: 1078 tests, 1 skipped (`-j 3`, seven chunks under 9 min) |
| 5 | Hub search, groups, scroll-to-group, 320 dp / 2.5× text / RTL (`settings_hub_test`, `search_index_test`) | as before | PASS |
| 6 | Server update, remote upgrade failure, default shell, privacy clears (`settings_server_updates_test`) | as before | PASS |
| 7 | Server editor flows: pairing, v2 detection, Codex/Paseo, keyring, re-entry (`server_*`, `first_run_*`, `profile_secure_storage_test`) | as before | PASS |
| 8 | Termux setup journeys (`termux_setup_screen_test`, 60 tests) | as before | PASS |
| 9 | `flutter analyze` over the 21 changed Dart files and folders; `dart format --language-version=3.10` | clean | PASS (no issues, 0 files reformatted) |

### Test expectations updated because the standard changed the UI

| Test file | Change |
|---|---|
| `settings_hub_test.dart`, `search_index_test.dart` | row type `ListTile` → `KitRow` (Disconnect gap, width checks, "no rows" after a failed search) |
| `settings_server_updates_test.dart` | `widget<ListTile>` → `widget<KitRow>` for the server-updates, default-shell and clear rows |
| `app_diagnostics_screen_test.dart`, `v2_feature_gating_test.dart` | Send is a `KitButton`, not a raw `FilledButton` |
| `oc2_server_discovery_test.dart` | the generation leads the row's one supporting line instead of its own keyed `Text` |
| `server_profile_reentry_test.dart` | "Password / Connection token re-entry required" is found with `textContaining` (it leads the row's supporting line) |
| `termux_setup_screen_test.dart` | copy/open and verify are `KitButton`s (their role swaps after the round trip); Reinstall is a `KitButton`; after Stop the test scrolls back up to Start installed OpenCode (the controls are stacked now, so Stop sat lower) |
| `e7_project_attention_layout_test.dart` | the quiet-hours start row is a `KitRow` |

## Evidence

- `before-N-*.png` / `after-N-*.png`: the same state rendered by
  `tool/capture/design_standard_settings_test.dart` (scenes in
  `test/support/settings_scenes.dart`) on `dca366f1` and on this branch, 412×915,
  dark, real fonts: 1 hub, 2 This server, 3 Notifications, 4 Appearance, 5 Privacy
  (destructive rows), 6 diagnostics with two errors, 7 diagnostics empty, 8 About,
  9 servers list (active, OpenCode 2, password re-entry), 10 add server,
  11 add server after a failed test, 12 Termux setup (Termux ready, nothing
  installed).
- `before-11` shows the solid red verdict block; `before-8` the nested cards on
  About; `before-9` tinted cards and three button styles on the servers list.
- `test/goldens/{settings_*,servers_*,termux_setup}_{dark,light}.png`: the reviewed
  renders the suite now holds these screens to.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 3 test/design_standard_test.dart test/goldens/settings_golden_test.dart \
  test/settings_hub_test.dart test/settings_server_updates_test.dart \
  test/notifications_settings_screen_test.dart test/search_index_test.dart \
  test/app_diagnostics_screen_test.dart test/v2_feature_gating_test.dart \
  test/oc2_server_discovery_test.dart test/server_profile_reentry_test.dart \
  test/termux_setup_screen_test.dart test/e7_project_attention_layout_test.dart
# Renders (after):
$F test --concurrency=1 tool/capture/design_standard_settings_test.dart
# Renders (before): export dca366f1, copy the scenes and the capture file in, run:
mkdir /tmp/old && git archive dca366f1 | tar -x -C /tmp/old
cp test/support/settings_scenes.dart /tmp/old/test/support/
cp tool/capture/design_standard_settings_test.dart /tmp/old/tool/capture/
(cd /tmp/old && $F pub get && $F test --concurrency=1 \
  --dart-define=SETTINGS_CAPTURE=before tool/capture/design_standard_settings_test.dart)
# Goldens, deliberately:
$F test --update-goldens test/goldens/settings_golden_test.dart
```

The before renders in this folder were taken in this worktree at `dca366f1`, before
any source change, with the same two files.

## NOT proven

- Not viewed on a device: no emulator or phone run, no APK.
- Renders and goldens are English, dark and light at 1× text; Arabic, RTL and large
  text are covered by the existing layout tests (no overflow), not by new images.
- About's golden includes `PRIVACY.md` as bundled; editing that document changes
  the golden.
- The servers list scene has no phone server running (no `PhoneServerCard`,
  running-server entries or managed-server health), and the Termux scene shows
  only the main "choose" state; the installed and progress views are covered by
  the Termux widget tests, not by renders.

## Not migrated (next steps)

- **Settings › Plugins** (`settings/plugins_screen.dart`,
  `settings/server_plugins_section.dart`): the AI Team area, built from the team
  agent's widgets (`builtin_team_section.dart`, team cards, host form); left for
  that owner. Still 6 forbidden parts.
- Widgets these screens embed that live in other files: `PhoneServerCard`,
  `TermuxRunningServerEntry`, `LocalAgentServerEntry`, `ManagedServerHealth`
  (servers list); `LocalAgentOnboardingBlock`, `TeamPhoneOnboardingBlock`,
  `TermuxPhoneToolsRows`, `SetupTerminal` (Termux); `LanguageSettingsTile`,
  `GatedRowTile`, the confirm and shell sheets.
- The first-run welcome inside `servers_screen.dart` (`FirstRunChoice` rows, 24 dp
  rails): no forbidden parts, not restyled.
- Switch rows (`SwitchListTile`), the diagnostics entries (`ExpansionTile`), the
  Termux runtime radio list and paste-guide illustrations: Material parts kept.
