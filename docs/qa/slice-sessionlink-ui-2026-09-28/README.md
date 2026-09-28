# slice-sessionlink-ui — session links that can carry the server address (2026-09-28)

Branch `revamp/slice-sessionlink-ui`, base `53c2bf2a`. Backend and contract:
[codex-sessionlink-2026-09-28](../codex-sessionlink-2026-09-28/README.md),
[session-address-link-contract.md](../../design/session-address-link-contract.md).
Owner decision 2026-09-28 (delegated): build it with a per-link opt-in.

Finish line: the handoff sheet offers "Include this server's address" (off each
time, showing host:port and the disclosure), and an incoming v2 link shows
plain states. Everything stays behind the backend's gates. Non-goal: switching
the gates on. That needs the host verification the backend README lists.

## Shipping state

| State | |
| --- | --- |
| Implemented | Sender switch and portable QR/copy. Receiver sheet for every controller phase and failure code. App-shell routing of `pendingAddress` / `pendingAddressFailure`. Add server prefill. |
| Enabled | **No.** `ServerCapabilities.sessionAddressHandoff` is false on every adapter, and the production `SessionAddressController` (`sessionAddressProvider`) refuses sending and receiving. In production the switch is hidden. An incoming v2 link opens the sheet saying "Conversation links with a server address are not available yet." |
| Verified | Widget tests against the verified test harness (fakes, no network). Not verified on a device or a live tailnet host. |
| Committed | Local commit on this branch. Not pushed. |

## What changed

**Open on another phone** (`lib/ui/widgets/session_handoff_sheets.dart`)
- New `SessionAddressOffer`. `forSession(...)` returns null, which hides the switch, unless the connected server reports `sessionAddressHandoff` and the coordinator is admitted. `SessionAddressOffer.of(context, connection:, sessionID:)` is the hook for the conversation menu.
- The switch "Include this server's address" is off every time the sheet opens. It shows the normalized `host:port`, with 443 spelled out, and the disclosure under it: no password, the recipient still needs their own access, screenshots, messages and the clipboard can keep the link.
- Switch on: the QR and the link text are the v2 link from `buildForProfile(..., includeServerAddress: <switch>)`. Copy builds the link again rather than reusing the shown string.
- A refused build shows the plain reason and a Details fold that holds the category only. No QR is shown, and the sheet never quietly falls back to the local link. A saved address that is not a private HTTPS `.ts.net` name, or that holds a password, disables the switch with a reason. The host is never shown with the password stripped out.
- Switch off, or no offer: the local-only link renders exactly as before. The existing `chat_continue_on_phone_sheet_qr_*` goldens give the same pixel result as on base `53c2bf2a`.

**Incoming link sheet** (new `lib/ui/widgets/session_address_sheets.dart`)
- `showSessionAddressSheet` follows the controller's stages:
  - asking: "Add this server?" or "Open on this saved server?", with host:port and "The link grants no access". Check server calls `approveContact`.
  - checking.
  - unknown server: Add server opens the existing editor with only the address filled in. Nothing connects on its own. The server added for the link is then selected.
  - several matches: a chooser.
  - verify a saved server: `approveBinding`.
  - needs sign-in: Sign in opens Servers.
  - ready: Open conversation calls `open`.
  - opening.
  - failed: every failure code has plain words from the contract table. Details holds only the category name. Try again appears only for connection-type failures, as one explicit retry.
- Closing the sheet calls `cancel()`, so the locator is consumed and no network call is made.
- `sessionAddressFailureText` maps each failure code to its copy. `sessionAddressHostPort` gives the address both sheets show.

**App shell** (`lib/main.dart`, small hook)
- Listens to `SessionLinkIntent.pendingAddress` and `pendingAddressFailure`. It takes each one once, calls `receive`, shows the sheet and never opens a second one.
- A found conversation navigates through the existing `_openSessionForLink`. Nothing is created, resumed or sent.

**Other files**
- `lib/state/session_address_controller.dart`: `sessionAddressProvider`, the closed production wiring. It uses default-closed `SessionAddressDeployment()` and `lookupForProfile` returns null.
- `lib/ui/screens/servers_screen.dart`: `ServersRouteRequest.add(initialUrl:)` passes the validated origin to the existing editor.
- `lib/l10n/app_en.arb`: 43 `sessionAddress*` strings, English only. `Try again` reuses `kitTryAgain`.

## Security checks (tests)

- The address goes in only after the opt-in. With the switch off there are no build calls, and the QR and clipboard carry the local link only. `build(includeServerAddress: false)` throws `consentRequired`.
- A credential-bearing link is rejected, not stripped:
  - sender: a session ID registered as a secret after the offer was created gives "contains private sign-in information", no QR and nothing on the clipboard. A `user:pass@` address disables the switch and never shows the host.
  - receiver: a `user:pass@` link fails with `credentials`, `pending` is null, and the page shows neither `hunter2` nor the host.
- Production hides the switch. An incoming link says the link type is not available yet, with no Check button and zero descriptor calls.
- Details never show the host or the session ID.

## Tests

New (all pass):
- `test/session_address_ui_test.dart`: 13 tests (sender gates, off-by-default and opt-in, rebuild on copy, secret refused, unsupported address; receiver production, credentials, parse failure, unknown server end to end, saved server with sign-in, not found, timeout with Try again, close cancels).
- `test/session_link_routing_test.dart`: 3 new app-shell tests (unavailable sheet, parse-failure category, verified link opens the existing chat with 0 created and 0 prompted).
- `test/revamp/sessionlink_ui_golden_test.dart`: 28 goldens.

Existing files run once:
- Pass: `kit_ratchet`, `l10n_coverage`, `no_raw_error_text`, `redaction`, `ui_glossary`, `architecture_boundaries`, `session_handoff_sheet_layout`, `session_address_controller`, `session_link`, `session_address_link_intent`, `server_backend_preselection`.
- `flutter analyze`: no issues.

Pre-existing failures, identical on base `53c2bf2a` in a separate worktree:
- `session_link_routing_test` "a saved server whose connection fails routes to Servers". This is the failure already recorded in the Codex README.
- 17 pixel diffs in `test/revamp/shared_chat_1_golden_test.dart`, with the same percentages and pixel counts on base: model sheet, continue on computer, the phone QR (0.07%, 270 px on both), and display toggles. They need a reviewed golden refresh; not touched here.

## Images

- `contact_send.png`: before (local link only) next to after (switch off by default, switch on, and on with a server not yet verified).
- `contact_receive_1.png`: not available yet (production), credential link rejected, asking before contact, unknown server.
- `contact_receive_2.png`: verify, ready, needs sign-in, not found with Details.
- Single images: `before_*`, `after_*`, including the wide window (`*_1280x800_dark`).
- Every state has phone dark and light goldens in `test/revamp/goldens/sessionlink_*`.

## Still gated, and why

- **Production is off by design.** Enabling needs the host evidence the backend README lists:
  - a private Serve ingress with requester identity on every request;
  - tagged-peer policy and no Funnel or other public ingress;
  - a scoped `SessionAddressLookupGateway` for real;
  - live proof with an authorized second phone and an unauthorized peer.
- Until then `sessionAddressHandoff` stays false, and the production controller refuses everything.
- **Conversation menu hook not wired.** The chat library is owned by the chat lane. The one-line hook is in the lane notes: pass `address: SessionAddressOffer.of(context, connection: _conn, sessionID: widget.sessionID)` to `showContinueOnPhoneSheet`. Without it the switch cannot appear even once the gates open. With the gates closed nothing changes for users either way.
- **Needs a device:** Android cold and warm delivery of a real `opencode-mobile://session/v2` intent into this sheet, the QR scanned by a second phone, and the Add server prefill on a real editor.
- **Not handled:** a parse failure that arrives while the sheet is already open is dropped, and the open sheet keeps its state. The sender's `bindingRequired` reuses the contract's receiver-side wording ("Verify this saved server before opening the conversation"), because no sender-side way to verify exists yet.
