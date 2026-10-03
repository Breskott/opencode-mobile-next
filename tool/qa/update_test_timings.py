#!/usr/bin/env python3
"""Write tool/qa/test_timings.json from Flutter JSON reporter output.

    python3 tool/qa/update_test_timings.py REPORT [REPORT ...]

Each REPORT is a ``flutter test --reporter json`` (or ``--file-reporter
json:<path>``) file, such as the ``chunks/*.report.jsonl`` files that
run_serial_tests.py writes for every chunk, including the CI shard logs. A
file's weight is the sum of its tests' durations (testDone - testStart) with
the hidden loading test included, so compile/load cost counts too. Reports
measured with ``--concurrency=1`` give the most faithful weights. Files absent
from every report keep their previous weight; the sharder gives files with no
weight at all the median.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import run_serial_tests as runner


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Drop previous weights instead of keeping them for unreported files.",
    )
    args = parser.parse_args()
    root = args.root.resolve()
    output = root / runner.TIMINGS_FILE

    milliseconds: dict[str, int] = {}
    if output.is_file() and not args.replace:
        milliseconds.update(runner.load_timings(root))
    measured: dict[str, int] = {}
    for report in args.reports:
        for path, entry in runner.report_suite_results(report).items():
            name = runner.relative_test_path(root, path)
            measured[name] = measured.get(name, 0) + entry["ms"]
    milliseconds.update(measured)
    # Keep only files that still exist so deleted tests do not skew the median.
    existing = {entry["path"] for entry in runner.collect_test_manifest(root)}
    files = {
        name: round(value / 1000, 1)
        for name, value in sorted(milliseconds.items())
        if name in existing
    }
    payload = {
        "schema_version": 1,
        "unit": "seconds",
        "description": (
            "Per-file flutter test time (load + tests) used to balance "
            "run_serial_tests.py shards. Regenerate with "
            "tool/qa/update_test_timings.py."
        ),
        "files": files,
    }
    # One file per line so a refresh reviews as a readable diff.
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Wrote {output.relative_to(root)}: {len(files)} files, "
        f"{len(measured)} measured, {sum(files.values()) / 60:.1f} min total"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
