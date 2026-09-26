#!/usr/bin/env python3
"""G13: the kit map stays true (STANDARDS.md §18, rule STATE-12).

Three checks over the UX system data, no Flutter needed:

1. Replaces (absolute). Every `replaces` entry anywhere in
   `docs/ux-system/kit-v2.json` names a page (`pageId`) and an element (`id`)
   that exist in `docs/ux-system/map/all.json`.
2. Kit none (ratchet). The number of map elements with `kit: "none"` may only
   go down from the committed baseline.
3. Hidden (ratchet, STATE-12). A page's `whenMissing` value may start with
   "hidden" only for a capability that has no enable flow in
   `docs/ux-system/capabilities.json` (`enableFlows`; a flow whose every step
   says "No path in the app" counts as none). Pairs that already break this
   are listed in the baseline, which may only shrink. Every `whenMissing` key
   must also name a capability that `capabilities.json` knows, so a typo
   cannot slip past the check (a trailing " (proposed)" is ignored).

Usage:
  python3 tool/ux/check_kit_map.py                  # run the gate
  python3 tool/ux/check_kit_map.py --update-baseline  # write a shrunk baseline
  python3 tool/ux/check_kit_map.py --self-test      # built-in fixtures, no pytest

Exit 0 on pass, 1 on a violation, 2 on unreadable input.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_KIT = REPO / "docs/ux-system/kit-v2.json"
DEFAULT_MAP = REPO / "docs/ux-system/map/all.json"
DEFAULT_CAPS = REPO / "docs/ux-system/capabilities.json"
DEFAULT_BASELINE = Path(__file__).resolve().with_name("check_kit_map_baseline.json")

HIDDEN = re.compile(r"^\s*hidden\b", re.IGNORECASE)
NO_PATH = re.compile(r"^\s*no path in the app\b", re.IGNORECASE)
PROPOSED = re.compile(r"\s*\(proposed\)\s*$", re.IGNORECASE)


class InputError(Exception):
    pass


def _load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as err:
        raise InputError(f"cannot read {path}: {err}") from err


def _walk_replaces(node, where):
    """Yields (json path, replaces list) for every `replaces` key."""
    if isinstance(node, dict):
        for key, value in node.items():
            here = f"{where}.{key}" if where else key
            if isinstance(node.get("name"), str):
                here = f"{where}[{node['name']}].{key}" if where else key
            if key == "replaces":
                yield here, value
            else:
                yield from _walk_replaces(value, here)
    elif isinstance(node, list):
        for i, value in enumerate(node):
            yield from _walk_replaces(value, f"{where}[{i}]")


def _capability(key: str) -> str:
    return PROPOSED.sub("", key).strip()


def _enable_flow_capabilities(caps) -> tuple[set[str], set[str]]:
    """Returns (known capability ids, ids that have an in-app enable flow)."""
    known: set[str] = set()
    for row in caps.get("matrix", []):
        if isinstance(row, dict) and isinstance(row.get("capability"), str):
            known.add(row["capability"])
    with_flow: set[str] = set()
    for flow in caps.get("enableFlows", []):
        cap = flow.get("capability") if isinstance(flow, dict) else None
        if not isinstance(cap, str):
            continue
        known.add(cap)
        steps = [s for s in flow.get("steps", []) if isinstance(s, str)]
        if steps and not all(NO_PATH.match(s) for s in steps):
            with_flow.add(cap)
    return known, with_flow


def measure(kit, pages, caps):
    """Returns the facts the gate compares: absolute errors and ratchet counts."""
    errors: list[str] = []
    if not isinstance(pages, list):
        raise InputError("map/all.json must be a list of page records")

    elements: dict[str, set[str]] = {}
    kit_none = 0
    for page in pages:
        page_id = page.get("pageId")
        ids = elements.setdefault(page_id, set())
        for element in page.get("elements", []):
            ids.add(element.get("id"))
            if element.get("kit") == "none":
                kit_none += 1

    replaces_total = 0
    for where, entries in _walk_replaces(kit, ""):
        if not isinstance(entries, list):
            errors.append(f"replaces: {where} is not a list")
            continue
        for entry in entries:
            replaces_total += 1
            if not isinstance(entry, dict) or not isinstance(entry.get("page"), str) or not isinstance(entry.get("element"), str):
                errors.append(f"replaces: {where} has a malformed entry {json.dumps(entry)}")
                continue
            page_id, element_id = entry["page"], entry["element"]
            if page_id not in elements:
                errors.append(f"replaces: {where} names page '{page_id}', which is not in map/all.json")
            elif element_id not in elements[page_id]:
                errors.append(f"replaces: {where} names element '{element_id}' on page '{page_id}', which the map does not list")

    known, with_flow = _enable_flow_capabilities(caps)
    hidden_with_flow: set[str] = set()
    for page in pages:
        when_missing = page.get("whenMissing") or {}
        if not isinstance(when_missing, dict):
            errors.append(f"whenMissing: page '{page.get('pageId')}' has a non-object whenMissing")
            continue
        for key, value in when_missing.items():
            cap = _capability(key)
            if cap not in known:
                errors.append(f"whenMissing: page '{page.get('pageId')}' names capability '{key}', which capabilities.json does not know")
                continue
            if isinstance(value, str) and HIDDEN.match(value) and cap in with_flow:
                hidden_with_flow.add(f"{page.get('pageId')}|{cap}")

    return {
        "errors": errors,
        "replacesTotal": replaces_total,
        "kitNone": kit_none,
        "hiddenWithEnableFlow": sorted(hidden_with_flow),
    }


def compare(facts, baseline):
    """Returns (failures, notes, shrunk baseline or None)."""
    failures = list(facts["errors"])
    notes: list[str] = []
    shrunk = False

    base_none = baseline.get("kitNone")
    if not isinstance(base_none, int):
        failures.append("baseline: kitNone is missing")
    elif facts["kitNone"] > base_none:
        failures.append(
            f"kit none: {facts['kitNone']} map elements have kit \"none\", baseline {base_none}; the count may only go down"
        )
    elif facts["kitNone"] < base_none:
        shrunk = True
        notes.append(f"kit none: {facts['kitNone']} (baseline {base_none}); lower the baseline")

    base_hidden = set(baseline.get("hiddenWithEnableFlow", []))
    now_hidden = set(facts["hiddenWithEnableFlow"])
    for pair in sorted(now_hidden - base_hidden):
        page_id, cap = pair.split("|", 1)
        failures.append(
            f"STATE-12: page '{page_id}' says whenMissing '{cap}': hidden, but '{cap}' has an enable flow; "
            "show one muted line with where it is available and offer the enable flow"
        )
    fixed = sorted(base_hidden - now_hidden)
    if fixed:
        shrunk = True
        notes.append(f"hidden: {len(fixed)} baselined pair(s) no longer hidden: {', '.join(fixed)}; drop them from the baseline")

    new_baseline = None
    if shrunk and not failures:
        new_baseline = dict(baseline)
        new_baseline["kitNone"] = facts["kitNone"]
        new_baseline["hiddenWithEnableFlow"] = sorted(now_hidden)
    return failures, notes, new_baseline


def write_baseline(path: Path, baseline) -> None:
    path.write_text(json.dumps(baseline, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def run(kit_path, map_path, caps_path, baseline_path, update=False, out=sys.stdout) -> int:
    try:
        facts = measure(_load(kit_path), _load(map_path), _load(caps_path))
        baseline = _load(baseline_path) if baseline_path.exists() else None
    except InputError as err:
        print(f"G13 error: {err}", file=out)
        return 2
    if baseline is None:
        if update:
            print(f"G13: refusing to create {baseline_path} with --update-baseline; a new baseline is added by hand in review", file=out)
            return 1
        print(f"G13 error: baseline {baseline_path} is missing", file=out)
        return 2

    failures, notes, new_baseline = compare(facts, baseline)
    print(
        f"G13 kit map: {facts['replacesTotal']} replaces entries checked; "
        f"kit none {facts['kitNone']} (baseline {baseline.get('kitNone')}); "
        f"hidden with an enable flow {len(facts['hiddenWithEnableFlow'])} "
        f"(baseline {len(baseline.get('hiddenWithEnableFlow', []))})",
        file=out,
    )
    for note in notes:
        print(f"  shrank: {note}", file=out)
    if failures:
        for failure in failures:
            print(f"  FAIL {failure}", file=out)
        print(f"G13 FAILED: {len(failures)} violation(s)", file=out)
        if update:
            print("G13: baseline not written; it may only shrink", file=out)
        return 1
    if new_baseline is not None:
        if update:
            write_baseline(baseline_path, new_baseline)
            print(f"G13: wrote the shrunk baseline to {baseline_path}", file=out)
        else:
            print("G13: new baseline (run with --update-baseline to write it):", file=out)
            print(json.dumps({k: new_baseline[k] for k in ("kitNone",)}, ensure_ascii=False), file=out)
            print(f"  hiddenWithEnableFlow: {len(new_baseline['hiddenWithEnableFlow'])} pairs", file=out)
    print("G13 PASSED", file=out)
    return 0


# ----------------------------------------------------------------- self-test

_CAPS = {
    "matrix": [{"capability": c} for c in ("server.any", "server.oc1", "team.on", "team.control", "quota.collector")],
    "enableFlows": [
        {"capability": "server.any", "steps": ["Set up on this phone"]},
        {"capability": "team.on", "steps": ["Settings > Plugins > Add"]},
        {"capability": "team.control", "steps": ["Computer: run the host front"]},
        {"capability": "quota.collector", "steps": ["No path in the app: installed at the server's origin"]},
    ],
}


def _fixture_map():
    return [
        {
            "pageId": "files",
            "whenMissing": {"server.oc1": "hidden (no enable flow)", "quota.collector": "hidden"},
            "elements": [
                {"id": "files-row", "kit": "none"},
                {"id": "files-header", "kit": "KitRow"},
            ],
        },
        {
            "pageId": "team",
            "whenMissing": {"team.on": "hidden: dock drops the tab", "team.control (proposed)": "explains"},
            "elements": [{"id": "team-card", "kit": "none"}],
        },
    ]


def _fixture_kit():
    return {
        "new": [{"name": "KitSheet", "replaces": [{"page": "files", "element": "files-row"}]}],
        "changed": [{"name": "KitRow", "replaces": [{"page": "team", "element": "team-card"}]}],
    }


def _fixture_baseline():
    return {"kitNone": 2, "hiddenWithEnableFlow": ["team|team.on"]}


def _self_test() -> int:
    import copy
    import io

    cases = []

    def case(name, expect_code, mutate=None, expect_text=(), update=False, baseline_check=None):
        cases.append((name, expect_code, mutate, expect_text, update, baseline_check))

    case("today's shape passes", 0)
    case(
        "replaces names a missing element",
        1,
        lambda k, m, c, b: k["new"][0]["replaces"].append({"page": "files", "element": "gone"}),
        ["names element 'gone' on page 'files'"],
    )
    case(
        "replaces names a missing page",
        1,
        lambda k, m, c, b: k["changed"][0]["replaces"].append({"page": "nowhere", "element": "x"}),
        ["names page 'nowhere'"],
    )
    case(
        "malformed replaces entry",
        1,
        lambda k, m, c, b: k["new"][0]["replaces"].append({"page": "files"}),
        ["malformed entry"],
    )
    case(
        "nested replaces key is checked too",
        1,
        lambda k, m, c, b: k.setdefault("notInKit", {}).update({"x": {"replaces": [{"page": "team", "element": "nope"}]}}),
        ["names element 'nope'"],
    )
    case(
        "kit none grows",
        1,
        lambda k, m, c, b: m[0]["elements"].append({"id": "extra", "kit": "none"}),
        ["kit none: 3 map elements", "may only go down"],
    )
    case(
        "kit none shrinks: passes and prints the new baseline",
        0,
        lambda k, m, c, b: m[0]["elements"][0].update({"kit": "KitSheet"}),
        ["shrank: kit none: 1", "new baseline", '"kitNone": 1'],
    )
    case(
        "hidden on a capability with an enable flow",
        1,
        lambda k, m, c, b: m[0]["whenMissing"].update({"server.any": "hidden (Settings needs a connection)"}),
        ["STATE-12: page 'files'", "'server.any'"],
    )
    case(
        "hidden on a (proposed) capability with an enable flow",
        1,
        lambda k, m, c, b: m[1]["whenMissing"].update({"team.control (proposed)": "Hidden rows"}),
        ["STATE-12: page 'team'", "'team.control'"],
    )
    case(
        "hidden where the flow says no path in the app is allowed",
        0,
        lambda k, m, c, b: m[1]["whenMissing"].update({"quota.collector": "hidden"}),
    )
    case(
        "explains on a capability with an enable flow is allowed",
        0,
        lambda k, m, c, b: m[0]["whenMissing"].update({"server.any": "explains (one muted line)"}),
    )
    case(
        "'hiddenly' is not the word hidden",
        0,
        lambda k, m, c, b: m[0]["whenMissing"].update({"server.any": "hiddenly offered"}),
    )
    case(
        "unknown capability",
        1,
        lambda k, m, c, b: m[0]["whenMissing"].update({"server.typo": "explains"}),
        ["'server.typo', which capabilities.json does not know"],
    )
    case(
        "baselined hidden pair fixed: passes and says so",
        0,
        lambda k, m, c, b: m[1]["whenMissing"].update({"team.on": "offers-enable:team-intro"}),
        ["no longer hidden: team|team.on", "new baseline"],
    )
    case(
        "--update-baseline writes a shrunk baseline",
        0,
        lambda k, m, c, b: (m[1]["whenMissing"].update({"team.on": "explains"}), m[0]["elements"][0].update({"kit": "KitSheet"})),
        ["wrote the shrunk baseline"],
        update=True,
        baseline_check=lambda b: b == {"kitNone": 1, "hiddenWithEnableFlow": []},
    )
    case(
        "--update-baseline refuses growth",
        1,
        lambda k, m, c, b: m[0]["elements"].append({"id": "extra", "kit": "none"}),
        ["baseline not written"],
        update=True,
        baseline_check=lambda b: b == _fixture_baseline(),
    )
    case(
        "missing baseline is an input error",
        2,
        lambda k, m, c, b: b.clear(),
        ["baseline", "is missing"],
    )

    failed = 0
    with tempfile.TemporaryDirectory(prefix="g13-self-test-") as tmp:
        root = Path(tmp)
        for name, expect_code, mutate, expect_text, update, baseline_check in cases:
            kit, pages, caps, base = _fixture_kit(), _fixture_map(), copy.deepcopy(_CAPS), _fixture_baseline()
            if mutate:
                mutate(kit, pages, caps, base)
            paths = {n: root / f"{n}.json" for n in ("kit", "map", "caps", "baseline")}
            for n, data in (("kit", kit), ("map", pages), ("caps", caps)):
                paths[n].write_text(json.dumps(data), encoding="utf-8")
            if base:
                write_baseline(paths["baseline"], base)
            elif paths["baseline"].exists():
                paths["baseline"].unlink()
            out = io.StringIO()
            code = run(paths["kit"], paths["map"], paths["caps"], paths["baseline"], update=update, out=out)
            text = out.getvalue()
            problems = []
            if code != expect_code:
                problems.append(f"exit {code}, expected {expect_code}")
            problems += [f"output lacks {t!r}" for t in expect_text if t not in text]
            if baseline_check and not baseline_check(_load(paths["baseline"])):
                problems.append(f"baseline after run is {_load(paths['baseline'])}")
            if problems:
                failed += 1
                print(f"not ok - {name}: {'; '.join(problems)}\n{text}")
            else:
                print(f"ok - {name}")
    print(f"G13 self-test: {len(cases) - failed} of {len(cases)} passed")
    return 1 if failed else 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--kit", type=Path, default=DEFAULT_KIT)
    parser.add_argument("--map", type=Path, default=DEFAULT_MAP)
    parser.add_argument("--capabilities", type=Path, default=DEFAULT_CAPS)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--update-baseline", action="store_true", help="write the baseline when it shrank; never grows it")
    parser.add_argument("--self-test", action="store_true", help="run the built-in fixtures (no pytest)")
    args = parser.parse_args(argv)
    if args.self_test:
        return _self_test()
    return run(args.kit, args.map, args.capabilities, args.baseline, update=args.update_baseline)


if __name__ == "__main__":
    sys.exit(main())
