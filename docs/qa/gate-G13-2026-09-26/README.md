# gate-G13: kit-map consistency check (2026-09-26)

## 1. Scope

- Unit: gate `G13` (W1, gate build). Finish line: `tool/ux/check_kit_map.py` passes on today's data, fails on each kind of violation, and ratchets what today's data already breaks. Non-goal: fixing the map, kit-v2 or product code so the ratchets shrink.
- Files changed: `tool/ux/check_kit_map.py`, `tool/ux/check_kit_map_baseline.json`, this folder.
- Pages (map ids): n/a: a docs-data gate, no page changes.
- Specs followed: STANDARDS.md §18.1 row G13 and §18.2 "G13 (ratchet)"; rule STATE-12; kit-v2.json `gates` G13 ("Map stays true", no Flutter).
- Contract problems (PROC-20): none blocking. Note: kit-v2.json's G13 text also says "when a page is re-mapped after a step, its elements' kit names the v2 part". STANDARDS §18.2 (the rulebook) does not carry that clause, so the gate does not enforce it; on today's data 4 replaced elements already name a different part (`KitChoiceList` over `KitRow+custom` on profile-editor, servers-welcome and team-board-priority-sheet; `KitChecklist` over `KitRow+KitStatusMark+custom` on phone-setup-progress). The coordinator can add it as a further ratchet if wanted.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a.
- States per page (STATE-20): n/a.
- Deferred states (STATE-21): none.

### What the gate checks

| # | Check | Kind | Today |
|---|---|---|---|
| 1 | Every `replaces` entry anywhere in `docs/ux-system/kit-v2.json` (walked recursively, so new sections are covered) is `{page, element}` and names a `pageId` and an element `id` present in `docs/ux-system/map/all.json`. | absolute | 721 entries, 0 missing |
| 2 | The number of map elements with `kit: "none"` is not above the baseline. | ratchet (count) | 809 = baseline 809 |
| 3 | STATE-12: a `whenMissing` value that starts with the word "hidden" is allowed only for a capability with no enable flow. "Has an enable flow" = listed in `capabilities.json` `enableFlows` with at least one step that does not start "No path in the app" (so `quota.collector` counts as none; `server.oc1` and `team.phone` have no flow). A trailing " (proposed)" on the key is ignored. | ratchet (per `page|capability` pair; a new pair fails) | 230 pairs = baseline 230 |
| 3a | Every `whenMissing` key names a capability that `capabilities.json` knows (matrix or enableFlows), so a typo cannot dodge check 3. | absolute | 0 unknown |

Ratchet behaviour: when counts drop the gate still passes, prints "shrank: …" and "new baseline …"; `--update-baseline` writes the shrunk baseline and refuses to write when anything grew or a violation remains. The tool never creates a baseline from nothing.

Baseline counts (`tool/ux/check_kit_map_baseline.json`): `kitNone` 809; `hiddenWithEnableFlow` 230 pairs, by capability: server.any 93, team.on 42, phone.termux 32, server.oc2 29, project.open 9, phone.builtin 7, claude.local 5, model.auth 3, perm.notifications 3, team.control 2, mcp.any 2, server.codex 1, server.paseo 1, voice.model 1.

## 2. Builds

- Branch `gate/G13`, base `9220f070`, code head `0e730d91`.
- No APK (gate agents do not build).

## 3. Devices

None: Python checks over docs data only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `python3 tool/ux/check_kit_map.py` on today's data | exit 0 | "G13 PASSED", exit 0 (`pass-today.txt`) | PASS |
| 2 | Throwaway violation: `make_violation.py` writes copies of the map and kit-v2 to a scratch dir with one missing replaces target, one more `kit: "none"` element and `chat` whenMissing `server.any: hidden`; gate run with `--kit`/`--map` on the copies | exit 1, one FAIL line per violation | 3 FAIL lines, exit 1 (`fail-on-violation.txt`) | PASS |
| 3 | Same copies with `--update-baseline` | baseline not written | "baseline not written; it may only shrink", `git status` clean for the baseline | PASS |
| 4 | `python3 tool/ux/check_kit_map.py --self-test` (17 built-in fixture cases, no pytest) | all pass | 17 of 17 passed (`self-test.txt`) | PASS |

## 5. Evidence

- `pass-today.txt`: run 1.
- `fail-on-violation.txt`: run 2; `make_violation.py`: the throwaway violation (writes only to the directory given as its argument; the repo copies were never edited).
- `self-test.txt`: run 4. The cases cover each check failing, the (proposed) suffix, the "no path in the app" exemption, "hiddenly" not matching, shrink reporting, `--update-baseline` writing only a shrunk baseline and a missing baseline.
- Rule evidence (PROC-31):

  | Rule | Test | Output |
  |---|---|---|
  | STATE-12 | `tool/ux/check_kit_map.py --self-test` "hidden on a capability with an enable flow" | `self-test.txt` |
  | STATE-12 | run 2, third FAIL line | `fail-on-violation.txt` |

- Changed test expectations (TEST-19): none.
- Goldens changed: none.
- Accessibility: n/a: no UI.
- Privacy and security: n/a: reads committed docs JSON only.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
python3 tool/ux/check_kit_map.py
python3 tool/ux/check_kit_map.py --self-test
mkdir -p /tmp/g13 && python3 docs/qa/gate-G13-2026-09-26/make_violation.py /tmp/g13
python3 tool/ux/check_kit_map.py --kit /tmp/g13/kit-v2.json --map /tmp/g13/all.json   # exit 1
```

No Flutter needed (the pinned Flutter is `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter`, unused here).

## 7. NOT proven

- Not run on a device or emulator (nothing to run there).
- Not wired into CI or a pre-commit hook; the integrator decides where it runs.
- Whether each of the 230 baselined hidden pairs really needs a muted line is not judged: the gate reads the map's words, and some "hidden" sub-sheets are reached only from a parent that already explains the gap.
- The kit-v2 clause "re-mapped elements name the v2 part" is not enforced (see Scope).
- The per-area map files (`docs/ux-system/map/*.json`) are not cross-checked against `all.json`.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G13` |
| Enabled | Yes: run by hand or by the integrator | |
| Verified | self-test and real-data runs | this record |
| Committed | Yes | code head `0e730d91` |
| Deployed | No | |
| Released | No | |
