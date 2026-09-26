# gate-G11-G28: copy gates (2026-09-26)

## 1. Scope

- Unit: gates G11 and G28 from `docs/ux-system/revamp/STANDARDS.md` §18 (wave W1, gate). Finish line: `test/ui_glossary_test.dart` checks the COPY-9, COPY-11 and COPY-17 rules (G11) and the glossary extension (G28) mechanically. It passes on today's code and fails on a new violation. Non-goal: fixing today's copy. That work belongs to the screen units and shrinks the baseline.
- Files changed: `test/ui_glossary_test.dart` (the existing glossary tests are unchanged, and the `G11` and `G28` groups are added), `test/ui_glossary_baseline.json` (new ratchet baseline) and this folder.
- Pages (map ids): none. The gate reads `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/**/*.dart`, `test/goldens/**` and `tool/capture/census/**`.
- Specs followed: STANDARDS.md §18.1 rows G11 and G28, §18.2 G11 and G28, rules COPY-6, COPY-7, COPY-8, COPY-9, COPY-10, COPY-11, COPY-12, COPY-17, COPY-21 and LOOK-15.
- Contract problems (PROC-20):
  1. **G11 rendered text (COPY-17).** What it says: "Collect rendered text from every golden fixture and fail on a contradiction pair" (`docs/ux-system/revamp/STANDARDS.md:1129`). Why it is wrong: no golden or census harness records the text it renders, and this gate may not edit the shared harness (`test/goldens/kit/kit_gallery.dart:88` `kitGalleryShot`, `tool/capture/census/census_core.dart:69` `CensusShot`), so the rule cannot be tested as written. The gate uses a static proxy instead (`test/ui_glossary_test.dart:917` `_renderedOnly`, `test/ui_glossary_test.dart:967` `_fixtureTexts`). The proxy reads each string literal on its own, and each `CensusShot`, `kitGalleryShot`, or `test`/`testWidgets` holding neither, as one text. It skips literals that are never rendered: test and group descriptions, a shot's page name, `state:` and `note:`, a gallery `name:`, `Key`/`ValueKey`/`ObjectKey`/`GlobalKey` and `matchesGoldenFile` arguments, and file-name literals. It still misses contradictions built at runtime, and text kept in a helper outside the shot's call. Proposed replacement text: "Until the golden and census harnesses dump the text they render (a hook owned by G4/G5), collect the string literals of each census or gallery shot in `test/goldens/**` and `tool/capture/census/**`, without descriptions, names, state tags, notes, keys and file names, and every English ARB value; fail on a contradiction pair in one literal, one shot or one ARB value. With the hook, check the dumped text of each shot instead." blocks: false (the proxy runs absolute and passes today; the gap is under NOT proven).
  2. **G11 absolute vs today's copy (COPY-9, COPY-11).** What it says: G11 is "absolute, with a reasoned allowlist" (`docs/ux-system/revamp/STANDARDS.md:1129`). Why it is wrong: today's copy breaks COPY-9 in 55 places and COPY-11 in 186, and no ARB key has a `Technical:` or `Field example:` description yet, so an absolute gate cannot pass on today's code. Following the gate build rule, those two checks are ratchets (sections `G11 confirm` and `G11 technical` in `test/ui_glossary_baseline.json`, enforced at `test/ui_glossary_test.dart:1361`). The contradiction check stays absolute. Proposed replacement text: "**G11 (ratchet for COPY-9 and COPY-11, absolute for COPY-17, with a reasoned allowlist).** … COPY-9 is counted per file and COPY-11 per ARB key in `test/ui_glossary_baseline.json` (sections `G11 confirm` and `G11 technical`), which may only shrink." blocks: false.
  3. **G31 does not cover this baseline (PROC-13, KIT-44).** What it says: G31 checks "any G2/G7/G17/G21/G24/G26/G27/G28/G29 baseline", and "a key may disappear only if its file no longer exists at HEAD" (`docs/ux-system/revamp/STANDARDS.md:1148`). Why it is wrong: (a) the file also holds the G11 ratchets (`test/ui_glossary_test.dart:1345-1346`), which G31's list does not name. (b) In `G11 technical` and `G28` the subjects are ARB keys, not files. When copy is fixed, the key's count reaches zero and the subject leaves the baseline while `app_en.arb` still exists, so G31's rule would reject every fix. Proposed replacement text: "…or any G2/G7/G11/G17/G21/G24/G26/G27/G28/G29 baseline (in `test/ui_glossary_baseline.json`: sections `G11 confirm`, `G11 technical` and `G28`)…; a file subject may disappear only if its file no longer exists at HEAD; an ARB-key subject (sections `G11 technical` and `G28`) may disappear when its counts reach zero or the key is removed from `app_en.arb`." blocks: false (G31 is not built yet).
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
| matcher tests: ICU expansion, wrapper following and outermost keys, pair finder, rendered-only scene text, technical patterns | — | unit |

- COPY-9: the test finds every call of `showKitConfirm(` and of the older `showConfirmSheet(` in `lib/`, with comments blanked. It also follows any wrapper that forwards its own parameter as the title or label, for example `confirmTeamControl` or gate_sheet's positional `_confirm(title, message, label)`, so the check runs at the wrapper's callers. In the `title:` and `confirmLabel:` expressions it resolves only the **outermost** ARB key: the key read at the top level of the expression (`l10n.x`, `copy.x(…)`, `lookupAppLocalizations(…).x`), in each branch of a top-level `?:` (not the condition) or `??`. A key inside that key's argument list is a placeholder value and is not checked (`l10n.e7SettingsDisconnectTitle(name ?? l10n.e7SettingsUi16)` checks only `e7SettingsDisconnectTitle`). The English title must end with "?", and the Arabic with "؟" or "?", in every ICU plural or select branch. The label must have at least two words and must not be OK, Yes, Continue, Confirm or Delete on its own. A title or label with no top-level ARB key, such as a string literal or a local variable, is counted as "not from app_en.arb".
- COPY-17: the pairs are Working + stopped, Paused + idle and Connected + reconnecting, matched as whole words in any case, over every English ARB value and the rendered-text proxy described in contract problem 1. The allowlist has one entry: `teamUiCardAgentsSummary`, which counts agents per state ("{working} working, … {stopped} stopped"), so no agent is said to be in both states. A second test fails if that entry stops being needed.
- COPY-11, over both `app_en.arb` and `app_ar.arb`, skipping keys whose English `@description` starts with `Technical:` or `Field example:`. Every match is counted, not only the first, so a key with a baseline gains a failure when it gains a hit:
  - engine words: convoy, formula, bead, rig, city, polecat, refinery, sling, wisp, mayor, gastown, PTY, SSE. The "City" in "Gas City" is a product name and is not counted.
  - `address`: any IPv4 address or CIDR range (127.0.0.1, 0.0.0.0, 100.64.0.0/10), and localhost.
  - `port`: `:4096`, `port 22`.
  - `path`: absolute and home paths of two or more segments (`/data/local/tmp`, `~/.config`), and relative paths that end in a file name (`docs/ai-team-host.md`). Slash commands such as `/sessions` are not paths.
  - `version`: `x.y.z` anywhere; `x.y` after `v`, "version" or a capitalised name ("A2A 1.0", "Ubuntu Base 24.04"), unless a unit follows ("Free 1.5 GB", "2.5 minutes"); and a `{…version…}` placeholder.
  - `status code`: HTTP 401, error 500.

**G28** (group `G28`, ratchet `G28`, per ARB key over `app_en.arb`). A "label" is an ICU variant of at most four words with no sentence punctuation. A trailing `…` or `:` is stripped first, so "Ask Codex…" and "Reload…" are labels. The older glossary tests keep their own stricter label rule.

| Pattern | Rule |
|---|---|
| `verb Reload`: a label starting with Reload | COPY-7 |
| `verb Cancel running work`: `^Cancel\s+(run\|task\|job\|work\|install\|download)\b` | COPY-7 |
| `verb Sign out/Close on a server`: a label starting with Sign out or Close on a key naming server, profile, host or connection | COPY-7 |
| `noun label …` / `noun sentence …`: workspace, location, profile, activity, attention and host (host not counted in `teamUi*` keys), Termux setup, On-device setup and Local server. Also session and chat in any variant the existing absolute label test does not cover, including labels that end in "…" | COPY-6 |
| `product name …`: OpenCode, Codex, Paseo or Gas City in a label, except on the allowlist of chooser keys (8) and app-name keys (3), each with its reason | COPY-12 |
| `bare …`: a value that is exactly OK, Ok, Yes, No, Continue, Confirm or Submit | COPY-8 |
| `uppercase`: `^[A-Z\s]{4,}$` | LOOK-15 |
| `title over four words`: a `*Title` key where some variant has more than four words, counting each placeholder as one word | COPY-10 |
| `title capital "…"`: a `*Title` key with a capitalised word after the first. Allowed: proper nouns on the list, the names AI Team, Claude Code, OpenCode Mobile, Gas City and Gas Town, acronyms, and the first word after `.`, `:`, `·` or `—` | COPY-10 |
| `body over two sentences`: a `*Body` key | COPY-10 |
| `mode`: "(expert\|simple\|advanced\|basic) mode" | COPY-21 |

**Ratchet mechanics.** The baseline is `test/ui_glossary_baseline.json`, shaped `{gate: {subject: {pattern: count}}}`. The subject is a file for `G11 confirm` and an ARB key for `G11 technical` and `G28`. A test fails when a subject gains a pattern or a count rises. When a gate's counts drop, the test passes and prints that gate's smaller section to stdout (`stdout.writeln`, with no analyzer ignore) for you to commit. `UI_GLOSSARY_WRITE=1` rewrites the file. G31 should read all three sections (contract problem 3).

## 2. Builds

- Branch `gate/G11-G28`, base `9220f070`, code head `842db6e7`. The gate code and baseline are final at that commit, and only this QA folder changes after it.
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

All runs are at code head `842db6e7`.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/ui_glossary_test.dart` on today's code | passes, prints no shrink | 21 passed, no shrink print (`pass-on-today.txt`) | PASS |
| 2 | Same, with throwaway violations. (a) A new `lib/ui/screens/zz_gate_violation.dart` calling `showKitConfirm(title: l10n.a2aDeleteAgent, confirmLabel: l10n.mcpRemove)`, plus a second call whose outer keys comply but whose arguments hold `l10n.mcpRemove`. (b) `test/goldens/zz_violation_golden_test.dart`: a `testWidgets('KitTaskMark working → stopped')` with one gallery shot named `zz_working_stopped` holding a `ValueKey('working-stopped')`, one gallery shot showing `Text('Working')` and `Text('stopped')`, and a `CensusShot('agent-working', state: 'stopped')`. (c) Six temporary `app_en.arb` keys: "Open 127.0.0.1:4096 on the rig, read docs/setup.md, speak A2A 1.0 and allow 10.0.0.0/8", "Server Settings For Everyone Here" (`*Title`), "OK", "Switch to expert mode.", "Reload…" and "Ask Codex…". (d) `a2aSupportedConnection` given a second "A2A 1.0". | G11 confirm, G11 contradiction, G11 technical and G28 fail and name each offender. The placeholder keys, the test description, the gallery name, the key and the census state tag are not reported. | 4 tests failed with exactly the expected offenders. Only the gallery shot showing both words is reported, and the second A2A hit shows as "rose from 1 to 2" (`fail-on-violation.txt`). The throwaway files were deleted and the ARB restored with `git checkout`. | PASS |
| 3 | Baseline raised by hand (`a2aSupportedConnection` `en version "A2A 1.0"` 1 → 2) so today's count is lower | passes and prints the smaller section | passed; printed the "G11 technical" section with the count back at 1 (`shrink-prints-baseline.txt`); baseline restored | PASS |
| 4 | `flutter analyze lib test` (whole tree, PROC-2) | no issues | No issues found (`analyze-lib-test.txt`) | PASS |

## 5. Evidence

- `pass-on-today.txt`: the output of run 1.
- `fail-on-violation.txt`: the output of run 2.
- `shrink-prints-baseline.txt`: the output of run 3.
- `analyze-lib-test.txt`: the output of run 4.
- Baseline counts at code head (`test/ui_glossary_baseline.json`):

  | Gate | Subjects | Hits | Breakdown |
  |---|---|---|---|
  | G11 confirm | 25 files | 55 | fewer than two words 27; English title without "?" 10; Arabic title without "؟" 10; bare OK/Yes/Continue/Confirm/Delete 5; title not from ARB 2; label not from ARB 1 |
  | G11 technical | 86 keys | 186 | version 39 en + 39 ar; engine word 32 en + 18 ar; address 17 en + 20 ar; port 9 en + 7 ar; path 3 en + 2 ar |
  | G28 | 268 keys | 280 | title over four words 66; product name 56 (OpenCode 46, Codex 5, Paseo 3, Gas City 2); noun host 37; noun local server 34; noun attention 27; noun session/chat outside labels 15; noun activity 10; body over two sentences 10; uppercase 5; profile(s) 4; Cancel running work 3; bare Continue 3; title capital 3; location 2; Sign out/Close on server 1; Reload 1; workspace 1; Termux setup 1; On-device setup 1 |
  | G11 contradiction | — | 0 | absolute; one allowlisted key |

  Compared with the first version of this gate: `G11 confirm` lost the two `e7SettingsUi16` false positives, a placeholder read as a title (57 → 55). `G11 technical` gained the two-part versions (`a2aSupportedConnection`, `a2aUnsupported`, `builtinServerUbuntuHint`), the file paths (`teamUiHostGuideDocs`, `quotaSetupGuide`), the addresses outside loopback (`connectionHelpRemoteHttp`, `paseoAddressHint`) and every repeat hit (159 → 186). `G28` gained the four ellipsis labels that name a product (`chatUiAskOpenCode`, `chatUiWriteYourOpenCodePrompt`, `e7LocaleUiStarting`, `e7SettingsUi41`) (276 → 280).

- Rule evidence (PROC-31):

  | Rule | Test (`test/ui_glossary_test.dart` + `--plain-name`) | Output |
  |---|---|---|
  | COPY-9 | "G11 confirmation titles ask and labels name the act (COPY-9)"; matcher: "G11 confirm titles and labels are checked through wrappers" | `pass-on-today.txt`, `fail-on-violation.txt` |
  | COPY-17 | "G11 no text says two contradicting states at once (COPY-17)"; matcher: "G11 the contradiction scan skips text that is never rendered" | same |
  | COPY-11 | "G11 technical words only in keys described as Technical: or Field example: (COPY-11)"; matcher: "G11 the technical-word rule finds engine words, ports, paths and versions" | same, and `shrink-prints-baseline.txt` |
  | COPY-6, COPY-7, COPY-8, COPY-10, COPY-12, COPY-21, LOOK-15 | "G28 labels and copy follow the glossary (COPY-6–8, COPY-10, COPY-12, COPY-21, LOOK-15)"; matcher: "G28 the glossary extension finds each pattern" | `pass-on-today.txt`, `fail-on-violation.txt` |
  | PROC-2 | `flutter analyze lib test` | `analyze-lib-test.txt` |

- Changed test expectations (TEST-19): none. The existing glossary tests are unchanged.
- Analyzer suppressions (PROC-3, G26): none added. The shrink print uses `stdout.writeln` from `dart:io`.
- Goldens changed: none.
- Accessibility: n/a (no UI change).
- Privacy and security: n/a (no credentials, stored data, links or notifications).
- Migration: n/a.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/ui_glossary_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze lib test
# after copy fixes land, shrink the baseline:
UI_GLOSSARY_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/ui_glossary_test.dart
```

## 7. NOT proven

- **Rendered text (COPY-17).** The contradiction check reads fixture source and ARB values, not the text a golden actually renders (contract problem 1). It misses a contradiction built at runtime from two separate keys, such as a "Working" chip beside a "stopped" status line. It also misses text that a shot takes from a helper function or fake declared outside the `CensusShot`/`kitGalleryShot` call: that text is checked one literal at a time, not joined with the shot. Test files outside `test/goldens/**` and `tool/capture/census/**` are not scanned. The runtime check needs a text-dump hook in the golden and census harnesses (G4/G5 owners).
- **COPY-11 values with no pattern.** IDs (session, message and task ids), plugin ids and package names have no general pattern and are not scanned. The same goes for IPv6 addresses, URLs, Windows paths, relative paths without a file extension (`lib/ui`), versions with no name or "v" before them ("update to 2.1"), and numeric placeholders other than `{…version…}`. Only ARB values are scanned, not strings still hard-coded in `lib/` (see `docs/localization-todo.md`). The scan also cannot tell whether a string is shown inside a `KitDetailsFold`, `KitLogPanel`, `KitCodeBlock`, `KitTechnicalValue` or a `KitField`: it relies on the `@description` prefix.
- **Confirm keys by name.** The confirm scan resolves ARB keys by name. A title held in a local variable, such as `development_services_screen.dart`'s switch record or `personal_settings_screens.dart`'s `title` parameter of a non-`Future<bool>` helper, counts as "not from app_en.arb" instead of being resolved. So does a title built by string interpolation.
- **The rest of COPY-9.** The confirm cancel word and body length are not checked here; they belong to G37 and `test/kit/kit_confirm_sheet_test.dart`.
- **G31.** The shrink-only rule for this baseline across commits waits for G31 (contract problem 3). Within one run, this gate only compares against the committed file.
- Not run on a device or emulator (not needed for a static gate).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G11-G28` |
| Enabled | Yes: runs with `flutter test` | `test/ui_glossary_test.dart` |
| Verified | tests only | this record |
| Committed | Yes | code head `842db6e7` |
| Deployed | No | |
| Released | No | |
