#!/usr/bin/env bash
# Publishes the pinned AI Team binaries (gc, bd, dolt and the opencode
# wrapper) as the GitHub release the app's manifests download from:
#   https://github.com/Eslamasabry/opencode-mobile-next/releases/download/aiteam-assets-1/<file>
#
# Usage: tool/release/upload_aiteam_assets.sh <asset dir> [--dry-run]
#
# Every file both manifests in assets/aiteam/ name must be in <asset dir> with
# exactly the size and sha256 the manifest pins; nothing is uploaded
# otherwise. The phone checks the same sums after downloading, so a wrong
# file here would only ever show up as a checksum refusal on every phone.
#
# The release is a prerelease that is never marked Latest, and its tag does
# not look like an app version, so the desktop update check skips it.
# Existing assets are never overwritten: a pinned file must not change under
# the same name. Publish a new tag (aiteam-assets-2) and new manifests
# instead.
set -euo pipefail

REPO=Eslamasabry/opencode-mobile-next
TAG=aiteam-assets-1

root=$(cd "$(dirname "$0")/../.." && pwd)
dir="${1:-}"
dry_run=0
[ "${2:-}" = --dry-run ] && dry_run=1
if [ -z "$dir" ] || [ ! -d "$dir" ]; then
  echo "usage: $0 <asset dir> [--dry-run]" >&2
  exit 64
fi

manifests=("$root/assets/aiteam/manifest.json" "$root/assets/aiteam/manifest-x86_64.json")
expected_base="https://github.com/$REPO/releases/download/$TAG/"

# "<name> <bytes> <sha256>" for every file a manifest names, after checking
# the manifest points at this release.
entries() {
  python3 - "$expected_base" "$@" <<'PY'
import json, sys
base = sys.argv[1]
seen = {}
for path in sys.argv[2:]:
    manifest = json.load(open(path))
    if manifest.get("base_url") != base:
        sys.exit(f"{path}: base_url is {manifest.get('base_url')!r}, expected {base!r}")
    for entry in manifest["files"].values():
        key = entry["name"]
        value = (entry["bytes"], entry["sha256"])
        if seen.setdefault(key, value) != value:
            sys.exit(f"{key}: the manifests pin it differently")
for name, (size, sha) in sorted(seen.items()):
    print(name, size, sha)
PY
}

files=()
failed=0
while read -r name bytes sha; do
  path="$dir/$name"
  if [ ! -f "$path" ]; then
    echo "missing: $path" >&2
    failed=1
    continue
  fi
  actual_bytes=$(wc -c < "$path" | tr -d ' ')
  actual_sha=$(sha256sum "$path" | cut -d' ' -f1)
  if [ "$actual_bytes" != "$bytes" ] || [ "$actual_sha" != "$sha" ]; then
    echo "mismatch: $name is $actual_bytes bytes, $actual_sha (manifest: $bytes, $sha)" >&2
    failed=1
    continue
  fi
  echo "ok: $name ($bytes bytes)"
  files+=("$path")
done < <(entries "${manifests[@]}")
[ "$failed" = 0 ] || { echo 'Nothing uploaded.' >&2; exit 65; }

notes="Pinned AI Team runtime binaries for OpenCode Mobile (Gas City gc, beads bd, Dolt, and the opencode wrapper) for Android arm64 and x86_64.

The app downloads these files on the phone when you set up AI Team and refuses any file whose sha256 differs from the one pinned in assets/aiteam/manifest*.json. This is not an app release; install the app from the version releases."

if [ "$dry_run" = 1 ]; then
  echo "dry run: would publish ${#files[@]} files to $REPO release $TAG"
  exit 0
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  # No --clobber: a pinned name keeps its bytes forever.
  gh release upload "$TAG" --repo "$REPO" "${files[@]}"
else
  gh release create "$TAG" --repo "$REPO" \
    --title 'AI Team runtime binaries (pinned)' \
    --notes "$notes" \
    --prerelease --latest=false \
    "${files[@]}"
fi
echo "published: https://github.com/$REPO/releases/tag/$TAG"
