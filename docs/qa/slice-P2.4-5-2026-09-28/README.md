# slice-P2.4-5: MCP Add chooser and MCP catalogue as toggles (2026-09-28)

On 2026-09-28 the owner decided to build P2.4 and P2.5 now. The rest of P2, the setup-assistant agent, stays "later".

**Finish line:** MCP › Add opens a sheet with two choices: Browse the catalogue, or Enter manually. The catalogue lists servers from one registry as switches. Turning one on runs the same form, Save and gateway call as manual entry. Turning one off removes it. **Non-goals:** the setup assistant, OAuth onboarding beyond what the manual path has, and installing packages.

## 1. Feasibility (AGENTS.md rule 2): feasible

The registry has a contract the app can call, and listing needs no credentials.

| Check | Result |
|---|---|
| Registry | The official MCP registry. `lib/domain/setup_registry.dart` `SetupRegistryClient.endpoint` = `https://registry.modelcontextprotocol.io/v0.1/servers` |
| Live call (2026-09-28, curl, no credentials, no cookies) | `GET /v0.1/servers?limit=100&version=latest` returned `200 application/json`, 82 KB. Shape: `{servers: [{server: {name, title?, description, version, remotes?, packages?, websiteUrl?, repository?}, _meta: {io.modelcontextprotocol.registry/official: {status, isLatest…}}}], metadata: {nextCursor, count}}` |
| Search | `&search=<text>` returned 200 and filtered by name (for example, `filesystem` gave 5 matches). The app sends a search only after the person agrees, and never sends a term that looks like a credential. |
| What the first 100 listings are | 68 hosted (`streamable-http`), 4 hosted with `sse` as well, 23 npm (`stdio`), 1 OCI, 1 with nothing usable. 10 hosted listings declare required headers, such as `Authorization` marked `isSecret`. |
| What the app relies on, pinned in tests | The request shape: fixed origin, no `Authorization`, no redirects, 512 KB cap, 100 entries (`test/setup_registry_test.dart`, existing). The `search` parameter, and header and variable names kept without their values (new tests in the same file). |

Nothing needed a credential or an internal endpoint, so no workaround was built.

## 2. What changed

| Where | Change |
|---|---|
| MCP page (`library/integrations_screen.dart`) | **Add** (top bar and empty state) opens the add sheet instead of the form. After the catalogue closes, the page reads its list again. |
| Add sheet (`mcp_catalog_screen.dart` `showMcpAddSheet`, map `mcp-add-sheet`) | Two choices, from the kit (`showKitChoiceSheet`): **Browse the catalogue** and **Enter manually** (the existing form). If the server cannot add MCP servers (`ServerCapabilities` has neither `mcpConfigWrites` nor `mcpRuntimeAdds`), Browse is disabled and says: "No catalogue for this server: it doesn't accept new MCP servers from the app." **The setup assistant row is left out.** The assistant is not built, and a row that says "not yet" and does nothing would be a dead end. The review-only AI setup page stays where it is, in Server settings. It cannot install anything, so linking it here would promise something it can't do. |
| MCP catalogue (new, `mcp_catalog_screen.dart`, map `mcp-catalog`) | **Consent first:** no request until the person taps "Load the list". The consent is saved per server (`oc.setupRegistry.<profileId>`, already covered by the profile deletion sweep), and the menu has "Stop using the registry" to take it back. **One list:** a search field, then switch rows in this order: on for this server, can add, can't add. Each row shows the title, the description as plain text, and one facts line: "Hosted by {host}", "Needs Node on the server" (or "on this phone"), "Needs Python with uv on the server", "Needs an API key", "Needs extra settings". Under the list is one note on cost: "The registry lists no prices. A hosted server's owner may charge for it or ask for an account." (The registry has no price field, so no price is made up.) **On** opens the manual form filled in from the listing. **Off** asks the MCP page's question and makes the same `ConnectionController.removeMcpServer` call. If the server has no `mcpRuntimeRemovals` (an OpenCode 1 configuration write), the switch stays on and says why. **States:** unsupported, consent, loading, list, list with a failed refresh (notice + Try again), no match, registry unreachable (Try again + Enter manually), this server's MCP list unreadable (Try again, and no switch guesses its state), a row adding or removing. |
| Phone host | If the server runs on this phone (in the app or in Termux; `lib/state/mcp_catalog_host.dart`), turning on a Node server first asks: **Add Node to this phone** (opens This phone, then Add tools › Node, using the existing phone tools flow) or **Node is already on this phone** (goes on to the form). The server doesn't just fail. |
| Manual form (`mcp_setup_screen.dart`) | New `prefill`, which carries names only. Values for headers and environment variables are never prefilled. A line at the top says where the values came from and that the server will run the command or connect to the address. A header or variable the listing requires keeps its name fixed and must have a value. **Environment variables** are now name + secret-value rows, like headers (P0.1). They sit next to the command instead of in a plain multi-line field under Advanced. **Timeout** is entered in seconds (the critic's minor finding) and sent as milliseconds. The discard question compares with how the form opened, so a filled-in form you haven't touched leaves without asking. |
| Domain (`lib/domain/mcp_catalog.dart`, new) | `McpCatalogItem.from(RegistryEntry)`: server name (`io.github.acme/files-mcp` → `files-mcp`; a generic `…/mcp` takes its namespace), runtime, host, needs, and the draft. Hosted: the HTTPS address plus the names of required headers. npm: `npx -y <id>@<version>`. PyPI: `uvx <id>==<version>`. OCI and anything else: not addable. `orderCatalog` gives the list order. |
| Registry client and store | `RegistryEntry.title`. `RegistryVariable` keeps a header or environment variable's name and its required/secret flags, never its value, default or description. `RegistryPackage` keeps transport, runtime hint, variables and "requires arguments", but never argument values. `fetch(search:)`. The store's `refresh(query:)` shows search results without saving them, and `showSaved()` goes back to the saved list. |
| Copy | 47 new `app_en.arb` strings (`mcpAdd*`, `mcpCatalog*`, `mcpSetup*`, `mcpVariable*`). Removed `e7LibraryTimeoutInMilliseconds` and `e7LibraryOptionalEnterOneKEYVALUEPairPer`, which are now unused, from both ARBs. `mcpSetupAdvancedLocal` is now "Working folder and timeout". `test/ui_glossary_test.dart`: added "Node" and "Python" to the proper nouns a title may capitalise. |

Architecture: the new UI imports only `lib/domain` and `lib/state`, never `api/` or `api2/` (G24 passes). Every part comes from the kit (G16 passes). Features are gated on `ServerCapabilities` (`serverCatalog`, `mcpConfigWrites`, `mcpRuntimeAdds`, `mcpRuntimeRemovals`), never on the server's flavour.

## 3. Security and privacy

- **Registry text is untrusted.** Titles and descriptions go through `KitRedact` and control-character stripping, and are shown as `KitText` only, never as markdown. A `[text](url)` in a description is shown as those characters, and no link in it opens. (The test checks that no `KitMarkdown` is built and that the literal text appears.)
- **Nothing from the registry runs without the form.** The command is built only from validated identifiers (`[A-Za-z0-9@._/+-]`). It is shown in the form's command field, and the person adds it with the same Save as manual entry. Registry argument values, defaults and header values are never kept (tested: `--evil; rm -rf /`, `fake-header-default` and `fake-env-default` appear nowhere).
- **Secrets:** values for headers and environment variables are typed into `KitField.secret` rows (obscured, never prefilled). No credential is sent to the registry: the client is unauthenticated, and a search term that looks like a secret is dropped. Tests use fake values only.
- **Storage:** the only stored data is the existing `oc.setupRegistry.<profileId>`, which is removed by `ProfileStore.profileScopedPreferenceKeys` and by "Stop using the registry". Search results are never saved.

## 4. Tests

New:
- `test/revamp/slice_p2_4_5_test.dart` (18). The catalogue model: each listing kind → draft, names, order, title redaction. The add sheet: two choices and no assistant row, and Browse explained when the server has no catalogue. The catalogue:
  - asks before the first request;
  - rows and facts, with registry text kept plain and redacted;
  - **turning on uses the manual form, and its Save produces a `toConfigJson()` and scope identical to typing the same server by hand**;
  - a required secret header blocks Save until it is filled;
  - a local listing shows its command and takes its key as a secret row;
  - **turning off calls `removeMcpServer`**, and a server without removal keeps the switch on and says why;
  - **on this phone, Node offers Add tools › Node**, or goes on to the form;
  - registry unreachable, no match, this server's MCP list unreadable (no raw text), server unsupported, and "Stop using the registry".
- `test/setup_registry_test.dart` (+3): `search` sent and not saved; a secret-looking term not sent; header and variable names kept without their values, with a round trip through the cache.
- `test/library_integrations_test.dart` (+1): Add › Browse opens the catalogue at its consent step.
- `test/revamp/slice_p2_4_5_golden_test.dart` (11 goldens).

Updated: `test/mcp_setup_screen_test.dart` (environment rows, timeout in seconds) and `test/library_integrations_test.dart` (Add → sheet → Enter manually).

Run once, all passing: the files above plus `screen_library_2_test`, `e7_library_layout_test`, `screen_library_1_test`, `integration_auth_recovery_test` and the gates `kit_ratchet` (G16), `redaction`, `ui_glossary` (G28), `no_raw_error_text`, `kit/kit_manifest`, `kit/kit_draft_manifest`, `architecture_boundaries` (G24), `l10n_coverage` and `credential_ingress_redaction`. `flutter analyze`: no issues.

Pre-existing failures, not caused by this slice: `screen_library_1_golden_test` and `screen_library_2_golden_test` fail the same 41 cases at the base commit `73b15550`, checked in a separate worktree. The failing sets are identical. The MCP form goldens (remote form, until restart, errors) pass unchanged.

## 5. Images

| Before (base `73b15550`) | After |
|---|---|
| MCP page: Add went straight to the form: `before-mcp_page_dark.png`, `before-add_opens_form_dark.png` | Add sheet: `after-add_sheet_dark.png`; no catalogue for this server: `after-add_sheet_none_dark.png` |
| No catalogue existed | Consent: `after-catalog_consent_dark.png`; list on a phone: `after-catalog_list_dark.png`, `after-catalog_list_light.png`; list in a wide window: `after-catalog_list_1280x800_dark.png`, `after-catalog_list_1280x800_light.png`; Node on this phone: `after-catalog_node_dark.png`; registry unreachable: `after-catalog_failed_dark.png` |
| Local form: environment as a plain `KEY=VALUE` field under Advanced: `before-form_local_dark.png` | Local form: environment variables as secret rows next to the command: `after-form_local_dark.png`; form filled in from a listing: `after-form_from_catalog_dark.png` |

## 6. Still needs a device

- An emulator run against OpenCode 2: turn a hosted catalogue server on and off, with a recording. Also OpenCode 1: turn one on (a configuration write, then a reconnect), with the switch staying on.
- On a phone host with and without Node, the Add Node route into This phone › Add tools.
- Live search latency on a phone network.

## 7. Shipping state

Implemented, committed on `revamp/slice-P2.4-5`, not merged, not on a device.
