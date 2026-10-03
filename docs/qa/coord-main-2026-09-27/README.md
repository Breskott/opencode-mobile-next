# coord-main: app root, saved-server card, app-level registrations (2026-09-27)

Finish line: main.dart speaks through the kit only (no SnackBar, no
MaterialBanner, no MaterialPageRoute), every kit error state can reach
Report a problem, and every capabilities.json enable flow resolves to a real
page. Non-goal: no new pages; Start fresh on the bootstrap gate is not built
(see Not done).

## What changed, per page

| Page (map id) | Before | After |
|---|---|---|
| `bootstrap-gate` | Material spinner, "OpenCode could not start", the sanitized exception as the body, a FilledButton | KitStateView: "Opening… · Reading your saved servers." with Try again after 8 s (STATE-5); on failure "Can't read saved servers · If your phone just restarted, unlock it, then try again.", Try again, Copy details, **Report a problem**; the exception only under Details |
| `root-connecting` | Scaffold; "Change server" / "Choose another server"; Try again beside Start on a stopped phone server; host:port in the body; no escalation | KitScreen on the kit ground (the app's status line shows over it); one name "Switch server"; no Try again beside Start; bodies are words, the address is under Details; the unplugged drawing on a remote failure; after 3 failed tries Switch server leads with Try again beside it; a Tailscale address (100.64/10, `*.ts.net`) that did not answer adds "is Tailscale on?" to the checks and offers **Set up Tailscale** through the registered `tailscale-setup` flow; the raw `lastError` goes to the diagnosis (it was mapped to words first, which lost the diagnosis) |
| `share-session-failed-banner` | MaterialBanner "Shared text kept. Could not open a conversation…" with Retry; Dismiss lost the text | The app's KitStatusLine "Shared text saved · couldn't open a conversation", the reason in words (`productErrorText`) under it, Try again, More › Copy shared text / Discard shared text (with **showKitUndo**); a second failure says "Still couldn't open a conversation · shared text saved" |
| `session-link-server-missing-banner` | (P3.9 made it the kit sheet "Add this server?") | unchanged, restyled only by the kit |
| App notices (share waiting, launcher/link waiting, no server, re-entry, connection failed, other server, new conversation failed, quota source changed, monitor open failed, phone server start failed) | 6 SnackBars | One app condition in KitStatusScope (`kit-status-app:*`), drawn by every KitScreen's status slot: waiting lines stay until routed; one-shot lines have Dismiss and go after the kit's undo window (never under accessible navigation); failures say what failed plus words, never raw text |

App-level registrations:

- `KitReportHook.handler = (c, r) => openReportProblem(c, error: r)` in
  `AppBootstrapGate.initState`, so every KitStateView.error / KitNotice error
  offers Report a problem (1 tap, the preview makes 2), from the first page.
- `lib/ui/capability_flows.dart`: `registerCapabilityFlows(controller)` in
  `_OcAppState.initState`. All 21 `KitEnableFlows` on Android; a computer
  leaves the 9 phone-only flows unregistered so their explainer explains
  instead of offering a dead button. Targets: Add server (add-server, codex,
  paseo, server-generation on a computer), This phone (server-generation on
  a phone), phone setup start / Termux, Claude Code page, providers or the
  agent account (model-sign-in), team page (team-turn-on), team host guide
  sheet, voice model sheet, Integrations MCP, Projects chooser, Project
  health (git init), Notifications, Keep running, camera and microphone
  permission (settings when permanently denied), Tailscale setup, Usage ›
  Remaining (quota collector), External agents.
- main.dart routes are KitPageRoute; kit_ratchet_baseline.json drops
  main.dart from G1, G16, G17 and all but "text scale clamp" in G21.

## Tests

New: `test/capability_flows_test.dart` (all flows resolve on Android and
match capabilities.json; desktop set; Turn it on opens Add server),
`test/revamp/coord_main_golden_test.dart` (8 goldens), new cases in
`share_routing_test` (Try again twice, Discard + Undo), `saved_server_connection_card_test`
(escalation, no Try again on stopped, Tailscale offer) and
`connection_failure_test` (tailnet detection, no address in the words).
Updated for the status line: launch/session shortcut and session link
routing, app_diagnostics (bootstrap), kit_ratchet KIT-7 fixture (main.dart
no longer has a route baseline).

Run: those files plus app_text_scale, builtin_server_autostart,
background_notification_navigation, app_lifecycle, appearance_effects,
no_raw_error_text, kit_ratchet: 146 pass, 3 fail, and the same 3 fail on
the base (feat/phone-setup-v2 52ab78c4) in a separate worktree: kit_ratchet
G17 and G21 (other slices' kit/team files), builtin_server_autostart "its
Open setup lands on phone setup" (setup status poll timer). Also
pre-existing on the base: server_profile_reentry (2), team_gate_answer
320dp layout (4), ui_glossary G11/G28, product_ui_regression files cases.
`flutter analyze`: clean.

## Images

Before (census): `before-*.png`. After (goldens, phone 412x915 and
1280x800): `after-*.png`. The share-waiting shots are the real OcApp (it
follows the app's own appearance, so both are dark); the share-failed shot
renders the same KitStatus fields and words in a KitScreen slot (the
routing is covered by share_routing_test).

## Not done / needs a device

- Start fresh on the bootstrap gate (owner map: "confirmed; removes saved
  sign-ins") needs a ProfileStore reset in lib/state/profiles.dart, outside
  this write set.
- "No network at all" on root-connecting needs a connectivity probe.
- add-server-codex / add-server-paseo open Add server at "What runs
  there?"; preselecting the backend needs an argument in servers_screen.dart.
- project-git-init opens Project health (where the action is today); the
  offer at the Git-needing action belongs to those screens.
- Device checks: share from another app while the server is starting, then
  failing; launcher shortcut waits; a Tailscale address with Tailscale off;
  keystore locked right after a reboot.
