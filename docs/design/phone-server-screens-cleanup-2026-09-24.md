# Plugins, Servers and "On this phone": cleanup (2026-09-24)

The owner, on build 2051 on his phone, said: "Wttf is this shiit".

Screenshots:
- `docs/qa/design-regressions-2026-09-24/phone-1-plugins.jpg`
- `phone-2-on-this-phone-termux.jpg`
- `phone-3-servers.jpg`

Ledger rows 10–12 in `docs/qa/design-regressions-2026-09-24.md`.

Build on `docs/design/design-standard.md` and `lib/ui/kit/`. Keep behaviour; fix structure, hierarchy and words.

## 1. Servers (`lib/ui/screens/servers_screen.dart` and the widgets it shows)

Today the phone's own server appears three times:
- a "Server found on this phone" card, with Connect, Restart and Stop as big buttons over two rows;
- a "This device (Termux)" row;
- an "On-device server" block, with explanations, a crash-recovery toggle, "Attempts used: 0 of 3", Refresh and "On this phone".

Target:
- **One row per server.** The phone's server is one row:
  - title "This phone";
  - supporting line "OpenCode 2 · Running", or Stopped, Starting, or Not answering;
  - a trailing overflow menu with Restart, Stop and Details.
- **Connect** is tapping the row. If a row is not the connected server, a small "Connect" text action can sit at its end; no large buttons in rows.
- The server you are connected to carries a visible current mark in its row. This is ledger row 3.
- The crash-recovery toggle, the attempt counter and the Android caveat move off this screen, into the phone server's Details (Settings › On this phone). The list is for choosing a server, not configuring one.
- "Connect OpenCode 2", "On this phone" and "More setup options" stay as rows below the servers, as today. The pinned "Add server" primary and "Try demo" stay.

## 2. On this phone (`lib/ui/screens/termux_setup_screen.dart`, and the phone-server Details it becomes)

Today, when the server runs:
- a big "Continue to app" button;
- "Other OpenCode versions";
- a big "Restart local server" button;
- then "Update OpenCode" and a red-square "Stop local server" crammed on one line;
- then storage, running processes, and a Claude Code card.

Target when running (standard §2 and §3):
- Title "OpenCode on this phone"; one status line: "Running · OpenCode 2 · version 2.0.10".
- One primary: "Continue to app".
- Then one secondary, "Restart".
- Then the tertiary actions stacked, never side by side: "Update OpenCode", and "Stop", destructive in the error colour with a confirm. The red square icon goes; use the kit's stop icon.
- "Other OpenCode versions" becomes a row in an "Options" section with the recovery toggle (moved from Servers) and the storage and "Running now" rows.
- The Claude Code card becomes a row ("Claude Code on this phone · Optional") that opens its own page. It is not a large card in the middle of this screen.
- The stopped, installing and failed states use `KitStateView` with the same button order.

## 3. Settings › Plugins (`lib/ui/screens/settings/plugins_screen.dart`, `server_plugins_section.dart`)

Today every server plugin is a row showing:
- its internal id (`opencode.tool.input.repair`);
- "Active", "Built in";
- and a "Link commands" button.

A "Clear personal links" action sits above the list.

Target:
- **Plain names.** Show a human title: the plugin's own title if the server gives one; otherwise a readable form of the id's last part, for example "Input repair", "Worktree", "Browser", "MCP". The raw id goes under the row's Details, in mono.
- **Built-in plugins collapse into one row:** "Built in · 7 active", which expands. Only plugins the person added are listed openly.
- **State lives in the row** (§6): a status mark and one supporting line ("Active", "Failed to load", "Disabled"). No separate "Built in" line.
- **"Link commands" moves into each row's overflow menu**, and only for plugins that have commands. "Clear personal links" moves into the section's overflow menu, with a confirm.
- **"In this app":** the AI Team row reads "AI Team · Off", or "On · This phone". "Gas City" and "Add manually" go into its own page.
- Keep the explanatory sentence to one line, or drop it.

## Rules and proof

- Kit only. Additions go in new kit files. `test/design_standard_test.dart` gains these files, with goldens (dark and light, 412×915) for:
  - Servers with a running phone server plus one remote server (connected);
  - On this phone: running, and stopped;
  - Plugins: server plugins plus the AI Team row.
- Before/after renders and a README in `docs/qa/phone-server-screens-2026-09-24/`, with a row in the `docs/qa/README.md` index.
- Update ledger rows 3, 10, 11 and 12 with the fix commit.
- Behaviour tests: the phone server appears once on Servers; the current server is marked; Stop confirms; Plugins shows no raw id in a row title; built-ins collapse. At least one fails on the old code.
- Pinned Flutter only. Tests with `-j 3` at most, run in the background. No emulator, no APK build.
