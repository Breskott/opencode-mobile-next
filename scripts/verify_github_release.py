#!/usr/bin/env python3
"""Validate GitHub publication metadata and bytes; never accesses credentials."""

import hashlib
import json
from pathlib import Path
import re
import sys


def require(condition, message):
    if not condition:
        raise SystemExit(f"ERROR: {message}")


def read_json(root, name):
    return json.loads((root / name).read_text())


def verify_run(run, workflow, head):
    require(run.get("head_sha") == head, "CI source differs from candidate")
    require(run.get("path") == f".github/workflows/{workflow}.yml", "Wrong CI workflow")
    require(
        run.get("status") == "completed" and run.get("conclusion") == "success",
        "CI run did not complete successfully",
    )
    require(run.get("event") in {"push", "workflow_dispatch"}, "Untrusted CI event")


def verify_notes(root, version):
    committed = Path(f"docs/releases/v{version}.md").read_text().strip()
    require(committed.startswith(f"# OpenCode Mobile {version}\n"), "Missing versioned stable notes")
    notes = (root / "ci/RELEASE_NOTES.md").read_text().strip()
    require(notes.startswith(committed + "\n"), "CI notes differ from committed release notes")
    release = read_json(root, "release.json")
    require(release.get("body", "").strip() == notes, "Draft body differs from verified CI notes")
    return notes


def verify_artifact(folder, name):
    manifest = (folder / "SHA256SUMS").read_text().strip()
    match = re.fullmatch(r"([0-9a-f]{64})  " + re.escape(name), manifest)
    require(match is not None, "Checksum manifest must contain exactly the candidate APK")
    with (folder / name).open("rb") as apk:
        hasher = hashlib.sha256()
        for chunk in iter(lambda: apk.read(1024 * 1024), b""):
            hasher.update(chunk)
        digest = hasher.hexdigest()
    require(digest == match.group(1), "APK checksum mismatch")
    return digest


def main():
    action, directory, head, version = sys.argv[1:]
    root = Path(directory)
    release = read_json(root, "release.json")
    require(release.get("tag_name") == f"v{version}", "Release tag mismatch")
    require(isinstance(release.get("id"), int) and release["id"] > 0, "Missing release identity")
    expected_assets = {f"opencode-mobile-{version}.apk", "SHA256SUMS"}
    assets = release.get("assets")
    require(isinstance(assets, list), "Release asset inventory is missing")
    require(
        len(assets) == len(expected_assets)
        and all(isinstance(asset, dict) for asset in assets)
        and {asset.get("name") for asset in assets} == expected_assets,
        "Release must contain exactly one candidate APK and one SHA256SUMS asset",
    )
    if action == "preflight":
        previous = root / "release-verified.json"
        if previous.exists():
            verified = read_json(root, "release-verified.json")
            fields = ("id", "name", "size", "digest", "updated_at")
            def identities(data):
                return sorted(
                    (tuple(asset.get(key) for key in fields) for asset in data.get("assets", [])),
                    key=repr,
                )
            require(release["id"] == verified["id"] and identities(release) == identities(verified), "Draft assets changed during verification")
        require(release.get("draft") is True, "Refusing to overwrite a published release")
        require(release.get("prerelease") is False, "Expected a stable draft")
        verify_run(read_json(root, "build.json"), "android-release", head)
        verify_run(read_json(root, "quality.json"), "android-quality", head)
        required_steps = {
            "Verify generated OpenCode SDK integrity",
            "Test generated OpenCode SDK",
            "Analyze generated OpenCode SDK",
            "Analyze",
            "Check the serial test runner",
            "Test",
            "Run Android release lint",
            "Compile test-signed release APK",
            "Verify release artifact exists",
        }
        jobs = read_json(root, "jobs.json").get("jobs", [])
        require(
            any(
                job.get("conclusion") == "success"
                and required_steps <= {
                    step.get("name") for step in job.get("steps", [])
                    if step.get("conclusion") == "success"
                }
                for job in jobs
            ),
            "Full Android quality steps did not pass (APK-only runs are insufficient)",
        )
    elif action == "artifacts":
        name = f"opencode-mobile-{version}.apk"
        require(
            verify_artifact(root / "ci", name) == verify_artifact(root / "draft", name),
            "Draft APK differs from the signed CI artifact",
        )
        notes = verify_notes(root, version)
        require(f"Source commit: `{head}`" in notes, "Release notes have no matching source evidence")
    elif action == "published":
        require(release.get("draft") is False, "Release remains a draft")
        require(release.get("prerelease") is False, "Release remains a prerelease")
        require(read_json(root, "latest.json").get("id") == release.get("id"), "Release is not latest")
        verify_notes(root, version)
    else:
        raise SystemExit("Unknown verification action")


if __name__ == "__main__":
    main()
