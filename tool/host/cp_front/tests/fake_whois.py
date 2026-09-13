#!/usr/bin/env python3
"""Stand-in for ``tailscale whois --json <ip>`` in the front's tests.

Maps a few loopback addresses to identities so tests can pick a peer by
connecting from that source address.  Unknown addresses exit 1 like the real
command does for a non-tailnet peer.  A counter file (FAKE_WHOIS_COUNT) is
appended per call so tests can prove the front caches answers.  With
FAKE_WHOIS_SLEEP_AFTER=N set, every call after the N-th recorded in the
counter file sleeps instead of answering, standing in for a hanging
``tailscale whois``.
"""

import json
import os
import sys
import time

PEERS = {
    "127.0.0.2": {"UserProfile": {"LoginName": "alice@example.com"}, "Node": {"Tags": None}},
    "127.0.0.3": {"UserProfile": {"LoginName": "bob@example.com"}, "Node": {"Tags": None}},
    "127.0.0.4": {"UserProfile": {"LoginName": "tagged-devices"}, "Node": {"Tags": ["tag:phone"]}},
}


def main() -> int:
    """Print the whois document for the last argument, or fail like tailscale."""
    ip = sys.argv[-1]
    counter = os.environ.get("FAKE_WHOIS_COUNT")
    calls = 0
    if counter:
        with open(counter, "a+", encoding="utf-8") as handle:
            handle.write(ip + "\n")
            handle.seek(0)
            calls = len(handle.read().splitlines())
    sleep_after = os.environ.get("FAKE_WHOIS_SLEEP_AFTER")
    if sleep_after and calls > int(sleep_after):
        time.sleep(60)
    doc = PEERS.get(ip)
    if doc is None:
        print(f"no match for IP {ip}", file=sys.stderr)
        return 1
    print(json.dumps(doc))
    return 0


if __name__ == "__main__":
    sys.exit(main())
