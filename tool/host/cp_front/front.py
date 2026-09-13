#!/usr/bin/env python3
"""Control-plane front for the AI Team · Gas City plugin (TEAM-201).

Runs on the computer next to the Gas City supervisor, listens on the
computer's Tailscale address (plain HTTP, WireGuard already encrypts and
authenticates the hop) and proxies to the loopback supervisor.  Identity
comes from ``tailscale whois <peer-ip>`` per request:

* reads (GET/HEAD/OPTIONS) are allowed for allowlisted identities, or for
  any tailnet peer with ``--reads-any-peer``;
* mutations (POST/PUT/PATCH/DELETE) only for allowlisted identities, are
  forwarded with ``X-GC-Request`` and a rewritten ``Host``, and answer a
  receipt keyed by the client's ``Idempotency-Key`` (replays never reach
  the supervisor twice);
* SSE (``/events/stream``, ``/session/{id}/stream``) is passed through chunk
  by chunk with ``Last-Event-ID`` forwarded;
* the merge roles (TEAM-205) live here, over git on the host, since Gas City
  v0 has no merge-request API: ``GET .../front/merge-readiness/{run}``,
  ``POST .../front/mr/{bead}/approve`` and ``POST .../front/merge/{run}``
  (see README.md).  Never a force push, never a branch or worktree deletion;
* the read-only policy (TEAM-207): ``GET .../front/policy[?rig=NAME]``
  answers the rig's supervision level and boundary texts from the same
  per-rig config the merge roles use.

Standard library only.  Nothing here is public: the front refuses to bind
anything but a tailnet or loopback address and never uses Tailscale Funnel.
"""

from __future__ import annotations

import argparse
import ipaddress
import json
import logging
import os
import re
import select
import shlex
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import uuid
from datetime import datetime, timezone
from http.client import HTTPConnection, HTTPResponse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Callable
from urllib.parse import parse_qs, urlsplit

FRONT_NAME = "opencode-mobile-front"
FRONT_VERSION = "0.2.0"
WELL_KNOWN = "/.well-known/opencode-mobile-orchestration"
DEFAULT_PORT = 8373
DEFAULT_STATE_DIR = "~/.config/opencode-mobile-front"
DEFAULT_WHOIS_CMD = "tailscale whois --json"
WHOIS_TTL = 600.0
WHOIS_TIMEOUT = 8.0
# A whois that times out (or cannot run) reuses the peer's last resolved
# identity this long after it was resolved (TEAM-117); an IP never resolved
# still answers 403.
WHOIS_STALE_MAX = 3600.0
UPSTREAM_TIMEOUT = 30.0
STREAM_POLL = 1.0
RECEIPTS_FILE = "receipts.json"
MAX_RECEIPTS = 5000
MAX_BODY = 4 * 1024 * 1024
READ_METHODS = ("GET", "HEAD", "OPTIONS")
MUTATION_METHODS = ("POST", "PUT", "PATCH", "DELETE")
TAILNET_V4 = ipaddress.ip_network("100.64.0.0/10")
TAILNET_V6 = ipaddress.ip_network("fd7a:115c:a1e0::/48")
# Headers that describe the hop, not the message; never forwarded (RFC 7230
# §6.1) plus the client's credentials, which the supervisor must never see.
HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailer", "transfer-encoding", "upgrade",
}
NEVER_FORWARD = HOP_BY_HOP | {"authorization", "cookie", "host", "content-length", "x-gc-request", "idempotency-key"}
NEVER_RETURN = HOP_BY_HOP | {"set-cookie", "content-length"}
# Merge roles (TEAM-205): routes the front answers itself.
FRONT_ROUTE = re.compile(r"^/v0/city/([^/]+)/front/(?:(merge-readiness|mr|merge)/([^/]+)(/approve)?|(policy))$")
RIGS_DIR = "rigs"
TMP_DIR = "tmp"
CHECKS_FILE = "merge-checks.json"
GIT_TIMEOUT = 60.0
DEFAULT_CHECK_TIMEOUT = 600
MERGE_CAPABILITY_TTL = 60.0
MAX_CHANGES = 200
DETAIL_LIMIT = 200
BOUNDARY_TEXT = {
    "require_approval": "Never merge without approval",
    "require_tests": "Require tests before merge",
}
# Supervision levels a rig config may name (TEAM-207); anything else is
# reported as the default so the phone never shows an unknown word.
SUPERVISION_LEVELS = ("high", "balanced", "autonomous")
DEFAULT_SUPERVISION = "balanced"
CONFLICT_CODES = {"UU", "AA", "DU", "UD", "AU", "UA", "DD"}
PASSED_WORDS = {"passed", "pass", "ok", "success", "true"}
FAILED_WORDS = {"failed", "fail", "error", "false"}

log = logging.getLogger("front")


class ConfigError(Exception):
    """A startup check failed; the message is printed and the front exits 2."""


class UpstreamDown(Exception):
    """The supervisor did not answer; nothing is stored for the request."""


class MergeError(Exception):
    """A merge-role request that ends in a problem+json answer."""

    def __init__(self, status: int, code: str, detail: str, **extra: Any) -> None:
        super().__init__(detail)
        self.status = status
        self.code = code
        self.detail = detail
        self.extra = extra

    def problem(self) -> dict[str, Any]:
        """The problem body, plus any extra fields (``line``, ``boundary``)."""
        titles = {404: "Not Found", 403: "Forbidden", 409: "Conflict", 422: "Unprocessable Entity", 500: "Internal Server Error"}
        body = problem(self.status, self.code, titles.get(self.status, f"HTTP {self.status}"), self.detail)
        body.update(self.extra)
        return body


# -- small helpers -----------------------------------------------------------


def is_local_bind(address: str) -> bool:
    """True for loopback and Tailscale (CGNAT / ULA) addresses; false otherwise."""
    try:
        ip = ipaddress.ip_address(address)
    except ValueError:
        return False
    return ip.is_loopback or ip in TAILNET_V4 or ip in TAILNET_V6


def problem(status: int, code: str, title: str, detail: str) -> dict[str, Any]:
    """A problem+json body in the supervisor's ErrorModel shape."""
    return {
        "type": f"urn:opencode-mobile:front:{code}",
        "title": title,
        "status": status,
        "detail": detail,
        "code": code,
    }


def is_sse(headers: dict[str, str]) -> bool:
    """True when an upstream response is a server-sent event stream."""
    return headers.get("content-type", "").split(";")[0].strip() == "text/event-stream"


def decode_body(raw: bytes, content_type: str) -> Any:
    """JSON-decode a response body when it claims JSON, else return text."""
    if "json" in content_type:
        try:
            return json.loads(raw) if raw else None
        except json.JSONDecodeError:
            pass
    return raw.decode("utf-8", "replace")


# -- identity ----------------------------------------------------------------


class Identity:
    """What ``tailscale whois`` said about one peer."""

    def __init__(self, login: str | None, tags: list[str], on_tailnet: bool) -> None:
        self.login = login
        self.tags = tags
        self.on_tailnet = on_tailnet

    @classmethod
    def unknown(cls) -> "Identity":
        """A peer whois could not resolve (not on the tailnet, or whois failed)."""
        return cls(None, [], False)

    @classmethod
    def from_whois(cls, doc: dict[str, Any]) -> "Identity":
        """Parse ``tailscale whois --json`` output."""
        login = (doc.get("UserProfile") or {}).get("LoginName") or None
        tags = list((doc.get("Node") or {}).get("Tags") or [])
        return cls(login, tags, True)


class Whois:
    """Resolve peer IPs to tailnet identities through a subprocess, cached.

    Answers are cached for ``ttl`` seconds, misses too.  When the subprocess
    times out or cannot run, the peer's last resolved identity is reused as
    long as it is under ``stale_max`` seconds old, so one slow ``tailscale
    whois`` never turns a known phone into a 403 (TEAM-117).  Only an IP
    the front never resolved answers as not on the tailnet.
    """

    def __init__(self, command: str, ttl: float = WHOIS_TTL, stale_max: float = WHOIS_STALE_MAX) -> None:
        self.argv = shlex.split(command)
        self.ttl = ttl
        self.stale_max = stale_max
        self.cache: dict[str, tuple[float, Identity]] = {}
        # Last identity whois resolved per IP, with when: (monotonic, identity).
        self.known: dict[str, tuple[float, Identity]] = {}
        self.lock = threading.Lock()

    def lookup(self, ip: str) -> Identity:
        """Identity for ``ip``; cached for ``ttl`` seconds (misses too)."""
        now = time.monotonic()
        with self.lock:
            hit = self.cache.get(ip)
            if hit and hit[0] > now:
                return hit[1]
        identity = self._run(ip)
        expires = now + self.ttl
        with self.lock:
            if identity is None:
                known = self.known.get(ip)
                if known is not None and now - known[0] <= self.stale_max:
                    log.warning("whois timeout for %s; using cached identity", ip)
                    identity = known[1]
                    # Never keep a reused answer past the hour it is good for.
                    expires = min(expires, known[0] + self.stale_max)
                else:
                    identity = Identity.unknown()
            elif identity.on_tailnet:
                self.known[ip] = (now, identity)
            else:
                # whois answered: the peer is not on the tailnet (any more).
                self.known.pop(ip, None)
            self.cache[ip] = (expires, identity)
        return identity

    def _run(self, ip: str) -> Identity | None:
        """What whois says; ``None`` when it timed out or could not run."""
        try:
            done = subprocess.run(self.argv + [ip], capture_output=True, timeout=WHOIS_TIMEOUT, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            log.warning("whois failed for %s: %s", ip, type(exc).__name__)
            return None
        if done.returncode != 0:
            return Identity.unknown()
        try:
            doc = json.loads(done.stdout)
        except json.JSONDecodeError:
            log.warning("whois returned non-JSON for %s", ip)
            return Identity.unknown()
        return Identity.from_whois(doc) if isinstance(doc, dict) else Identity.unknown()


class Policy:
    """Who may read and who may write."""

    def __init__(self, logins: list[str], tags: list[str], reads_any_peer: bool, insecure: bool) -> None:
        self.logins = {login.strip().lower() for login in logins if login.strip()}
        self.tags = {tag.strip() for tag in tags if tag.strip()}
        self.reads_any_peer = reads_any_peer
        self.insecure = insecure

    def empty(self) -> bool:
        """True when nobody is allowlisted."""
        return not self.logins and not self.tags

    def allowed(self, identity: Identity) -> bool:
        """Allowlisted (may write)."""
        if self.insecure:
            return True
        if identity.login and identity.login.lower() in self.logins:
            return True
        return any(tag in self.tags for tag in identity.tags)

    def may_read(self, identity: Identity) -> bool:
        """May read: allowlisted, or any tailnet peer with --reads-any-peer."""
        return self.allowed(identity) or (self.reads_any_peer and identity.on_tailnet)

    def on_tailnet(self, identity: Identity) -> bool:
        """May see unauthenticated routes such as the well-known document."""
        return self.insecure or identity.on_tailnet


# -- idempotency store -------------------------------------------------------


class ReceiptStore:
    """``Idempotency-Key -> receipt`` persisted as one fsynced JSON file."""

    def __init__(self, state_dir: Path) -> None:
        self.path = state_dir / RECEIPTS_FILE
        self.lock = threading.Lock()
        self.key_locks: dict[str, threading.Lock] = {}
        self.records: dict[str, dict[str, Any]] = self._load()

    def _load(self) -> dict[str, dict[str, Any]]:
        try:
            with self.path.open(encoding="utf-8") as handle:
                data = json.load(handle)
        except FileNotFoundError:
            return {}
        except (OSError, json.JSONDecodeError) as exc:
            log.warning("receipt store unreadable, starting empty: %s", type(exc).__name__)
            return {}
        return data if isinstance(data, dict) else {}

    def key_lock(self, key: str) -> threading.Lock:
        """One lock per key so a concurrent duplicate waits for the receipt."""
        with self.lock:
            return self.key_locks.setdefault(key, threading.Lock())

    def get(self, key: str) -> dict[str, Any] | None:
        """The stored record for ``key`` or None."""
        with self.lock:
            return self.records.get(key)

    def put(self, key: str, record: dict[str, Any]) -> None:
        """Store ``record`` under ``key`` and fsync the file."""
        with self.lock:
            self.records[key] = record
            self._prune()
            self._write()

    def _prune(self) -> None:
        if len(self.records) <= MAX_RECEIPTS:
            return
        oldest = sorted(self.records, key=lambda k: self.records[k].get("ts", 0))
        for key in oldest[: len(self.records) - MAX_RECEIPTS]:
            del self.records[key]

    def _write(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        with tmp.open("w", encoding="utf-8") as handle:
            json.dump(self.records, handle)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, self.path)


def receipt_of(record: dict[str, Any]) -> dict[str, Any]:
    """The client-facing receipt (identity and timestamps stay in the store)."""
    return {
        "request_id": record["request_id"],
        "status": record["status"],
        "upstream_status": record["upstream_status"],
        "body": record["body"],
        "idempotency_key": record["idempotency_key"],
    }


# -- upstream ----------------------------------------------------------------


class Upstream:
    """The loopback supervisor."""

    def __init__(self, url: str) -> None:
        parts = urlsplit(url)
        if parts.scheme != "http" or not parts.hostname:
            raise ConfigError(f"--supervisor must be an http:// URL, got {url!r}")
        self.host = parts.hostname
        self.port = parts.port or 80
        self.prefix = parts.path.rstrip("/")
        self.url = f"http://{self.host}:{self.port}{self.prefix}"

    def connect(self, timeout: float = UPSTREAM_TIMEOUT) -> HTTPConnection:
        """A fresh connection (one per proxied request; streams hold theirs)."""
        return HTTPConnection(self.host, self.port, timeout=timeout)

    def get_json(self, path: str) -> Any:
        """One GET, JSON-decoded; raises ConfigError when it fails."""
        conn = self.connect(timeout=5.0)
        try:
            conn.request("GET", self.prefix + path, headers={"Connection": "close"})
            response = conn.getresponse()
            raw = response.read()
        except OSError as exc:
            raise ConfigError(f"supervisor {self.url} did not answer {path}: {exc}") from exc
        finally:
            conn.close()
        if response.status != 200:
            raise ConfigError(f"supervisor {self.url}{path} answered {response.status}")
        try:
            return json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ConfigError(f"supervisor {self.url}{path} did not return JSON") from exc

    def call(self, method: str, path: str, body: Any = None) -> tuple[int, Any]:
        """One request the front makes on its own behalf (merge roles).

        Returns ``(status, decoded body)``; raises :class:`UpstreamDown` when
        the supervisor does not answer.  Mutations carry ``X-GC-Request``."""
        payload = json.dumps(body).encode("utf-8") if body is not None else None
        headers = {"Connection": "close", "X-GC-Request": FRONT_NAME}
        if payload is not None:
            headers["Content-Type"] = "application/json"
            headers["Content-Length"] = str(len(payload))
        conn = self.connect()
        try:
            conn.request(method, self.prefix + path, body=payload, headers=headers)
            response = conn.getresponse()
            raw = response.read()
        except OSError as exc:
            raise UpstreamDown(f"{method} {path}: {type(exc).__name__}") from exc
        finally:
            conn.close()
        return response.status, decode_body(raw, response.getheader("Content-Type", ""))

    def get(self, path: str) -> Any:
        """A GET that must succeed; a non-200 answer is a MergeError 502."""
        status, body = self.call("GET", path)
        if status != 200:
            raise MergeError(502, "upstream-error", f"supervisor answered {status} for {path}")
        return body


def first_running_city(cities: Any) -> str | None:
    """Name of the first running city in a ``/v0/cities`` document."""
    items = cities.get("items") if isinstance(cities, dict) else None
    for item in items or []:
        if isinstance(item, dict) and item.get("running") and item.get("name"):
            return str(item["name"])
    return None


# -- merge roles (TEAM-205) --------------------------------------------------


def as_dict(value: Any) -> dict[str, Any]:
    """``value`` when it is a dict, else an empty dict."""
    return value if isinstance(value, dict) else {}


def as_list(value: Any) -> list[Any]:
    """``value`` when it is a list, else an empty list."""
    return value if isinstance(value, list) else []


def text_of(value: Any) -> str:
    """A stripped string, or "" for anything else."""
    return value.strip() if isinstance(value, str) else ""


def bead_meta(bead: dict[str, Any], key: str) -> str:
    """One metadata string of a bead ("" when absent)."""
    return text_of(as_dict(bead.get("metadata")).get(key))


def bead_labels(bead: dict[str, Any]) -> set[str]:
    return {text_of(label) for label in as_list(bead.get("labels")) if text_of(label)}


def bead_closed(bead: dict[str, Any]) -> bool:
    return text_of(bead.get("status")).lower() == "closed"


def bead_approved_by(bead: dict[str, Any]) -> str:
    return bead_meta(bead, "review.approved_by")


def bead_validation(bead: dict[str, Any]) -> bool | None:
    """True/False for a reported validation result, None when not reported."""
    metadata = as_dict(bead.get("metadata"))
    raw = metadata.get("validation") or metadata.get("validation_result") or metadata.get("gc.validation")
    if isinstance(raw, str):
        stripped = raw.strip()
        if stripped.startswith("{"):
            try:
                raw = json.loads(stripped)
            except json.JSONDecodeError:
                return None
        else:
            lower = stripped.lower()
            return True if lower in PASSED_WORDS else False if lower in FAILED_WORDS else None
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, dict):
        if isinstance(raw.get("passed"), bool):
            return raw["passed"]
        word = (text_of(raw.get("status")) or text_of(raw.get("result"))).lower()
        return True if word in PASSED_WORDS else False if word in FAILED_WORDS else None
    return None


def rig_of_identity(identity: str) -> str:
    """The rig prefix of ``rig/agent`` identities ("" when there is none)."""
    slash = identity.find("/")
    return identity[:slash] if slash > 0 else ""


def clip(text: str, limit: int = DETAIL_LIMIT) -> str:
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def last_line(*outputs: bytes) -> str:
    """The last non-empty line of the first output that has one."""
    for output in outputs:
        lines = [line for line in output.decode("utf-8", "replace").splitlines() if line.strip()]
        if lines:
            return lines[-1].strip()
    return ""


class RigConfig:
    """``<state_dir>/rigs/<rig>.json``: merge checks, boundaries and supervision."""

    def __init__(self, checks: list[tuple[str, str]], require_approval: bool, require_tests: bool,
                 allowed_logins: list[str] | None, check_timeout: int,
                 supervision: str = DEFAULT_SUPERVISION, extra_boundaries: list[str] | None = None) -> None:
        self.checks = checks
        self.require_approval = require_approval
        self.require_tests = require_tests
        self.allowed_logins = allowed_logins
        self.check_timeout = check_timeout
        self.supervision = supervision
        self.extra_boundaries = extra_boundaries or []

    def policy(self, rig: str) -> dict[str, Any]:
        """The read-only policy document (TEAM-207): supervision level and boundary texts."""
        boundaries: list[dict[str, str]] = []
        if self.require_approval:
            boundaries.append({"key": "require_approval", "text": BOUNDARY_TEXT["require_approval"]})
        if self.require_tests:
            boundaries.append({"key": "require_tests", "text": BOUNDARY_TEXT["require_tests"]})
        if self.allowed_logins is not None:
            boundaries.append({"key": "allowed_logins", "text": f"Only {', '.join(self.allowed_logins)} may merge"})
        for index, text in enumerate(self.extra_boundaries, start=1):
            boundaries.append({"key": f"extra-{index}", "text": text})
        return {"rig": rig, "supervision": self.supervision, "boundaries": boundaries}

    @classmethod
    def load(cls, state_dir: Path, rig: str) -> "RigConfig":
        """The rig's config; defaults when the file is missing or malformed."""
        doc: dict[str, Any] = {}
        path = state_dir / RIGS_DIR / f"{rig}.json"
        try:
            if rig:
                doc = as_dict(json.loads(path.read_text(encoding="utf-8")))
        except FileNotFoundError:
            pass
        except (OSError, json.JSONDecodeError) as exc:
            log.warning("rig config %s unreadable, using defaults: %s", path.name, type(exc).__name__)
        checks: list[tuple[str, str]] = []
        for index, item in enumerate(as_list(doc.get("merge_checks")), start=1):
            if isinstance(item, str) and item.strip():
                checks.append((f"check-{index}", item.strip()))
            elif isinstance(item, dict) and text_of(item.get("command")):
                checks.append((text_of(item.get("key")) or f"check-{index}", text_of(item.get("command"))))
        boundaries = as_dict(doc.get("boundaries"))
        logins = boundaries.get("allowed_logins")
        allowed = [text_of(x).lower() for x in as_list(logins) if text_of(x)] if isinstance(logins, list) else None
        timeout = doc.get("check_timeout_sec")
        supervision = text_of(doc.get("supervision")).lower()
        if supervision not in SUPERVISION_LEVELS:
            if supervision:
                log.warning("rig config %s names supervision %r; using %s", path.name, supervision, DEFAULT_SUPERVISION)
            supervision = DEFAULT_SUPERVISION
        extra = [text_of(x) for x in as_list(boundaries.get("extra")) if text_of(x)]
        return cls(
            checks=checks,
            require_approval=boundaries.get("require_approval") is not False,
            require_tests=bool(boundaries.get("require_tests", bool(checks))),
            allowed_logins=allowed,
            check_timeout=int(timeout) if isinstance(timeout, (int, float)) and timeout > 0 else DEFAULT_CHECK_TIMEOUT,
            supervision=supervision,
            extra_boundaries=extra,
        )


class Git:
    """Runs git and records every argv (tests assert nothing forbidden ran)."""

    def __init__(self, executable: str, calls: list[list[str]]) -> None:
        self.executable = executable
        self.calls = calls
        self.lock = threading.Lock()

    def run(self, args: list[str], cwd: str | Path | None = None, env: dict[str, str] | None = None,
            check: bool = True, timeout: float = GIT_TIMEOUT) -> subprocess.CompletedProcess[bytes]:
        argv = [self.executable, *args]
        with self.lock:
            self.calls.append(list(argv))
        full_env = {**os.environ, "GIT_TERMINAL_PROMPT": "0", **(env or {})}
        try:
            done = subprocess.run(argv, cwd=cwd, env=full_env, capture_output=True, timeout=timeout, check=False)
        except FileNotFoundError as exc:
            raise MergeError(422, "merge-unavailable", f"git is not available on the host ({self.executable})") from exc
        except subprocess.TimeoutExpired as exc:
            raise MergeError(500, "merge-failed", f"git {args[0]} timed out after {int(timeout)} s") from exc
        if check and done.returncode != 0:
            raise MergeError(500, "merge-failed", clip(f"git {' '.join(args[:2])}: {last_line(done.stderr, done.stdout) or f'exit {done.returncode}'}"))
        return done

    def out(self, args: list[str], cwd: str | Path | None = None, check: bool = True) -> str:
        return self.run(args, cwd=cwd, check=check).stdout.decode("utf-8", "replace").strip()

    def available(self) -> bool:
        try:
            return self.run(["--version"], check=False).returncode == 0
        except MergeError:
            return False


class CheckRunner:
    """Runs a rig's merge checks in a temp clone, once per merged tree."""

    def __init__(self, state_dir: Path) -> None:
        self.path = state_dir / CHECKS_FILE
        self.lock = threading.Lock()
        self.running: set[str] = set()
        self.results: dict[str, dict[str, Any]] = self._load()

    def _load(self) -> dict[str, dict[str, Any]]:
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}
        return data if isinstance(data, dict) else {}

    def cached(self, rig: str, tree: str) -> dict[str, Any] | None:
        with self.lock:
            return self.results.get(f"{rig}:{tree}")

    def is_running(self, rig: str, tree: str) -> bool:
        with self.lock:
            return f"{rig}:{tree}" in self.running

    def start(self, rig: str, tree: str, clone: Path, config: RigConfig) -> bool:
        """Start the checks for ``tree`` in ``clone`` (owned from now on); False when already running."""
        key = f"{rig}:{tree}"
        with self.lock:
            if key in self.running or key in self.results:
                return False
            self.running.add(key)
        threading.Thread(target=self._run, args=(key, clone, config), daemon=True).start()
        return True

    def _run(self, key: str, clone: Path, config: RigConfig) -> None:
        results: dict[str, Any] = {}
        try:
            for name, command in config.checks:
                results[name] = self._one(command, clone, config.check_timeout)
        finally:
            shutil.rmtree(clone, ignore_errors=True)
            with self.lock:
                self.running.discard(key)
                self.results[key] = results
                self._write()

    @staticmethod
    def _one(command: str, clone: Path, timeout: int) -> dict[str, Any]:
        try:
            done = subprocess.run(command, shell=True, cwd=clone, capture_output=True, timeout=timeout, check=False)
        except subprocess.TimeoutExpired:
            return {"ok": False, "detail": f"timed out after {timeout} s", "ts": time.time()}
        if done.returncode == 0:
            return {"ok": True, "detail": "passed", "ts": time.time()}
        return {"ok": False, "detail": clip(f"exit {done.returncode}: {last_line(done.stderr, done.stdout)}"), "ts": time.time()}

    def _write(self) -> None:
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.path.with_suffix(".tmp")
            tmp.write_text(json.dumps(self.results), encoding="utf-8")
            os.replace(tmp, self.path)
        except OSError as exc:
            log.warning("check cache not written: %s", type(exc).__name__)


class Candidate:
    """What git said about merging a run's branches into the target."""

    def __init__(self) -> None:
        self.conflict: str | None = None
        self.merge_commit: str | None = None
        self.tree: str | None = None
        self.files = 0
        self.additions = 0
        self.deletions = 0
        self.changes: list[dict[str, Any]] = []
        self.clone: Path | None = None
        self.fast_forward = False


class MergeService:
    """Readiness, approval and merge over git on the host (README.md)."""

    def __init__(self, upstream: Upstream, git: Git, state_dir: Path) -> None:
        self.upstream = upstream
        self.git = git
        self.state_dir = state_dir
        self.checks = CheckRunner(state_dir)
        self.cache: dict[tuple[str, str], Candidate] = {}
        self.capability: dict[str, tuple[float, bool]] = {}
        self.lock = threading.Lock()

    # -- run resolution --------------------------------------------------

    def _run(self, city: str, run_id: str) -> tuple[dict[str, Any], list[str]]:
        """The convoy bead (or a stand-in for a formula run) and its tracked ids."""
        convoys = as_list(as_dict(self.upstream.get(f"/v0/city/{city}/convoys")).get("items"))
        for convoy in convoys:
            if isinstance(convoy, dict) and convoy.get("id") == run_id:
                tracked = [
                    text_of(dep.get("depends_on_id"))
                    for dep in as_list(convoy.get("dependencies"))
                    if isinstance(dep, dict) and dep.get("type") == "tracks" and text_of(dep.get("depends_on_id"))
                ]
                return convoy, tracked
        runs = as_list(as_dict(self.upstream.get(f"/v0/city/{city}/runs")).get("runs"))
        for run in runs:
            if isinstance(run, dict) and run.get("run_id") == run_id:
                beads = as_list(as_dict(self.upstream.get(f"/v0/city/{city}/beads")).get("items"))
                tracked = [
                    text_of(bead.get("id")) for bead in beads
                    if isinstance(bead, dict) and run_id in (bead_meta(bead, "run_id"), bead_meta(bead, "gc.run_id"))
                ]
                stand_in = {"id": run_id, "title": text_of(run.get("title")) or run_id, "status": text_of(run.get("status")),
                            "metadata": {"rig": text_of(as_dict(run.get("scope")).get("ref")) if as_dict(run.get("scope")).get("kind") == "rig" else ""}}
                return stand_in, tracked
        raise MergeError(404, "run-not-found", f"no convoy or run {run_id} in city {city}")

    def _beads(self, city: str, ids: list[str]) -> list[dict[str, Any]]:
        beads = []
        for bead_id in ids:
            status, body = self.upstream.call("GET", f"/v0/city/{city}/bead/{bead_id}")
            if status == 404:
                log.info("tracked bead %s is gone; skipped", bead_id)
                continue
            if status != 200 or not isinstance(body, dict):
                raise MergeError(502, "upstream-error", f"supervisor answered {status} for bead {bead_id}")
            beads.append(body)
        return beads

    def _merge_request(self, city: str, convoy: dict[str, Any], tracked: list[str]) -> dict[str, Any]:
        """The merge-request bead that references the run, else the convoy bead."""
        wanted = {convoy.get("id"), *tracked}
        for bead in as_list(as_dict(self.upstream.get(f"/v0/city/{city}/beads")).get("items")):
            if not isinstance(bead, dict) or bead.get("issue_type") != "merge-request":
                continue
            refs = {dep.get("depends_on_id") for dep in as_list(bead.get("dependencies")) if isinstance(dep, dict)}
            refs |= {dep.get("issue_id") for dep in as_list(bead.get("dependencies")) if isinstance(dep, dict)}
            if refs & wanted or bead.get("parent") == convoy.get("id"):
                return bead
        return convoy

    @staticmethod
    def _rig_name(convoy: dict[str, Any], beads: list[dict[str, Any]]) -> str:
        for bead in (convoy, *beads):
            if bead_meta(bead, "rig"):
                return bead_meta(bead, "rig")
        for bead in beads:
            rig = rig_of_identity(text_of(bead.get("assignee"))) or rig_of_identity(bead_meta(bead, "gc.routed_to"))
            if rig:
                return rig
        raise MergeError(422, "merge-unavailable", "the run names no rig")

    def _rig(self, city: str, name: str) -> tuple[str, str]:
        """``(path, default_branch)`` of a rig; the branch may be ""."""
        if "/" in name or name in ("", ".", ".."):
            raise MergeError(422, "merge-unavailable", f"rig name {name!r} is not usable")
        status, body = self.upstream.call("GET", f"/v0/city/{city}/rig/{name}")
        if status == 200 and isinstance(body, dict) and text_of(body.get("path")):
            return text_of(body.get("path")), text_of(body.get("default_branch"))
        for rig in as_list(as_dict(self.upstream.get(f"/v0/city/{city}/status")).get("rig_details")):
            if isinstance(rig, dict) and rig.get("name") == name and text_of(rig.get("path")):
                return text_of(rig.get("path")), text_of(rig.get("default_branch"))
        raise MergeError(422, "merge-unavailable", f"rig {name} has no path on the host")

    # -- git -------------------------------------------------------------

    def _origin(self, rig_path: str) -> str:
        if not Path(rig_path).is_dir():
            raise MergeError(422, "merge-unavailable", f"rig path {rig_path} does not exist")
        done = self.git.run(["-C", rig_path, "remote", "get-url", "origin"], check=False)
        url = done.stdout.decode("utf-8", "replace").strip()
        if done.returncode != 0 or not url:
            raise MergeError(422, "merge-unavailable", "the rig has no origin remote")
        return url

    def _heads(self, rig_path: str) -> dict[str, str]:
        out = self.git.out(["-C", rig_path, "ls-remote", "--heads", "origin"])
        heads = {}
        for line in out.splitlines():
            sha, _, ref = line.partition("\t")
            if ref.startswith("refs/heads/"):
                heads[ref[len("refs/heads/"):]] = sha
        return heads

    def _target(self, rig_path: str, heads: dict[str, str], beads: list[dict[str, Any]], default_branch: str) -> str:
        for bead in beads:
            if bead_meta(bead, "target"):
                return bead_meta(bead, "target")
        if default_branch:
            return default_branch
        head = self.git.run(["-C", rig_path, "symbolic-ref", "--short", "refs/remotes/origin/HEAD"], check=False)
        name = head.stdout.decode("utf-8", "replace").strip()
        if head.returncode == 0 and name:
            return name[len("origin/"):] if name.startswith("origin/") else name
        for candidate in ("main", "master"):
            if candidate in heads:
                return candidate
        raise MergeError(422, "merge-unavailable", "the rig has no default branch")

    def default_branch_of(self, rig_path: str, default_branch: str) -> str | None:
        """For the well-known document: the resolvable default branch or None."""
        try:
            self._origin(rig_path)
            return self._target(rig_path, self._heads(rig_path), [], default_branch)
        except MergeError:
            return None

    def _build(self, rig_path: str, origin: str, target: str, branches: list[tuple[str, dict[str, Any]]], login: str) -> Candidate:
        """Merge ``branches`` onto origin/target in a fresh temp clone."""
        candidate = Candidate()
        clone = self.state_dir / TMP_DIR / uuid.uuid4().hex
        clone.parent.mkdir(parents=True, exist_ok=True)
        try:
            self.git.run(["clone", "--quiet", "--shared", "--no-checkout", rig_path, str(clone)])
            self.git.run(["-C", str(clone), "remote", "set-url", "origin", origin])
            self.git.run(["-C", str(clone), "fetch", "--quiet", "origin", "+refs/heads/*:refs/remotes/origin/*"])
            self.git.run(["-C", str(clone), "checkout", "--quiet", "--detach", f"origin/{target}"])
            email = login if "@" in login else f"{login}@tailnet"
            env = {"GIT_AUTHOR_NAME": login, "GIT_AUTHOR_EMAIL": email,
                   "GIT_COMMITTER_NAME": FRONT_NAME, "GIT_COMMITTER_EMAIL": "front@localhost"}
            for branch, bead in branches:
                ff = len(branches) == 1 and self.git.run(
                    ["-C", str(clone), "merge-base", "--is-ancestor", "HEAD", f"origin/{branch}"], check=False).returncode == 0
                if ff:
                    args = ["merge", "--ff-only", f"origin/{branch}"]
                else:
                    title = text_of(bead.get("title")) or text_of(bead.get("id"))
                    args = ["-c", f"user.name={login}", "-c", f"user.email={email}", "merge", "--no-ff", "--no-edit",
                            "-m", f"Merge {branch} ({title})", f"origin/{branch}"]
                done = self.git.run(["-C", str(clone), *args], env=env, check=False)
                if done.returncode != 0:
                    status = self.git.out(["-C", str(clone), "status", "--porcelain"], check=False)
                    files = [line[3:] for line in status.splitlines() if line[:2] in CONFLICT_CODES]
                    self.git.run(["-C", str(clone), "merge", "--abort"], check=False)
                    candidate.conflict = clip(f"conflicts merging {branch}: {', '.join(files) or last_line(done.stdout, done.stderr)}")
                    return candidate
                candidate.fast_forward = ff
            candidate.merge_commit = self.git.out(["-C", str(clone), "rev-parse", "HEAD"])
            candidate.tree = self.git.out(["-C", str(clone), "rev-parse", "HEAD^{tree}"])
            for line in self.git.out(["-C", str(clone), "diff", "--numstat", f"origin/{target}", "HEAD"]).splitlines():
                parts = line.split("\t", 2)
                if len(parts) != 3:
                    continue
                added = int(parts[0]) if parts[0].isdigit() else 0
                removed = int(parts[1]) if parts[1].isdigit() else 0
                candidate.files += 1
                candidate.additions += added
                candidate.deletions += removed
                if len(candidate.changes) < MAX_CHANGES:
                    candidate.changes.append({"path": parts[2], "additions": added, "deletions": removed})
            candidate.clone = clone
            return candidate
        finally:
            if candidate.clone is None:
                shutil.rmtree(clone, ignore_errors=True)

    # -- readiness -------------------------------------------------------

    def readiness(self, city: str, run_id: str, identity: Identity, keep_clone: bool = False) -> dict[str, Any]:
        """The readiness document; with ``keep_clone`` the candidate clone is kept under ``_candidate``."""
        convoy, tracked_ids = self._run(city, run_id)
        beads = self._beads(city, tracked_ids)
        mr = self._merge_request(city, convoy, tracked_ids)
        rig = self._rig_name(convoy, beads)
        config = RigConfig.load(self.state_dir, rig)
        rig_path, default_branch = self._rig(city, rig)
        origin = self._origin(rig_path)
        self.git.run(["-C", rig_path, "fetch", "--quiet", "origin"])
        heads = self._heads(rig_path)
        target = self._target(rig_path, heads, beads, default_branch)
        if target not in heads:
            raise MergeError(422, "merge-unavailable", f"origin has no branch {target}")

        merge_set: list[tuple[str, dict[str, Any]]] = []
        missing: list[str] = []
        for bead in beads:
            branch = bead_meta(bead, "branch") or f"polecat/{text_of(bead.get('id'))}"
            if branch in heads:
                merged = self.git.run(["-C", rig_path, "merge-base", "--is-ancestor", f"origin/{branch}", f"origin/{target}"], check=False)
                if merged.returncode != 0:
                    merge_set.append((branch, bead))
            elif not bead_closed(bead):
                missing.append(f"no branch {branch} on origin for {text_of(bead.get('id'))}")

        login = identity.login or "front"
        fingerprint = target + heads[target] + "|" + ",".join(f"{b}={heads[b]}" for b, _ in sorted(merge_set, key=lambda x: x[0]))
        candidate = self._candidate(rig, rig_path, origin, target, merge_set, login, fingerprint, config, keep_clone)

        lines = [self._work_line(beads)]
        lines += self._check_lines(rig, candidate, config)
        lines.append(self._review_line(beads, mr))
        if missing:
            lines.append({"key": "conflicts", "ok": False, "detail": "; ".join(missing)})
        elif candidate.conflict:
            lines.append({"key": "conflicts", "ok": False, "detail": candidate.conflict})
        elif not merge_set:
            lines.append({"key": "conflicts", "ok": True, "detail": f"nothing left to merge · already on {target}"})
        else:
            lines.append({"key": "conflicts", "ok": True, "detail": f"{len(merge_set)} branch(es) merge cleanly into {target}"})
        lines.append(self._acceptance_line(beads))

        approved_by = bead_approved_by(mr)
        boundaries = []
        if config.require_approval:
            boundaries.append({"key": "require_approval", "satisfied": bool(approved_by), "text": BOUNDARY_TEXT["require_approval"]})
        if config.require_tests:
            checks_ok = bool(config.checks) and all(
                line["ok"] for line in lines if line["key"] in {k for k, _ in config.checks})
            boundaries.append({"key": "require_tests", "satisfied": checks_ok, "text": BOUNDARY_TEXT["require_tests"]})
        if config.allowed_logins is not None:
            boundaries.append({"key": "allowed_logins", "satisfied": (identity.login or "").lower() in config.allowed_logins,
                               "text": f"Only {', '.join(config.allowed_logins)} may merge"})
        doc = {
            "ready": all(line["ok"] for line in lines),
            "runId": run_id,
            "rig": rig,
            "targetBranch": target,
            "lines": lines,
            "files": candidate.files,
            "additions": candidate.additions,
            "deletions": candidate.deletions,
            "changes": candidate.changes,
            "boundaries": boundaries,
            "mergeRequest": {
                "id": text_of(mr.get("id")) or run_id,
                "title": text_of(mr.get("title")) or text_of(convoy.get("title")) or run_id,
                "approvedBy": approved_by or None,
                "approvedAt": bead_meta(mr, "review.approved_at") or None,
            },
            "mergeCommit": heads[target] if not merge_set else candidate.merge_commit,
            "branches": [branch for branch, _ in merge_set],
        }
        if keep_clone:
            doc["_candidate"] = candidate
            doc["_rig_path"] = rig_path
        return doc

    def _candidate(self, rig: str, rig_path: str, origin: str, target: str, merge_set: list[tuple[str, dict[str, Any]]],
                   login: str, fingerprint: str, config: RigConfig, keep_clone: bool) -> Candidate:
        """The (cached) merge candidate; builds a clone when checks or the caller need one."""
        if not merge_set:
            return Candidate()
        key = (rig, fingerprint)
        with self.lock:
            cached = self.cache.get(key)
        tree = cached.tree if cached else None
        need_clone = keep_clone or (bool(config.checks) and (
            cached is None or (tree is not None and self.checks.cached(rig, tree) is None and not self.checks.is_running(rig, tree))))
        if cached is not None and not need_clone:
            return cached
        candidate = self._build(rig_path, origin, target, merge_set, login)
        with self.lock:
            self.cache[key] = candidate
        clone = candidate.clone
        if clone is not None and not keep_clone:
            handed = bool(config.checks) and candidate.tree is not None and self.checks.start(rig, candidate.tree, clone, config)
            if not handed:
                shutil.rmtree(clone, ignore_errors=True)
            candidate.clone = None
        return candidate

    @staticmethod
    def _work_line(beads: list[dict[str, Any]]) -> dict[str, Any]:
        if not beads:
            return {"key": "work", "ok": False, "detail": "no work items tracked"}
        open_ids = [text_of(b.get("id")) for b in beads
                    if not (bead_closed(b) or "needs-review" in bead_labels(b) or bead_approved_by(b))]
        if open_ids:
            return {"key": "work", "ok": False, "detail": f"{len(open_ids)} open: {', '.join(open_ids)}"}
        return {"key": "work", "ok": True, "detail": f"{len(beads)}/{len(beads)} work items"}

    def _check_lines(self, rig: str, candidate: Candidate, config: RigConfig) -> list[dict[str, Any]]:
        configured = dict(config.checks)
        results = self.checks.cached(rig, candidate.tree) if candidate.tree else None
        running = candidate.tree is not None and self.checks.is_running(rig, candidate.tree)
        lines = []
        for key in ["tests", "build", *[k for k in configured if k not in ("tests", "build")]]:
            if key not in configured:
                lines.append({"key": key, "ok": True, "detail": "not configured on the host"})
            elif candidate.tree is None:
                lines.append({"key": key, "ok": candidate.conflict is None, "detail": "nothing to check" if candidate.conflict is None else "not run: merge conflicts"})
            elif results is not None and key in results:
                lines.append({"key": key, "ok": bool(results[key].get("ok")), "detail": str(results[key].get("detail", ""))})
            elif running or results is None:
                lines.append({"key": key, "ok": False, "pending": True, "detail": "running on the host"})
            else:
                lines.append({"key": key, "ok": False, "detail": "not run"})
        return lines

    @staticmethod
    def _review_line(beads: list[dict[str, Any]], mr: dict[str, Any]) -> dict[str, Any]:
        waiting = [text_of(b.get("id")) for b in beads if "needs-review" in bead_labels(b) and not bead_approved_by(b)]
        approved = bead_approved_by(mr)
        mr_ok = bool(approved) or bead_closed(mr) or "needs-review" not in bead_labels(mr)
        if waiting or not mr_ok:
            ids = waiting + ([text_of(mr.get("id"))] if not mr_ok else [])
            return {"key": "review", "ok": False, "detail": f"waiting for review: {', '.join(ids)}"}
        if approved:
            return {"key": "review", "ok": True, "detail": f"approved by {approved}"}
        return {"key": "review", "ok": True, "detail": "no review requested"}

    @staticmethod
    def _acceptance_line(beads: list[dict[str, Any]]) -> dict[str, Any]:
        failed, validated = [], 0
        for bead in beads:
            result = bead_validation(bead)
            if result is False:
                failed.append(text_of(bead.get("id")))
            elif result is True:
                validated += 1
        if failed:
            return {"key": "acceptance", "ok": False, "detail": f"validation failed: {', '.join(failed)}"}
        if validated:
            return {"key": "acceptance", "ok": True, "detail": f"{validated} validated"}
        return {"key": "acceptance", "ok": True, "detail": "not reported by the host"}

    # -- mutations -------------------------------------------------------

    def approve(self, city: str, bead_id: str, identity: Identity) -> tuple[int, Any]:
        """Record the approval on the bead: metadata via PATCH, ``needs-review`` cleared."""
        status, body = self.upstream.call("GET", f"/v0/city/{city}/bead/{bead_id}")
        if status != 200:
            return status, body
        patch = {
            "metadata": {
                "review.approved_by": identity.login or "front",
                "review.approved_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
            },
            "remove_labels": ["needs-review"],
        }
        return self.upstream.call("PATCH", f"/v0/city/{city}/bead/{bead_id}", patch)

    def merge(self, city: str, run_id: str, identity: Identity) -> tuple[int, Any]:
        """Fast-forward or ``--no-ff`` merge into the target, pushed without force."""
        doc = self.readiness(city, run_id, identity, keep_clone=True)
        candidate: Candidate = doc.pop("_candidate")
        rig_path: str = doc.pop("_rig_path")
        try:
            for line in doc["lines"]:
                if not line["ok"]:
                    raise MergeError(409, "not-ready", f"{line['key']}: {line['detail']}", line=line["key"])
            for boundary in doc["boundaries"]:
                if not boundary["satisfied"]:
                    raise MergeError(403, "boundary", boundary["text"], boundary=boundary["key"])
            target = doc["targetBranch"]
            if not doc["branches"]:
                return 200, {"status": "merged", "mergeCommit": doc["mergeCommit"], "branch": target, "alreadyMerged": True, "branches": []}
            clone = candidate.clone
            if clone is None or candidate.merge_commit is None:
                raise MergeError(500, "merge-failed", "no merge candidate to push")
            self.git.run(["-C", str(clone), "push", "--quiet", "origin", f"HEAD:refs/heads/{target}"])
            self.git.run(["-C", rig_path, "fetch", "--quiet", "origin"], check=False)
            return 200, {"status": "merged", "mergeCommit": candidate.merge_commit, "branch": target, "alreadyMerged": False,
                         "branches": doc["branches"], "fastForward": candidate.fast_forward}
        finally:
            if candidate.clone is not None:
                shutil.rmtree(candidate.clone, ignore_errors=True)
                candidate.clone = None
            self.invalidate(doc["rig"])

    def invalidate(self, rig: str) -> None:
        with self.lock:
            for key in [k for k in self.cache if k[0] == rig]:
                del self.cache[key]

    # -- policy (TEAM-207) -----------------------------------------------

    def rig_names(self, city: str) -> list[str]:
        """The city's rig names from ``/status`` ``rig_details``, in host order."""
        return [
            text_of(rig.get("name"))
            for rig in as_list(as_dict(self.upstream.get(f"/v0/city/{city}/status")).get("rig_details"))
            if isinstance(rig, dict) and text_of(rig.get("name"))
        ]

    def policy(self, city: str, rig: str | None) -> dict[str, Any]:
        """The policy document for ``rig`` (``?rig=``), else the city's first rig, else the defaults."""
        if rig and ("/" in rig or rig in (".", "..")):
            raise MergeError(422, "rig-unusable", f"rig name {rig!r} is not usable")
        if not rig:
            names = self.rig_names(city)
            rig = names[0] if names else ""
        return RigConfig.load(self.state_dir, rig).policy(rig)

    # -- capability ------------------------------------------------------

    def capable(self, city: str | None) -> bool:
        """True when some rig of the city has an origin and a default branch (cached 60 s)."""
        if not city:
            return False
        now = time.monotonic()
        with self.lock:
            hit = self.capability.get(city)
            if hit and hit[0] > now:
                return hit[1]
        result = False
        try:
            if self.git.available():
                for rig in as_list(as_dict(self.upstream.get(f"/v0/city/{city}/status")).get("rig_details")):
                    if isinstance(rig, dict) and text_of(rig.get("path")) and self.default_branch_of(text_of(rig["path"]), text_of(rig.get("default_branch"))):
                        result = True
                        break
        except (MergeError, UpstreamDown) as exc:
            log.debug("merge capability check failed: %s", exc)
        with self.lock:
            self.capability[city] = (now + MERGE_CAPABILITY_TTL, result)
        return result


# -- server ------------------------------------------------------------------


class FrontServer(ThreadingHTTPServer):
    """Threaded HTTP server carrying the policy, whois cache and receipt store."""

    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, options: argparse.Namespace) -> None:
        self.options = options
        self.upstream = Upstream(options.supervisor)
        self.policy = Policy(options.allow, options.allow_tags, options.reads_any_peer, options.insecure_allow_any_peer)
        self.whois = Whois(options.whois_cmd, options.whois_ttl)
        self.store = ReceiptStore(Path(options.state_dir).expanduser())
        self.git_calls: list[list[str]] = []
        self.merge = MergeService(self.upstream, Git(options.git, self.git_calls), Path(options.state_dir).expanduser())
        self.check_startup()
        super().__init__((options.bind, options.port), Handler)
        self.stopping = threading.Event()

    def check_startup(self) -> None:
        """The documented refusals: bind address, allowlist, supervisor health."""
        if not is_local_bind(self.options.bind):
            raise ConfigError(f"--bind {self.options.bind!r} is neither loopback nor a Tailscale address (100.64.0.0/10)")
        if self.policy.empty() and not self.policy.insecure:
            raise ConfigError("allowlist is empty: pass --allow <login> and/or --allow-tags <tag> (or --insecure-allow-any-peer for tests)")
        if self.policy.insecure:
            log.warning("--insecure-allow-any-peer: EVERY peer may read and write; tests only")
        health = self.upstream.get_json("/health")
        self.supervisor_version = str(health.get("version", "")) if isinstance(health, dict) else ""
        self.city = self.options.city or (health.get("city") if isinstance(health, dict) else None)
        if not self.city:
            self.city = first_running_city(self.upstream.get_json("/v0/cities"))

    def base_url(self) -> str:
        """The front's own URL as configured."""
        host, port = self.server_address[:2]
        if ":" in host:
            host = f"[{host}]"
        return f"http://{host}:{port}"

    def stop(self) -> None:
        """Stop serving; streams notice ``stopping`` within one poll."""
        self.stopping.set()
        self.shutdown()
        self.server_close()


class Handler(BaseHTTPRequestHandler):
    """Gates by identity, then proxies or answers the well-known document."""

    protocol_version = "HTTP/1.1"
    server: FrontServer

    def log_message(self, fmt: str, *args: Any) -> None:  # noqa: D401
        return  # one structured line per request is written by _finish instead

    # -- entry points ----------------------------------------------------

    def do_GET(self) -> None:  # noqa: N802
        self._handle()

    do_HEAD = do_OPTIONS = do_POST = do_PUT = do_PATCH = do_DELETE = do_GET

    def _handle(self) -> None:
        self.request_id = ""
        self.identity = self.server.whois.lookup(self.client_address[0])
        path = urlsplit(self.path).path
        try:
            if path == WELL_KNOWN and self.command in ("GET", "HEAD"):
                self._well_known()
            elif (route := FRONT_ROUTE.match(path)) is not None:
                self._front_route(route)
            elif self.command in READ_METHODS:
                self._read()
            elif self.command in MUTATION_METHODS:
                self._mutate()
            else:
                self._problem(405, "method-not-allowed", "Method Not Allowed", f"{self.command} is not supported")
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True

    def _finish(self, status: int) -> None:
        """The single log line: method, path, login, status, request id."""
        log.info(
            "%s %s login=%s status=%s request_id=%s",
            self.command, urlsplit(self.path).path, self.identity.login or "-", status, self.request_id or "-",
        )

    # -- responses -------------------------------------------------------

    def _send(self, status: int, body: bytes, content_type: str, extra: dict[str, str] | None = None) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)
        self._finish(status)

    def _json(self, status: int, body: Any, extra: dict[str, str] | None = None) -> None:
        self._send(status, json.dumps(body, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8", extra)

    def _problem(self, status: int, code: str, title: str, detail: str) -> None:
        raw = json.dumps(problem(status, code, title, detail)).encode("utf-8")
        self._send(status, raw, "application/problem+json")

    def _forbidden(self, what: str) -> None:
        """Answer 403 for a peer that may not ``what``."""
        if not self.identity.on_tailnet:
            self._problem(403, "peer-not-on-tailnet", "Forbidden", "the peer address is not a tailnet device this host can identify")
        else:
            self._problem(403, "identity-not-allowed", "Forbidden", f"{self.identity.login or 'this peer'} may not {what} through this front")

    # -- routes ----------------------------------------------------------

    def _well_known(self) -> None:
        if not self.server.policy.on_tailnet(self.identity):
            self._forbidden("discover")
            return
        host = self.headers.get("Host") or self.server.base_url()[len("http://"):]
        self._json(200, {
            "provider": "gascity",
            "supervisorUrl": f"http://{host}",
            "city": self.server.city,
            "front": True,
            "version": self.server.supervisor_version,
            "capabilities": {"read": True, "control": True, "merge": self.server.merge.capable(self.server.city)},
            "identity": {"login": self.identity.login, "allowed": self.server.policy.allowed(self.identity)},
        })

    # -- merge roles (front-answered routes) -----------------------------

    def _front_route(self, route: "re.Match[str]") -> None:
        """``/v0/city/{c}/front/merge-readiness/{run}``, ``.../mr/{bead}/approve``, ``.../merge/{run}``, ``.../policy``."""
        city, kind, target, approve, policy = route.groups()
        merge = self.server.merge
        if policy:
            if self.command != "GET":
                self._problem(405, "method-not-allowed", "Method Not Allowed", "policy is a GET")
            elif not self.server.policy.may_read(self.identity):
                self._forbidden("read")
            else:
                rig = (parse_qs(urlsplit(self.path).query).get("rig") or [""])[0].strip()
                try:
                    self._json(200, merge.policy(city, rig or None))
                except MergeError as exc:
                    self._send(exc.status, json.dumps(exc.problem()).encode("utf-8"), "application/problem+json")
                except UpstreamDown:
                    self._problem(502, "upstream-unavailable", "Bad Gateway", "the supervisor did not answer")
        elif kind == "merge-readiness" and not approve:
            if self.command != "GET":
                self._problem(405, "method-not-allowed", "Method Not Allowed", "merge-readiness is a GET")
            elif not self.server.policy.may_read(self.identity):
                self._forbidden("read")
            else:
                try:
                    self._json(200, merge.readiness(city, target, self.identity))
                except MergeError as exc:
                    self._send(exc.status, json.dumps(exc.problem()).encode("utf-8"), "application/problem+json")
                except UpstreamDown:
                    self._problem(502, "upstream-unavailable", "Bad Gateway", "the supervisor did not answer")
        elif kind == "mr" and approve:
            self._local_mutation(lambda: merge.approve(city, target, self.identity))
        elif kind == "merge" and not approve:
            self._local_mutation(lambda: merge.merge(city, target, self.identity))
        else:
            self._problem(404, "not-found", "Not Found", "no such front route")

    def _local_mutation(self, handler: "Callable[[], tuple[int, Any]]") -> None:
        """A mutation the front performs itself, under the same receipt rules."""
        if self.command != "POST":
            self._problem(405, "method-not-allowed", "Method Not Allowed", "this route is a POST")
            return
        if not self.server.policy.allowed(self.identity):
            self._forbidden("write")
            return
        if self._read_body() is None:
            return

        def send(key: str | None) -> None:
            try:
                status, body = handler()
            except MergeError as exc:
                status, body = exc.status, exc.problem()
            except UpstreamDown:
                self._problem(502, "upstream-unavailable", "Bad Gateway", "the supervisor did not answer")
                return
            self._answer_receipt(status, body, key)

        self._with_receipt(send)

    def _read(self) -> None:
        if not self.server.policy.may_read(self.identity):
            self._forbidden("read")
            return
        self._proxy()

    def _mutate(self) -> None:
        if not self.server.policy.allowed(self.identity):
            self._forbidden("write")
            return
        body = self._read_body()
        if body is None:
            return
        self._with_receipt(lambda key: self._forward_mutation(body, key))

    def _with_receipt(self, send: "Callable[[str | None], None]") -> None:
        """Run ``send`` once per Idempotency-Key; replays answer the stored receipt."""
        key = (self.headers.get("Idempotency-Key") or "").strip()
        if not key:
            send(None)
            return
        with self.server.store.key_lock(key):
            stored = self.server.store.get(key)
            if stored is None:
                send(key)
            elif stored.get("identity") != self.identity.login:
                self._problem(409, "idempotency-mismatch", "Conflict", "this Idempotency-Key was first used by another identity")
            else:
                self.request_id = stored["request_id"]
                self._json(stored["upstream_status"], receipt_of(stored), {"X-GC-Request-Id": stored["request_id"], "Idempotent-Replayed": "true"})

    def _read_body(self) -> bytes | None:
        """The request body, or None after answering a 4xx."""
        if self.headers.get("Transfer-Encoding"):
            self._problem(411, "length-required", "Length Required", "send a Content-Length, not a chunked body")
            return None
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY:
            self._problem(413, "payload-too-large", "Payload Too Large", f"bodies above {MAX_BODY} bytes are refused")
            return None
        return self.rfile.read(length) if length else b""

    # -- proxying --------------------------------------------------------

    def _upstream_headers(self, body: bytes | None) -> dict[str, str]:
        """Client headers minus hop-by-hop and credentials, plus the CSRF header."""
        headers = {k: v for k, v in self.headers.items() if k.lower() not in NEVER_FORWARD}
        headers["X-GC-Request"] = FRONT_NAME
        headers["X-Forwarded-For"] = self.client_address[0]
        headers["Connection"] = "close"
        if body is not None:
            headers["Content-Length"] = str(len(body))
        return headers

    def _open_upstream(self, body: bytes | None) -> tuple[HTTPConnection, HTTPResponse] | None:
        """Send the request upstream; answer 502 and return None on failure."""
        conn = self.server.upstream.connect()
        try:
            conn.request(self.command, self.server.upstream.prefix + self.path, body=body, headers=self._upstream_headers(body))
            return conn, conn.getresponse()
        except OSError as exc:
            conn.close()
            log.warning("upstream failed: %s", type(exc).__name__)
            self._problem(502, "upstream-unavailable", "Bad Gateway", "the supervisor did not answer")
            return None

    def _proxy(self) -> None:
        """Pass a read through; SSE streams are relayed as they arrive."""
        opened = self._open_upstream(None)
        if opened is None:
            return
        conn, response = opened
        headers = {k.lower(): v for k, v in response.getheaders()}
        self.request_id = headers.get("x-gc-request-id", "")
        try:
            if is_sse(headers):
                self._relay_stream(conn, response, headers)
            else:
                raw = response.read()
                self._send(response.status, raw, headers.get("content-type", "application/octet-stream"), self._returned(headers))
        finally:
            conn.close()

    def _returned(self, headers: dict[str, str]) -> dict[str, str]:
        """Upstream headers worth echoing to the client."""
        return {k: v for k, v in headers.items() if k not in NEVER_RETURN and k != "content-type"}

    def _relay_stream(self, conn: HTTPConnection, response: HTTPResponse, headers: dict[str, str]) -> None:
        """Copy SSE bytes as they arrive; stop when either side goes away."""
        self.send_response(response.status)
        self.send_header("Content-Type", headers.get("content-type", "text/event-stream"))
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        for key, value in self._returned(headers).items():
            self.send_header(key, value)
        self.end_headers()
        self.close_connection = True
        pump = threading.Thread(target=self._pump, args=(response,), daemon=True)
        pump.start()
        try:
            while pump.is_alive() and not self.server.stopping.is_set() and not self._client_gone():
                pump.join(STREAM_POLL)
        finally:
            self._shutdown_upstream(conn, response, pump)
            self._finish(response.status)

    def _pump(self, response: HTTPResponse) -> None:
        """Reader thread: every chunk goes to the client unbuffered."""
        try:
            while True:
                chunk = response.read1(65536)
                if not chunk:
                    return
                self.wfile.write(chunk)
                self.wfile.flush()
        except (OSError, ValueError, AttributeError):
            # AttributeError: the response was closed under us (client left
            # and _shutdown_upstream ran) while read1 was mid-chunk.
            return

    @staticmethod
    def _shutdown_upstream(conn: HTTPConnection, response: HTTPResponse, pump: threading.Thread) -> None:
        """Wake the blocked reader, then really close the supervisor socket.

        ``shutdown`` unblocks ``read1``; the fd itself only closes once the
        response's file object is closed too, and only then does the
        supervisor see the stream go away."""
        try:
            if conn.sock is not None:
                conn.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        pump.join(STREAM_POLL * 5)
        response.close()
        conn.close()

    def _client_gone(self) -> bool:
        """True when the client closed its side (so the upstream must close too)."""
        try:
            readable, _, _ = select.select([self.connection], [], [], 0)
            if not readable:
                return False
            return self.connection.recv(1, socket.MSG_PEEK) == b""
        except OSError:
            return True

    def _forward_mutation(self, body: bytes, key: str | None) -> None:
        """Forward one mutation and answer (and, with a key, store) a receipt."""
        opened = self._open_upstream(body)
        if opened is None:
            return
        conn, response = opened
        try:
            headers = {k.lower(): v for k, v in response.getheaders()}
            raw = response.read()
        finally:
            conn.close()
        self._answer_receipt(response.status, decode_body(raw, headers.get("content-type", "")), key, headers.get("x-gc-request-id"))

    def _answer_receipt(self, status: int, body: Any, key: str | None, request_id: str | None = None) -> None:
        """Store (with a key) and answer the receipt for one performed mutation."""
        self.request_id = request_id or f"front-{uuid.uuid4().hex}"
        record = {
            "request_id": self.request_id,
            "status": "accepted" if 200 <= status < 300 else "rejected",
            "upstream_status": status,
            "body": body,
            "idempotency_key": key,
            "identity": self.identity.login,
            "method": self.command,
            "path": urlsplit(self.path).path,
            "ts": time.time(),
        }
        if key is not None:
            self.server.store.put(key, record)
        self._json(status, receipt_of(record), {"X-GC-Request-Id": self.request_id})


# -- CLI -----------------------------------------------------------------------


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """CLI flags."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--supervisor", default="http://127.0.0.1:8372", help="loopback supervisor URL")
    parser.add_argument("--bind", required=True, help="address to listen on: the computer's Tailscale IP or loopback")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"port to listen on (default {DEFAULT_PORT}; 0 = ephemeral)")
    parser.add_argument("--allow", action="append", default=[], metavar="LOGIN", help="tailnet login allowed to read and write (repeatable)")
    parser.add_argument("--allow-tags", action="append", default=[], metavar="TAG", help="node tag (tag:phone) allowed to read and write (repeatable)")
    parser.add_argument("--reads-any-peer", action="store_true", help="let every identified tailnet peer read (writes stay allowlisted)")
    parser.add_argument("--insecure-allow-any-peer", action="store_true", help="TESTS ONLY: skip identity checks entirely")
    parser.add_argument("--city", default=None, help="city name to advertise (default: the supervisor's first running city)")
    parser.add_argument("--whois-cmd", default=DEFAULT_WHOIS_CMD, help="command that maps a peer IP to JSON identity")
    parser.add_argument("--whois-ttl", type=float, default=WHOIS_TTL, help="seconds to cache whois answers")
    parser.add_argument("--state-dir", default=DEFAULT_STATE_DIR, help="where receipts.json, rigs/<rig>.json and merge-checks.json live")
    parser.add_argument("--git", default="git", help="git executable used for the merge roles")
    parser.add_argument("--print-config", action="store_true", help="print the effective settings and exit")
    parser.add_argument("--verbose", action="store_true", help="debug logging")
    return parser.parse_args(argv)


def effective_config(options: argparse.Namespace) -> dict[str, Any]:
    """The settings the front will run with (no secrets are involved)."""
    return {
        "supervisor": options.supervisor,
        "bind": options.bind,
        "port": options.port,
        "allow": options.allow,
        "allow_tags": options.allow_tags,
        "reads_any_peer": options.reads_any_peer,
        "insecure_allow_any_peer": options.insecure_allow_any_peer,
        "city": options.city,
        "whois_cmd": options.whois_cmd,
        "whois_ttl": options.whois_ttl,
        "state_dir": str(Path(options.state_dir).expanduser()),
        "git": options.git,
        "bind_is_local": is_local_bind(options.bind),
        "front_version": FRONT_VERSION,
    }


def install_signal_handlers(server: FrontServer) -> None:
    """SIGTERM/SIGINT stop the server from a helper thread (shutdown blocks)."""

    def _stop(signum: int, _frame: Any) -> None:
        log.info("signal %s: shutting down", signum)
        threading.Thread(target=server.stop, daemon=True).start()

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)


def main(argv: list[str] | None = None) -> int:
    """Run the front until SIGTERM/SIGINT."""
    options = parse_args(argv)
    level = logging.DEBUG if options.verbose else logging.INFO
    logging.basicConfig(stream=sys.stderr, level=level, format="%(asctime)s front %(levelname)s %(message)s")
    if options.print_config:
        print(json.dumps(effective_config(options), indent=2))
        return 0
    try:
        server = FrontServer(options)
    except ConfigError as exc:
        print(f"front: refusing to start: {exc}", file=sys.stderr)
        return 2
    install_signal_handlers(server)
    log.info("listening on %s -> %s city=%s allow=%d logins %d tags", server.base_url(), server.upstream.url, server.city, len(server.policy.logins), len(server.policy.tags))
    try:
        server.serve_forever()
    finally:
        server.stopping.set()
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
