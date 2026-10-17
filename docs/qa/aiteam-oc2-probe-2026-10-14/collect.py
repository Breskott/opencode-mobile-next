"""Collect allowlisted evidence from this isolated probe, never raw credentials.

Run on the build host: python3 collect.py <isolated-root>. Requires server.log,
openapi.json and sid from the probe. Does not launch or stop a server. Mutates
only the recorded scratch session; leaves it with deny-all permissions.
"""

import base64
import datetime
import json
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

root = pathlib.Path(sys.argv[1]).resolve()
if not root.name.startswith("oc2-probe-aiteam-20261014-"):
    raise SystemExit("unexpected scratch root")
password = re.search(
    r"server password[:\s]+(\S+)", (root / "server.log").read_text()
).group(1)
authorization = "Basic " + base64.b64encode(
    ("opencode:" + password).encode()
).decode()


def call(method, path, body=None):
    request = urllib.request.Request(
        "http://127.0.0.1:4191" + path,
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"Authorization": authorization, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        # Never include server bodies or exception text in evidence.
        raise SystemExit("unexpected HTTP status " + str(error.code)) from None
    except Exception:
        raise SystemExit("transport failure; do not retry mutations") from None


sid = (root / "sid").read_text().strip()
if not re.fullmatch(r"ses_[A-Za-z0-9]+", sid):
    raise SystemExit("unexpected session id")
path = "/api/session/" + sid
status, info = call("GET", "/api/info")
if info.get("version") != "2.0.29":
    raise SystemExit("unexpected server version")
status, session = call("GET", path)
if session["data"]["location"]["directory"] != str(root / "repo"):
    raise SystemExit("unexpected session directory")

evidence = {
    "collectedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "version": info["version"],
    "listenerPid": info["pid"],
    "sessionId": sid,
    "policies": [],
}
deny = [{"action": "*", "resource": "*", "effect": "deny"}]
for name, actions in [
    ("deny-all", []),
    ("readonly", ["read", "glob", "grep"]),
    ("worker", ["read", "glob", "grep", "edit", "bash"]),
    ("deny-all-after-worker", []),
]:
    rules = deny + [
        {"action": action, "resource": "*", "effect": "allow"}
        for action in actions
    ]
    patch_status, _ = call("PATCH", path, {"permissions": rules})
    get_status, session = call("GET", path)
    results = {}
    for action in ["read", "glob", "grep", "edit", "bash", "webfetch", "task", "unknown_probe"]:
        status, decision = call(
            "POST", path + "/permission", {"action": action, "resources": ["*"]}
        )
        results[action] = {"status": status, "effect": decision["data"]["effect"]}
    evidence["policies"].append({
        "name": name,
        "patchStatus": patch_status,
        "getStatus": get_status,
        "exactReadback": session["data"]["permissions"] == rules,
        "rules": session["data"]["permissions"],
        "evaluations": results,
    })

status, messages = call("GET", path + "/message")
evidence["transcript"] = []
for message in messages["data"]:
    row = {key: message[key] for key in ["id", "type", "outcome", "finish", "model"] if key in message}
    if "error" in message:
        row["error"] = {key: message["error"][key] for key in ["type", "status"] if key in message["error"]}
    if message["type"] == "assistant":
        row["contentCount"] = len(message.get("content", []))
    evidence["transcript"].append(row)
evidence["transcriptHasMorePages"] = bool(messages.get("cursor", {}).get("next"))
status, entries = call("GET", "/api/experimental/session/" + sid + "/instructions/entries")
evidence["roleEntryStored"] = any(
    item["key"] == "aiteam-role" and "ROLE_WIRE_4191" in item["value"]
    for item in entries["data"]
)
query = "?" + urllib.parse.urlencode({"location[directory]": str(root / "repo")})
for name, endpoint in [
    ("pendingPermissions", "/api/permission/request" + query),
    ("pendingForms", "/api/form" + query),
    ("sessionPermissions", path + "/permission"),
    ("sessionForms", path + "/form"),
]:
    status, response = call("GET", endpoint)
    evidence[name] = {"status": status, "count": len(response["data"])}
evidence["activeAtEnd"] = call("GET", "/api/session/active")[1]
status, interrupt = call("POST", path + "/interrupt?resume=false")
evidence["idleInterrupt"] = {"status": status, "interrupted": interrupt["interrupted"]}
evidence["realToolDenialProven"] = False
evidence["roleDeliveredToModelProven"] = False
evidence["verdict"] = "blocked-provider-failure-before-tool-execution"
print(json.dumps(evidence, indent=2))
