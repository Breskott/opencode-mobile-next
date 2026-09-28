# slice-aisetup-review — AI setup, review only (2026-09-28)

Owner decision 2026-09-28: ship the setup assistant as **review only** now.
This supersedes STANDARDS AUTO-20's "no assistant row" for this one read-only
page; nothing here proposes, applies or undoes a change, and no model runs.

**Finish line:** from a server's settings page a person opens **AI setup** and
sees the configuration that applies, the MCP tool servers with their status in
plain words, and read-only suggestions, in every state, with no credential ever
shown. **Non-goal:** Apply/Undo, MCP mutation, AI sessions, the guided planner
form, the registry.

## What changed

| Where | Change |
| --- | --- |
| Server settings (`lib/ui/screens/settings/server_settings_screen.dart`) | New row **AI setup** · "Models, tools and suggestions for this server", first in the host group. Shown only when `ServerCapabilities.setupConfigRead` (OC1 and OC2 yes; Codex / Claude Code via Paseo no entry). Never gated on flavor. |
| New page `lib/ui/screens/settings/ai_setup_screen.dart` | Kit parts only (KitScreen, KitTopBar, KitNotice, KitRowGroup/KitRow, KitDetailsFold, KitStateView). One list, most urgent first: review-only line → Suggestions → Tool servers (needs sign-in, failed, waiting/unknown, off, connected) → configuration. OC1: "Settings in effect" (model, small model, default agent, providers by name, permission rule count) + "All settings" fold with the redacted JSON. OC2: "Configuration sources" in the server's lowest→highest priority order, each with the top-level settings it sets + "All sources" fold; never a merged view. |
| New `lib/state/setup_session.dart` | Composition owner outside the UI: builds `SetupController` for the connection's profile + directory + workspace + transport (`setupGatewayFor`: OC1 → `OpenCode1SetupConfigGateway`, OC2 → `OpenCode2SetupConfigGateway`, anything else → unsupported), recreates it (awaiting the old one's disposal) on any change including away-and-back, releases it on `profileDataChanges`, follows online state (offline keeps the last read; reconnect reads again). Exposes only `refresh()`. |
| New `lib/domain/setup_suggestions.dart` | Pure suggestions from the redacted snapshot: sign in to a tool that needs it, check a failed tool, choose a default model (effective config only), add tool servers. Kinds only; the UI words them. |
| `lib/l10n/app_en.arb` | 52 `aiSetup*` strings (English only). |
| `docs/design/ai-setup-assistant-contract.md` | Status line notes the wired review-only page. |

States designed: loading, ready (OC1 / OC2), empty, offline (nothing read yet /
last read kept with a line saying so), unsupported, needs sign-in (action:
"Change sign-in for <server>"), error (plain words, Try again, authored reason
only under Details; `uncertain` maps here too). The top-bar refresh appears only
over a successful read, so no action shows twice.

Privacy/security: the page renders only the controller's `setupRedact`ed
snapshot (provider options, headers, environment, commands, prompts masked
structurally; KitRedact for URL sign-ins and known keys); KitDetailsFold redacts
its text again and Copy all copies the redacted text. No new storage key, no
write path, no credential entry. The controller's audit store requires the
profile to be saved (`oc.profiles`), as it is in the app.

## Tests

New, all passing:

- `test/revamp/slice_aisetup_review_test.dart` (13): entry shown/opened through
  the real OC1 adapter over a fake HTTP transport; no entry on a Paseo server;
  **no credential renders** (provider apiKey, plain password, URL user-info,
  Authorization header, command-line token, env value; fold and "Show all"
  opened) — verified to fail when `setupRedact` is made a no-op; OC1 content,
  urgency order, status words, no Apply/Undo/Save/Propose text; OC2 ordered
  sources, no invented merge; loading, empty, unsupported, needs sign-in, error +
  Try again, offline before a read, offline keeps data + reconnect re-reads;
  location change recreates the owner.
- `test/revamp/slice_aisetup_review_golden_test.dart` (22 goldens).

Pre-existing tests run once: kit_ratchet,
redaction, credential_ingress_redaction, ui_glossary, no_raw_error_text,
l10n_coverage, kit/kit_manifest, kit/kit_draft_manifest, screen_servers_2 (+
goldens, 14 server-settings goldens regenerated for the new row),
settings_hub, v2_feature_gating, safety_confirms, setup_controller,
setup_config_adapter, goldens/settings_golden, revamp/screen_settings_1_golden.
All gates pass (kit_ratchet G16/G17/G21, redaction, ui_glossary G28,
no_raw_error_text, l10n_coverage, kit_manifest, kit_draft_manifest).
38 failures remain in screen_servers_2_golden (pairing scanner, switch-server
question), safety_confirms (3), goldens/settings_golden and
revamp/screen_settings_1_golden; the identical 38 fail at base `33ccb2ea` in a
separate worktree, so none is new. `flutter analyze`: no issues.

## Images

- `before/servers_server_settings_loaded_*` → `after/servers_server_settings_loaded_*`
  (phone and 1280x800, dark and light): the new AI setup row.
- `after/aisetup_*`: every state, dark and light; `aisetup_oc1_ready_1280x800_*`
  and `aisetup_oc2_sources_1280x800_*` for the wide window;
  `aisetup_oc1_all_settings_412x2300_*` shows the unfolded settings with the
  provider key masked.

## Still needs a device

- A live OC1 1.18.32 and OC2 2.0.10 server: real `/config` and `/mcp` answers,
  especially OC2 source `type` words and large configs in the fold.
- Settings search does not index the new row yet (reachable from server
  settings only).
