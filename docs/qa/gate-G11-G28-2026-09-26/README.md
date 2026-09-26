# gate-G11-G28: copy gates (2026-09-26)

## 1. Scope

- Unit: gates G11 and G28 from `docs/ux-system/revamp/STANDARDS.md` §18 (wave W1, gate). Finish line: `test/ui_glossary_test.dart` checks the COPY-9, COPY-11 and COPY-17 rules (G11) and the glossary extension (G28) mechanically. It passes on today's code and fails on a new violation. Non-goal: fixing today's copy. That work belongs to the screen units and shrinks the baseline.
- Files changed: `test/ui_glossary_test.dart` (the existing glossary tests are unchanged, and the `G11` and `G28` groups are added), `test/ui_glossary_baseline.json` (new ratchet baseline) and this folder.
- Pages (map ids): none. The gate reads `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/**/*.dart`, `test/goldens/**` and `tool/capture/census/**`.
- Specs followed: STANDARDS.md §18.1 rows G11 and G28, §18.2 G11 and G28, rules COPY-6, COPY-7, COPY-8, COPY-9, COPY-10, COPY-11, COPY-12, COPY-17, COPY-21 and LOOK-15.
- Contract problems (PROC-20):
  - G11 says "Collect rendered text from every golden fixture". No golden harness records the text it renders, and this gate may not edit the shared harness (`test/goldens/kit/kit_gallery.dart` and the capture/census core). The gate therefore scans fixture text statically: each string literal in `test/goldens/**` and `tool/capture/census/**` on its own, and each `testWidgets`/`test`/`CensusShot` block as one text, together with every English ARB value. A runtime version needs a text-dump hook in the golden harness (G23/G5 owner). Proposed text: "…collect the text of every string literal and fixture block in the golden and census sources, and every ARB value…" until that hook exists.
  - G11 is "absolute", but today's copy breaks COPY-9 (57 hits) and COPY-11 (159 hits), and no ARB key has a `Technical:` or `Field example:` description yet. Following the build rule for gates, those two checks are ratchets. The contradiction check is absolute because today's copy passes it.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a (the gate has no pages).
- States per page (STATE-20): n/a.
- Deferred states (STATE-21): none.

### What the gate checks

**G11** (group `G11`):

| Test | Rule | Kind |
|---|---|---|
| confirmation titles ask and labels name the act | COPY-9 | ratchet `G11 confirm`, per file |
| no text says two contradicting states at once | COPY-17 | absolute, with a reasoned allowlist |
| technical words only in keys described as Technical: or Field example: | COPY-11 | ratchet `G11 technical`, per ARB key |
| matcher tests: ICU expansion, wrapper following, pair finder, technical patterns | — | unit |

- COPY-9: the test finds every call of `showKitConfirm(` and of the older `showConfirmSheet(` in `lib/`, with comments blanked. It also follows any wrapper that forwards its own parameter as the title or label, for example `confirmTeamControl` or gate_sheet's positional `_confirm(title, message, label)`, so the check runs at the wrapper's callers. It resolves the ARB keys in the `title:` and `confirmLabel:` expressions, including both branches of a conditional. The English title must end with "?", and the Arabic with "؟" or "?", in every ICU plural or select branch. The label must have at least two words and must not be OK, Yes, Continue, Confirm or Delete on its own. A title or label that does not come from the ARB is counted as "not from app_en.arb".
- COPY-17: the pairs are Working + stopped, Paused + idle and Connected + reconnecting, matched as whole words in any case. The allowlist has one entry: `teamUiCardAgentsSummary`, which counts agents per state ("{working} working, … {stopped} stopped"), so no agent is said to be in both states. A second test fails if that entry stops being needed.
- COPY-11: engine words (convoy, formula, bead, rig, city, polecat, refinery, sling, wisp, mayor, gastown, PTY, SSE; the "City" in "Gas City" is a product name and is not counted), loopback addresses (127.0.0.1, localhost, 0.0.0.0), ports, paths with at least two segments or starting with `~/` (slash commands such as `/sessions` are not paths), versions (`x.y.z`, `{version}`) and status codes (HTTP 401). The scan covers both `app_en.arb` and `app_ar.arb`, and skips keys whose English `@description` starts with `Technical:` or `Field example:`.

**G28** (group `G28`, ratchet `G28`, per ARB key over `app_en.arb`). A "label" is an ICU variant of at most four words with no sentence punctuation.

| Pattern | Rule |
|---|---|
| `verb Reload`: a label starting with Reload | COPY-7 |
| `verb Cancel running work`: `^Cancel\s+(run\|task\|job\|work\|install\|download)\b` | COPY-7 |
| `verb Sign out/Close on a server`: a label starting with Sign out or Close on a key naming server, profile, host or connection | COPY-7 |
| `noun label …` / `noun sentence …`: workspace, location, profile, activity, attention and host (host not counted in `teamUi*` keys), Termux setup, On-device setup and Local server; plus session and chat in sentences (the label check stays absolute in the existing test) | COPY-6 |
| `product name …`: OpenCode, Codex, Paseo or Gas City in a label, except on the allowlist of chooser keys (8) and app-name keys (3), each with its reason | COPY-12 |
| `bare …`: a value that is exactly OK, Ok, Yes, No, Continue, Confirm or Submit | COPY-8 |
| `uppercase`: `^[A-Z\s]{4,}$` | LOOK-15 |
| `title over four words`: a `*Title` key where some variant has more than four words, counting each placeholder as one word | COPY-10 |
| `title capital "…"`: a `*Title` key with a capitalised word after the first. Allowed: proper nouns on the list, the names AI Team, Claude Code, OpenCode Mobile, Gas City and Gas Town, acronyms, and the first word after `.`, `:`, `·` or `—` | COPY-10 |
| `body over two sentences`: a `*Body` key | COPY-10 |
| `mode`: "(expert\|simple\|advanced\|basic) mode" | COPY-21 |

**Ratchet mechanics.** The baseline is `test/ui_glossary_baseline.json`, shaped `{gate: {subject: {pattern: count}}}`. The subject is a file for `G11 confirm` and an ARB key for `G11 technical` and `G28`. A test fails when a subject gains a pattern or a count rises. When a gate's counts drop, the test passes and prints that gate's smaller section to commit. `UI_GLOSSARY_WRITE=1` rewrites the file. G31 can read this file as one of the "G28 baseline" files it lists.

## 2. Builds

- Branch `gate/G11-G28`, base `9220f070`, code head: the commit that adds this record (the record is committed with the gate).
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/ui_glossary_test.dart` on today's code | passes, prints no shrink | 20 passed, no shrink print (`pass-on-today.txt`) | PASS |
| 2 | Same, with throwaway violations: a new `lib/ui/screens/zz_gate_violation.dart` calling `showKitConfirm(title: l10n.a2aDeleteAgent, confirmLabel: l10n.mcpRemove)`; `test/goldens/zz_violation_golden_test.dart` with `'Working · stopped'`; five temporary `app_en.arb` keys (`"Open 127.0.0.1:4096 on the rig"`, `zzGateProbeTitle: "Server Settings For Everyone Here"`, `"OK"`, `"Switch to expert mode."`, `"Reload servers"`) | G11 confirm, G11 contradiction, G11 technical and G28 fail and name each offender | 4 tests failed with the expected offenders (`fail-on-violation.txt`); the throwaway files were deleted and the ARB restored with `git checkout` | PASS |
| 3 | Baseline raised by hand (`workspaceDismissNotice` 1 → 2) so today's count is lower | passes and prints the smaller section | passed; printed the "G11 confirm" section (`shrink-prints-baseline.txt`); baseline restored | PASS |
| 4 | `flutter analyze test/ui_glossary_test.dart` | no issues | No issues found | PASS |

## 5. Evidence

- `pass-on-today.txt`: the output of run 1.
- `fail-on-violation.txt`: the output of run 2.
- `shrink-prints-baseline.txt`: the start of run 3's shrink print.
- Baseline counts at creation (`test/ui_glossary_baseline.json`):

  | Gate | Subjects | Hits | Breakdown |
  |---|---|---|---|
  | G11 confirm | 25 files | 57 | fewer than two words 27; English title without "?" 11; Arabic title without "؟" 11; bare OK/Yes/Continue/Confirm/Delete 5; title not from ARB 2; label not from ARB 1 |
  | G11 technical | 80 keys | 159 | version 34 en + 34 ar; engine word 29 en + 18 ar; loopback 13 en + 15 ar; port 8 en + 7 ar; path 1 en |
  | G28 | 264 keys | 276 | title over four words 66; product name 52 (OpenCode 42, Codex 5, Paseo 3, Gas City 2); noun host 37; noun local server 34; noun attention 27; noun activity 10; noun session/chat in sentences 15; body over two sentences 10; uppercase 5; profile(s) 4; location 2; Cancel running work 3; bare Continue 3; title capital 3; Sign out/Close on server 1; Reload 1; workspace 1; Termux setup 1; On-device setup 1 |
  | G11 contradiction | — | 0 | absolute; one allowlisted key |

- Rule evidence (PROC-31):

  | Rule | Test (`test/ui_glossary_test.dart` + `--plain-name`) | Output |
  |---|---|---|
  | COPY-9 | "G11 confirmation titles ask and labels name the act (COPY-9)" | `pass-on-today.txt`, `fail-on-violation.txt` |
  | COPY-17 | "G11 no text says two contradicting states at once (COPY-17)" | same |
  | COPY-11 | "G11 technical words only in keys described as Technical: or Field example: (COPY-11)" | same |
  | COPY-6, COPY-7, COPY-8, COPY-10, COPY-12, COPY-21, LOOK-15 | "G28 labels and copy follow the glossary (COPY-6–8, COPY-10, COPY-12, COPY-21, LOOK-15)" | same |

- Changed test expectations (TEST-19): none. The existing tests are unchanged.
- Goldens changed: none.
- Accessibility: n/a (no UI change).
- Privacy and security: n/a (no credentials, stored data, links or notifications).
- Migration: n/a.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/ui_glossary_test.dart
# after copy fixes land, shrink the baseline:
UI_GLOSSARY_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/ui_glossary_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/ui_glossary_test.dart
```

## 7. NOT proven

- Rendered text: the contradiction check reads fixture source and ARB values, not the text a golden actually renders. A contradiction built at runtime from two separate keys, such as a "Working" chip beside a "stopped" status line, is not caught until the golden harness can dump its text.
- The confirm scan resolves ARB keys by name. A title held in a local variable, such as `development_services_screen.dart`'s switch record or `personal_settings_screens.dart`'s `title` parameter of a non-`Future<bool>` helper, counts as "not from app_en.arb" instead of being resolved.
- The confirm cancel word and body length (the rest of COPY-9) are not checked here; they belong to G37 and `test/kit/kit_confirm_sheet_test.dart`.
- IDs and plugin ids (COPY-11) have no general pattern and are not scanned.
- Not run on a device or emulator (not needed for a static gate).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G11-G28` |
| Enabled | Yes: runs with `flutter test` | `test/ui_glossary_test.dart` |
| Verified | tests only | this record |
| Committed | Yes | branch `gate/G11-G28` |
| Deployed | No | |
| Released | No | |
