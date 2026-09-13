#!/usr/bin/env python3
"""Replay a recorded Gas City supervisor for the AI Team plugin tests.

Standard-library only.  Serves the TEAM-001 recordings under
``/v0/city/bright-lights/...`` and replays the recorded event logs as SSE.
It never runs an agent, a model, a shell command or a network call.

Time model: each scenario owns a "producer" that advances a head cursor
through the recorded event log at ``--pace`` seconds per event.  The producer
starts the first time a client opens ``/events/stream`` for that scenario.
Events at or below the head are history (visible in ``GET /events`` and
replayable with ``after_seq`` / ``Last-Event-ID``); events above it are the
future.  ``GET /bead/{id}`` reflects the last bead payload at or below the
head, so a client that follows the stream watches the bead go
open -> in_progress -> handed to the refinery.

Writes (TEAM-202): the supervisor's mutation routes answer in the pinned
spec's shapes and append their effects to the scenario's live events --
``/session/{id}/respond`` (202, then a ``pending_cleared`` frame),
``/session/{id}/messages`` (202 with a ``request_id``, then
``request.result.session.message`` -- or ``request.failed`` for a message
starting with ``fail:`` -- after ``--result-delay`` seconds),
``stop``/``kill``/``wake``/``suspend`` (200, then ``session.stopped`` /
``session.woke``), ``runs/{id}/cancel`` (202, then ``run.canceled``),
``convoy/{id}/close`` (200, then ``convoy.closed``), ``agent/{...}/{action}``
(200) and ``/sling`` (200, then two ``bead.updated``).  Session ids come
from the recordings; ``upstream-down`` as a session id makes the front
answer 502 ``upstream-unavailable``.

``--front`` makes the fixture also play the host front of
``tool/host/cp_front``: it serves ``/.well-known/opencode-mobile-orchestration``
and wraps every mutation in a receipt keyed by ``Idempotency-Key`` (replays
carry ``Idempotent-Replayed: true``; a key whose value starts with
``mismatch-`` is answered 409 ``idempotency-mismatch`` as if another
identity had used it first).
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import sys
import threading
import time
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlsplit

HERE = Path(__file__).resolve().parent
RECORDINGS = HERE / "recordings"
EVENTS = HERE / "events"
CONTRACT = HERE.parents[2] / "contracts" / "gascity-supervisor-openapi-v0-3648ca2d499a.json"

CITY = "bright-lights"
BEAD = "oc-loy"
SCENARIOS = ("normal", "blocked", "failed", "stream-drop")
DEFAULT_PORT = int(os.environ.get("GC_FIXTURE_PORT", "8382"))
DEFAULT_HOST = os.environ.get("GC_FIXTURE_HOST", "127.0.0.1")
DEFAULT_SCENARIO = os.environ.get("GC_FIXTURE_SCENARIO", "normal")
# blocked/failed follow the recording up to this event, then diverge.
BRANCH_SEQ = 1200
# Session ids that have a recorded transcript stream.  bl-48k is the polecat
# that worked oc-loy in the recorded run (its stream is a shape sample taken
# from the earlier polecat bl-5qc); it answers 404 once the run stops it.
TRANSCRIPTS = {
    "bl-5qc": "session-polecat.ndjson",
    "bl-48k": "session-polecat.ndjson",
    "bl-wisp-qqpj": "session-refinery.ndjson",
}
# Read-only recordings served verbatim, keyed by path under /v0/city/<city>.
PLAIN_RECORDINGS = {
    "/health": "health.json",
    "/status": "status.json",
    "/agents": "agents.json",
    "/sessions": "sessions.json",
    "/convoys": "convoys.json",
    "/waits": "waits.json",
    "/usage": "usage.json",
}


def now_iso() -> str:
    """UTC timestamp in the shape the supervisor uses for heartbeats."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_json(name: str) -> Any:
    """Load one recorded response body."""
    with (RECORDINGS / name).open(encoding="utf-8") as handle:
        return json.load(handle)


def load_ndjson(name: str) -> list[dict[str, Any]]:
    """Load one recorded event log (one JSON object per line)."""
    rows: list[dict[str, Any]] = []
    with (EVENTS / name).open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def problem(status: int, code: str, title: str, detail: str, urn: str = "urn:gascity:error") -> dict[str, Any]:
    """Build a problem+json body in the supervisor's ErrorModel shape."""
    return {
        "type": f"{urn}:{code}",
        "title": title,
        "status": status,
        "detail": detail,
        "code": code,
    }


FRONT_URN = "urn:opencode-mobile:front"
FRONT_LOGIN = "fixture@example.com"
WELL_KNOWN = "/.well-known/opencode-mobile-orchestration"


def known_session_ids() -> set[str]:
    """Every session id the recordings name: the sessions list, the
    transcript samples, the single-session recording and the polecat the
    blocked scenario's pending interaction belongs to."""
    ids = {item["id"] for item in load_json("sessions.json")["items"]}
    ids.update(TRANSCRIPTS)
    ids.add(load_json("session.json")["id"])
    blocked = load_json("bead_handed_to_refinery.json").get("metadata", {}).get("gc.session_id")
    if blocked:
        ids.add(blocked)
    return ids


def bead_of(event: dict[str, Any]) -> dict[str, Any] | None:
    """Return the bead carried by a bead.* event, if any."""
    if not event.get("type", "").startswith("bead."):
        return None
    bead = event.get("payload", {}).get("bead")
    return bead if isinstance(bead, dict) else None


def derived_event(base: dict[str, Any], seq: int, scenario: str, **bead_edits: Any) -> dict[str, Any]:
    """Copy a recorded bead.updated event with clearly marked scenario edits."""
    event = copy.deepcopy(base)
    event["seq"] = seq
    event["ts"] = now_iso()
    bead = event["payload"]["bead"]
    bead.update(bead_edits)
    bead.setdefault("metadata", {})["fixture.scenario"] = scenario
    return event


def last_bead_event(log: list[dict[str, Any]], bead_id: str) -> dict[str, Any]:
    """The latest recorded bead.* event for ``bead_id`` in ``log``."""
    for event in reversed(log):
        bead = bead_of(event)
        if bead and bead.get("id") == bead_id:
            return event
    raise KeyError(bead_id)


def blocked_pending(bead: dict[str, Any]) -> dict[str, Any]:
    """The human decision the blocked polecat is waiting on."""
    return {
        "session_id": bead.get("metadata", {}).get("gc.session_id", ""),
        "request_id": "req-fixture-choice-1",
        "kind": "choice",
        "prompt": "calc.py already defines subtract(). Replace it, keep it, or stop?",
        "options": ["replace", "keep", "stop"],
        "metadata": {"bead": bead["id"], "fixture.scenario": "blocked"},
    }


def failed_run(bead: dict[str, Any]) -> dict[str, Any]:
    """A terminal run projection for the failed scenario (Run schema)."""
    metadata = bead.get("metadata", {})
    return {
        "run_id": bead["id"],
        "title": bead["title"],
        "status": "failed",
        "scope": {"kind": "rig", "ref": "ocproof"},
        "target": metadata.get("gc.routed_to", ""),
        "started_at": bead["created_at"],
        "updated_at": now_iso(),
        "last_error": {"code": "fail", "message": metadata.get("last_error", "")},
    }


class Scenario:
    """One replayable timeline: recorded log, derived edits and live appends."""

    def __init__(
        self,
        name: str,
        log: list[dict[str, Any]],
        history: list[dict[str, Any]],
        pace: float,
        drop_seq: int | None = None,
        final_bead: dict[str, Any] | None = None,
    ) -> None:
        self.name = name
        self.history = history
        self.log = log
        self.live: list[dict[str, Any]] = []
        self.pace = pace
        self.drop_seq = drop_seq
        self.final_bead = final_bead
        self.head = log[0]["seq"] - 1
        self.cond = threading.Condition()
        self.producer: threading.Thread | None = None

    def start(self, stopping: threading.Event) -> None:
        """Start advancing the head (idempotent)."""
        with self.cond:
            if self.producer is not None:
                return
            self.producer = threading.Thread(target=self._produce, args=(stopping,), daemon=True)
            self.producer.start()

    def _produce(self, stopping: threading.Event) -> None:
        while not stopping.is_set():
            with self.cond:
                pending = [e for e in self.log + self.live if e["seq"] > self.head]
                if not pending:
                    self.cond.wait(0.5)
                    continue
            if self.pace > 0:
                time.sleep(self.pace)
            with self.cond:
                self.head = pending[0]["seq"]
                self.cond.notify_all()

    def visible(self) -> list[dict[str, Any]]:
        """All events at or below the head, oldest first."""
        with self.cond:
            return self.history + [e for e in self.log + self.live if e["seq"] <= self.head]

    def after(self, cursor: int) -> list[dict[str, Any]]:
        """Visible events with seq > cursor."""
        return [e for e in self.visible() if e["seq"] > cursor]

    def append(self, events: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Append write-side events after everything recorded; returns them.

        An event carrying ``_frame`` is written to the stream under that SSE
        event name (``pending_cleared``) instead of ``event``; the key never
        reaches the wire."""
        with self.cond:
            tail = self.live[-1]["seq"] if self.live else self.log[-1]["seq"]
            for offset, event in enumerate(events, start=1):
                event["seq"] = tail + offset
                event["ts"] = now_iso()
            self.live.extend(events)
            self.cond.notify_all()
        return events

    def append_later(self, events: list[dict[str, Any]], delay: float, stopping: threading.Event) -> None:
        """Append ``events`` after ``delay`` seconds (at once when zero)."""
        if delay <= 0:
            self.append(events)
            return

        def run() -> None:
            if not stopping.wait(delay):
                self.append(events)

        threading.Thread(target=run, daemon=True).start()

    def bead_versions(self, bead_id: str) -> list[tuple[int, dict[str, Any]]]:
        """Every (seq, bead) version known for ``bead_id``, oldest first."""
        versions = []
        for event in self.log + self.live:
            bead = bead_of(event)
            if bead and bead.get("id") == bead_id:
                versions.append((event["seq"], bead))
        if self.final_bead and self.final_bead.get("id") == bead_id:
            versions.append((self.log[-1]["seq"], self.final_bead))
        versions.sort(key=lambda item: item[0])
        return versions

    def bead_state(self, bead_id: str) -> dict[str, Any] | None:
        """The bead as of the current head (the earliest version before it)."""
        versions = self.bead_versions(bead_id)
        if not versions:
            return None
        with self.cond:
            head = self.head
        seen = [bead for seq, bead in versions if seq <= head]
        return copy.deepcopy(seen[-1] if seen else versions[0][1])

    def session_finished(self, session_id: str) -> bool:
        """True once a visible session.stopped names this session and no later
        session.woke restarted its template."""
        stopped, woke, template = -1, -1, None
        for event in self.visible():
            payload = event.get("payload", {})
            if event.get("type") == "session.stopped" and payload.get("session_id") == session_id:
                stopped, template = event["seq"], payload.get("template")
            elif event.get("type") == "session.woke" and template and event.get("subject") == template:
                woke = event["seq"]
        return stopped > woke


def build_scenarios(pace: float, drop_after: int) -> dict[str, Scenario]:
    """Derive the four scenarios from the recorded normal run."""
    log = [row["data"] for row in load_ndjson("normal-run.ndjson")]
    history = [e for e in load_ndjson("events-snapshot.ndjson") if e["seq"] < log[0]["seq"]]
    final = load_json("bead_handed_to_refinery.json")
    trunk = [e for e in log if e["seq"] <= BRANCH_SEQ]
    base = last_bead_event(trunk, BEAD)
    blocked = derived_event(base, BRANCH_SEQ + 1, "blocked", is_blocked=True)
    failed = derived_event(base, BRANCH_SEQ + 1, "failed", status="failed")
    failed["payload"]["bead"]["metadata"]["last_error"] = (
        "polecat exited before pushing polecat/oc-loy: git push rejected (non-fast-forward)"
    )
    drop_seq = log[0]["seq"] + max(drop_after, 1) - 1
    return {
        "normal": Scenario("normal", log, history, pace, final_bead=final),
        "stream-drop": Scenario("stream-drop", log, history, pace, drop_seq=drop_seq, final_bead=final),
        "blocked": Scenario("blocked", trunk + [blocked], history, pace),
        "failed": Scenario("failed", trunk + [failed], history, pace),
    }


class FixtureServer(ThreadingHTTPServer):
    """Threaded HTTP server carrying the scenario table and stream options."""

    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], options: argparse.Namespace) -> None:
        super().__init__(address, Handler)
        self.options = options
        self.scenarios = build_scenarios(options.pace, options.drop_after)
        self.transcripts = {sid: load_ndjson(name) for sid, name in TRANSCRIPTS.items()}
        self.sessions = known_session_ids()
        self.stopping = threading.Event()
        self.log_requests = options.verbose
        self.front = bool(getattr(options, "front", False))
        self.result_delay = float(getattr(options, "result_delay", 0.0))
        # Idempotency-Key -> receipt record, as the front keeps them.
        self.receipts: dict[str, dict[str, Any]] = {}
        self.receipts_lock = threading.Lock()

    def stop(self) -> None:
        """Wake every stream so handler threads exit, then shut down."""
        self.stopping.set()
        for scenario in self.scenarios.values():
            with scenario.cond:
                scenario.cond.notify_all()
        self.shutdown()
        self.server_close()


class Handler(BaseHTTPRequestHandler):
    """Routes the supervisor paths this fixture implements."""

    protocol_version = "HTTP/1.1"
    server: FixtureServer

    def log_message(self, fmt: str, *args: Any) -> None:  # noqa: D401
        if self.server.log_requests:
            super().log_message(fmt, *args)

    # -- plumbing --------------------------------------------------------

    def _parse(self) -> tuple[str, dict[str, str]]:
        parts = urlsplit(self.path)
        query = {k: v[-1] for k, v in parse_qs(parts.query).items()}
        return parts.path.rstrip("/") or "/", query

    def _scenario(self, query: dict[str, str]) -> Scenario | None:
        name = query.get("scenario") or self.server.options.scenario
        return self.server.scenarios.get(name)

    def _send_json(self, status: int, body: Any, headers: dict[str, str] | None = None) -> None:
        raw = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("X-GC-Request-Id", uuid.uuid4().hex)
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(raw)

    def _send_problem(self, status: int, code: str, title: str, detail: str, urn: str = "urn:gascity:error") -> None:
        raw = json.dumps(problem(status, code, title, detail, urn)).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/problem+json")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("X-GC-Request-Id", uuid.uuid4().hex)
        self.end_headers()
        self.wfile.write(raw)

    def _not_found(self, detail: str = "no route for this path") -> None:
        self._send_problem(404, "not-found", "Not Found", detail)

    def _read_body(self) -> dict[str, Any] | None:
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        if not raw:
            return {}
        try:
            body = json.loads(raw)
        except json.JSONDecodeError:
            return None
        return body if isinstance(body, dict) else None

    def _cursor(self, query: dict[str, str], default: int) -> int | None:
        """Resolve after_seq (query) or Last-Event-ID (header); None if malformed."""
        raw = query.get("after_seq") or self.headers.get("Last-Event-ID")
        if raw is None or raw == "":
            return default
        try:
            return int(raw)
        except ValueError:
            return None

    def _city_path(self, path: str) -> str | None:
        """Strip /v0/city/<city>; None when the city is not this fixture's."""
        prefix = "/v0/city/"
        if not path.startswith(prefix):
            return None
        rest = path[len(prefix):]
        city, _, tail = rest.partition("/")
        if city != CITY:
            return None
        return "/" + tail

    # -- routing ---------------------------------------------------------

    def do_GET(self) -> None:  # noqa: N802
        path, query = self._parse()
        if path == WELL_KNOWN:
            self._well_known()
        elif path == "/health":
            self._send_json(200, load_json("health.json"))
        elif path == "/openapi.json":
            self._send_json(200, json.loads(CONTRACT.read_text(encoding="utf-8")))
        elif path == "/v0/cities":
            self._send_json(200, self._cities())
        elif path.startswith("/v0/city/"):
            self._city_get(path, query)
        else:
            self._not_found()

    def do_POST(self) -> None:  # noqa: N802
        path, query = self._parse()
        tail = self._city_path(path)
        scenario = self._scenario(query)
        if tail is None:
            self._city_missing(path)
            return
        if scenario is None:
            self._send_problem(400, "invalid-request", "Invalid Request", f"unknown scenario {query.get('scenario')!r}")
            return
        if self.server.front:
            self._front_mutation(scenario, tail)
        else:
            self._mutation(scenario, tail)

    def _mutation(self, scenario: Scenario, tail: str) -> None:
        """Route one supervisor mutation (no front semantics)."""
        if not self.headers.get("X-GC-Request"):
            self._send_problem(403, "forbidden", "Forbidden", "X-GC-Request header is required on mutation requests")
            return
        parts = tail.strip("/").split("/")
        if tail == "/sling":
            self._sling(scenario)
        elif len(parts) == 3 and parts[0] == "session":
            self._session_mutation(scenario, parts[1], parts[2])
        elif len(parts) == 3 and parts[0] == "runs" and parts[2] == "cancel":
            self._run_cancel(scenario, parts[1])
        elif len(parts) == 3 and parts[0] == "convoy" and parts[2] == "close":
            self._convoy_close(scenario, parts[1])
        elif len(parts) in (3, 4) and parts[0] == "agent":
            self._agent_action(parts[1:-1], parts[-1])
        else:
            self._read_body()
            self._not_found()

    # -- front ------------------------------------------------------------

    def _well_known(self) -> None:
        if not self.server.front:
            self._not_found()
            return
        host = self.headers.get("Host") or f"127.0.0.1:{self.server.server_address[1]}"
        self._send_json(200, {
            "provider": "gascity",
            "supervisorUrl": f"http://{host}",
            "city": CITY,
            "front": True,
            "version": load_json("health.json").get("version"),
            "capabilities": {"read": True, "control": True, "merge": False},
            "identity": {"login": FRONT_LOGIN, "allowed": True},
        })

    def _front_mutation(self, scenario: Scenario, tail: str) -> None:
        """The front's receipt semantics around ``_mutation``."""
        key = (self.headers.get("Idempotency-Key") or "").strip()
        if "/session/upstream-down/" in tail + "/":
            self._read_body()
            self._send_problem(502, "upstream-unavailable", "Bad Gateway", "the supervisor did not answer", FRONT_URN)
            return
        if key.startswith("mismatch-"):
            self._read_body()
            self._send_problem(409, "idempotency-mismatch", "Conflict", "this Idempotency-Key was first used by another identity", FRONT_URN)
            return
        with self.server.receipts_lock:
            stored = self.server.receipts.get(key) if key else None
        if stored is not None:
            self._read_body()  # drain
            self._send_json(stored["upstream_status"], stored, {"Idempotent-Replayed": "true"})
            return
        captured: dict[str, Any] = {}
        original_send_json, original_send_problem = self._send_json, self._send_problem

        def capture_json(status: int, body: Any, headers: dict[str, str] | None = None) -> None:
            captured.update(status=status, body=body)

        def capture_problem(status: int, code: str, title: str, detail: str, urn: str = "urn:gascity:error") -> None:
            captured.update(status=status, body=problem(status, code, title, detail, urn))

        self._send_json, self._send_problem = capture_json, capture_problem  # type: ignore[method-assign]
        try:
            self._mutation(scenario, tail)
        finally:
            self._send_json, self._send_problem = original_send_json, original_send_problem  # type: ignore[method-assign]
        status = captured.get("status", 500)
        receipt = {
            "request_id": uuid.uuid4().hex[:16],
            "status": "accepted" if 200 <= status < 300 else "rejected",
            "upstream_status": status,
            "body": captured.get("body"),
            "idempotency_key": key or None,
        }
        if key:
            with self.server.receipts_lock:
                self.server.receipts[key] = receipt
        self._send_json(status, receipt)

    # -- session, run, convoy and agent writes ------------------------------

    def _session_mutation(self, scenario: Scenario, session_id: str, verb: str) -> None:
        if session_id not in self.server.sessions:
            self._read_body()
            self._send_problem(404, "session-not-found", "Session Not Found", f"session {session_id} not found")
            return
        body = self._read_body()
        if body is None:
            self._send_problem(400, "invalid-request", "Invalid Request", "body must be a JSON object")
            return
        stopping = self.server.stopping
        if verb == "respond":
            action = body.get("action")
            if not isinstance(action, str) or not action:
                self._send_problem(422, "invalid-request", "Unprocessable Entity", "action is required")
                return
            request_id = body.get("request_id")
            if isinstance(request_id, str) and request_id:
                scenario.append_later([{
                    "_frame": "pending_cleared",
                    "request_id": request_id,
                    "session_id": session_id,
                    "action": action,
                }], self.server.result_delay, stopping)
            self._send_json(202, {"status": "accepted", "id": session_id})
        elif verb == "messages":
            message = body.get("message")
            if not isinstance(message, str) or not message.strip():
                self._send_problem(422, "invalid-request", "Unprocessable Entity", "message is required")
                return
            request_id = f"req-{uuid.uuid4().hex[:12]}"
            with scenario.cond:
                cursor = scenario.head
            if message.startswith("fail:"):
                result = {
                    "type": "request.failed",
                    "actor": "supervisor",
                    "subject": session_id,
                    "session_id": session_id,
                    "message": message[len("fail:"):].strip() or "the session refused the message",
                    "payload": {
                        "request_id": request_id,
                        "operation": "session.message",
                        "error_code": "session-refused",
                        "error_message": message[len("fail:"):].strip() or "the session refused the message",
                    },
                }
            else:
                result = {
                    "type": "request.result.session.message",
                    "actor": "supervisor",
                    "subject": session_id,
                    "session_id": session_id,
                    "payload": {"request_id": request_id, "session_id": session_id},
                }
            scenario.append_later([result], self.server.result_delay, stopping)
            self._send_json(202, {"status": "accepted", "request_id": request_id, "event_cursor": str(cursor)})
        elif verb in ("stop", "kill", "suspend"):
            scenario.append_later([{
                "type": "session.stopped" if verb != "suspend" else "session.suspended",
                "actor": "supervisor",
                "subject": session_id,
                "session_id": session_id,
                "payload": {"session_id": session_id, "reason": verb},
            }], self.server.result_delay, stopping)
            self._send_json(200, {"status": "ok", "id": session_id})
        elif verb == "wake":
            scenario.append_later([{
                "type": "session.woke",
                "actor": "supervisor",
                "subject": session_id,
                "session_id": session_id,
                "payload": {"session_id": session_id},
            }], self.server.result_delay, stopping)
            self._send_json(200, {"status": "ok", "id": session_id})
        elif verb == "close":
            self._send_json(200, {"status": "ok", "id": session_id})
        else:
            self._not_found()

    def _run_cancel(self, scenario: Scenario, run_id: str) -> None:
        self._read_body()
        runs = load_json("runs.json").get("runs") or []
        known = {run.get("run_id") or run.get("id") for run in runs} | {BEAD}
        if run_id not in known:
            self._send_problem(404, "run-not-found", "Run Not Found", f"run {run_id} not found")
            return
        scenario.append_later([{
            "type": "run.canceled",
            "actor": "supervisor",
            "subject": run_id,
            "run_id": run_id,
            "payload": {"run_id": run_id, "status": "canceled"},
        }], self.server.result_delay, self.server.stopping)
        self._send_json(202, {"run_id": run_id, "status": "canceling", "closed": 0})

    def _convoy_close(self, scenario: Scenario, convoy_id: str) -> None:
        self._read_body()
        convoys = load_json("convoys.json").get("items", [])
        if convoy_id not in {c.get("id") for c in convoys}:
            self._send_problem(404, "convoy-not-found", "Convoy Not Found", f"convoy {convoy_id} not found")
            return
        scenario.append_later([{
            "type": "convoy.closed",
            "actor": "supervisor",
            "subject": convoy_id,
            "payload": {"convoy_id": convoy_id, "status": "closed"},
        }], self.server.result_delay, self.server.stopping)
        self._send_json(200, {"status": "ok", "id": convoy_id})

    def _agent_action(self, name_parts: list[str], action: str) -> None:
        self._read_body()
        if action not in ("suspend", "resume"):
            self._send_problem(422, "invalid-request", "Unprocessable Entity", f"unknown agent action {action!r}")
            return
        name = "/".join(name_parts)
        agents = {a["name"] for a in load_json("agents.json")["items"]}
        if name not in agents:
            self._send_problem(404, "agent-not-found", "Agent Not Found", f"agent {name} not found")
            return
        self._send_json(200, {"status": "ok"})

    def _city_missing(self, path: str) -> None:
        if path.startswith("/v0/city/"):
            self._send_problem(404, "city-not-found", "City Not Found", f"no city registered for {path}")
        else:
            self._not_found()

    def _city_get(self, path: str, query: dict[str, str]) -> None:
        tail = self._city_path(path)
        if tail is None:
            self._city_missing(path)
            return
        scenario = self._scenario(query)
        if scenario is None:
            self._send_problem(400, "invalid-request", "Invalid Request", f"unknown scenario {query.get('scenario')!r}")
            return
        if tail in PLAIN_RECORDINGS:
            self._send_json(200, load_json(PLAIN_RECORDINGS[tail]))
        elif tail == "/beads":
            self._beads(scenario, query)
        elif tail.startswith("/bead/") and tail.count("/") == 2:
            self._bead(scenario, tail.split("/")[2])
        elif tail == "/runs":
            self._runs(scenario)
        elif tail == "/pending":
            self._pending(scenario)
        elif tail == "/events":
            self._events_page(scenario, query)
        elif tail == "/events/stream":
            self._events_stream(scenario, query)
        elif tail.startswith("/session/") and tail.endswith("/stream"):
            self._session_stream(scenario, tail.split("/")[2], query)
        elif tail.startswith("/session/") and tail.count("/") == 2:
            self._session(tail.split("/")[2])
        else:
            self._not_found()

    # -- JSON reads ------------------------------------------------------

    def _cities(self) -> dict[str, Any]:
        status = load_json("status.json")
        city = {"name": status["name"], "path": status["path"], "running": True, "status": "running"}
        return {"items": [city], "total": 1}

    def _beads(self, scenario: Scenario, query: dict[str, str]) -> None:
        if query.get("ready") == "true":
            self._send_json(200, load_json("beads_ready.json"))
            return
        page = load_json("beads.json")
        current = scenario.bead_state(BEAD)
        if current is not None:
            page["items"].insert(0, current)
            page["total"] = page.get("total", len(page["items"]) - 1) + 1
        self._send_json(200, page)

    def _bead(self, scenario: Scenario, bead_id: str) -> None:
        bead = scenario.bead_state(bead_id)
        if bead is None and bead_id == "oc-cq6":
            bead = load_json("bead_after_sling.json")
        if bead is None:
            bead = next((b for b in load_json("beads.json")["items"] if b["id"] == bead_id), None)
        if bead is None:
            self._send_problem(404, "bead-not-found", "Bead Not Found", f"bead {bead_id} not found")
            return
        self._send_json(200, bead)

    def _runs(self, scenario: Scenario) -> None:
        runs = load_json("runs.json")
        if scenario.name == "failed":
            bead = scenario.bead_state(BEAD) or {}
            if bead.get("status") == "failed":
                runs = {
                    "runs": [failed_run(bead)],
                    "status_counts": {**runs["status_counts"], "failed": 1},
                    "partial": False,
                    "partial_errors": [],
                }
        self._send_json(200, runs)

    def _pending(self, scenario: Scenario) -> None:
        page = load_json("pending.json")
        if scenario.name == "blocked":
            bead = scenario.bead_state(BEAD) or {}
            if bead.get("is_blocked"):
                page = {"items": [blocked_pending(bead)], "total": 1}
        self._send_json(200, page)

    def _events_page(self, scenario: Scenario, query: dict[str, str]) -> None:
        try:
            limit = max(1, min(int(query.get("limit", "50")), 500))
        except ValueError:
            self._send_problem(400, "invalid-request", "Invalid Request", "limit must be an integer")
            return
        events = [e for e in scenario.visible() if "_frame" not in e]
        newest_first = list(reversed(events))[:limit]
        self._send_json(200, {"items": newest_first, "total": len(events)})

    def _session(self, session_id: str) -> None:
        if session_id == "gc-58":
            self._send_json(200, load_json("session.json"))
            return
        item = next((s for s in load_json("sessions.json")["items"] if s["id"] == session_id), None)
        if item is None:
            self._send_problem(404, "session-not-found", "Session Not Found", f"session {session_id} not found")
            return
        self._send_json(200, item)

    # -- writes ----------------------------------------------------------

    def _sling(self, scenario: Scenario) -> None:
        if not self.headers.get("X-GC-Request"):
            self._send_problem(403, "forbidden", "Forbidden", "X-GC-Request header is required on mutation requests")
            return
        body = self._read_body()
        if body is None or not isinstance(body.get("target"), str) or not body["target"]:
            self._send_problem(400, "invalid-request", "Invalid Request", "target is required")
            return
        bead_id = body.get("bead") or BEAD
        response = load_json("sling_response.json")
        response["target"] = body["target"]
        response["bead"] = bead_id
        scenario.append(self._sling_events(scenario, bead_id, body["target"]))
        runs_url = f"/v0/city/{CITY}/runs"
        self._send_json(200, response, {"Location": runs_url})

    def _sling_events(self, scenario: Scenario, bead_id: str, target: str) -> list[dict[str, Any]]:
        """Routed then claimed bead.updated events, shaped like seq 1034/1072."""
        routed = copy.deepcopy(next(e for e in scenario.log if e["seq"] == 1034))
        claimed = copy.deepcopy(next(e for e in scenario.log if e["seq"] == 1072))
        for event in (routed, claimed):
            event["subject"] = bead_id
            bead = event["payload"]["bead"]
            bead["id"] = bead_id
            bead["metadata"]["gc.routed_to"] = target
            bead["metadata"]["fixture.scenario"] = "sling"
        return [routed, claimed]

    # -- SSE -------------------------------------------------------------

    def _start_sse(self) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.send_header("X-GC-Request-Id", uuid.uuid4().hex)
        self.end_headers()

    def _write_sse(self, event: str, data: Any, event_id: str | None = None) -> None:
        frame = ""
        if event_id is not None:
            frame += f"id: {event_id}\n"
        frame += f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"
        self.wfile.write(frame.encode("utf-8"))
        self.wfile.flush()

    def _events_stream(self, scenario: Scenario, query: dict[str, str]) -> None:
        with scenario.cond:
            cursor = self._cursor(query, scenario.head)
            if cursor is not None and cursor > scenario.head:
                # A cursor the server has never issued (a restarted supervisor,
                # a client from another host): resume from the head instead.
                # The client sees a first id that is not cursor + 1 and must
                # treat every scope as dirty (head-only replay).
                cursor = scenario.head
        if cursor is None:
            self._send_problem(400, "invalid-cursor", "Invalid Cursor", "after_seq / Last-Event-ID must be an integer")
            return
        scenario.start(self.server.stopping)
        self._start_sse()
        heartbeat = self.server.options.heartbeat
        last_write = time.monotonic()
        try:
            while not self.server.stopping.is_set():
                batch = scenario.after(cursor)
                if not batch:
                    with scenario.cond:
                        scenario.cond.wait(heartbeat)
                    if time.monotonic() - last_write >= heartbeat:
                        self._write_sse("heartbeat", {"timestamp": now_iso()})
                        last_write = time.monotonic()
                    continue
                for event in batch:
                    frame = event.get("_frame", "event")
                    data = {k: v for k, v in event.items() if k != "_frame"} if frame != "event" else event
                    self._write_sse(frame, data, str(event["seq"]))
                    cursor = event["seq"]
                    last_write = time.monotonic()
                    if scenario.drop_seq is not None and cursor == scenario.drop_seq:
                        return  # stream-drop: vanish mid-run, no terminal event
        except (BrokenPipeError, ConnectionResetError):
            return

    def _session_stream(self, scenario: Scenario, session_id: str, query: dict[str, str]) -> None:
        rows = self.server.transcripts.get(session_id)
        if rows is None or scenario.session_finished(session_id):
            detail = f"session {session_id} has no live output" if rows else f"session {session_id} not found"
            self._send_problem(404, "session-not-found", "Session Not Found", detail)
            return
        cursor = self._cursor(query, 0)
        if cursor is None:
            self._send_problem(400, "invalid-cursor", "Invalid Cursor", "after_seq / Last-Event-ID must be an integer")
            return
        turns = [row for row in rows if row.get("event") == "turn" and int(row["id"]) > cursor]
        self._start_sse()
        try:
            self._replay_turns(turns)
            while not self.server.stopping.is_set():
                self.server.stopping.wait(self.server.options.heartbeat)
                self._write_sse("heartbeat", {"timestamp": now_iso()})
        except (BrokenPipeError, ConnectionResetError):
            return

    def _replay_turns(self, turns: list[dict[str, Any]]) -> None:
        pace = self.server.options.pace
        for row in turns:
            if self.server.stopping.is_set():
                return
            if pace > 0:
                time.sleep(pace)
            self._write_sse("turn", row["data"], row["id"])


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """CLI flags; environment variables supply the defaults."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", default=DEFAULT_HOST, help="bind address (GC_FIXTURE_HOST)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="bind port, 0 for ephemeral (GC_FIXTURE_PORT)")
    parser.add_argument("--scenario", choices=SCENARIOS, default=DEFAULT_SCENARIO, help="default scenario (GC_FIXTURE_SCENARIO); any request may override with ?scenario=")
    parser.add_argument("--pace", type=float, default=0.05, help="seconds between replayed events")
    parser.add_argument("--heartbeat", type=float, default=15.0, help="seconds between SSE heartbeats")
    parser.add_argument("--drop-after", type=int, default=20, help="stream-drop: close the stream after this many recorded events")
    parser.add_argument("--front", action="store_true", help="also play the host front: well-known document and receipts keyed by Idempotency-Key")
    parser.add_argument("--result-delay", type=float, default=0.0, help="seconds between a mutation's answer and its result / effect event")
    parser.add_argument("--once", action="store_true", help="serve a single request and exit")
    parser.add_argument("--verbose", action="store_true", help="log requests to stderr")
    args = parser.parse_args(argv)
    if args.scenario not in SCENARIOS:
        parser.error(f"unknown scenario {args.scenario!r}")
    return args


def main(argv: list[str] | None = None) -> int:
    """Run the fixture until Ctrl-C (or one request with --once)."""
    options = parse_args(argv)
    server = FixtureServer((options.host, options.port), options)
    host, port = server.server_address[:2]
    print(f"gascity fixture: http://{host}:{port}/v0/city/{CITY} scenario={options.scenario}", file=sys.stderr)
    try:
        if options.once:
            server.daemon_threads = False  # server_close() then joins the handler
            server.handle_request()
        else:
            server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.stopping.set()
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
