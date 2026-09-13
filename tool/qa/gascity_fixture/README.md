# Gas City supervisor fixture

A standard-library Python server that replays a recorded Gas City supervisor
for the AI Team plugin (TEAM-103). It binds to loopback, serves the TEAM-001
recordings under `/v0/city/bright-lights/...`, replays the recorded event
logs as SSE and never runs an agent, a model, a shell command or a network
call. Recordings and event logs are described at the end of this file.

## Run

```sh
python3 tool/qa/gascity_fixture/fixture_server.py                      # normal, port 8382
python3 tool/qa/gascity_fixture/fixture_server.py --scenario blocked --pace 0.2
GC_FIXTURE_SCENARIO=failed python3 tool/qa/gascity_fixture/fixture_server.py --port 0
```

| Flag | Env | Default | Meaning |
|---|---|---|---|
| `--host` | `GC_FIXTURE_HOST` | `127.0.0.1` | bind address; do not expose it remotely |
| `--port` | `GC_FIXTURE_PORT` | `8382` | bind port, `0` picks an ephemeral one (printed on stderr) |
| `--scenario` | `GC_FIXTURE_SCENARIO` | `normal` | default scenario; any request may override it with `?scenario=` |
| `--pace` | | `0.05` | seconds between replayed events (`0` = instant) |
| `--heartbeat` | | `15` | seconds between SSE `event: heartbeat` frames (tests use `0.2`) |
| `--drop-after` | | `20` | `stream-drop`: close the stream after this many recorded events |
| `--front` | | | also play the host front (`tool/host/cp_front`): serves the well-known document and wraps mutations in receipts keyed by `Idempotency-Key` (TEAM-202) |
| `--result-delay` | | `0` | seconds between a mutation's answer and its result / effect event on the stream |
| `--once` | | | serve a single request and exit |
| `--verbose` | | | log requests to stderr |

Stop it with Ctrl-C. `X-GC-Request-Id` is minted on every response.

## Endpoints

Top level: `GET /health` (the recorded city health), `GET /v0/cities`
(`{items:[{name,path,running,status}],total}` derived from `status.json`),
`GET /openapi.json` (the pinned contract in `contracts/`).

Under `/v0/city/bright-lights` (any other city name is a 404
`city-not-found`):

| Path | Source |
|---|---|
| `GET /health /status /agents /sessions /convoys /waits /usage` | recordings, verbatim |
| `GET /beads`, `GET /beads?ready=true` | recording; `/beads` gets the live `oc-loy` bead prepended |
| `GET /bead/{id}` | `oc-loy` follows the replay head (see below); `oc-cq6` and the ids in `beads.json` are static; else 404 `bead-not-found` |
| `GET /runs`, `GET /pending` | recordings, replaced by the derived payloads in `failed` / `blocked` |
| `GET /events?limit=N` | JSON page, newest first, `{items,total}` of everything at or below the head |
| `GET /events/stream` | SSE: `id: <seq>`, `event: event`, resumable with `?after_seq=N` or `Last-Event-ID`; a cursor beyond the head (never issued) resumes from the head instead, so the client sees a first id that is not `cursor + 1` (head-only replay); heartbeats while idle |
| `GET /session/{id}` | `sessions.json` items and `gc-58`; else 404 `session-not-found` |
| `GET /session/{id}/stream` | SSE replay of a transcript (`event: turn`, `id: 1..n`), resumable the same way, then heartbeats; 404 `session-not-found` for unknown ids or sessions with no live output |
| `POST /sling` | needs a non-empty `X-GC-Request` header (403 `forbidden` otherwise) and a JSON `target` (400 `invalid-request`); answers the recorded sling response with `Location: /v0/city/bright-lights/runs` and appends two `bead.updated` events (routed, then claimed) to the live stream |
| `POST /session/{id}/respond` | `{action, request_id?, text?}` → 202 `{status, id}`, then a `pending_cleared` frame with the `request_id` (TEAM-202) |
| `POST /session/{id}/messages` | `{message}` → 202 `{status, request_id, event_cursor}`, then `request.result.session.message` with that `request_id`; a message starting with `fail:` yields `request.failed` (the rest of the text as `error_message`) |
| `POST /session/{id}/stop` `kill` `suspend` `wake` `close` | 200 `{status: ok, id}`, then `session.stopped` / `session.suspended` / `session.woke` |
| `POST /runs/{id}/cancel` | 202 `{run_id, status: canceling, closed}`, then `run.canceled`; ids from `runs.json` or `oc-loy`, else 404 `run-not-found` |
| `POST /convoy/{id}/close` | 200 `{status: ok, id}`, then `convoy.closed`; ids from `convoys.json`, else 404 `convoy-not-found` |
| `POST /agent/{base}/{action}`, `/agent/{dir}/{base}/{action}` | `suspend` / `resume` → 200 `{status: ok}`; names from `agents.json`, else 404 `agent-not-found` |

Every mutation needs `X-GC-Request` (403 `forbidden`). Session ids are the
ones the recordings name (`sessions.json`, `gc-58`, the transcript sessions);
anything else is a 404 `session-not-found`. Result and effect events are
appended `--result-delay` seconds after the answer.

With `--front`, `GET /.well-known/opencode-mobile-orchestration` answers the
front's document (`front: true`, `capabilities.control: true`,
`identity: {login: fixture@example.com, allowed: true}`) and every mutation
answers a receipt `{request_id, status: accepted|rejected, upstream_status,
body, idempotency_key}` with the supervisor's status code, stored by
`Idempotency-Key`: a replay returns the stored receipt with
`Idempotent-Replayed: true` and never reaches the routes above. Two
deliberate front problems for tests: the session id `upstream-down` answers
502 `urn:opencode-mobile:front:upstream-unavailable`, and a key starting with
`mismatch-` answers 409 `urn:opencode-mobile:front:idempotency-mismatch`.

Everything else is a 404 problem+json
(`{"type":"urn:gascity:error:<code>","title","status","detail","code"}`).

Transcript streams: `bl-5qc` (polecat, always live), `bl-wisp-qqpj`
(refinery) and `bl-48k`, the polecat that worked `oc-loy` in the recorded run;
its stream replays the same polecat transcript and answers 404 "no live
output" once the replay passes its `session.stopped` (seq 1245).

## Time model

Each scenario owns a replay head. The head starts just before the recorded
run (seq 1025); the 92 older events from `events-snapshot.ndjson` are always
history. The first client that opens `/events/stream` for a scenario starts
its producer, which advances the head one event per `--pace` seconds. Events
at or below the head are history (visible in `GET /events`, replayable with
a cursor); the rest is the future. A stream opened without a cursor starts at
the current head, exactly like the real supervisor.

`GET /bead/oc-loy` returns the last bead payload at or below the head, so a
client that follows the stream sees `open` (routed) → `in_progress` (claimed,
branch `polecat/oc-loy`) → handed to the refinery (the recorded
`bead_handed_to_refinery.json`, which stands in as the state after the last
recorded event). Events appended by `POST /sling` get sequence numbers after
the recording and are produced once the recorded log has been replayed.

Scenarios are independent: streaming `failed` does not move the `normal`
head. Restart the server to rewind.

## Scenarios

| Scenario | What differs from the recording |
|---|---|
| `normal` | none: seq 1026→1443 as recorded, bead ends handed to the refinery |
| `blocked` | the log stops after seq 1200 and one derived `bead.updated` (seq 1201) sets `is_blocked: true`; `/pending` then lists one `choice` interaction (`session_id`, `request_id`, `kind`, `prompt`, `options`) |
| `failed` | the log stops after seq 1200 and one derived `bead.updated` (seq 1201) sets `status: "failed"` with `metadata.last_error`; `/runs` then carries one `failed` run with `last_error: {code, message}` |
| `stream-drop` | the `normal` log, but any stream that reaches seq `1025 + --drop-after` closes right after it, with no terminal event; reconnecting with `Last-Event-ID` (or `after_seq`) at that seq receives the rest |

Derived events are copies of the last recorded `oc-loy` event (seq 1186)
with only the edited fields changed, plus `metadata["fixture.scenario"]` so a
client can tell them from recorded data. Sling-appended events copy seq 1034
and 1072 and are marked `fixture.scenario: "sling"`.

## Tests

```sh
python3 -m unittest discover -s tool/qa/gascity_fixture -p 'test_*.py'
```

29 tests, about 15 s: each starts a server on an ephemeral port with
`--pace 0 --heartbeat 0.2 --drop-after 5`. They cover every scenario's key
endpoints, cursor resume, heartbeats, the stream drop and its resume, sling
with and without the header, problem+json shapes, the session streams, the
mutation routes with their result events and the `--front` receipts
(replay, rejected, 502, 409, `--result-delay`).

## Pointing the Flutter tests at it

TEAM-104's gateway tests start the fixture as a subprocess with
`--port 0 --pace 0 --heartbeat 0.2` (plus `--drop-after` for the reconnect
case), read the port from the first stderr line
(`gascity fixture: http://127.0.0.1:<port>/v0/city/bright-lights ...`), and
configure the orchestration profile with base URL
`http://127.0.0.1:<port>`, city `bright-lights`, plain HTTP allowed on
loopback. Select scenarios per request with `?scenario=` so one server can
serve several test groups, or start one server per scenario. On the phone,
`adb reverse tcp:8382 tcp:8382` exposes a PC-side fixture to the app.

## Dart fixture gateway

`lib/orchestration/adapters/fixture/fixture_gateway.dart`, the in-process
gateway for widget tests, is not part of this bead: it implements the
gateway interfaces that TEAM-101 defines, so it lands with TEAM-104 next to
the HTTP gateway and reuses these recordings through the same scenario
names.

## Recordings

Recorded 2026-09-10 from Gas City 1.4.1 (`bd` 1.2.2, Dolt 2.3.3, OpenCode
1.18.25 harness) during spike TEAM-001. See
`docs/qa/ai-team/spike-pc-2026-09.md` for the run and the findings, and
`contracts/gascity-supervisor-openapi-v0-3648ca2d499a.json` for the spec.

- `recordings/*.json` — one response body per file, pretty-printed,
  per-session `instance_token` values redacted. City name `bright-lights`,
  rig `ocproof`, bead `oc-loy`.
- `events/normal-run.ndjson` — `GET /events/stream?after_seq=1025`, one
  `{id,event,data}` per line, seq 1026→1443: sling, claim, polecat work,
  refinery merge.
- `events/resume-last-event-id.ndjson` — same stream resumed with the
  `Last-Event-ID: 1030` header.
- `events/events-snapshot.ndjson` — `GET /events` JSON page flattened
  (oldest first).
- `events/session-polecat.ndjson` — `GET /session/bl-5qc/stream`, the
  polecat session from the earlier wrong-rig attempt (bead `oc-cq6`); shape
  sample only, `event: turn` carries the whole transcript so far.
- `events/session-refinery.ndjson` — the refinery session that fast-forwarded
  `master` to `c02e375` and closed the stale `oc-cq6`.

Still to record: a `--formula` sling that shows up in `/runs`, and real
`blocked` / `failed` / `stream-drop` captures to replace the derived ones.
