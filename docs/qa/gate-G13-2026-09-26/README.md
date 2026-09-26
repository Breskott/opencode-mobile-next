# gate-G13: kit-map consistency check (2026-09-26)

## 1. Scope

- Unit: gate `G13` (W1, gate build). Finish line: `tool/ux/check_kit_map.py` passes on today's data, fails on each kind of violation, ratchets what today's data already breaks, and runs inside `flutter test` through `test/kit_map_gate_test.dart`. Non-goal: fixing the map, kit-v2 or product code so the ratchets shrink.
- Files changed: `tool/ux/check_kit_map.py`, `tool/ux/check_kit_map_baseline.json`, `test/kit_map_gate_test.dart`, this folder.
- Pages (map ids): n/a: a docs-data gate, no page changes.
- Specs followed: STANDARDS.md §18.1 row G13 and §18.2 "G13 (ratchet)"; rule STATE-12 (both clauses); MAP-1 (which pages may lose elements); PROC-13 (baselines only shrink); kit-v2.json `gates` G13 ("Map stays true", no Flutter).
- Contract problems (PROC-20), for the integrator:
  - STANDARDS §18.1 still lists G13 as "missing". With the flutter-test twin it now exists and runs in the full suite; the status flip belongs to whoever owns STANDARDS.md (not edited here, shared file).
  - PROC-13 and G31 name G2/G7/G17/G21/G24/G26–G29 baselines, not G13's. G31 (`tool/qa/check_ratchets_only_shrink.py`) is another gate's file, so this gate protects its own baseline instead (`--base`, check 6). Adding `tool/ux/check_kit_map_baseline.json` to the PROC-13 and G31 lists would be a belt-and-braces follow-up.
  - kit-v2.json's G13 text also says "when a page is re-mapped after a step, its elements' kit names the v2 part". STANDARDS §18.2 does not carry that clause, so it is not enforced; on today's data 4 replaced elements name a different part (`KitChoiceList` over `KitRow+custom` on profile-editor, servers-welcome and team-board-priority-sheet; `KitChecklist` over `KitRow+KitStatusMark+custom` on phone-setup-progress).
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a.
- States per page (STATE-20): n/a.
- Deferred states (STATE-21): none.

### What the gate checks

| # | Check | Kind | Today |
|---|---|---|---|
| 1 | Every `replaces` entry anywhere in `docs/ux-system/kit-v2.json` (walked recursively) is `{page, element}` and names a `pageId` and an element `id` present in `docs/ux-system/map/all.json`. | absolute | 721 entries, 0 missing |
| 2 | Every map element has a string `id` and a `kit` value that is `"none"` or a `+`-joined list of `Kit*`, `Product*` or `SectionLabel` names, with `custom` only as a final suffix after one of them. `"custom"`, `""`, `"None"`, `"Material"` and a missing key fail. | absolute | 0 bad values |
| 3 | Kit none per element: the set of `pageId#elementId` pairs with `kit: "none"` may only shrink; a new pair fails even when another element was fixed in the same change. A baselined pair may leave the map only if its page is gone or its page's `proposal` is `remove`, `merge-into:*` or `redesign` (MAP-1); vanishing from a `keep`/`fix` page fails, so deleting records cannot lower the count. | ratchet (set) | 809 = baseline 809 |
| 4a | Every `whenMissing` value is a string. A list or object is an absolute error. | absolute | 0 |
| 4b | Closed vocabulary: the leading token (lower-cased, trailing `:;,.` dropped) is one of `explains`, `offers-enable:<id>`, `hidden`, `disabled`, `n/a`, `same`, `shown`. Other leads are ratcheted per `page|capability`. | ratchet (set) | 3 = baseline 3 |
| 4c | STATE-12 hidden clause: a value that leads with `hidden`, or says hidden/hides/hiding/vanish*/drop* anywhere, is allowed only for a capability with no enable flow (listed in `capabilities.json` `enableFlows` with at least one step that does not start "No path in the app"; a trailing " (proposed)" on the key is ignored). | ratchet (set) | 235 = baseline 235 |
| 4d | STATE-12 dead-row clause: a value that leads with `disabled`, or says disabled/dim/dims/dimmed/greyed/grayed/dead anywhere, is a dead row, for any capability. | ratchet (set) | 15 = baseline 15 |
| 5 | Every `whenMissing` key names a capability `capabilities.json` knows (matrix or enableFlows), so a typo cannot dodge check 4. | absolute | 0 unknown |
| 6 | Branch mode, `--base <ref>`: every list in the committed baseline is a subset of the same list at `git merge-base HEAD <ref>`; a pair added by hand fails. No baseline at the merge base is a note, not a failure. The flutter-test twin passes `--base feat/phone-setup-v2` (override with `G13_BASE`) when that ref exists locally. | absolute | no baseline at base `9220f070` yet (new file) |

Ratchet behaviour: when a set shrinks the gate still passes, prints "shrank: …" and the new sizes; `--update-baseline` writes the shrunk baseline and refuses to write when anything grew or any failure remains. The tool never creates a baseline from nothing.

Baseline (`tool/ux/check_kit_map_baseline.json`), all lists of pairs:

- `kitNoneElements` 809 `pageId#elementId` pairs (was a count of 809; now per element).
- `hiddenWithEnableFlow` 235 pairs: server.any 98, team.on 42, phone.termux 32, server.oc2 29, project.open 9, phone.builtin 7, claude.local 5, model.auth 3, perm.notifications 3, team.control 2, mcp.any 2, server.codex 1, server.paseo 1, voice.model 1. The 5 pairs new since the first build came from matching hide words anywhere: `timeline-sheet|server.any` ("fork rows hidden without sessionFork"), `permission-sheet|server.any` ("n/a; Always allow hidden on Codex"), `development-services|server.any` ("… Start/Logs hidden"), `session-approvals-sheet|server.any` ("demo hides it"), `embedded-chat-nudge-slot|server.any` ("… hidden otherwise").
- `deadRow` 15 pairs: server.any 8, project.open 5, phone.termux 2 (13 leading "disabled", plus `local-agent-page|phone.termux` and `embedded-local-agent-onboarding-block|phone.termux`, which say "dead end").
- `offVocabulary` 3 pairs: `chat-pending-photo-sheet|perm.camera` ("system prompt …"), `profile-monitor|perm.battery` ("not mentioned …"), `timeline-sheet|server.any` ("fork rows hidden …").

### Review of 2026-09-26: findings and what changed

| # | Finding | Verdict | Change |
|---|---|---|---|
| 1 | Hidden check only matched values starting "hidden" | confirmed (reproduced: "the retry row is hidden (evasion)" passed) | closed vocabulary (4b) plus hide words anywhere (4c); 5 existing pairs baselined incl. `timeline-sheet|server.any`; self-test cases for "<noun> hidden", mid-value "n/a; … hidden", hides/vanishes |
| 2 | Non-string whenMissing values skipped | confirmed (`["hidden"]` passed) | absolute error (4a); self-test cases for a list and an object |
| 3 | kit-none count ignored other spellings and could be traded or lowered by deleting records | confirmed | kit value check (2); per-element set (3) with the MAP-1 removal rule |
| 4 | Dead-row clause of STATE-12 unchecked | confirmed (13 leading "disabled") | `deadRow` ratchet (4d) |
| 5 | Baseline could be raised by hand | confirmed | `--base` merge-base comparison (6), used by the flutter-test twin; G31/PROC-13 list left to its owner (see Scope) |
| 6 | Gate ran nowhere | confirmed | `test/kit_map_gate_test.dart` runs the gate and its self-test through `Process.runSync`; STANDARDS §18.1 status flip left to the integrator |
| 7 | Docstring said `pageId`/`id` for replaces keys | confirmed | docstring now says `{page, element}` |

## 2. Builds

- Branch `gate/G13`, base `9220f070`; first build `0e730d91`, review fixes `7cadcb53`.
- No APK (gate agents do not build).

## 3. Devices

None: Python checks over docs data plus a flutter-test wrapper.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `python3 tool/ux/check_kit_map.py --base feat/phone-setup-v2` on today's data | exit 0 | "G13 PASSED", exit 0 (`pass-today.txt`) | PASS |
| 2 | Throwaway violations: `make_violation.py` writes copies of the map and kit-v2 to a scratch dir with a missing replaces target, a new kit-none element, elements with kit `custom`/`""`/`None`/no key, chat `server.any` = "the retry row is hidden (evasion)", chat `team.on` = `["hidden"]`, chat `project.open` = "disabled (rows dim)", and one baselined kit-none element deleted from the `fix` page worktrees; gate run with `--kit`/`--map` on the copies | exit 1, one FAIL per violation | 11 FAIL lines, exit 1 (`fail-on-violation.txt`) | PASS |
| 3 | Same copies with `--update-baseline` | baseline not written | "baseline not written; it may only shrink", baseline byte-identical (`fail-on-violation.txt`) | PASS |
| 4 | Throwaway raised baseline: the real map gets a new kit-none element and hides chat `server.any`, and the working-tree baseline gains both pairs by hand; run without and with `--base HEAD` | without: passes (the hole); with: exit 1 | without: PASSED; with: 2 "gained … over the merge base" FAIL lines, exit 1 (`base-fail-on-raised-baseline.txt`); both files restored with `git checkout` | PASS |
| 5 | `python3 tool/ux/check_kit_map.py --self-test` (40 fixture cases plus 4 branch-mode cases in a throwaway git repo) | all pass | 44 of 44 passed (`self-test.txt`) | PASS |
| 6 | `tool/qa/machine_lock.sh test -- $F test -j 1 test/kit_map_gate_test.dart` | 2 tests pass | All tests passed (`dart-pass-today.txt`) | PASS |
| 7 | Same test with a throwaway element `{"id": "g13-throwaway", "kit": "custom"}` added to chat in the real map (restored after) | the test fails | "Expected: <0> Actual: <1>" with the kit FAIL line, exit 1 (`dart-fail-on-violation.txt`) | PASS |
| 8 | `tool/qa/machine_lock.sh analyze -- $F analyze test/kit_map_gate_test.dart` | clean | No issues found | PASS |

## 5. Evidence

- `pass-today.txt`: run 1. `fail-on-violation.txt`: runs 2 and 3; `make_violation.py`: the throwaway violations (writes only to the directory given as its argument; the repo copies were never edited). `base-fail-on-raised-baseline.txt`: run 4. `self-test.txt`: run 5. `dart-pass-today.txt` and `dart-fail-on-violation.txt`: runs 6 and 7.
- Rule evidence (PROC-31):

  | Rule | Test | Output |
  |---|---|---|
  | STATE-12 (hidden only without an enable flow) | self-test "hidden on a capability with an enable flow", "'<noun> hidden' (hidden not first) is caught", "'n/a; X hidden on Codex' is caught mid-value"; run 2 | `self-test.txt`, `fail-on-violation.txt` |
  | STATE-12 (never a dead row) | self-test "a new disabled pair fails", "'rows dim' mid-value counts as a dead row"; run 2 | `self-test.txt`, `fail-on-violation.txt` |
  | MAP-1 (elements leave only with removed/merged/redesigned pages) | self-test "deleting a kit none element from a keep/fix page fails"; run 2 | `self-test.txt`, `fail-on-violation.txt` |
  | PROC-13 (baselines only shrink) | self-test "--base: a baseline raised in the violating commit fails"; run 4 | `self-test.txt`, `base-fail-on-raised-baseline.txt` |

- Changed test expectations (TEST-19): none (new test file only).
- Goldens changed: none.
- Accessibility: n/a: no UI.
- Privacy and security: n/a: reads committed docs JSON and runs `git merge-base`/`git show` read-only.
- Migration: the baseline file changed shape (the `kitNone` count became the `kitNoneElements` list; `deadRow` and `offVocabulary` added). The tool rejects the old shape with "baseline: kitNoneElements is missing"; `--base` against an old-shape baseline compares the list size with the old count.

## 6. How to reproduce

```bash
python3 tool/ux/check_kit_map.py --base feat/phone-setup-v2
python3 tool/ux/check_kit_map.py --self-test
mkdir -p "$TMPDIR/g13" && python3 docs/qa/gate-G13-2026-09-26/make_violation.py "$TMPDIR/g13"
python3 tool/ux/check_kit_map.py --kit "$TMPDIR/g13/kit-v2.json" --map "$TMPDIR/g13/all.json"   # exit 1
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/kit_map_gate_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (nothing to run there). Not wired into CI or a pre-commit hook; it runs in the full `flutter test` suite through `test/kit_map_gate_test.dart`, which needs `python3` and `git` on the PATH (as the integrator's machine has).
- The `--base` check in the flutter-test twin only runs where `feat/phone-setup-v2` (or `G13_BASE`) resolves locally; elsewhere the twin runs the gate without it. The integration base's name is an assumption the integrator may override with `G13_BASE`.
- The gate reads the map's words, not the app. It cannot tell whether a page that says "explains" really shows one muted line with where the capability is available, nor whether "offers-enable:<id>" leads to a working flow; the hide and dead-row word lists catch today's phrasings, not every possible one (the closed vocabulary limits the lead, not the rest of the sentence).
- Whether each of the 235 baselined hidden pairs and 15 dead-row pairs really needs a muted line is not judged: some "hidden" sub-sheets are reached only from a parent that already explains the gap.
- Kit names are checked by shape (`Kit*`, `Product*`, `SectionLabel`), not against the `kit.dart` export list or kit-v2's part names, so a misspelt `KitRwo` passes check 2.
- The kit-v2 clause "re-mapped elements name the v2 part" is not enforced (see Scope).
- The per-area map files (`docs/ux-system/map/*.json`) are not cross-checked against `all.json`.
- STANDARDS §18.1 still says G13 "missing" and PROC-13/G31 do not list this baseline; both are left to their owners (see Scope).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G13` |
| Enabled | Yes: in the full `flutter test` suite via `test/kit_map_gate_test.dart`, and by hand | |
| Verified | self-test, real-data, throwaway-violation and flutter-test runs | this record |
| Committed | Yes | code head `7cadcb53` |
| Deployed | No | |
| Released | No | |
