# revamp-screen-library-1: Revamp library (3 files) (2026-09-27)

## 1. Scope

- Unit: `screen-library-1` (wave 2b, screen-revamp). Finish line: the three write-set files construct only kit parts (G1, G16, G7 and the look gates at 0), the pages follow their map proposals in the visual language, gates explain instead of vanishing, and the two OAuth-code dialogs are one KitDialog. Non-goal: no gateway call, controller field or persistence added; the `integrations` redesign (agent-driven and catalog MCP setup) waits for its wave-3 slice.
- Files changed: `lib/ui/screens/library/catalog_screen.dart`, `lib/ui/screens/library/integration_tiles.dart`, `lib/ui/screens/library/integrations_screen.dart`, `lib/l10n/app_en.arb` (43 new keys, `catalogScreen*` and `integrations*`), `lib/ui/screens/library_screen.dart` (one import line, see Contract problems), `test/revamp/screen_library_1_test.dart`, `test/revamp/screen_library_1_golden_test.dart`, `test/revamp/goldens/library_*.png` (22).
- Pages (map ids): catalog, integrations, integrations-authorization-launch-dialog, integrations-connect-key-dialog, integrations-connect-method-sheet, integrations-disconnect-provider-sheet, integrations-mcp-oauth-code-dialog, integrations-oauth-code-dialog, integrations-oauth-inputs-dialog, integrations-remove-mcp-sheet.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-20, KIT-22, KIT-23, KIT-25, KIT-27, KIT-28, KIT-34, LOOK-1, LOOK-2, LOOK-5, LOOK-12, LOOK-15, LOOK-21, STATE-8, STATE-9, STATE-12, SEC-1, SEC-3, MAP-1; kit-v2 §9.1; visual-language §5 (rows in surface1 panels, sentence-case section labels, sheets with icon tile and start-aligned title).
- Contract problems (PROC-20):
  - {PROC-10 / write set, "a unit writes only its write set", the three files are `part of '../library_screen.dart'` and a part file cannot import, so no kit part is reachable without an import in `lib/ui/screens/library_screen.dart`, evidence `lib/ui/screens/library_screen.dart:1-36`, proposed: "a screen unit whose write set holds part files may add import lines to their library file", blocks: false if the coordinator accepts the one-line commit `eaecb9a8` (`kit_refresh.dart` import replaced by `kit.dart`, which re-exports it); screen-library-3 and -4 need the identical line}.
- New kit parts (KIT-3): none.
- Moved or removed items (owner rule 2026-09-27, rethink):
  - "Manage accounts" and "Server sign-in" buttons under every provider row → the provider's row menu ("Manage {name} accounts", "Sign in to {name} on the server").
  - Trailing "Disconnect" button → the row menu, last and destructive ("Disconnect {name}"); a connected row's tap opens that menu.
  - Separate red "Remove" line under every MCP row → the MCP row menu ("Remove {name} until restart"), neutral.
  - The "legacy sign-ins cannot be recovered" paragraph at the top of the page → a note on the pending sign-in notice, the only moment it matters (new wording `integrationsPendingNotRecoverable`).
  - Section description lines → the section label's in-place explanation (KitTerm ⓘ); in single-domain modes the duplicated section label is dropped and the provider count moves to the top bar subtitle.
  - The "2 connected · 5 available" row → the Providers label's count ("2 of 4 connected").
  - Success SnackBars → one dismissible KitNotice at the top of the list (KIT-34).
  - `ModelStatusPill` (unused anywhere) deleted.
  - Added: "Copy address" in a resource row's menu.
- Map items (EVID-11):
  - catalog: actionsMissing "Connect a provider" → done: `screen_library_1_test.dart` "Models offers to connect a provider when none is signed in", golden `library_catalog_no_provider_*`. statesMissing "no provider signed in" → done (same); "loading skeleton" → done as KitScreen's loading bar while `catalogLoading` (no test); "offline" → done: KitNotice when the stream is not connected, visible in the golden (no dedicated test). couldBeAutomatic: none.
  - integrations: actionsMissing "ask an agent to set up an MCP server", "browse MCP servers from a catalog as toggles" → deferred to the integrations redesign slice (map proposal `redesign`, no slice id in work-units.json: no owner); "undo Remove" → no owner (runtime removal has no re-add call; the confirmation now says the server comes back on restart). statesMissing "first run: no provider connected" → partial: every provider reads "Not connected" with a chevron that opens its connect flow; "loading skeleton" → done: KitSkeletonRows per section; "offline" → done: inline KitStateView.error with Try again; "MCP empty with the three ways to add" → partial: one way (Add an MCP server); the other two deferred with the redesign. couldBeAutomatic: MCP reconnect on token expiry → no owner; pending check already polls → n/a.
  - integrations-mcp-oauth-code-dialog: actionsMissing "Paste" → done (KitField.secret paste suffix, golden of the same field in `library_integrations_connect_key_dialog_*`); statesMissing "code rejected (state mismatch)" → done: the parse error stays under the field (onSubmit keeps the dialog open; no dedicated test); "expired" → no owner (the server sends no expiry for MCP attempts).
  - integrations-oauth-code-dialog: `merge-into:integrations-mcp-oauth-code-dialog` → done: both flows call `_showFinishSignInDialog`. A retired `_OAuthCodeDialog` built from kit parts stays only because `pending_auth_recovery.dart` (screen-library-3) still calls it.
  - integrations-oauth-inputs-dialog: statesMissing "invalid value" → done: each required question shows its reason under it; primary named for its result → done, golden `library_integrations_oauth_inputs_sheet_*`.
  - integrations-remove-mcp-sheet: actionsMissing "Turn off until restart" → done as "Remove {name} until restart" (neutral confirmation); "Delete from configuration" → no owner (no gateway call deletes configuration; wave 2 adds none).
  - integrations-authorization-launch-dialog: fix → done: "Sign in at {host}?" plus "Approve access in your browser, then come back to this app.", golden `library_integrations_sign_in_sheet_*`.
  - integrations-disconnect-provider-sheet: fix → done: "Removes the {name} key from this server. A reply already running finishes first.", test "Disconnect names the provider and confirms before it acts", golden `library_integrations_disconnect_sheet_*`.
  - integrations-connect-method-sheet: fix → done: titled "Connect {name}", each method's supporting line, golden `library_integrations_connect_method_sheet_*`.
  - integrations-connect-key-dialog: statesMissing "key rejected", "saving" → done: test "a key is sent from the one dialog and never shown again"; actionsMissing "paste", "show/hide" → done (KitField.secret); "Get a key" → no owner (no provider key-page URLs in the app's data; not invented).
- States per page (STATE-20): integrations: loading (skeleton), empty (KitStateView per section), error (KitStateView.error with Try again), not available (KitCapabilityExplainer, test + golden), loaded (goldens). catalog: loading bar, offline notice, no provider (test + golden), not available (explainer), loaded (ModelCatalogView, unchanged).
- Deferred states (STATE-21): MCP OAuth "expired" → needs an expiry signal from the server, no owner.

## 2. Builds

- Branch `revamp/screen-library-1`, base `9007257d`, code head `101cc2df`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_library_1_test.dart` | passes | 5 passed (`tests.txt`) | PASS |
| 2 | `test/revamp/screen_library_1_golden_test.dart` | passes against the committed goldens | 22 passed (`tests.txt`) | PASS |
| 3 | `test/kit_ratchet_test.dart` (and a `KIT_RATCHET_WRITE=1` dry run, baseline restored) | passes; the three files at 0 for G1, G15, G16, G7, G17, G21 | passed; only G2 `launchUrl(` 1 remains in `integrations_screen.dart` | PASS |
| 4 | `flutter analyze lib test` | no errors; no issues in changed paths | 5 infos, all in other units' test files (`analyze.txt`) | PASS |

Other suites were not run (owner decision 2026-09-27).

## 5. Evidence

- `tests.txt`: steps 1 and 2. `analyze.txt`: step 4.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | SEC-3 (a key is never echoed) | `test/revamp/screen_library_1_test.dart` "a key is sent from the one dialog and never shown again" | `tests.txt` |
  | DATA-11 (confirm before a destructive act) | same file, "Disconnect names the provider and confirms before it acts" | `tests.txt` |
  | STATE-8, STATE-12 (explain, never vanish) | same file, "MCP rows: urgent first, the act named, Remove explained" and "a server without a catalog explains instead of loading"; golden `library_integrations_mcp_menu_*`, `library_integrations_unavailable_*` | `tests.txt` |
  | Owner rule: one list by urgency | same file, "MCP rows: urgent first, the act named, Remove explained" | `tests.txt` |

- Changed test expectations (TEST-19): none (no existing test edited).
- Goldens added (each opened and looked at), `test/revamp/goldens/`: `library_integrations_loaded` (phone and 1280x800), `library_integrations_mcp`, `library_integrations_unavailable`, `library_integrations_connect_method_sheet`, `library_integrations_connect_key_dialog`, `library_integrations_oauth_inputs_sheet`, `library_integrations_disconnect_sheet`, `library_integrations_sign_in_sheet`, `library_integrations_mcp_menu`, `library_catalog_no_provider`, each dark and light. Approved render: `docs/design/visual-language-2026-09-26/Settings.png` (grouped rows in surface1 panels, sentence-case labels) and `Confirm.png` (sheets): differences: provider rows lead with the provider monogram rather than an icon tile; the Models page shows ModelCatalogView's own "basic catalog" banner and empty state under the new notice (pickers.dart, not this unit).
- Before and after (EVID-10): `before-integrations-loaded.png` / `after-integrations-loaded.png`, `before-catalog-default.png` / `after-catalog-no-provider.png`, `before-integrations-connect-key-dialog.png` / `after-integrations-connect-key-dialog.png`, `before-integrations-remove-mcp-sheet.png` / `after-integrations-remove-mcp-gate.png`, `before-integrations-authorization-launch-dialog.png` / `after-integrations-authorization-launch-dialog.png` (before images from `docs/qa/screen-census/j2-library/`).
- Accessibility: every row action is also a semantic custom action through KitRow's menu; menu items that cannot run say why as visible text (not a tooltip); row acts are 48 dp kit buttons; the code and key fields have visible labels and a labelled reveal toggle (KitField.secret); the helper wraps and is never cut (the map's critical a11y finding); no text-scale golden was made.
- Privacy and security: the API key goes straight to `connectIntegrationKey` inside the dialog; a failure shows fixed words, never the server's reply; the key field is never prefilled or kept in a draft; the sign-in code field is a secret field; sign-in errors never quote the server reply; authorization links still pass `parseAuthorizationUrl` and `openExternalLink`; the device-code instructions are displayed for the launch only and never stored or logged.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/revamp/screen_library_1_test.dart test/revamp/screen_library_1_golden_test.dart test/kit_ratchet_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator; no live OpenCode server.
- Shared tests were not run; expected to need the integrator (keys and words changed): `test/library_integrations_test.dart`, `test/integration_auth_recovery_test.dart`, `test/e7_library_layout_test.dart`, `test/product_ui_regression_test.dart` (CatalogScreen title), census capture guards for these pages.
- The Manage accounts and server sign-in sheets now open through `showKitSheet`; their bodies (screen-library-3's files) still draw their own header until that unit aligns them, so a double header is possible there.
- Opening a sign-in page asks twice: this page's "Sign in at {host}?" and then `openExternalLink`'s own host confirmation (`lib/ui/widgets/external_link.dart`, not this unit).
- `design_standard_test.dart` `_migrated`, the ratchet baselines, the l10n coverage baseline and the ui-ledger were not edited (integrator-owned).
- No text-scale 200 % or keyboard run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-library-1` |
| Enabled | Yes (no flag) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `101cc2df` |
| Deployed | No | |
| Released | No | |
