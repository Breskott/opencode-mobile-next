# FactsBook F5: event triggers (2026-10-11)

Finish line: behind the hidden flag `oc.dev.factsbook`, a person can open
Triggers from About you or FactsBook settings, see rules grouped by source with
counts and a pause, create or edit a rule in plain words and test it on a
sample, open "Why this fired", review trigger outcomes in Memory care, and
answer a "Talk about this with your agent?" offer that opens a new chat seeded
with the offer's summary only.

Non-goals kept: no Android notification capture (Notification access says
"Not available yet"), no automatic chat start (the switch is shown off and
unavailable), no real Gmail or SMS.

Contract read: factsbook `docs/specs/44-event-triggers.md`, `02-contracts.md`
3.12, `api/openapi-v1.yaml` 1.3.0-dev, `api/CHANGELOG.md`,
`api/capabilities.json` (B4), the fixtures and the design artboards.

## What changed

- Gateway: rules (list, create, replace, delete, test), events, firings,
  reminder proposals (list, decide), offers (list, accept, cancel) in
  `FactsBookGateway`, `HttpFactsBookGateway` and `FakeFactsBookGateway`
  (fake trigger half in `fake_factsbook_triggers.dart`). Owner-signed writes
  use the existing proof; `503 busy` is asked again with the same key like
  `429`.
- Capabilities: the shipped matrix is now the node's B4 one (`b4`, replaces
  `b2`); every trigger surface is gated on `local_trigger_slice` and offers on
  `explicit_synthetic_conversation_offers`. A node that answers `not_found` or
  `not_enabled` reads as "not available yet", never as an error.
- State: `FactsBookTriggers` (lists, week counts, grouping, stable offer
  receipt key). Offers count in Needs you.
- Screens: Triggers, Rule editor, Why this fired, Notification access, offer
  card, trigger cards in Memory care (reminder proposals: Approve, Reject,
  Skip; fact cards made by a rule get "From a trigger" and "Why this fired").
- `NewChatScreen` accepts unsent `initialText`; the offer seeds it with a
  fixed lead-in plus `summary` and nothing else.
- Fixtures: all of the node's current fixtures copied to
  `test/fixtures/factsbook/` (a told fact's `source` is now an evidence digest).
- Copy: English and Arabic (other languages fall back to English, as for the
  rest of FactsBook).

## Checks run

See the final report of the slice. No emulator, no APK, no real node.

## Contract questions

1. **Sender as a condition.** `RuleDefinition` has no sender field, only the
   source binding (client, kind, instance) and up to four literal words. The
   design's "When [source/sender]" is therefore source only; the sender and
   app are shown as claims in Why this fired.
2. **Who posts events.** The app's capture path uses `POST /v1/inbox`, not
   `POST /v1/events`, so no rule fires from what the app captures today. The
   editor binds `client_id` of the paired client and the instances
   `manual-share`, `selected-chat`, `manual-note`; the spec does not say which
   instance strings the app's own share/chat paths will use once they post
   events. Left for the capture slice.
3. **Test needs a saved rule.** `POST /v1/rules/{id}/test` takes a rule id, so
   a draft cannot be tested. The editor asks to save first and to save again
   after an edit (the test reads the stored rule).
4. **Reminder proposals versus review.** A rule's reminder outcome id (`rvw_`)
   is served by `/v1/reminder-proposals`; the spec does not say whether
   `/v1/review` also lists it. The app shows one card per id (proposal wins).
   Decisions are only `confirm`, `reject`, `skip` bound to revision and
   digest, so there is **no Edit** on a proposal; editing would break the
   binding. Safest option chosen.
5. **Fact outcomes.** A fact outcome needs `thing_id`, `base_rev`, `fact_id`
   and `category`; the editor cannot pick them, so it never creates one and
   keeps an existing one unchanged (with a note).
6. **Accepting an offer.** `adapter_result` (`started` or `unknown`) is a
   synthetic-adapter input. The app sends `started` and opens the chat on this
   phone itself. The node records the start when the person taps, before they
   send the first message; abandoning the new-chat screen leaves the offer
   `started`. `unknown` in the answer opens nothing and is not retried. The
   `/receipt` reconcile endpoint is not used.
7. **"Not now".** Maps to `cancel`, which is final for that offer. The spec has
   no snooze; offers expire in 24 hours anyway.
8. **Area.** A rule keeps `general` (or its existing area); there is no area
   picker, because the spec lists no rule area choices beyond "normal area".
9. **Capabilities source.** There is no endpoint that returns the node's
   matrix (`/v1/info` has none), so the app ships the B4 file and compares it
   with the node's `capabilities.json` in a test.
10. **Review to firing link.** `Review.proposer` is opaque; a fact card is tied
    to its firing by the id in the firing's `outcomes`.
11. **Automatic start.** The capability name is `automatic_conversation_start`
    in `disabled`; the schema allows only `auto_start: false`, so the switch is
    off and unavailable whatever the matrix says.

## Not done

- No run against a real node, no emulator proof, no screenshots.
- Posting trigger events from share and chat selection (`POST /v1/events`).
- Area picker, fact-outcome editing, offer receipt reconcile, "Make a rule from
  this" on Why this fired.
- Other languages than English and Arabic.

## Update 2026-10-11 (B5)

The node's contract moved to B5 after this record was written and answers most
of the questions above (`02-contracts.md` 3.13): a sender claim exists, events
go to `/v1/events` (not the inbox) with owner-signed classification for shares
and chat, drafts can be tested unsaved, proposals can be edited, offers are
client-reported (`pending` until the first message is sent), capabilities come
from `GET /v1/capabilities`, and the area comes from `/v1/areas`. The app now
follows all of it (see `docs/qa/factsbook-f6-2026-10-11/README.md` for the run
against the real node). Still open: fact outcomes (needs a thing picker).
