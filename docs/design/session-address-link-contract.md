# P3.9 — Address-bearing session links: privacy and transport contract

Status: **backend implemented, production capability off**. The 2026-09-28 implementation, callable APIs, acceptance evidence and remaining host/UI activation gates are recorded in [the backend handoff](../qa/codex-sessionlink-2026-09-28/README.md). The original research follows. Reviewed 2026-09-28 at `98c4c67a`. Finish line: a portable, credential-free session locator with explicit sender disclosure and receiver consent, private Tailscale access, and a safe Add server continuation. Non-goals: public sharing, account invitation, pairing credentials, session creation/resume, or a new relay. This is a docs-only follow-up to the [P3.9 blocker](../qa/slice-P3.9-2026-09-27/README.md).

## Original review evidence

| Boundary | Current behavior |
| --- | --- |
| [SessionLink](../../lib/domain/session_handoff.dart#L136) | `opencode-mobile://session?profile=…&session=…` carries the sender's local profile ID, not an address. Profile IDs do not identify a server across phones. Parsing bounds the string to 1,024 characters and validates both identifiers. It rejects non-root paths, but does not reject every unknown query key. |
| [Receiver](../../lib/main.dart#L979) | Resolves that profile ID locally; a missing profile consumes the link and opens the [unprefilled Add server sheet](../../lib/main.dart#L1147). A known profile can be connected automatically. |
| [Native ingress](../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/MainActivity.kt#L650) / [Dart bridge](../../lib/platform/session_link.dart#L20) | Native accepts the custom scheme/host, clears the intent, and caps length at 1,024; Dart parses and holds a pending route in memory. Native capture itself never connects. |
| [Current sharing sheet](../../lib/ui/widgets/session_handoff_sheets.dart#L205) | QR and copy contain the current route-only link. They do not establish permission to disclose a new address field. |
| [Tailscale bridge](../../lib/platform/tailscale.dart#L5) | Checks installed-package availability, not an active tunnel, account, route, peer identity or ACL. |
| [Existing host classifier](../../lib/orchestration/adapters/gascity/gascity_probe.dart#L26) | Recognizes loopback, a CGNAT IPv4 range and `.ts.net` suffixes. This is a syntactic transport hint, not verified private connectivity. Do not reuse it as this feature's security proof. |

## Privacy review and decision

An address is not an authentication credential, but disclosing it reveals a machine/tailnet name, service port and an association with a session. Session and installation IDs are correlatable metadata. A QR screenshot, clipboard manager, messaging app or another custom-scheme handler can retain the complete link. Android documents that another app can register the same custom scheme; this link must therefore confer no authority. Prefer scanning inside the app for a predictable receiver; do not claim custom-scheme interception is prevented. [Android deep-link contract](https://developer.android.com/training/app-links/create-deeplinks)

The sender must choose **Include this server's address** before generating or copying the portable link, with the normalized host/port visible and a short disclosure that the recipient still needs their own access. Existing local-only links remain available. Opening the handoff sheet alone is not consent to expose a hostname. Reject credential-bearing input instead of silently stripping a password and sharing a different target. Redaction is a final sink guard, not the URL builder's validation algorithm.

Never include passwords, Basic/Bearer authorization, cookies, API/provider keys, Tailscale auth keys, OAuth codes, pairing codes, one-use login tokens or signed access URLs. Also exclude titles, prompts, messages, project paths, usernames, email, provider configuration and remote repository URLs. No public shortening service, redirector, link preview service or hosted QR generator. This feature does not grant tailnet membership, authorize a session or create a public session share.

The Tailscale HTTPS option has its own metadata cost: certificate transparency publishes the device's certificate name, including its tailnet DNS name. That is separate from link disclosure and needs to be explained during server setup; this link feature must not silently enable certificate provisioning. [Tailscale HTTPS documentation](https://tailscale.com/docs/how-to/set-up-https-certificates)

## Wire format (implemented codec)

```text
opencode-mobile://session/v2?server=https%3A%2F%2Fworkstation.example-tailnet.ts.net&instance=9e30af6d-422d-4d89-baad-006ac07cb9d1&session=ses_example
```

The hostname and IDs above are illustrative, not a deployed endpoint. `server` is the canonical agent API **origin**, not the Gas City attachment's origin. `instance` is a stable, non-secret, host-generated UUID for that agent installation. `session` remains an opaque safe identifier, never an access token. No sender profile ID is used for cross-device matching.

| Field/rule | Contract |
| --- | --- |
| Envelope | Scheme `opencode-mobile`, host `session`, exact path `/v2`; no authority user-info, port or fragment. Case-normalize scheme/host only. Whole encoded string at most 1,024 ASCII bytes, matching both existing ingress ceilings without widening the channel. |
| Query | Exactly `server`, `instance`, `session`, each once. Reject unknown keys, duplicate keys (including percent-encoded duplicates), invalid escapes, empty values, control/bidi characters, and unexpected decoded delimiters. Decode one query layer only. Never recursively decode a URL. |
| Origin | HTTPS only for this first version, full ASCII `device.tailnet.ts.net`-shaped DNS name, optional explicit port 1–65535. No user-info, query, fragment, custom base path, wildcard, short name, trailing dot, IP literal or alternate numeric-IP spelling. Normalize DNS case and omit default port 443. Validate labels structurally, not by a substring match. |
| IDs | UUID for `instance`; existing bounded `SessionResumeCommand.isSafeIdentifier` rule for `session` (1–128 ASCII characters). Reject secrets recognized by `KitRedact` in any serialized field; never transform an identifier through redaction and then route it. |
| Compatibility | `/v2` is deliberately a path the current parser rejects. Merely adding `server` to a v1 query is unsafe because old clients ignore unknown query keys and might resolve an unrelated local profile. Keep a separate v1 parser; unknown versions are unavailable, with no downgrade fallback. |

This first format intentionally does not export raw HTTP/CGNAT addresses, loopback-only servers, public custom domains or path-prefixed reverse proxies. Those setups retain manual Add server/local links. Tailscale's shared CGNAT range can overlap ISP/other-VPN routes, so an address beginning `100.` is insufficient to safely bootstrap a credential-bearing HTTP connection. [Tailscale CGNAT conflict documentation](https://tailscale.com/docs/reference/troubleshooting/network-configuration/cgnat-conflicts)

A future raw-IP variant would need a supported, verified peer/route and server-identity binding before authentication. No such proof API is present in `TailscaleBridge`; do not invent one around “installed”, a user checkbox or a successful TCP connection.

## Host prerequisites: private HTTPS and identity binding

Preferred deployment is Tailscale Serve to an agent service bound only to localhost, with an allowlisted Tailscale requester checked on **every** descriptor and API request, plus the agent's ordinary session authorization. No Funnel, public reverse proxy or exposed alternate API port. Serve supplies peer identity and strips spoofed identity headers; Funnel does not supply that identity. Missing identity must fail closed. Tagged devices need a separately verified capability/identity policy; do not silently allow them because a login header is missing. This is a proposed agent-host integration, not a change to the current HTTP/whois-based Gas City front. [Tailscale Serve security and identity contract](https://tailscale.com/docs/features/tailscale-serve)

Proposed credential-free discovery, reachable only by an authorized tailnet peer:

```http
GET /.well-known/opencode-mobile-session-handoff
```

```json
{
  "schemaVersion": 1,
  "instanceId": "9e30af6d-422d-4d89-baad-006ac07cb9d1",
  "canonicalOrigin": "https://workstation.example-tailnet.ts.net",
  "linkVersions": [2],
  "capabilities": {"sessionLookupById": true}
}
```

It returns no session existence, title, user identity or credentials. Session authorization happens later through the established domain gateway. The host must support authorized lookup of a session by ID across its own project scoping, so the app need not put filesystem directories in a link. If a protocol cannot resolve the ID without an additional private scope, do not advertise this capability yet.

The capability is enabled only for deployments whose private ingress, requester validation and session lookup have been verified. A response field saying “Tailscale” is not itself route attestation. The authenticated TLS origin identifies the server; the instance ID detects accidental replacement/misrouting, not sender trust. Refuse changed origins or mismatching instances instead of trying another server. This proposal does not claim the current phone bridge can attest a VPN tunnel.

Client transport must validate TLS normally, refuse all redirects, restrict resolved destinations to the verified tailnet route/peer where available, and at minimum reject public, loopback, link-local and ordinary LAN resolution for this flow on every connection. A DNS range check supplements the private host deployment; it cannot prove Tailscale identity. Do not fall back to HTTP, bypass certificate validation, call a public URL on failure or forward credentials to a discovered alternative origin. If the transport cannot enforce the required destination policy, keep portable linking unavailable.

## Receiver and UI contract

1. **Parse locally.** No DNS, HTTP, profile creation, credential lookup, automatic connection, browser launch or session mutation on intent receipt. Keep the parsed pending intent in memory and clear it on dismissal. Coalesce duplicate intent delivery; cap one pending route. Parsing failure shows safe localized words without echoing the input.
2. **Ask before contacting the host.** Show the actual normalized host and “Add this server?” or “Open on this saved server?”. State that the link grants no access. Approval authorizes a bounded discovery request only; Cancel is network-silent. Do not auto-match by display name, profile ID, protocol flavor or session ID.
3. **Check private reachability and descriptor.** Installed Tailscale is only a recovery hint. Missing access, denied ACL, invalid certificate and unknown connectivity remain distinct safe states. Allow Open Tailscale and Check again; never invite disabling security or using a public relay. No endless background retries or persistent foreground service.
4. **Bind a saved profile.** Match canonical origin and previously verified instance ID. An old profile without an instance binding requires explicit re-verification; an ID collision or host change never reuses its stored password automatically. Multiple matches require selection. An unknown origin starts Add server with only the validated address preset and no credentials; the recipient enters/pairs their own credentials separately. Register new secrets at trusted ingress before error/report capture.
5. **Finish Add server, then read the session.** Retain the pending locator across the in-app setup flow; after connection succeeds, confirm the bound instance and use a domain operation to read/open the authorized session. A missing or denied session does not create/resume it, dispatch a prompt or search other servers. Cancellation consumes the locator. Process death may require rescanning; do not persist unknown-origin links just to avoid that friction.
6. **Show truthful outcomes.** While waiting, show the actual stage: awaiting permission, checking server, sign-in required, opening session. A timeout says the server did not answer; it does not claim Tailscale is off. Failures use authored words plus redacted Details, excluding the complete link, host identifiers and session ID from diagnostics by default.

The v2 route is an internal parsed navigation action, not an external `launchUrl`. Any supplied help/web destination still goes through [openExternalLink](../../lib/ui/widgets/external_link.dart#L40); do not widen its custom-scheme policy to implement v2. UI consumes domain `SessionAddressLink` values and `SessionAddressController` states; it must not parse links, construct HTTP requests or gate on a flavor enum. The implemented support flag `ServerCapabilities.sessionAddressHandoff` defaults off on every adapter. Production coordinator admission also stays off until the host requirements and complete UI flow above are verified. See the backend handoff for callable APIs.

## Data lifecycle and refusal rules

If instance binding needs persistence, use `oc.sessionLinkBinding.<profileId>` and the existing profile deletion transaction; stop admission and drain before removing it. Store only canonical-origin/instance binding, schema version and verification time, never the original link or credential. Clear in-memory pending links referring to a removed profile. No shared durable pending-link blob is proposed. Cross-device link recipients cannot be erased by deleting a profile; authorization revocation must happen at the host, and the UI must not promise link recall.

Keep v2 generation and reception unavailable until the parser/native bounds, consent flow, private host descriptor/authorization and scoped session lookup are implemented and verified together. No placeholder address, origin inferred from a session URL, export of a saved password, or “public sharing” fallback. A server that exposes bearer-accessible sessions by ID fails this contract even when the link contains no explicit password.

## Acceptance and validation

Acceptance requirements (client coverage and remaining live-host/UI evidence are tracked in the backend handoff):

- Valid link round-trip is canonical and contains exactly three fields; old parser rejects `/v2`; malformed/duplicate/unknown/encoded keys and oversized input fail before any network request.
- Password-bearing origins, token queries, fragments, credentials embedded in an ID, loopback, short DNS, IPv4/IPv6 literals, public hosts, certificate failures and redirects are refused without copying/logging input.
- Receiving/dismissing a v2 link makes zero network calls and reads no credentials. A known origin still requires contact consent; unbound or conflicting instances cannot reuse secrets.
- Sender QR/copy is unavailable until address disclosure is selected. Host/session/installation metadata stays out of automatic diagnostics, notification previews and analytics. Synthetic arbitrary known secrets never appear in QR, clipboard or report output.
- Authorized second phone on the tailnet can add the server and open its existing session. Tailscale off, another unauthorized tailnet peer, public/Funnel access, spoofed identity headers and ACL denial cannot reach authenticated session data. Tagged-peer behavior is explicit. Test DNS changes between validation and request.
- Missing/denied session leaves the server saved but creates no session/task. Newer intent wins over late completion; cancellation and profile deletion invalidate pending routes. Cold and warm Android deliveries are each consumed once.

The original research revision added no runtime API, backend change, storage or localization. Its research was source/schema inspection plus official Tailscale/Android documentation accessed 2026-09-28; no live host, VPN, device, account or credential was used. Docs-only checks are relative-link/line-anchor validation and `git diff --check`; Flutter tests/analyzer/builds are not applicable to these prose changes.

Original docs-only validation: all 73 relative links/line anchors across the four
contracts resolve, both JSON examples parse, and the staged whitespace check
passes. No application source changed; no runtime test pass is claimed.
