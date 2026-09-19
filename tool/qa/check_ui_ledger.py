#!/usr/bin/env python3
"""Validate docs/design/ui-ledger/ledger.json.

Checks:
  1. the file parses and has the expected top-level shape;
  2. page ids and element ids are unique; enums are within the vocabulary;
  3. every element `target`, every `reachedFrom.page`, every navigation root and
     every navigation edge endpoint references an existing page id, and every
     `reachedFrom.element` / edge `element` references an element of that page;
  4. every referenced source file and line exists;
  5. every Dart file under lib/ui/screens/ is referenced by a page or an
     element, or is listed under "Not a page" in README.md (or `notPages`).

Usage: python3 tool/qa/check_ui_ledger.py   (from anywhere; exit code 1 on failure)
"""
from __future__ import annotations

import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LEDGER_DIR = os.path.join(ROOT, "docs", "design", "ui-ledger")

KINDS = {"screen", "sheet", "dialog", "tab", "overlay", "onboarding-step"}
TYPES = {
    "button", "icon-button", "fab", "list-tile", "menu-item", "chip", "toggle",
    "text-field", "slider", "dropdown", "tab", "link", "gesture", "card", "banner",
}
ACTIONS = {
    "navigate", "open-sheet", "open-dialog", "mutate", "toggle-setting", "submit",
    "copy", "external-link", "dismiss", "other",
}


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    path = os.path.join(LEDGER_DIR, "ledger.json")
    try:
        with open(path, encoding="utf-8") as fh:
            ledger = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"FAIL: cannot parse {path}: {exc}")
        return 1

    for key in ("generatedFrom", "pages", "navigation"):
        if key not in ledger:
            errors.append(f"missing top-level key {key!r}")
    pages = ledger.get("pages", [])
    page_ids: dict[str, dict] = {}
    for p in pages:
        pid = p.get("id")
        if not pid:
            errors.append(f"page without id: {p.get('widget')}")
            continue
        if pid in page_ids:
            errors.append(f"duplicate page id {pid}")
        page_ids[pid] = p
        for key in ("title", "kind", "file", "widget", "line", "purpose", "reachedFrom", "gates", "elements"):
            if key not in p:
                errors.append(f"page {pid}: missing {key!r}")
        if p.get("kind") not in KINDS:
            errors.append(f"page {pid}: kind {p.get('kind')!r} not in vocabulary")

    element_owner: dict[str, str] = {}
    line_cache: dict[str, int] = {}

    def check_loc(what: str, file: str | None, line) -> None:
        if not file:
            errors.append(f"{what}: no file")
            return
        full = os.path.join(ROOT, file)
        if file not in line_cache:
            if not os.path.isfile(full):
                errors.append(f"{what}: file {file} does not exist")
                line_cache[file] = -1
                return
            with open(full, encoding="utf-8", errors="replace") as fh:
                line_cache[file] = sum(1 for _ in fh)
        if line_cache[file] < 0:
            return
        if line is None:
            warnings.append(f"{what}: no line")
        elif not isinstance(line, int) or line < 1 or line > line_cache[file]:
            errors.append(f"{what}: line {line!r} outside {file} (1..{line_cache[file]})")

    for pid, p in page_ids.items():
        check_loc(f"page {pid}", p.get("file"), p.get("line"))
        for e in p.get("elements", []):
            eid = e.get("id")
            if not eid:
                errors.append(f"page {pid}: element without id ({e.get('label')})")
                continue
            if eid in element_owner:
                errors.append(f"duplicate element id {eid} ({element_owner[eid]} and {pid})")
            element_owner[eid] = pid
            if e.get("type") not in TYPES:
                errors.append(f"element {eid}: type {e.get('type')!r} not in vocabulary")
            if e.get("action") not in ACTIONS:
                errors.append(f"element {eid}: action {e.get('action')!r} not in vocabulary")
            if not isinstance(e.get("destructive"), bool):
                errors.append(f"element {eid}: destructive must be a boolean")
            if not isinstance(e.get("gates"), list):
                errors.append(f"element {eid}: gates must be a list")
            check_loc(f"element {eid}", e.get("file") or p.get("file"), e.get("line"))

    for pid, p in page_ids.items():
        for e in p.get("elements", []):
            tgt = e.get("target")
            if tgt is not None and tgt not in page_ids:
                errors.append(f"element {e.get('id')}: target {tgt!r} is not a page id")
            if e.get("action") in ("navigate", "open-sheet", "open-dialog") and tgt is None:
                warnings.append(f"element {e.get('id')}: {e.get('action')} without a resolved target"
                                + (f" (unresolved: {e.get('unresolvedTarget')})" if e.get("unresolvedTarget") else ""))
        for r in p.get("reachedFrom", []):
            if r.get("page") not in page_ids:
                errors.append(f"page {pid}: reachedFrom.page {r.get('page')!r} is not a page id")
            el = r.get("element")
            if el is not None and element_owner.get(el) != r.get("page"):
                errors.append(f"page {pid}: reachedFrom.element {el!r} is not an element of {r.get('page')!r}")

    nav = ledger.get("navigation", {})
    for root in nav.get("roots", []):
        if root not in page_ids:
            errors.append(f"navigation root {root!r} is not a page id")
    if not nav.get("roots"):
        errors.append("navigation.roots is empty")
    for ed in nav.get("edges", []):
        if ed.get("from") not in page_ids or ed.get("to") not in page_ids:
            errors.append(f"edge {ed}: endpoint is not a page id")
        if ed.get("element") is not None and element_owner.get(ed["element"]) != ed.get("from"):
            errors.append(f"edge {ed}: element does not belong to the from-page")

    # coverage of lib/ui/screens
    referenced = {p.get("file") for p in pages}
    referenced |= {e.get("file") for p in pages for e in p.get("elements", [])}
    excused = {n.get("file") for n in ledger.get("notPages", [])}
    readme = os.path.join(LEDGER_DIR, "README.md")
    readme_text = ""
    if os.path.isfile(readme):
        with open(readme, encoding="utf-8") as fh:
            readme_text = fh.read()
    if "not a page" not in readme_text.lower():
        errors.append('README.md has no "Not a page" section')
    not_a_page_section = readme_text.lower().split("not a page", 1)[-1]
    screens_dir = os.path.join(ROOT, "lib", "ui", "screens")
    for dirpath, _dirs, files in os.walk(screens_dir):
        for name in sorted(files):
            if not name.endswith(".dart"):
                continue
            rel = os.path.relpath(os.path.join(dirpath, name), ROOT).replace(os.sep, "/")
            if rel in referenced:
                continue
            if rel.lower() in not_a_page_section:
                continue
            if rel in excused:
                errors.append(f"{rel}: excused in ledger.notPages but not listed in README.md under 'Not a page'")
                continue
            errors.append(f"{rel}: not referenced by any page and not listed under 'Not a page'")

    n_elements = len(element_owner)
    print(f"ledger: {len(page_ids)} pages, {n_elements} elements, {len(nav.get('edges', []))} edges, "
          f"{len(nav.get('roots', []))} roots")
    for w in warnings:
        print(f"warn: {w}")
    for err in errors:
        print(f"FAIL: {err}")
    print(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
