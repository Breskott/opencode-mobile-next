#!/usr/bin/env python3
"""Tests for the Gas City fixture server.

Run with ``python3 -m unittest discover -s tool/qa/gascity_fixture -p 'test_*.py'``.
Each test starts its own server on an ephemeral loopback port with an
instant pace and a 0.2 s heartbeat so the whole module finishes in seconds.
"""

from __future__ import annotations

import contextlib
import http.client
import io
import json
import threading
import unittest
from typing import Any

import fixture_server as fx

CITY_PATH = f"/v0/city/{fx.CITY}"
FIRST_SEQ = 1026
LAST_SEQ = 1443
DROP_AFTER = 5


class FixtureCase(unittest.TestCase):
    """Boots a fixture per test and offers small HTTP/SSE helpers."""

    extra_args: list[str] = []

    def setUp(self) -> None:
        options = fx.parse_args(
            ["--port", "0", "--pace", "0", "--heartbeat", "0.2", "--drop-after", str(DROP_AFTER), *self.extra_args]
        )
        self.server = fx.FixtureServer(("127.0.0.1", 0), options)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self._stop)

    def _stop(self) -> None:
        self.server.stop()
        self.thread.join(timeout=5)

    def request(self, method: str, path: str, headers: dict[str, str] | None = None, body: Any = None):
        """One request; returns (status, headers, decoded body)."""
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        payload = json.dumps(body).encode() if body is not None else None
        conn.request(method, path, body=payload, headers={"Connection": "close", **(headers or {})})
        response = conn.getresponse()
        raw = response.read()
        conn.close()
        content_type = response.getheader("Content-Type", "")
        decoded = json.loads(raw) if "json" in content_type else raw
        return response.status, dict(response.getheaders()), decoded

    def get_json(self, path: str, **headers: str) -> Any:
        status, _, body = self.request("GET", path, headers)
        self.assertEqual(status, 200, body)
        return body

    def open_stream(self, path: str, headers: dict[str, str] | None = None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request("GET", path, headers=headers or {})
        response = conn.getresponse()
        self.addCleanup(conn.close)
        return response

    def read_frames(self, response, stop, limit: int = 2000) -> list[dict[str, Any]]:
        """Parse SSE frames until ``stop(frame)`` is true or the stream ends."""
        frames: list[dict[str, Any]] = []
        current: dict[str, Any] = {}
        while len(frames) < limit:
            line = response.readline()
            if not line:
                break
            text = line.decode().rstrip("\n")
            if text == "":
                if current:
                    if "data" in current:
                        current["data"] = json.loads(current["data"])
                    frames.append(current)
                    if stop(current):
                        break
                    current = {}
                continue
            key, _, value = text.partition(": ")
            current[key] = value
        return frames

    def stream_to_end(self, scenario: str, last_seq: int) -> list[dict[str, Any]]:
        response = self.open_stream(f"{CITY_PATH}/events/stream?scenario={scenario}&after_seq={FIRST_SEQ - 1}")
        self.assertEqual(response.status, 200)
        return self.read_frames(response, lambda f: f.get("id") == str(last_seq))


class ReadEndpointsTest(FixtureCase):
    def test_top_level_probe_endpoints(self) -> None:
        health = self.get_json("/health")
        self.assertEqual(health["city"], fx.CITY)
        cities = self.get_json("/v0/cities")
        self.assertEqual(cities["items"][0]["name"], fx.CITY)
        self.assertTrue(cities["items"][0]["running"])
        spec = self.get_json("/openapi.json")
        self.assertIn(f"/v0/city/{{cityName}}/events/stream", spec["paths"])

    def test_key_endpoints_parse_in_every_scenario(self) -> None:
        paths = [
            "/health", "/status", "/agents", "/sessions", "/beads", "/beads?ready=true",
            "/bead/oc-loy", "/bead/oc-cq6", "/convoys", "/runs", "/pending", "/waits",
            "/usage", "/events", "/session/bl-wisp-qqpj", "/session/gc-58",
        ]
        for scenario in fx.SCENARIOS:
            for path in paths:
                joiner = "&" if "?" in path else "?"
                body = self.get_json(f"{CITY_PATH}{path}{joiner}scenario={scenario}")
                self.assertIsInstance(body, dict, (scenario, path))

    def test_beads_list_carries_the_run_bead(self) -> None:
        beads = self.get_json(f"{CITY_PATH}/beads")
        self.assertEqual(beads["items"][0]["id"], fx.BEAD)
        self.assertEqual(beads["total"], len(beads["items"]))

    def test_events_page_is_newest_first_and_follows_the_head(self) -> None:
        before = self.get_json(f"{CITY_PATH}/events?limit=3")
        self.assertEqual(len(before["items"]), 3)
        self.assertLess(before["items"][0]["seq"], FIRST_SEQ)
        self.stream_to_end("normal", LAST_SEQ)
        after = self.get_json(f"{CITY_PATH}/events?limit=2")
        self.assertEqual(after["items"][0]["seq"], LAST_SEQ)
        self.assertEqual(after["total"], before["total"] + (LAST_SEQ - FIRST_SEQ + 1))
        self.assertEqual(self.get_json(f"{CITY_PATH}/events?limit=1&scenario=blocked")["total"], before["total"])


class ProblemJsonTest(FixtureCase):
    def assert_problem(self, path: str, status: int, code: str, method: str = "GET", headers=None) -> dict:
        got_status, got_headers, body = self.request(method, path, headers)
        self.assertEqual(got_status, status, body)
        self.assertEqual(got_headers["Content-Type"], "application/problem+json")
        self.assertEqual(body["code"], code)
        self.assertEqual(body["type"], f"urn:gascity:error:{code}")
        self.assertEqual(body["status"], status)
        for key in ("title", "detail"):
            self.assertIsInstance(body[key], str)
        return body

    def test_unknown_paths(self) -> None:
        self.assert_problem("/nope", 404, "not-found")
        self.assert_problem(f"{CITY_PATH}/nope", 404, "not-found")
        self.assert_problem("/v0/city/other-city/status", 404, "city-not-found")
        self.assert_problem(f"{CITY_PATH}/bead/zz-000", 404, "bead-not-found")
        self.assert_problem(f"{CITY_PATH}/session/zz-000", 404, "session-not-found")
        self.assert_problem(f"{CITY_PATH}/status?scenario=bogus", 400, "invalid-request")
        self.assert_problem(f"{CITY_PATH}/events/stream?after_seq=abc", 400, "invalid-cursor")

    def test_sling_without_header_is_forbidden(self) -> None:
        self.assert_problem(f"{CITY_PATH}/sling", 403, "forbidden", method="POST")
        status, _, body = self.request(
            "POST", f"{CITY_PATH}/sling", {"X-GC-Request": "1"}, {"bead": "oc-loy"}
        )
        self.assertEqual((status, body["code"]), (400, "invalid-request"))


class EventStreamTest(FixtureCase):
    def test_normal_replays_the_run_and_the_bead_progresses(self) -> None:
        start = self.get_json(f"{CITY_PATH}/bead/oc-loy")
        self.assertEqual(start["status"], "open")
        self.assertNotIn("assignee", start)
        frames = self.stream_to_end("normal", LAST_SEQ)
        self.assertEqual(len(frames), LAST_SEQ - FIRST_SEQ + 1)
        self.assertTrue(all(f["event"] == "event" for f in frames))
        seqs = [int(f["id"]) for f in frames]
        self.assertEqual(seqs, list(range(FIRST_SEQ, LAST_SEQ + 1)))
        self.assertEqual([f["data"]["seq"] for f in frames], seqs)
        statuses = [
            f["data"]["payload"]["bead"]["status"]
            for f in frames
            if f["data"]["type"] == "bead.updated" and f["data"]["subject"] == "oc-loy"
        ]
        self.assertEqual(statuses[0], "open")
        self.assertIn("in_progress", statuses)
        end = self.get_json(f"{CITY_PATH}/bead/oc-loy")
        self.assertEqual(end["assignee"], "ocproof/gastown.refinery")

    def test_last_event_id_and_after_seq_resume_after_the_cursor(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        response = self.open_stream(f"{CITY_PATH}/events/stream", {"Last-Event-ID": "1400"})
        frames = self.read_frames(response, lambda f: f.get("id") == str(LAST_SEQ))
        self.assertEqual([int(f["id"]) for f in frames], list(range(1401, LAST_SEQ + 1)))
        response = self.open_stream(f"{CITY_PATH}/events/stream?after_seq=1440", {"Last-Event-ID": "1"})
        frames = self.read_frames(response, lambda f: f.get("id") == str(LAST_SEQ))
        self.assertEqual([int(f["id"]) for f in frames], [1441, 1442, 1443])

    def test_cursor_beyond_the_head_replays_from_the_head(self) -> None:
        # Fresh scenario: head is FIRST_SEQ - 1; a cursor far ahead is unknown.
        response = self.open_stream(f"{CITY_PATH}/events/stream?scenario=stream-drop&after_seq=999999")
        frames = self.read_frames(response, lambda f: f.get("id") == str(FIRST_SEQ))
        self.assertEqual(frames[0]["id"], str(FIRST_SEQ))

    def test_no_cursor_starts_at_the_head_then_heartbeats(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        response = self.open_stream(f"{CITY_PATH}/events/stream")
        frames = self.read_frames(response, lambda f: f.get("event") == "heartbeat")
        self.assertEqual(len(frames), 1)
        self.assertEqual(frames[0]["event"], "heartbeat")
        self.assertNotIn("id", frames[0])
        self.assertRegex(frames[0]["data"]["timestamp"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")

    def test_stream_drop_closes_early_and_resume_completes_the_log(self) -> None:
        response = self.open_stream(f"{CITY_PATH}/events/stream?scenario=stream-drop&after_seq={FIRST_SEQ - 1}")
        frames = self.read_frames(response, lambda f: False)
        self.assertEqual(len(frames), DROP_AFTER)
        self.assertEqual(response.readline(), b"")
        last = frames[-1]["id"]
        self.assertEqual(last, str(FIRST_SEQ + DROP_AFTER - 1))
        response = self.open_stream(f"{CITY_PATH}/events/stream?scenario=stream-drop", {"Last-Event-ID": last})
        rest = self.read_frames(response, lambda f: f.get("id") == str(LAST_SEQ))
        self.assertEqual([int(f["id"]) for f in rest], list(range(int(last) + 1, LAST_SEQ + 1)))

    def test_sling_with_header_appends_bead_updates_to_the_stream(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        status, headers, body = self.request(
            "POST", f"{CITY_PATH}/sling", {"X-GC-Request": "1"},
            {"target": "ocproof/gastown.polecat", "bead": "oc-loy", "merge": "local"},
        )
        self.assertEqual(status, 200)
        self.assertEqual(body["status"], "slung")
        self.assertEqual(body["bead"], "oc-loy")
        self.assertEqual(body["mode"], "direct")
        self.assertIn("dashboard_url", body)
        self.assertEqual(headers["Location"], f"{CITY_PATH}/runs")
        response = self.open_stream(f"{CITY_PATH}/events/stream", {"Last-Event-ID": str(LAST_SEQ)})
        frames = self.read_frames(response, lambda f: f.get("id") == str(LAST_SEQ + 2))
        self.assertEqual([f["data"]["type"] for f in frames], ["bead.updated", "bead.updated"])
        beads = [f["data"]["payload"]["bead"] for f in frames]
        self.assertEqual([b["status"] for b in beads], ["open", "in_progress"])
        self.assertEqual(self.get_json(f"{CITY_PATH}/bead/oc-loy")["status"], "in_progress")

    def test_bead_create_answers_201_and_appends_bead_created(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        status, _, body = self.request("POST", f"{CITY_PATH}/beads", {"X-GC-Request": "1"}, {"rig": "ocproof"})
        self.assertEqual(status, 400)
        status, headers, body = self.request(
            "POST", f"{CITY_PATH}/beads", {"X-GC-Request": "1"},
            {"title": "Add a docstring", "rig": "ocproof", "type": "task", "priority": 2, "labels": ["opencode-mobile"]},
        )
        self.assertEqual(status, 201)
        self.assertEqual(body["status"], "open")
        self.assertEqual(body["title"], "Add a docstring")
        self.assertEqual(body["rig"], "ocproof")
        self.assertTrue(body["id"].startswith("fx-"))
        self.assertEqual(headers["Location"], f"{CITY_PATH}/bead/{body['id']}")
        response = self.open_stream(f"{CITY_PATH}/events/stream", {"Last-Event-ID": str(LAST_SEQ)})
        frames = self.read_frames(response, lambda f: f.get("id") == str(LAST_SEQ + 1))
        self.assertEqual([f["data"]["type"] for f in frames], ["bead.created"])
        self.assertEqual(frames[0]["data"]["payload"]["bead"]["id"], body["id"])
        self.assertEqual(self.get_json(f"{CITY_PATH}/bead/{body['id']}")["title"], "Add a docstring")


class ScenarioTest(FixtureCase):
    def test_blocked_bead_and_pending_choice(self) -> None:
        self.assertEqual(self.get_json(f"{CITY_PATH}/pending?scenario=blocked")["total"], 0)
        frames = self.stream_to_end("blocked", fx.BRANCH_SEQ + 1)
        last = frames[-1]["data"]
        self.assertEqual(last["type"], "bead.updated")
        self.assertTrue(last["payload"]["bead"]["is_blocked"])
        bead = self.get_json(f"{CITY_PATH}/bead/oc-loy?scenario=blocked")
        self.assertTrue(bead["is_blocked"])
        self.assertEqual(bead["status"], "in_progress")
        pending = self.get_json(f"{CITY_PATH}/pending?scenario=blocked")
        self.assertEqual(pending["total"], 1)
        item = pending["items"][0]
        self.assertEqual(item["kind"], "choice")
        self.assertEqual(item["session_id"], bead["metadata"]["gc.session_id"])
        self.assertTrue(item["prompt"])
        self.assertGreaterEqual(len(item["options"]), 2)

    def test_failed_bead_and_run(self) -> None:
        self.assertEqual(self.get_json(f"{CITY_PATH}/runs?scenario=failed")["runs"], [])
        frames = self.stream_to_end("failed", fx.BRANCH_SEQ + 1)
        last = frames[-1]["data"]
        self.assertEqual((last["type"], last["payload"]["bead"]["status"]), ("bead.updated", "failed"))
        bead = self.get_json(f"{CITY_PATH}/bead/oc-loy?scenario=failed")
        self.assertEqual(bead["status"], "failed")
        self.assertTrue(bead["metadata"]["last_error"])
        runs = self.get_json(f"{CITY_PATH}/runs?scenario=failed")
        self.assertEqual(runs["status_counts"]["failed"], 1)
        run = runs["runs"][0]
        self.assertEqual((run["run_id"], run["status"]), ("oc-loy", "failed"))
        self.assertEqual(run["last_error"]["code"], "fail")
        self.assertTrue(run["last_error"]["message"])

    def test_normal_scenario_is_not_affected_by_the_others(self) -> None:
        self.stream_to_end("failed", fx.BRANCH_SEQ + 1)
        self.assertEqual(self.get_json(f"{CITY_PATH}/bead/oc-loy")["status"], "open")
        self.assertEqual(self.get_json(f"{CITY_PATH}/runs")["partial"], True)


class SessionStreamTest(FixtureCase):
    def test_transcript_replay_with_cursor_and_heartbeat(self) -> None:
        response = self.open_stream(f"{CITY_PATH}/session/bl-5qc/stream")
        frames = self.read_frames(response, lambda f: f.get("event") == "heartbeat")
        turns = [f for f in frames if f["event"] == "turn"]
        self.assertEqual([f["id"] for f in turns], [str(i) for i in range(1, 18)])
        self.assertEqual(turns[0]["data"]["id"], "bl-5qc")
        self.assertIn("turns", turns[-1]["data"])
        self.assertEqual(frames[-1]["event"], "heartbeat")
        response = self.open_stream(f"{CITY_PATH}/session/bl-wisp-qqpj/stream", {"Last-Event-ID": "24"})
        frames = self.read_frames(response, lambda f: f.get("event") == "heartbeat")
        self.assertEqual([f["id"] for f in frames if f["event"] == "turn"], ["25", "26"])

    def test_unknown_and_finished_sessions_are_404(self) -> None:
        for session_id in ("zz-000", "bl-wn9"):
            status, headers, body = self.request("GET", f"{CITY_PATH}/session/{session_id}/stream")
            self.assertEqual((status, body["code"]), (404, "session-not-found"), session_id)
            self.assertEqual(headers["Content-Type"], "application/problem+json")
        self.assertEqual(self.open_stream(f"{CITY_PATH}/session/bl-48k/stream").status, 200)
        self.stream_to_end("normal", LAST_SEQ)
        status, _, body = self.request("GET", f"{CITY_PATH}/session/bl-48k/stream")
        self.assertEqual((status, body["code"]), (404, "session-not-found"))
        self.assertIn("no live output", body["detail"])


class MutationTest(FixtureCase):
    """The supervisor's write routes (TEAM-202), without front semantics."""

    HEADERS = {"X-GC-Request": "1"}

    def tail_after(self, last: int, stop) -> list[dict[str, Any]]:
        response = self.open_stream(f"{CITY_PATH}/events/stream", {"Last-Event-ID": str(last)})
        return self.read_frames(response, stop)

    def test_respond_is_202_then_pending_cleared_frame(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        status, headers, body = self.request(
            "POST", f"{CITY_PATH}/session/bl-wn9/respond", self.HEADERS,
            {"action": "replace", "request_id": "req-1"},
        )
        self.assertEqual(status, 202, body)
        self.assertEqual(body, {"status": "accepted", "id": "bl-wn9"})
        self.assertIn("X-GC-Request-Id", headers)
        frames = self.tail_after(LAST_SEQ, lambda f: f.get("event") == "pending_cleared")
        self.assertEqual(frames[-1]["data"]["request_id"], "req-1")
        self.assertNotIn("_frame", frames[-1]["data"])

    def test_message_is_202_with_request_id_then_request_result(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        status, _, body = self.request(
            "POST", f"{CITY_PATH}/session/bl-wn9/messages", self.HEADERS, {"message": "please continue"},
        )
        self.assertEqual(status, 202, body)
        self.assertEqual(body["status"], "accepted")
        self.assertTrue(body["request_id"].startswith("req-"))
        self.assertIn("event_cursor", body)
        frames = self.tail_after(LAST_SEQ, lambda f: f["data"].get("type", "").startswith("request."))
        result = frames[-1]["data"]
        self.assertEqual(result["type"], "request.result.session.message")
        self.assertEqual(result["payload"]["request_id"], body["request_id"])

    def test_failing_message_yields_request_failed(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        status, _, body = self.request(
            "POST", f"{CITY_PATH}/session/bl-wn9/messages", self.HEADERS, {"message": "fail: no"},
        )
        self.assertEqual(status, 202)
        frames = self.tail_after(LAST_SEQ, lambda f: f["data"].get("type", "").startswith("request."))
        result = frames[-1]["data"]
        self.assertEqual(result["type"], "request.failed")
        self.assertEqual(result["payload"]["request_id"], body["request_id"])
        self.assertEqual(result["payload"]["error_message"], "no")

    def test_session_lifecycle_and_unknown_session(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        for verb, event_type in (("stop", "session.stopped"), ("wake", "session.woke"), ("suspend", "session.suspended")):
            status, _, body = self.request("POST", f"{CITY_PATH}/session/bl-wn9/{verb}", self.HEADERS, {})
            self.assertEqual(status, 200, (verb, body))
            self.assertEqual(body["status"], "ok")
        frames = self.tail_after(LAST_SEQ, lambda f: f.get("id") == str(LAST_SEQ + 3))
        self.assertEqual([f["data"]["type"] for f in frames], ["session.stopped", "session.woke", "session.suspended"])
        status, _, body = self.request("POST", f"{CITY_PATH}/session/nope/stop", self.HEADERS, {})
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "session-not-found")
        status, _, body = self.request("POST", f"{CITY_PATH}/session/bl-wn9/messages", self.HEADERS, {"message": " "})
        self.assertEqual(status, 422)

    def test_run_cancel_convoy_close_and_agent_actions(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        status, _, body = self.request("POST", f"{CITY_PATH}/runs/oc-loy/cancel", self.HEADERS, {})
        self.assertEqual(status, 202, body)
        self.assertEqual(body["run_id"], "oc-loy")
        status, _, body = self.request("POST", f"{CITY_PATH}/convoy/oc-xru/close", self.HEADERS, {})
        self.assertEqual(status, 200, body)
        status, _, body = self.request("POST", f"{CITY_PATH}/agent/gastown.mayor/suspend", self.HEADERS, {})
        self.assertEqual(status, 200, body)
        status, _, body = self.request("POST", f"{CITY_PATH}/agent/gastown.mayor/explode", self.HEADERS, {})
        self.assertEqual(status, 422)
        status, _, body = self.request("POST", f"{CITY_PATH}/runs/none/cancel", self.HEADERS, {})
        self.assertEqual(status, 404)
        frames = self.tail_after(LAST_SEQ, lambda f: f.get("id") == str(LAST_SEQ + 2))
        self.assertEqual([f["data"]["type"] for f in frames], ["run.canceled", "convoy.closed"])
        self.assertEqual(frames[0]["data"]["payload"]["status"], "canceled")

    def test_mutations_need_the_identity_header(self) -> None:
        status, _, body = self.request("POST", f"{CITY_PATH}/session/bl-wn9/stop", {}, {})
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "forbidden")


class FrontModeTest(FixtureCase):
    """``--front``: the well-known document and receipts keyed by Idempotency-Key."""

    extra_args = ["--front"]

    def test_well_known_document(self) -> None:
        body = self.get_json(fx.WELL_KNOWN)
        self.assertEqual(body["provider"], "gascity")
        self.assertTrue(body["front"])
        self.assertEqual(body["city"], fx.CITY)
        self.assertEqual(body["supervisorUrl"], f"http://127.0.0.1:{self.port}")
        self.assertEqual(body["capabilities"], {"read": True, "control": True, "merge": False})
        self.assertEqual(body["identity"], {"login": fx.FRONT_LOGIN, "allowed": True})

    def test_accepted_receipt_and_replay(self) -> None:
        self.stream_to_end("normal", LAST_SEQ)
        headers = {"X-GC-Request": "1", "Idempotency-Key": "k-1"}
        status, response_headers, receipt = self.request(
            "POST", f"{CITY_PATH}/session/bl-wn9/messages", headers, {"message": "hi"},
        )
        self.assertEqual(status, 202, receipt)
        self.assertEqual(receipt["status"], "accepted")
        self.assertEqual(receipt["upstream_status"], 202)
        self.assertEqual(receipt["idempotency_key"], "k-1")
        self.assertTrue(receipt["body"]["request_id"].startswith("req-"))
        self.assertNotIn("Idempotent-Replayed", response_headers)
        status, response_headers, again = self.request(
            "POST", f"{CITY_PATH}/session/bl-wn9/messages", headers, {"message": "hi"},
        )
        self.assertEqual(status, 202)
        self.assertEqual(again, receipt)
        self.assertEqual(response_headers["Idempotent-Replayed"], "true")
        # One result event only: the replay never reached the supervisor.
        response = self.open_stream(f"{CITY_PATH}/events/stream", {"Last-Event-ID": str(LAST_SEQ)})
        frames = self.read_frames(response, lambda f: f.get("event") == "heartbeat")
        results = [f for f in frames if f.get("event") == "event" and f["data"]["type"].startswith("request.")]
        self.assertEqual(len(results), 1)

    def test_rejected_receipt_keeps_the_problem(self) -> None:
        status, _, receipt = self.request(
            "POST", f"{CITY_PATH}/session/nope/stop", {"X-GC-Request": "1", "Idempotency-Key": "k-2"}, {},
        )
        self.assertEqual(status, 404)
        self.assertEqual(receipt["status"], "rejected")
        self.assertEqual(receipt["body"]["code"], "session-not-found")

    def test_front_problems(self) -> None:
        status, _, body = self.request(
            "POST", f"{CITY_PATH}/session/upstream-down/stop", {"X-GC-Request": "1", "Idempotency-Key": "k-3"}, {},
        )
        self.assertEqual(status, 502)
        self.assertEqual(body["type"], f"{fx.FRONT_URN}:upstream-unavailable")
        status, _, body = self.request(
            "POST", f"{CITY_PATH}/session/bl-wn9/stop", {"X-GC-Request": "1", "Idempotency-Key": "mismatch-1"}, {},
        )
        self.assertEqual(status, 409)
        self.assertEqual(body["type"], f"{fx.FRONT_URN}:idempotency-mismatch")

    def test_result_delay_defers_the_result(self) -> None:
        self.server.result_delay = 0.5
        self.stream_to_end("normal", LAST_SEQ)
        status, _, receipt = self.request(
            "POST", f"{CITY_PATH}/session/bl-wn9/messages", {"X-GC-Request": "1", "Idempotency-Key": "k-4"}, {"message": "hi"},
        )
        self.assertEqual(status, 202)
        page = self.get_json(f"{CITY_PATH}/events?limit=1")
        self.assertNotEqual(page["items"][0]["type"], "request.result.session.message")
        response = self.open_stream(f"{CITY_PATH}/events/stream", {"Last-Event-ID": str(LAST_SEQ)})
        frames = self.read_frames(response, lambda f: f.get("event") == "event")
        self.assertEqual(frames[-1]["data"]["type"], "request.result.session.message")


class CliTest(unittest.TestCase):
    def test_defaults_and_scenario_flag(self) -> None:
        options = fx.parse_args([])
        self.assertEqual((options.host, options.heartbeat, options.pace), ("127.0.0.1", 15.0, 0.05))
        self.assertIn(options.scenario, fx.SCENARIOS)
        self.assertFalse(options.front)
        self.assertEqual(options.result_delay, 0.0)
        self.assertTrue(fx.parse_args(["--front", "--result-delay", "2"]).front)
        self.assertEqual(fx.parse_args(["--scenario", "stream-drop"]).scenario, "stream-drop")
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            fx.parse_args(["--scenario", "bogus"])


if __name__ == "__main__":
    unittest.main()
