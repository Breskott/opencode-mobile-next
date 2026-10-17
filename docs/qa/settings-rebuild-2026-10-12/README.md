# Settings rebuild, 2026-10-12: evidence record

Branch `feat/settings-rebuild`. Spec: the approved Settings Standard, `docs/design/settings-ia-audit-2026-10-12.md`, `docs/design/settings-scope-2026-10-12.md` §5 and §11, and the frozen contract `docs/design/settings-scope-contract-2026-10-12.md`.

## How the images were made

Release build (`flutter build apk --release --target-platform android-x64`, pinned Flutter 3.47.1, signed with the public Android debug keystore, never the owner's keys) on a fresh Android 14 emulator (shotlist, `settings.toml` here). Two real OpenCode 1.18.23 servers ran on the host loopback and were added through the app's own Add server screen, named Workstation and Laptop. English, dark, one screen per image. The owner's phone was not touched.

| Image | What it shows |
|---|---|
| `one-server-hub.png` | Hub with one server. The Settings tab has no server switcher chip, only search. |
| `several-hub.png` | Two servers: Servers "2 servers"; Model, Providers, Tools and Shell for commands say "By server". |
| `several-hub-servers.png` | The same hub scrolled to the end: "You can change some of these for one server" and each server with its state. |
| `hub-different.png` | Notifications reads "Different on 1 server" after Laptop's own "Notify when attention is needed" was switched off. |
| `server-page.png` | Laptop's page, top: Connection, In this app (model by name, per-server Share read state), On Laptop. No icons, no repeated subtitle. |
| `server-page-bottom.png` | Its bottom: "Saved on Laptop. Other apps using Laptop get this too.", Shell for commands "Automatic", Details, Disconnect and Remove last. |
| `server-page-use-my-default.png` | The page of a server with a difference, ending in "Use my default" above Disconnect and Remove. |
| `arabic-hub.png`, `arabic-hub-top.png` | Arabic hub, mirrored: bottom with the server block, and top. |

## Not shown, and why

- The tablet two-pane layout is covered by a widget test only.
- Round 2 images were taken from a rebuilt release APK after merging `feat/settings-scope-state`.
- This phone showed "Set up" because no phone host was installed on the emulator.

## Tests

`test/settings_rebuild_test.dart` (new, 15 tests): one-server hub without pickers, one-line rows and fixed labels, an honest Model row, "By server" rows and the server list, By server pages opening the server page, the three sections and the "Saved on" line, a not-connected server pinned to its own name, override count and Use my default, search deep links (quiet hours, keep running, permissions, language, new and retired names), Arabic mirroring, tablet two-pane.
Updated: `settings_hub_test`, `search_index_test`, `settings_search_rows_test` and about 25 more that opened rows that moved. Goldens regenerated on purpose: hub, server settings, AI Team (now on the Agents page), Settings IA, default model.

## Known gaps

See the final report of this branch: Voice typing is still a sheet, quota alerts did not move to Usage, Usage has no "62% left" value, no personal "preferred model" yet (slice E), so "Use my default" resets notifications only.

## Round 3 (owner test on APK 2226): five gaps

Images below are widget-test renders with the app's real fonts (412x915 at 2.5x), not emulator shots.

| Image | What it shows |
|---|---|
| `server-page-reconnect-and-default.png` | Server page end: Use my default now names notifications, model and read sharing; "Reconnect to Workstation" above Disconnect. |
| `voice-typing-page.png` | Voice typing as a normal page with the download pinned at the bottom. |
| `usage-remaining-quota-alerts.png` | Usage > Remaining holds the "Low quota alerts" switch. |
| `notifications-quota-points-to-usage.png` | Notifications keeps only a "Quota alerts" row that leads to Usage. |
| `hub-language-chevron.png` | Language is a plain row; its chevron lines up with Appearance's. |
