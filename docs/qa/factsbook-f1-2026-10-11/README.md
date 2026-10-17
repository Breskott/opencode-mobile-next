# FactsBook frontend: F1 (fake node), F2 (real API) and F3 (B2 contract) (2026-10-11)

F1: behind a hidden developer flag, the Inbox (Chats home) shows a Memory section and the v1 screens work
against a fake node. F2: the same screens talk to the node's published v1 contract
(`factsbook/api/openapi-v1.yaml`, `api/README.md`, `api/fixtures/*.json`), with pairing, owner-signed
approvals, a phone outbox, and the pages Reminders, Memory care, Areas and sharing, Status and Set up.

## State

| Stage | Status |
|---|---|
| Implemented | `lib/domain/factsbook/` (types, gateway, fake, HTTP gateway, address rule, Ed25519, JCS, owner signer), `lib/state/factsbook/` (flag, store, session, outbox, controller), `lib/ui/screens/factsbook/`, kit part `KitFactRow` |
| Enabled | off by default: About > Developer > FactsBook (preview), or `--dart-define=OC_FACTSBOOK=true`, or the boolean preference `oc.dev.factsbook` |
| Verified | focused tests below; the HTTP gateway is tested against a stand-in node built from the node's own fixtures, not against a running node, and nothing was run on a device |
| Committed | local, branch `feat/factsbook-ui` |
| Deployed / released | no |

## What talks to the real API

`HttpFactsBookGateway` (bearer token, `Idempotency-Key` on every mutation, the error envelope mapped to plain
words with the code and request id under Details): status, things, search, inbox capture, retry and discard,
pending, outbox batch, review list and signed decisions, reminder parse, create, pause and edit, areas and
signed sharing, pairing. `FakeFactsBookGateway` is used only by tests and previews; an unpaired app shows one
row, "Set up FactsBook", and never sample data.

## Contract notes (where the app follows the node, not the older spec)

- No needs-you endpoint exists in v1: the app derives Needs you from the review queue and Not saved yet.
- A node-held couldn't-save entry has no text (only its item id); only phone-held notes can be copied or exported.
- The node reads one reminder shape: an ISO date-time then the title, one time, no repeat. The check sheet builds
  that text from its fields, and a reminder is saved only when the node's preview agrees with them.
- Owner proof (review decisions, area sharing): Ed25519 (the vetted `cryptography` 2.9.0 package, Apache-2.0) over the RFC 8785 canonical envelope (our JCS code,
  vector-tested); the RFC 8032 vectors run against the package. The key is made on the phone; its public half is shown for the console
  (`factsbook-node pair --owner-key HEX --scopes read,write,admin,owner`), and the owner device id it returns is
  typed into Set up. `authenticated_at` is the signing time: the app has no `local_auth` dependency, so no fingerprint or PIN prompt yet (F3).
- Settings (`PATCH /v1/config`) are signed the same way but no page changes them yet.

## Checks run (pinned Flutter 3.47.1, `OC_TEST_SLOTS=2`, affected files only)

- `test/factsbook/*` (contract fixtures, Ed25519/JCS/signer, HTTP gateway, address rule, session/outbox/deletion,
  fake node, controller and flag, screens, pages), `test/kit/kit_fact_row_test.dart`, the keyboard test and the
  `KitFactRow` gallery goldens.
- Gates: `kit_ratchet_test`, `kit/kit_manifest_test`, `golden_harness_test`, `l10n_coverage_test`,
  `ui_ledger_coverage_test`, `design_standard_test`, `l10n_new_locales_test`, `l10n_fg5_screens_test`.
- Existing tests touched by the About switch and the profile sweep: About, settings hub, release blockers, iOS gating,
  the two About goldens (regenerated: they gain the Developer group), `profile_deletion_test`, `profile_store_test`,
  `chats_home_test`, `home_navigation_test`.
- `flutter analyze` on the whole project.

## F3: the B2 contract (api 1.1), device authentication, and the F2 gaps

Contract alignment (read: `api/CHANGELOG.md`, `openapi-v1.yaml` 1.1, `README.md`, `capabilities.json`, the fixtures):

- Fixtures re-copied into `test/fixtures/factsbook/` (now 20 responses plus `capabilities.json`); the contract test
  fails when a fixture is added without a parser, and checks the English and Arabic inbox examples, the refusal
  fixtures (an outbox refusal, `index_rebuilding`), clients and the control chain.
- **Signature and control vectors, byte for byte: pass.** Our RFC 8785 canonical form of the vector's envelope equals
  `canonical_utf8`; the vector's Ed25519 signature verifies with the `cryptography` package; each change the vector
  lists (body, method, path, vault, nonce, time) breaks it; the root key hashes to the vector's fingerprint; the control
  chain's two records verify with the root key, link by hash, and a changed record, a reordered chain, a fork, or a
  different pinned fingerprint is not trusted. Status shows that check against the fingerprint pinned at pairing.
- Types: status `generated_at`, `state_revision`, `stale_seconds` null (cloud freshness unknown, never read as fresh),
  the `replication` module; preview `settings_rev`, `effective_zone`, `area`, `sens` (kept through confirmation as the
  preview object is sent back unchanged); reminder `area` and `sens`; settings, export, clients, control.
- Reminders use the structured schedule form: the schedule as JSON text, the title in `what`, the schedule id kept on
  edits, `floating_confirmed` on edits. A preview needs no idempotency header.
- Every error code the node can raise has plain words (English and Arabic), including `bad_request`, a full node queue
  (`outbox_full`, which keeps the note on the phone), `index_rebuilding`, a wait in seconds for `slow_down`, and four
  device-authentication outcomes. Codes and request ids appear only under Details.
- Outbox refusals with an unusable key (returned with an empty key) are matched by position.
- The capability matrix is bundled (`FactsBookCapabilities.b2`) and compared with the node's file in a test. Menu entries,
  the add-a-reminder row and Export are hidden where unsupported. Status lists cloud sync, opening the locked folder and
  reminder alarms as "Not available yet", the Reminders page says this phone does not sound reminders yet, and Status
  says plainly that replication is off and cloud freshness is not known. Nothing disabled is shown as working.

F2 gaps closed: Add a reminder from the Reminders page (title field); repeating reminders (daily, weekly with days,
monthly on a day or the last day, yearly) as far as the node's schedule forms go (intervals, events and cron are listed,
paused, not edited); FactsBook settings (brief cap changed with device authentication and the owner key; lock timeout,
brief time, quiet hours, home zone and spending limit shown; area sharing one row away); an edited approval keeps its
original source (shown beneath the fact as "Originally read from ... · date", and on the Memory care card); export of a
note the node holds (the encrypted object, to copy; it does not unlock the locked folder).

Device authentication: `local_auth` 3.0.2 (exact, published 2026-07-09; resolved `local_auth_android` 2.2.0,
`_darwin` 2.0.4, `_windows` 2.0.2, `_platform_interface` 1.1.0, all more than two weeks old). It is called only from
FactsBook's signing path, right before an owner decision (review, area sharing, settings) is signed; `authenticated_at`
is the time authentication succeeded. A PIN or pattern is accepted where no biometric is enrolled. No screen lock or
biometric, cancel, lock-out and failure each have plain words, and nothing is signed or sent when it does not succeed.
Native changes for the plugin (none built or run here): `MainActivity` extends `FlutterFragmentActivity`; `LaunchTheme`
and `NormalTheme` (day and night) inherit `Theme.AppCompat.DayNight.NoActionBar` (plugin README, Android 8 and below);
`USE_BIOMETRIC` comes from the plugin's own manifest, so the app manifest is unchanged. `ManageSpaceActivity` is left
as a `FlutterActivity`. This ships only in a new release (native change), not a Shorebird patch.

### Checks run (pinned Flutter 3.47.1, `OC_TEST_SLOTS=2`, affected files only)

`test/factsbook/*` (228 tests), the gates listed above, the Android native contract tests, `release_blockers_test`,
About and settings tests, the three About goldens, `profile_deletion_test`, `profile_store_test`, `chats_home_test`,
`home_navigation_test`; `flutter analyze` on the whole project.

### Still not available (the node says so; the app says so)

Cloud transport and safe-in-cloud claims, sensitive unlock, phone alarm delivery, external-edit application, outward
actions, automatic failover, AI features. Interval, event and cron reminders cannot be edited in the app.
`POST /v1/inbox/{id}/review` (a candidate from a text span, for "Remember this" from chat), client listing and
revocation (`GET /v1/clients`, `DELETE /v1/clients/{id}`) and the node's `--resume-client` repair are in the contract
but have no screen yet.

### Gaps for F4

An emulator or phone run of the native change (FragmentActivity, AppCompat theme, the biometric prompt) and
screenshots of every FactsBook screen; LAN HTTPS pinning (the token still travels over plain HTTP, private addresses
only); a clients page (list, revoke with a fresh owner proof); the span-to-candidate review for chat selections; Map,
Watching, Move and brief; the Arabic glossary words need the owner's choice.
