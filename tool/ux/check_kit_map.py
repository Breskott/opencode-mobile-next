#!/usr/bin/env python3
"""G13: the kit map stays true (STANDARDS.md §18, rule STATE-12).

Checks over the UX system data, no Flutter needed:

1. Replaces (absolute). Every `replaces` entry anywhere in
   `docs/ux-system/kit-v2.json` is `{page, element}` and names a page
   (`pageId`) and an element (`id`) that exist in `docs/ux-system/map/all.json`.
2. Kit values (absolute). Every map element has a `kit` value that is either
   "none" or a '+'-joined list of kit names: `Kit*`, `Product*`,
   `SectionLabel`, with `custom` allowed only as a suffix after a kit name.
3. Kit none (ratchet, per element). The set of `pageId#elementId` pairs with
   `kit: "none"` may only shrink. A new pair fails. A baselined pair may leave
   the map only when its page is gone or its page's `proposal` is `remove`,
   `merge-into:*` or `redesign` (MAP-1); on a `keep` or `fix` page a vanished
   element fails, so deleting records cannot lower the count.
4. whenMissing (STATE-12). Every value is a string whose leading token is in
   the closed vocabulary: explains, offers-enable:<id>, hidden, disabled,
   n/a, same, shown (a non-string value is an absolute error). Three
   ratchets over `page|capability` pairs, each a set that may only shrink:
   - `hiddenWithEnableFlow`: the value hides something (leading "hidden", or
     hidden/hides/vanish/drop anywhere) for a capability that has an enable
     flow in `docs/ux-system/capabilities.json` (`enableFlows`; a flow whose
     every step says "No path in the app" counts as none);
   - `deadRow`: the value leads with "disabled" or says disabled/dim/greyed/
     dead anywhere (STATE-12: never a dead row);
   - `offVocabulary`: the leading token is outside the vocabulary.
   Every `whenMissing` key must name a capability that `capabilities.json`
   knows, so a typo cannot slip past the check (a trailing " (proposed)" is
   ignored).
5. Baseline only shrinks (branch mode). With `--base <ref>`, the committed
   baseline is compared with the baseline at `git merge-base HEAD <ref>`; any
   pair the committed baseline gained fails, so a baseline cannot be raised
   by hand in the commit that adds violations.

Usage:
  python3 tool/ux/check_kit_map.py                    # run the gate
  python3 tool/ux/check_kit_map.py --base feat/phone-setup-v2   # plus the base check
  python3 tool/ux/check_kit_map.py --update-baseline  # write a shrunk baseline
  python3 tool/ux/check_kit_map.py --self-test        # built-in fixtures, no pytest

Exit 0 on pass, 1 on a violation, 2 on unreadable input.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_KIT = REPO / "docs/ux-system/kit-v2.json"
DEFAULT_MAP = REPO / "docs/ux-system/map/all.json"
DEFAULT_CAPS = REPO / "docs/ux-system/capabilities.json"
DEFAULT_BASELINE = Path(__file__).resolve().with_name("check_kit_map_baseline.json")

NO_PATH = re.compile(r"^\s*no path in the app\b", re.IGNORECASE)
PROPOSED = re.compile(r"\s*\(proposed\)\s*$", re.IGNORECASE)

VOCABULARY = ("explains", "hidden", "disabled", "n/a", "same", "shown")
OFFERS_ENABLE = re.compile(r"^offers-enable:[a-z0-9][a-z0-9-]*$")
HIDE_WORDS = re.compile(
    r"\b(hidden|hides?|hiding|vanish(?:es|ed|ing)?|drops?|dropped|dropping)\b", re.IGNORECASE
)
DEAD_WORDS = re.compile(r"\b(disabled|dims?|dimmed|greyed|grayed|dead)\b", re.IGNORECASE)

KIT_PART = re.compile(r"^(Kit[A-Z][A-Za-z0-9]*|Product[A-Z][A-Za-z0-9]*|SectionLabel)$")
REMOVABLE_PROPOSAL = re.compile(r"^(remove|redesign|merge-into:.+)$")

SETS = ("kitNoneElements", "hiddenWithEnableFlow", "deadRow", "offVocabulary")


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


def kit_value_ok(value) -> bool:
    """True for "none" or a '+'-joined list of kit names, `custom` only as a suffix."""
    if not isinstance(value, str):
        return False
    if value == "none":
        return True
    parts = value.split("+")
    if parts[-1] == "custom":
        parts = parts[:-1]
        if not parts:
            return False
    return all(KIT_PART.match(p) for p in parts)


def leading_token(value: str) -> str:
    match = re.match(r"\s*(\S+)", value)
    return match.group(1).lower().rstrip(":;,.") if match else ""


def in_vocabulary(token: str) -> bool:
    return token in VOCABULARY or bool(OFFERS_ENABLE.match(token))


def measure(kit, pages, caps):
    """Returns the facts the gate compares: absolute errors and ratchet sets."""
    errors: list[str] = []
    if not isinstance(pages, list):
        raise InputError("map/all.json must be a list of page records")

    elements: dict[str, set[str]] = {}
    proposals: dict[str, str] = {}
    kit_none: set[str] = set()
    for page in pages:
        page_id = page.get("pageId")
        proposals[page_id] = page.get("proposal") if isinstance(page.get("proposal"), str) else ""
        ids = elements.setdefault(page_id, set())
        for element in page.get("elements", []):
            element_id = element.get("id") if isinstance(element, dict) else None
            if not isinstance(element_id, str):
                errors.append(f"kit: page '{page_id}' has an element without a string id: {json.dumps(element)[:120]}")
                continue
            ids.add(element_id)
            if "kit" not in element:
                errors.append(f"kit: element '{page_id}#{element_id}' has no kit value; write \"none\" or its kit parts")
            elif not kit_value_ok(element["kit"]):
                errors.append(
                    f"kit: element '{page_id}#{element_id}' has kit {json.dumps(element['kit'])}; "
                    "use \"none\" or '+'-joined Kit*/Product*/SectionLabel names, 'custom' only as a suffix"
                )
            elif element["kit"] == "none":
                kit_none.add(f"{page_id}#{element_id}")

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
    dead_row: set[str] = set()
    off_vocabulary: set[str] = set()
    for page in pages:
        page_id = page.get("pageId")
        when_missing = page.get("whenMissing") or {}
        if not isinstance(when_missing, dict):
            errors.append(f"whenMissing: page '{page_id}' has a non-object whenMissing")
            continue
        for key, value in when_missing.items():
            cap = _capability(key)
            if cap not in known:
                errors.append(f"whenMissing: page '{page_id}' names capability '{key}', which capabilities.json does not know")
                continue
            if not isinstance(value, str):
                errors.append(
                    f"whenMissing: page '{page_id}' capability '{key}' has a non-string value {json.dumps(value)}; "
                    "write one string that starts with " + ", ".join(VOCABULARY + ("offers-enable:<id>",))
                )
                continue
            pair = f"{page_id}|{cap}"
            token = leading_token(value)
            if not in_vocabulary(token):
                off_vocabulary.add(pair)
            if (token == "hidden" or HIDE_WORDS.search(value)) and cap in with_flow:
                hidden_with_flow.add(pair)
            if token == "disabled" or DEAD_WORDS.search(value):
                dead_row.add(pair)

    return {
        "errors": errors,
        "replacesTotal": replaces_total,
        "pages": set(elements),
        "proposals": proposals,
        "elements": elements,
        "kitNoneElements": sorted(kit_none),
        "hiddenWithEnableFlow": sorted(hidden_with_flow),
        "deadRow": sorted(dead_row),
        "offVocabulary": sorted(off_vocabulary),
    }


_NEW_MESSAGES = {
    "kitNoneElements": lambda pair: (
        f"kit none: element '{pair}' is hand-built (kit \"none\") and is not in the baseline; build it from kit parts"
    ),
    "hiddenWithEnableFlow": lambda pair: (
        f"STATE-12: page '{pair.split('|', 1)[0]}' hides whenMissing '{pair.split('|', 1)[1]}', but "
        f"'{pair.split('|', 1)[1]}' has an enable flow; show one muted line with where it is available and offer the enable flow"
    ),
    "deadRow": lambda pair: (
        f"STATE-12: page '{pair.split('|', 1)[0]}' leaves whenMissing '{pair.split('|', 1)[1]}' as a dead row "
        "(disabled/dim); a missing capability never shows as a dead row: explain where it is available instead"
    ),
    "offVocabulary": lambda pair: (
        f"whenMissing: page '{pair.split('|', 1)[0]}' capability '{pair.split('|', 1)[1]}' does not start with "
        "one of " + ", ".join(VOCABULARY + ("offers-enable:<id>",))
    ),
}


def compare(facts, baseline):
    """Returns (failures, notes, shrunk baseline or None)."""
    failures = list(facts["errors"])
    notes: list[str] = []
    shrunk = False

    for key in SETS:
        if not isinstance(baseline.get(key), list):
            failures.append(f"baseline: {key} is missing")
    if failures and any(f.startswith("baseline:") for f in failures):
        return failures, notes, None

    for key in SETS:
        base = set(baseline[key])
        now = set(facts[key])
        for pair in sorted(now - base):
            failures.append(_NEW_MESSAGES[key](pair))
        gone = sorted(base - now)
        if not gone:
            continue
        if key == "kitNoneElements":
            fixed, removed_ok, removed_bad = [], [], []
            for pair in gone:
                page_id, element_id = pair.split("#", 1)
                if page_id in facts["pages"] and element_id in facts["elements"][page_id]:
                    fixed.append(pair)
                elif page_id not in facts["pages"] or REMOVABLE_PROPOSAL.match(facts["proposals"].get(page_id, "")):
                    removed_ok.append(pair)
                else:
                    removed_bad.append(pair)
            for pair in removed_bad:
                page_id = pair.split("#", 1)[0]
                failures.append(
                    f"kit none: element '{pair}' left the map, but page '{page_id}' has proposal "
                    f"'{facts['proposals'].get(page_id, '')}'; an element leaves a keep/fix page only by being re-kitted (MAP-1)"
                )
            if fixed:
                shrunk = True
                notes.append(f"kit none: {len(fixed)} element(s) now built from kit parts: {', '.join(fixed)}")
            if removed_ok:
                shrunk = True
                notes.append(f"kit none: {len(removed_ok)} element(s) left with their removed or redesigned page: {', '.join(removed_ok)}")
        else:
            shrunk = True
            notes.append(f"{key}: {len(gone)} baselined pair(s) fixed: {', '.join(gone)}")

    new_baseline = None
    if shrunk and not failures:
        new_baseline = dict(baseline)
        for key in SETS:
            new_baseline[key] = list(facts[key])
    return failures, notes, new_baseline


def _git(cwd: Path, *args) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True)


def base_baseline(baseline_path: Path, ref: str):
    """Returns (merge-base sha, baseline dict at that commit or None)."""
    folder = baseline_path.resolve().parent
    top = _git(folder, "rev-parse", "--show-toplevel")
    if top.returncode != 0:
        raise InputError(f"--base needs a git checkout: {top.stderr.strip()}")
    mb = _git(folder, "merge-base", "HEAD", ref)
    if mb.returncode != 0:
        raise InputError(f"--base {ref}: no merge base with HEAD: {mb.stderr.strip() or mb.stdout.strip()}")
    sha = mb.stdout.strip()
    rel = baseline_path.resolve().relative_to(Path(top.stdout.strip())).as_posix()
    shown = _git(folder, "show", f"{sha}:{rel}")
    if shown.returncode != 0:
        return sha, None
    try:
        return sha, json.loads(shown.stdout)
    except ValueError as err:
        raise InputError(f"baseline at {sha[:10]} is not JSON: {err}") from err


def compare_with_base(baseline, base, sha: str) -> list[str]:
    """Fails for every pair the committed baseline gained over the merge base."""
    failures = []
    for key in SETS:
        if isinstance(base.get(key), list):
            for pair in sorted(set(baseline.get(key, [])) - set(base[key])):
                failures.append(
                    f"baseline: {key} gained '{pair}' over the merge base {sha[:10]}; baselines may only shrink (PROC-13)"
                )
    if isinstance(base.get("kitNone"), int) and not isinstance(base.get("kitNoneElements"), list):
        count = len(baseline.get("kitNoneElements", []))
        if count > base["kitNone"]:
            failures.append(f"baseline: kit none {count} is above {base['kitNone']} at the merge base {sha[:10]}")
    return failures


def write_baseline(path: Path, baseline) -> None:
    path.write_text(json.dumps(baseline, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def run(kit_path, map_path, caps_path, baseline_path, update=False, base_ref=None, out=sys.stdout) -> int:
    try:
        facts = measure(_load(kit_path), _load(map_path), _load(caps_path))
        baseline = _load(baseline_path) if baseline_path.exists() else None
        base = base_baseline(baseline_path, base_ref) if base_ref and baseline is not None else None
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
    if base is not None:
        sha, base_data = base
        if base_data is None:
            notes.append(f"base: no baseline at the merge base {sha[:10]}; nothing to compare")
        else:
            failures += compare_with_base(baseline, base_data, sha)

    def size(key):
        return len(baseline[key]) if isinstance(baseline.get(key), list) else "?"

    print(
        f"G13 kit map: {facts['replacesTotal']} replaces entries checked; "
        f"kit none {len(facts['kitNoneElements'])} (baseline {size('kitNoneElements')}); "
        f"hidden with an enable flow {len(facts['hiddenWithEnableFlow'])} (baseline {size('hiddenWithEnableFlow')}); "
        f"dead rows {len(facts['deadRow'])} (baseline {size('deadRow')}); "
        f"off vocabulary {len(facts['offVocabulary'])} (baseline {size('offVocabulary')})"
        + (f"; base {base[0][:10]}" if base is not None else ""),
        file=out,
    )
    for note in notes:
        print(f"  shrank: {note}" if not note.startswith("base:") else f"  {note}", file=out)
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
            print(json.dumps({k: len(new_baseline[k]) for k in SETS}), file=out)
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
            "proposal": "fix",
            "whenMissing": {"server.oc1": "hidden (no enable flow)", "quota.collector": "hidden"},
            "elements": [
                {"id": "files-row", "kit": "none"},
                {"id": "files-header", "kit": "KitRow"},
                {"id": "files-footer", "kit": "KitRow+KitStatusMark+custom"},
            ],
        },
        {
            "pageId": "team",
            "proposal": "keep",
            "whenMissing": {
                "team.on": "hidden: dock drops the tab",
                "team.control (proposed)": "explains",
                "server.any": "disabled (rows dim)",
            },
            "elements": [{"id": "team-card", "kit": "none"}, {"id": "team-label", "kit": "SectionLabel"}],
        },
        {
            "pageId": "old",
            "proposal": "merge-into:team",
            "whenMissing": {"server.oc1": "system prompt only"},
            "elements": [{"id": "old-row", "kit": "none"}],
        },
    ]


def _fixture_kit():
    return {
        "new": [{"name": "KitSheet", "replaces": [{"page": "files", "element": "files-row"}]}],
        "changed": [{"name": "KitRow", "replaces": [{"page": "team", "element": "team-card"}]}],
    }


def _fixture_baseline():
    return {
        "kitNoneElements": ["files#files-row", "old#old-row", "team#team-card"],
        "hiddenWithEnableFlow": ["team|team.on"],
        "deadRow": ["team|server.any"],
        "offVocabulary": ["old|server.oc1"],
    }


def _page(pages, page_id):
    return next(p for p in pages if p["pageId"] == page_id)


def _self_test() -> int:
    import copy
    import io

    cases = []

    def case(name, expect_code, mutate=None, expect_text=(), update=False, baseline_check=None):
        cases.append((name, expect_code, mutate, expect_text, update, baseline_check))

    def wm(page_id, cap, value):
        return lambda k, m, c, b: _page(m, page_id)["whenMissing"].update({cap: value})

    case("today's shape passes", 0)
    # replaces
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
    # kit values
    for bad in ("custom", "", "None", "KitRow+custom+KitNotice", "Material", "KitRow+"):
        case(
            f"kit value {bad!r} is refused",
            1,
            (lambda v: lambda k, m, c, b: _page(m, "files")["elements"].append({"id": "hand", "kit": v}))(bad),
            ["kit: element 'files#hand' has kit"],
        )
    case(
        "element without a kit key is refused",
        1,
        lambda k, m, c, b: _page(m, "files")["elements"].append({"id": "hand"}),
        ["kit: element 'files#hand' has no kit value"],
    )
    case(
        "Product*, SectionLabel and Kit+custom are accepted",
        0,
        lambda k, m, c, b: _page(m, "files")["elements"].extend(
            [{"id": "a", "kit": "ProductEmptyState"}, {"id": "b", "kit": "SectionLabel+KitRow"}, {"id": "c", "kit": "KitPanel+custom"}]
        ),
    )
    # kit none per element
    case(
        "a new kit none element fails",
        1,
        lambda k, m, c, b: _page(m, "files")["elements"].append({"id": "extra", "kit": "none"}),
        ["kit none: element 'files#extra' is hand-built"],
    )
    case(
        "one fix does not pay for one new kit none element",
        1,
        lambda k, m, c, b: (
            _page(m, "files")["elements"][0].update({"kit": "KitSheet"}),
            _page(m, "files")["elements"].append({"id": "extra", "kit": "none"}),
        ),
        ["kit none: element 'files#extra' is hand-built"],
    )
    case(
        "kit none shrinks: passes and prints the new baseline",
        0,
        lambda k, m, c, b: _page(m, "files")["elements"][0].update({"kit": "KitSheet"}),
        ["now built from kit parts: files#files-row", "new baseline", '"kitNoneElements": 2'],
    )
    case(
        "deleting a kit none element from a keep/fix page fails",
        1,
        lambda k, m, c, b: _page(m, "team")["elements"].pop(0),
        ["element 'team#team-card' left the map", "proposal 'keep'"],
    )
    case(
        "an element may leave with its merge-into page",
        0,
        lambda k, m, c, b: _page(m, "old")["elements"].clear(),
        ["left with their removed or redesigned page: old#old-row"],
    )
    case(
        "an element may leave when its page is gone",
        0,
        lambda k, m, c, b: m.remove(_page(m, "old")),
        ["left with their removed or redesigned page: old#old-row", "offVocabulary: 1 baselined pair(s) fixed"],
    )
    # whenMissing: hidden
    case(
        "hidden on a capability with an enable flow",
        1,
        wm("files", "server.any", "hidden (Settings needs a connection)"),
        ["STATE-12: page 'files' hides whenMissing 'server.any'"],
    )
    case(
        "'<noun> hidden' (hidden not first) is caught",
        1,
        wm("files", "server.any", "the retry row is hidden (evasion)"),
        ["STATE-12: page 'files' hides whenMissing 'server.any'", "does not start with one of"],
    )
    case(
        "'n/a; X hidden on Codex' is caught mid-value",
        1,
        wm("files", "server.any", "n/a; Always allow hidden on Codex"),
        ["STATE-12: page 'files' hides whenMissing 'server.any'"],
    )
    case(
        "'hides', 'vanishes' and 'drops' count as hiding",
        1,
        lambda k, m, c, b: (
            _page(m, "files")["whenMissing"].update({"server.any": "explains; the demo hides it"}),
            _page(m, "team")["whenMissing"].update({"team.control": "explains, but the chip vanishes"}),
        ),
        ["hides whenMissing 'server.any'", "hides whenMissing 'team.control'"],
    )
    case(
        "hidden on a (proposed) capability with an enable flow",
        1,
        wm("team", "team.control (proposed)", "Hidden rows"),
        ["STATE-12: page 'team' hides whenMissing 'team.control'"],
    )
    case(
        "hidden where the flow says no path in the app is allowed",
        0,
        wm("team", "quota.collector", "hidden"),
    )
    case(
        "explains on a capability with an enable flow is allowed",
        0,
        wm("files", "server.any", "explains (one muted line)"),
    )
    case(
        "'hiddenly' is not the word hidden",
        0,
        wm("files", "server.any", "explains hiddenly"),
    )
    # whenMissing: shape and vocabulary
    case(
        "a list value is an absolute error",
        1,
        wm("team", "team.on", ["hidden"]),
        ["capability 'team.on' has a non-string value [\"hidden\"]"],
    )
    case(
        "an object value is an absolute error",
        1,
        wm("files", "server.any", {"state": "hidden"}),
        ["capability 'server.any' has a non-string value"],
    )
    case(
        "a leading token outside the vocabulary fails",
        1,
        wm("files", "server.oc1", "fork rows stay put"),
        ["capability 'server.oc1' does not start with one of"],
    )
    case(
        "offers-enable:<id> is in the vocabulary",
        0,
        wm("files", "server.any", "offers-enable:termux-setup"),
    )
    case(
        "unknown capability",
        1,
        wm("files", "server.typo", "explains"),
        ["'server.typo', which capabilities.json does not know"],
    )
    # whenMissing: dead rows
    case(
        "a new disabled pair fails",
        1,
        wm("files", "server.any", "disabled"),
        ["STATE-12: page 'files' leaves whenMissing 'server.any' as a dead row"],
    )
    case(
        "'rows dim' mid-value counts as a dead row",
        1,
        wm("files", "server.any", "explains, but the rows dim"),
        ["page 'files' leaves whenMissing 'server.any' as a dead row"],
    )
    case(
        "baselined dead row fixed: passes and says so",
        0,
        wm("team", "server.any", "explains (one muted line)"),
        ["deadRow: 1 baselined pair(s) fixed: team|server.any", "new baseline"],
    )
    case(
        "baselined hidden pair fixed: passes and says so",
        0,
        wm("team", "team.on", "offers-enable:team-intro"),
        ["hiddenWithEnableFlow: 1 baselined pair(s) fixed: team|team.on", "new baseline"],
    )
    # baseline handling
    case(
        "--update-baseline writes a shrunk baseline",
        0,
        lambda k, m, c, b: (
            _page(m, "team")["whenMissing"].update({"team.on": "explains"}),
            _page(m, "files")["elements"][0].update({"kit": "KitSheet"}),
        ),
        ["wrote the shrunk baseline"],
        update=True,
        baseline_check=lambda b: b
        == {**_fixture_baseline(), "kitNoneElements": ["old#old-row", "team#team-card"], "hiddenWithEnableFlow": []},
    )
    case(
        "--update-baseline refuses growth",
        1,
        lambda k, m, c, b: _page(m, "files")["elements"].append({"id": "extra", "kit": "none"}),
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
    case(
        "an old-shape baseline (no sets) fails",
        1,
        lambda k, m, c, b: (b.clear(), b.update({"kitNone": 3})),
        ["baseline: kitNoneElements is missing"],
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
            failed += _report(name, code, expect_code, out.getvalue(), expect_text, paths["baseline"], baseline_check)
        failed_base, count_base = _self_test_base(root / "repo")
        failed += failed_base
    total = len(cases) + count_base
    print(f"G13 self-test: {total - failed} of {total} passed")
    return 1 if failed else 0


def _report(name, code, expect_code, text, expect_text, baseline_path=None, baseline_check=None) -> int:
    problems = []
    if code != expect_code:
        problems.append(f"exit {code}, expected {expect_code}")
    problems += [f"output lacks {t!r}" for t in expect_text if t not in text]
    if baseline_check and not baseline_check(_load(baseline_path)):
        problems.append(f"baseline after run is {_load(baseline_path)}")
    if problems:
        print(f"not ok - {name}: {'; '.join(problems)}\n{text}")
        return 1
    print(f"ok - {name}")
    return 0


def _self_test_base(repo: Path) -> tuple[int, int]:
    """Branch-mode cases in a throwaway git repo: the baseline may not grow over the merge base."""
    import io

    repo.mkdir()
    env_git = ["-c", "user.name=g13", "-c", "user.email=g13@example.invalid", "-c", "commit.gpgsign=false"]

    def git(*args):
        subprocess.run(["git", "-C", str(repo), *env_git, *args], check=True, capture_output=True)

    git("init", "-q", "-b", "base")
    paths = {n: repo / f"{n}.json" for n in ("kit", "map", "caps")}
    for n, data in (("kit", _fixture_kit()), ("map", _fixture_map()), ("caps", _CAPS)):
        paths[n].write_text(json.dumps(data), encoding="utf-8")
    baseline_path = repo / "tool" / "baseline.json"
    baseline_path.parent.mkdir()
    git("add", "-A")
    git("commit", "-q", "-m", "no baseline yet")
    git("tag", "before")
    write_baseline(baseline_path, _fixture_baseline())
    git("add", "-A")
    git("commit", "-q", "-m", "baseline")
    git("switch", "-q", "-c", "feature")

    failed = 0
    count = 0

    def check(name, expect_code, expect_text, ref="base"):
        nonlocal failed, count
        count += 1
        out = io.StringIO()
        code = run(paths["kit"], paths["map"], paths["caps"], baseline_path, base_ref=ref, out=out)
        failed += _report(name, code, expect_code, out.getvalue(), expect_text)

    check("--base: unchanged baseline passes", 0, ["G13 PASSED", "base "])
    check("--base: no baseline at the merge base is a note", 0, ["no baseline at the merge base"], ref="before")

    # The commit that adds a hidden violation also raises the baseline by hand.
    pages = _fixture_map()
    _page(pages, "files")["whenMissing"]["server.any"] = "hidden"
    _page(pages, "files")["elements"].append({"id": "extra", "kit": "none"})
    paths["map"].write_text(json.dumps(pages), encoding="utf-8")
    raised = _fixture_baseline()
    raised["hiddenWithEnableFlow"].append("files|server.any")
    raised["kitNoneElements"].append("files#extra")
    write_baseline(baseline_path, raised)
    git("commit", "-q", "-am", "violation plus a raised baseline")
    check(
        "--base: a baseline raised in the violating commit fails",
        1,
        ["hiddenWithEnableFlow gained 'files|server.any' over the merge base", "kitNoneElements gained 'files#extra'"],
    )
    check("--base: an unknown ref is an input error", 2, ["no merge base"], ref="no-such-ref")
    return failed, count


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--kit", type=Path, default=DEFAULT_KIT)
    parser.add_argument("--map", type=Path, default=DEFAULT_MAP)
    parser.add_argument("--capabilities", type=Path, default=DEFAULT_CAPS)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--base", metavar="REF", help="also fail if the baseline gained a pair over git merge-base HEAD REF")
    parser.add_argument("--update-baseline", action="store_true", help="write the baseline when it shrank; never grows it")
    parser.add_argument("--self-test", action="store_true", help="run the built-in fixtures (no pytest)")
    args = parser.parse_args(argv)
    if args.self_test:
        return _self_test()
    return run(args.kit, args.map, args.capabilities, args.baseline, update=args.update_baseline, base_ref=args.base)


if __name__ == "__main__":
    sys.exit(main())
