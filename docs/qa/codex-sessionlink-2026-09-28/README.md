# Session-address links backend — 2026-09-28

Base: `d4bdfb3c`, after `git merge feat/phone-setup-v2` fast-forwarded this
worktree. Contract: [session-address-link-contract.md](../../design/session-address-link-contract.md).

Finish line: implement and test the non-UI v2 codec, bounded native delivery,
private descriptor transport, consent/binding/lookup coordinator and deletion
lifecycle. Non-goals: screens, public sharing, host deployment, pairing secrets,
new host endpoints for session lookup, session creation/resume, or activation.

**Implemented backend; production unavailable.** Every current adapter keeps
`ServerCapabilities.sessionAddressHandoff == false`. The production
`SessionAddressController` constructor additionally refuses sender generation
and receive/contact actions. `verifiedTestHarness` exists only for tests. No
widget, route, QR/copy action or automatic connection was enabled.

## Callable contract

| API | Behavior |
| --- | --- |
| `SessionAddressLink.require(raw)` / `parse(raw)` | Typed failure / null; pure local parsing, exact `/v2`, 1,024 printable ASCII bytes, exactly three literal keys once, strict escapes and one decode. Encoded key aliases are refused, not interpreted. |
| `SessionAddressLink.build(origin, instanceId, sessionId, includeServerAddress)` | Low-level codec requires disclosure true; canonical HTTPS origin only, UUID instance and bounded safe session ID. Rejects secrets before and after normalization; never strips them. |
| `SessionAddressLink.encode()` | Rechecks registered secrets, returns canonical wire text. This is sensitive metadata: use only for the explicitly approved QR/copy sink. `toString()` omits fields. |
| `SessionLinkIntent.pendingAddress` / `takeAddress()` | Separate in-memory v2 route, never passed to the legacy profile-ID router. New valid route replaces other kinds; duplicate delivery coalesces; cold consume cannot replace newer warm delivery. |
| `PrivateSessionDescriptorReader.discover(origin)` | Anonymous GET of `/.well-known/opencode-mobile-session-handoff`; ten-second whole-request deadline, 8 KiB body limit, no auth/cookies, proxy, redirect, HTTP fallback or invalid-certificate callback. |
| `SessionAddressDescriptor.parse(json)` | Exact schema, canonical origin, UUID, v2 support and lookup capability; no arbitrary identity/credential fields. The response is not proof of private deployment or authorization. |
| `SessionLinkBindings.forProfile(prefs, id)` | Shared serialized owner of `oc.sessionLinkBinding.<id>`. `read`, `save`, `isAvailable`, `revision` and listeners. Do not dispose the shared owner. |
| `SessionAddressController.receive(raw)` | No network, saved credential reads, automatic connection or durable locator. Keeps one pending locator; typed state only. |
| `approveContact()` | Explicit permission for one anonymous descriptor read. Known origin still requires approval. No authenticated gateway is created here. |
| `selectProfile(id)` | After descriptor verification, explicitly select among matches or the newly saved Add server result. Origin must match exactly. No display-name/flavor/session-ID matching. |
| `approveBinding()` | Explicitly verify an unbound profile after discovery, persist origin/instance/time and confirm durable write. Existing conflicting binding cannot be overwritten. |
| `open()` | Rechecks descriptor and current profile/binding before asking `lookupForProfile` for a scoped domain gateway, then performs one authorized read. No generic `session(id)` fallback. |
| `checkAgain()` | Explicit retry from failed state grants one new bounded descriptor request; no timer/background retries. |
| `cancel()` / `dispose()` | Consume locator, detach observers and invalidate late results. No persistence across process death. |
| `buildForProfile(id, sessionId, includeServerAddress: …)` | App-facing sender entry point: feature admission, explicit disclosure, verified deployment and exact saved origin/instance binding all required. |

`SessionAddressLookupGateway.lookupAuthorizedSession(id)` is intentionally a
separate domain integration boundary. It must resolve the session across the
installation's private scopes and apply ordinary requester/session authorization.
It returns the existing domain `Session`, including its private location when
needed by navigation. Missing/denied/sign-in failures are typed; neither the
locator nor an arbitrary returned session grants access. A mismatching result ID
is rejected. The coordinator has no create, resume, prompt or task operation.

`lookupForProfile` is the first boundary that may use the recipient's existing
credential paths. It is called only after consent, saved-origin checks and
verified binding, and again guarded before the actual lookup. No password,
provider key or pairing token is passed into these new APIs. A current generic
OC1/OC2 session getter is not an implementation of this private scoped contract.
No production adapter was fabricated around it.

## Private transport and deployment proof

The descriptor client resolves at each actual connection, rejects any result
outside `100.64.0.0/10` or Tailscale's `fd7a:115c:a1e0::/48`, and connects to the
checked `InternetAddress` rather than resolving the hostname again. Mixed
public/private DNS is refused. TLS authenticates the original DNS name through
the standard HttpClient; no certificate bypass is installed. Each discovery
uses a fresh client, disables connection reuse, and closes/cancels it on success,
failure or timeout. Late DNS completion cannot start a socket after timeout.

A range check is **not** Tailscale route or peer attestation. The independently
supplied `SessionAddressDeployment` must affirm private ingress, requester
identity on every request, verified tagged-peer policy, no public/alternate
ingress, private destination policy on authenticated requests, and scoped
session authorization. `sessionIdsAreBearerCredentials` defaults true and must
be proved false. Every requirement defaults closed. Descriptor booleans do not
populate this evidence. Both discovery admission and the lookup gateway check
it; bearer-by-ID or unknown gateways never receive a lookup call.

Remaining activation evidence requires an actual host: authorized second phone,
unauthorized peer/ACL denial, public/Funnel and spoofed-header rejection, tagged
peer policy, TLS and DNS changes on authenticated requests, plus Claude's
consent/Add server/navigation flow. The repo has no verified deployment or
production cross-scope private lookup adapter. Fakes prove client enforcement,
not the live host's security. Keep both production gates off until these tests
pass together; do not use a boolean from an HTTP response as a substitute.

## Persistence and deletion

Only schema version, canonical origin, instance UUID and UTC verification time
are stored. No link, session ID, title, path, username, credential or pending
route is durable. No migration is needed for absent bindings; older profiles
remain unbound until explicit verification. A conflicting binding requires a
new verified profile; this backend deliberately offers no silent replacement.

`ConnectionController.deleteProfileAndLocalData` closes the owner synchronously
at deletion admission, invalidating pending routes before awaiting other work,
and drains admitted writes before the sweep. `ProfileStore.removeScopedPreferences`
also closes/drains it before discovering keys. Its existing `oc.<what>.<id>`
sweep removes the binding. Fresh facades cannot reopen deletion admission.
After an aborted transaction, durable membership is reloaded before a fresh
owner can be created; old facades stay closed. Refused/throwing writes and failed
read-back never expose optimistic cached bindings as verified identity.

The controller watches known matching profiles even before contact approval,
and then the selected owner. Removal consumes the pending route and invalidates
late lookup results. Deleting a profile cannot recall links already sent to
another phone; the host owns authorization revocation.

## UI hook-up for Claude

Do not enable the UI yet. UI consumes domain values/controller state, never a
protocol client or `flavor` switch. Do not call the low-level codec to bypass
`buildForProfile` admission. No Dart presentation strings were added by this
backend; add the following copy intents to `lib/l10n/app_en.arb`, then generate
localizations when implementing the screens.

Sender:

- Default the toggle **Include this server's address** off for each disclosure.
  Show the normalized host and effective port alongside it (including 443 when
  omitted from the canonical origin). The full wire link does not belong in
  diagnostics, analytics, notifications, previews or error Details.
- Explain: the link reveals this server's address and a conversation identifier;
  the recipient still needs their own access. Clipboard managers, messages and
  QR screenshots can retain it. This does not invite someone to the tailnet or
  make the conversation public. Do not silently provision HTTPS certificates.
- Until disclosure and capability admission succeed, portable QR/Copy remain
  unavailable with the reason. Existing local-profile links remain separate.
  Rebuild on every explicit Copy/QR action so newly registered secrets are
  rejected. Never cache a previously built wire string for later automatic use.

Receiver:

1. Observe `pendingAddress`; take it once into a coordinator. The existing app
   shell does not yet subscribe, and no v2 link reaches its v1 auto-connect path.
   Scanned text goes through the same `receive` path. Dismiss both pending UI
   state and coordinator state. Do not persist either across process death.
2. `awaitingConsent`: show actual normalized host/port and “Add this server?” or
   “Open on this saved server?”. State that the link grants no access. Cancel
   calls `cancel`; approval calls `approveContact` only.
3. `checkingServer`: bounded checking state. `addServer`: validated origin only
   may prefill existing Add server; recipient enters/pairs their own credentials
   through existing paths. Retain the locator in memory while this flow runs.
4. `chooseProfile`: explicit selection among `candidateProfileIds`.
   `bindingRequired`: explicit verify-this-installation approval before
   `approveBinding`. Host/instance conflict is a stop, never password reuse.
5. `readyToOpen`: recipient sign-in complete, explicit Open calls `open`.
   `openingSession`: show that specific read stage. `opened`: copy `profileId`
   and `openedSession` for existing-session navigation, then consume with
   `cancel`. Do not create/resume a session or dispatch a message.
6. `failed`: map the code below. Check again is an explicit bounded retry;
   installed Tailscale is only a recovery hint, never evidence the tunnel is up.
   Help links go through `openExternalLink`; internal v2 routes never go through
   `launchUrl`. `idle` means no pending operation.
   Observe `pendingAddressFailure` for malformed versioned intents and consume
   it with `takeAddressFailure`; only an enum is retained. Android rejects and
   consumes over-limit/non-ASCII input before Dart delivery, without retaining
   it for an error preview.

Failure codes → English copy intent (localize in ARB; no exception interpolation):

| Code | Plain words / action |
| --- | --- |
| `unavailable` | Conversation links with a server address are not available yet. |
| `invalidLink` | This conversation link is not valid. Scan or copy it again. |
| `tooLarge` | This link is too long. Ask the sender for a new link. |
| `credentials` | This link contains private sign-in information and cannot be used. |
| `consentRequired` | Choose whether to include this server's address first. |
| `privateRouteRequired` | This server cannot be reached through the required private connection. Check your connection. |
| `unreachable` | The server could not be reached. Check your connection and try again. |
| `timedOut` | The server did not answer in time. Try again. Do not claim Tailscale is off. |
| `tlsRejected` | The server's secure connection could not be verified. Do not offer a bypass. |
| `redirectsRejected` | This server tried to send the request somewhere else. The link was not opened. |
| `accessDenied` | Your access to this server or conversation was refused. |
| `invalidDescriptor` | This server did not provide the information needed to open this link. |
| `instanceMismatch` | This link and the saved server do not identify the same installation. |
| `bindingRequired` | Verify this saved server before opening the conversation. |
| `ambiguousProfile` | Choose which saved server to use. Current coordinator represents this with `chooseProfile`. |
| `profileMissing` | This saved server is no longer available. |
| `storage` | The server verification could not be saved or read. Try again after restarting the app. |
| `signInRequired` | Sign in to this server with your own account before continuing. |
| `unsafeLookup` | This server has not been verified for private conversation links. |
| `sessionMissing` | This conversation is not available on this server. |
| `cancelled` | Opening this link was cancelled. |

Details may contain the fixed failure category only. Do not interpolate original
exceptions, complete links, host/instance/session IDs, descriptor bodies or
credentials. The visible host in the explicit consent surface is intentional
privacy disclosure; it is not permission for automatic logging or previews.

## Acceptance evidence

| Contract acceptance item | Automated evidence / boundary |
| --- | --- |
| Canonical 3-field round trip, legacy `/v2` rejection, malformed/duplicate/unknown/encoded keys and size bound | `session_address_link_test.dart`; malformed cases use only case numbers in failure output. |
| Credentials, user-info, query/fragment, known opaque secrets, IDs, non-private/invalid origins | Codec test matrices, including secrets registered after model construction; no repair/redaction routing. |
| Certificate and redirect refusal, private destinations, changed/mixed DNS, bounded timeout/body | `session_address_transport_test.dart`, exercising the concrete client with fake sockets/HTTP; normal TLS policy is retained. |
| Silent receive/dismiss; known host still needs consent; unbound/conflicting instance cannot reuse credentials | `session_address_controller_test.dart` counters and staged binding/read tests. |
| Disclosure required for portable generation; metadata excluded from automatic sinks | Codec + controller sender tests; safe model/error `toString`; no new automatic sink calls. UI clipboard/QR rendering remains owner acceptance. |
| Private authorized lookup, bearer-ID refusal, denied/missing/sign-in failure leaves saved server | Controller fake scoped gateway tests; no create/task method exists on that gateway. |
| Newer intent/cancel/deletion defeats late completions | Coordinator tests, real ConnectionController removal, binding held-write tests. |
| Cold/warm Android delivery consumed once with native bound | `session_address_link_intent_test.dart`, `session_address_link_native_test.dart` executable pure Kotlin harness, existing ingress/routing tests. Actual phone launch remains activation evidence. |
| Binding restart/read-back, absent profiles, deletion admission/drain, abort reopening, corrupt/refused storage | `session_link_bindings_test.dart` and real-controller deletion test. |
| Authorized second phone, unauthorized peer/Funnel/spoofed identity, tagged devices and host scope authorization | NOT live-verified. Default-closed deployment fields plus production capability test enforce the blocker; host integration and UI acceptance remain mandatory. |

## Verification

Pinned Flutter/Dart `91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, formatting
`--language-version=3.10`. Heavy checks run through `tool/qa/machine_lock.sh`.
No exploratory full-suite run, live server mutation, credentials, push or release.
Verified implementation candidate: `df245d29` (documentation-only commit follows).
The [15-file manifest](focused-tests.txt) ran serially with:

```sh
OC_TEST_SLOTS=1 tool/qa/machine_lock.sh test -- bash /tmp/oc-sessionlink-final-checks.sh
# Inside the lock:
flutter test --no-pub --concurrency=1 <focused-tests.txt entries> --reporter expanded
flutter analyze --no-pub
```

- All **72 new acceptance tests passed**, including the executable native
  Kotlin ingress harness and real-controller deletion cases.
- All four gates passed: kit_ratchet, redaction, ui_glossary, no_raw_error_text.
- Broader 15-file run: **198 passed, 1 inherited legacy failure, zero skips**;
  `/tmp/oc-sessionlink-final-tests.log`. This is not a completely green manifest
  or a full-suite pass.
- The initial transport fake attempted to implement Dart's final
  `ConnectionTask`; it was corrected to use `ConnectionTask.fromSocket`.
  Its isolated rerun passed all 25 tests before the final manifest.
- Analysis found two style-only lints. After adding braces and using a nullable
  map element, the affected transport/binding files passed **38 tests**
  (`/tmp/oc-sessionlink-lint-recheck.log`). Other production behavior is unchanged.
- Final `flutter analyze --no-pub`: **No issues found**, exit 0, 50.4 seconds
  (`/tmp/oc-sessionlink-clean-analyze.log`).
- Pinned format check: 15 changed Dart files, zero changes. Whitespace and
  relative-document-link checks passed. No Android APK/device build or live
  tailnet test was performed; the native claim is the compiled JVM helper
  harness plus ingress/manifest contract tests.

### Separate legacy UI verification failure

`test/session_link_routing_test.dart:445`, **a saved server whose connection
fails routes to Servers**, finds no app-notice widget after the v1 connection
failure. Its preceding assertions do find Servers and no chat. The failure
repeats in isolation (`/tmp/oc-sessionlink-routing-recheck.log`).

Control run: temporarily restored the four changed pre-existing Dart files
(`server_gateway.dart`, `platform/session_link.dart`, `state/connection.dart`,
`state/profiles.dart`) to `d4bdfb3c`, ran the exact same test, then restored every
candidate file byte-for-byte. Newly added backend files are unreachable from
that legacy test on the base imports. The control fails at the same notice
assertion (`/tmp/oc-sessionlink-baseline-routing.log`), and the restore verification
passes (`/tmp/oc-sessionlink-baseline-result.log`). This establishes that the
failure predates this backend change. No screen code or legacy assertion was
changed to obtain a pass.

Claude/main-shell follow-up: inspect v1 `_openSessionForLink` →
`_showLaunchNotice`/the app status slot during failed saved-server connection.
The existing Servers fallback works; verify the intended notice is presented
and the existing assertion passes. Keep this separate from v2 activation.

Implemented and locally committed; production admission disabled. No push,
signing, deployment or release.
