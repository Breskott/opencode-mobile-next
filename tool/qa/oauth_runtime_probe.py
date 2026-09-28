#!/usr/bin/env python3
"""Check OC1 provider loading with fake credentials and loopback-only networking.

Run through machine_lock.sh and unshare -Urn; see the OAuth evidence README.
The supplied release archive is checked against the app's pinned SHA-256 before
extraction or execution. No package manager, OAuth exchange or prompt is run.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tarfile
import tempfile
import time
import urllib.request


ARCHIVE_SHA256 = "763af386ef88a8cab18df00fcf055690e5a55e31a7088beabe02307142a6adce"
PROVIDERS = ("anthropic", "google", "openai")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def run(archive):
    # Refuse host networking, even if a caller forgets the documented wrapper.
    require(
        os.readlink("/proc/self/ns/net") != os.readlink("/proc/1/ns/net")
        and {name for _, name in socket.if_nameindex()} == {"lo"},
        "Run in a fresh network namespace: unshare -Urn python3 ...",
    )
    subprocess.run(["/usr/sbin/ip", "link", "set", "lo", "up"], check=True)
    with archive.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    require(digest == ARCHIVE_SHA256, "Release archive checksum mismatch")

    with tempfile.TemporaryDirectory(prefix="oc-oauth-fake-") as temporary:
        root = Path(temporary)
        for name in (
            "home", "data/opencode", "config/opencode", "cache", "state",
            "project", "tmp",
        ):
            (root / name).mkdir(parents=True, exist_ok=True)
        binary = root / "opencode"
        with tarfile.open(archive) as release:
            member = release.getmember("opencode")
            require(member.isfile(), "Release binary is not a regular file")
            with release.extractfile(member) as source, binary.open("wb") as target:
                while chunk := source.read(1024 * 1024):
                    target.write(chunk)
        binary.chmod(0o700)

        # Deliberately do not inherit provider keys, config, proxies, HOME,
        # server credentials, shell hooks, or SDK environment from this PC.
        env = {
            "PATH": "/usr/bin:/bin",
            "HOME": str(root / "home"),
            "XDG_DATA_HOME": str(root / "data"),
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_CACHE_HOME": str(root / "cache"),
            "XDG_STATE_HOME": str(root / "state"),
            "TMPDIR": str(root / "tmp"),
            "OPENCODE_CONFIG_DIR": str(root / "config/opencode"),
            "OPENCODE_DISABLE_MODELS_FETCH": "1",
            "OPENCODE_PURE": "1",
            "OPENCODE_DISABLE_CLAUDE_CODE": "1",
            "OPENCODE_DISABLE_EXTERNAL_SKILLS": "1",
            "OPENCODE_DISABLE_LSP_DOWNLOAD": "1",
        }
        version = subprocess.check_output(
            [str(binary), "--version"], cwd=root / "project", env=env,
            stderr=subprocess.DEVNULL, text=True, timeout=30,
        ).strip()
        require(version == "1.18.32", "Unexpected release version")

        auth = root / "data/opencode/auth.json"
        auth.write_text(json.dumps({
            provider: {
                "type": "oauth",
                "access": "FAKE-ACCESS-NOT-A-CREDENTIAL",
                "refresh": "FAKE-REFRESH-NOT-A-CREDENTIAL",
                "expires": 4102444800000,
            }
            for provider in PROVIDERS
        }))
        auth.chmod(0o600)
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

        def request(path, method="GET", data=None):
            message = urllib.request.Request(
                f"http://127.0.0.1:{port}{path}", method=method,
                data=None if data is None else json.dumps(data).encode(),
                headers={"Content-Type": "application/json"},
            )
            with opener.open(message, timeout=45) as response:
                body = response.read()
                return json.loads(body) if body else None

        def snapshot(stage, expect_keys=False):
            connected = set(request("/provider")["connected"])
            # This response contains credentials. Keep it in memory only;
            # project just the known IDs to booleans, never print the body.
            loaded = {item["id"] for item in request("/config/providers")["providers"]}
            methods = request("/provider/auth")
            result = {
                provider: {
                    "connected": provider in connected,
                    "loaded": provider in loaded,
                    "browser_method": any(
                        method["type"] == "oauth"
                        for method in methods.get(provider, [])
                    ),
                }
                for provider in PROVIDERS
            }
            for provider in PROVIDERS:
                require(result[provider]["connected"], "Stored sign-in missing")
                require(
                    result[provider]["loaded"] == (expect_keys or provider == "openai"),
                    "Unexpected provider loading result",
                )
                require(
                    result[provider]["browser_method"] == (provider == "openai"),
                    "Unexpected browser method discovery",
                )
            return {"stage": stage, "providers": result}

        observations = []
        # Server logs stay in the throwaway directory and are never printed.
        with (root / "server.log").open("w") as log:
            process = subprocess.Popen(
                [str(binary), "serve", "--hostname", "127.0.0.1", "--port", str(port)],
                cwd=root / "project", env=env, stdout=log, stderr=log,
            )
            try:
                ready = False
                for _ in range(120):
                    require(process.poll() is None, "Throwaway server stopped")
                    try:
                        request("/global/health")
                        ready = True
                        break
                    except (OSError, ValueError):
                        time.sleep(0.25)
                require(ready, "Throwaway server did not become ready")
                observations.append(snapshot("stored_oauth"))
                require(request("/session/status") == {}, "Unexpected active sessions")
                request("/instance/dispose", "POST")
                observations.append(snapshot("oauth_after_idle_dispose"))
                for provider in ("anthropic", "google"):
                    require(
                        request(f"/auth/{provider}", "PUT", {
                            "type": "api", "key": "FAKE-KEY-NOT-A-CREDENTIAL",
                        }) is True,
                        "Fake key write was not acknowledged",
                    )
                # OC1 caches the provider runtime until an idle refresh.
                observations.append(snapshot("keys_saved_before_dispose"))
                require(request("/session/status") == {}, "Unexpected active sessions")
                request("/instance/dispose", "POST")
                observations.append(snapshot("keys_after_idle_dispose", expect_keys=True))
            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)

        # Print only a fixed schema, after cleanup of the captured server PID.
        return {
            "runtime": version, "archive_sha256": digest,
            "network": "isolated_loopback_only", "credentials": "fake_only",
            "scope": "provider_loading_not_inference_or_browser_exchange",
            "observations": observations,
        }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    arguments = parser.parse_args()
    try:
        result = run(arguments.archive.resolve())
    except Exception as error:
        # No exception body, HTTP response, raw server log or credential value.
        raise SystemExit(f"OAuth loading probe failed ({type(error).__name__})") from None
    print(json.dumps(result, indent=2))
