# App revamp: the whole redesign as parallel agent work (2026-09-26, cut v2)

The owner asked: "plan work in a way that I can enable ultramode and you run hundreds of agents in parallel to finish in an hour the whole app revamp and redesign … save in a document for everyone." Before any agent starts, the owner added: "Make sure all rules and standards are established before agents."

This document is that plan. Cut v2 applies a verified review of the first cut: 52 changes (C01–C52) and 24 rules (R01–R24), each checked by a skeptic whose corrections are applied. Everything it relies on is on `feat/phone-setup-v2`:

| File | What it is |
|---|---|
| `docs/ux-system/revamp/work-units.json` | the cut: 168 units in waves and tiers, lock groups, hotspots, the golden-owner table and the estimate |
| `docs/ux-system/revamp/build_units.py` | regenerates the cut from the tree, and fails loudly when an assertion fails |
| `docs/ux-system/revamp/revamp.workflow.js` | the ultracode workflow that runs one wave |
| `docs/ux-system/revamp/STANDARDS.md` | the one rulebook every agent and reviewer reads |
| `.gitattributes` and `tool/l10n/arb_merge.py` | the merge rules for copy and generated files (R04, R09) |

## 1. What "done" means

Done is every screen of the app:

- **Built from the kit only.** The G16 ratchet reaches zero and becomes absolute (slice P9.10).
- **In the approved look** (`docs/design/visual-language-2026-09-26.md`):
  - Geist type;
  - colours from a theme the person can change;
  - liquid glass on the floating navigation layer;
  - everything sharp and crisp.
- **Adaptive** for phone, tablet and PC (kit-v2.md §8). Android is the target.
- **On its target journey** (`docs/ux-system/target-ia.md`): the 11 programmes the owner approved, except P2, which is deferred.

Every change carries tests. Every wave ends with emulator proof and a QA record. The full checklist is STANDARDS.md §1.

## 2. The honest numbers

- **Concurrency on this PC.** A workflow runs at most min(16, CPUs − 2) agents at once. This PC has 8 CPUs, so that is **6 agents at a time**. Hundreds of agents run in total, one after another in those 6 slots; hundreds at the same moment would need more machines.
- **Machine limits:** 15 GB RAM, one Gradle build at a time, and a serial test suite of 27–40 minutes.
- **What serialises the work:**
  - wave 1 runs in 7 dependency tiers, and each tier is integrated before the next branches;
  - the chat library has one editor at a time, so wave 2c is a chain of 9 links;
  - one integrator merges everything, one integration at a time;
  - in wave 3, the 11 slices that touch the chat library form one serial lane, which is wave 3's critical path.
- **Estimate.** `build_units.py` computes it from the cut (`estimate` in work-units.json). A kit unit takes 45–75 minutes from build through review and fix; a screen unit 60–90 minutes; a chain link or slice 75–105 minutes.

  | Wave | Units | Shape | Agent-hours | Wall-clock |
  |---|---|---|---|---|
  | 1 Kit | 68 | 7 tiers: 28 · 12 · 15 · 8 · 3 · 1 · 1 | 51–85 | 11–19 h, plus 7 integrations |
  | 2a Shared widgets | 13 | 1 tier | 13–20 | 3–4.5 h |
  | 2b Screens | 31, plus coord-main | 2 tiers | 31–46 | 6–9 h, alongside 2c |
  | 2c Chat chain | 9 | serial, starts after 2a | 11–16 | 11–16 h: wave 2's critical path |
  | coord-main | 1 | the coordinator | — | 1–2 h |
  | 2d Kit hygiene | 1 | 1 | 1–2 | 1–1.5 h |
  | 3 Behaviour | 45 | 8 batches (preview) plus an 11-slice CHAT lane | 56–79 | 14–19 h: the lane is the critical path |
  | Integration and proof | per tier, batch or slice | — | — | 6–10 h |

  **Total: about 52–80 hours, so 2–3.5 days of unattended running, not one hour.** The waves can run overnight. The owner looks at results at each wave's checkpoint.
- **What would make it faster:** more machines, meaning cloud agents with the branch pushed. That needs the owner's OK to push, and a cloud image with the pinned Flutter. Goldens would still have to be regenerated on one machine so they match. More machines do not shorten the two serial paths: the chat chain and the wave-3 CHAT lane.

## 3. What is frozen before any agent starts (the contracts)

| Contract | File | State |
|---|---|---|
| The rulebook | `docs/ux-system/revamp/STANDARDS.md` | being written; frozen before wave 1 |
| Vocabulary | `docs/ux-system/taxonomy.md` | frozen |
| Every page, its journey and proposal | `docs/ux-system/map/all.json` | frozen |
| Where each job lands (264 pages) | `docs/ux-system/target-ia.md` | frozen; §4 amended for glass (C27) |
| Kit parts, rules, adaptive, kit only | `docs/ux-system/kit-v2.md` | frozen; :1290, §9.1 and §9.3 amended (C03, C21) |
| **Frozen API block per kit unit** | `docs/ux-system/kit-api/<Part>.md` | being written (C02); a kit unit without one is refused (R16) |
| Look, glass, crispness, theme roles | `docs/design/visual-language-2026-09-26.md` | frozen; its implementation `feat/visual-language-v1` **must be merged before wave 1** |
| Programmes and slices | `docs/ux-system/programmes.json` + the owner's decisions (`programme-decisions-2026-09-26.json`) | frozen; cut v2 rescopes some slices (§4) |
| Merge rules | `.gitattributes`, `tool/l10n/arb_merge.py` | committed |

The API freeze (C02) settles, for every part: its constructor and parameters, states, and tests. It also settles three open points:

- pane widths: the visual language wins, so list 296 · conversation 700 · changes 340, and `kit_layout.dart`'s `paneListWidth` 360 changes;
- KitIcon sizes: s/m/l = 20/22/24, the only sizes the visual language allows;
- `KitIconButton`: §1.10 names the parameter `tooltip`, the code has `label`. Either §1.10 is amended, or `tooltip` is added and `label` becomes a `@Deprecated` alias.

An agent that finds a contract wrong reports it (`contractProblems` in its build record) and does not work around it. The coordinator changes the contract, and the next wave uses it.

## 4. The cut: 168 units

`build_units.py` reads the current tree and ends with assertions. It exits non-zero when any fails:

1. no file is in two units that run at the same time (each wave-1 tier; 2a; 2b with 2c; each wave-3 batch after lock expansion), with `kit.dart` and the hotspots excluded;
2. every `after` id resolves, and there is no cycle;
3. every G1 and G16 baseline file, and every existing file a map record names, is in some unit or in the ratchet's `_allowed`;
4. no wave-3 slice names a wave-1 kit part except as declared read-only use;
5. every kit unit has a `spec`.

It also checks the counts below, the chain, the hotspots, the planned part names and that no wave-2 file has only remove or merge pages.

Its inputs: every `lib/**.dart` outside the kit and l10n that declares a widget, the G1/G16 baseline, and every map-named file, split on `+` as well as `:` (R21). The chat library is globbed. Units stop at 3,200 lines and 150 raw widgets; a single file over the cap is allowed and flagged (`screen-review-1`, `screen-servers-1`).

### Wave 1: the kit (68 units, 7 tiers)

Tier = 1 + the highest tier of the units it builds on (R02). Tiers 1a–1g hold 28, 12, 15, 8, 3, 1 and 1 units.

- **New parts:** dialog, field, search field, segmented, choice list, details fold, code block, log panel, checklist, progress row, viewer, diff view, receipt, undo, top bar, jump pill, term, needs-you marker, icon, surface, tappable, divider, page route, date/time picker, menu, chip, since (the 8 s escalation helper), image, motion parts, capability explainer and request sheet.
- **Chat parts** (`lib/ui/kit/chat/`): turn, message, markdown, tool row, work line, composer, composer chips, queued message and agent strip. They write only their own new files, never the chat library (C03).
- **Surfaces:** terminal view, scanner, work graph, nav (bar, rail and PC sidebar header in one part), level meter, board lane, task card, swatch with theme preview, QR and breadcrumb.
- **Changed parts:** icon button, status mark, screen (absorbs scaffold: slots, keyboard lift, two- and three-pane), row and row parts (split), request card, state view, status line, notice (cost line and the report hook), action, progress, tab switcher, text (selectable, mono), sheet, the ask line look and the scenes.
- **Gates:** `kit-gates-ratchet` in tier 1a (G16 over all of `lib`, the G2/G7/look patterns, `app_theme.dart` allowed) and `kit-gates-manifest` last (galleries, redaction, map, drafts, glossary).

Files the kit replaces move into the kit unit that replaces them and become `@Deprecated` wrappers (R12): for example `diff_view.dart` into KitDiffView, `info_label.dart` into KitTerm, `app_iconography.dart` into KitIcon. Units whose files `feat/visual-language-v1` also touches are marked `provisional` until that merge; their titles then drop what it delivered (R22).

### Wave 2: every screen file (55 units, one of them run by the coordinator)

- **2a, shared widgets:** 13 units.
- **2b, screens:** 31 units, including `screen-voice-1` (voice setup and notices) and `screen-system-2` (update and feedback notices). **coord-main** follows the 2b integration and is run by the coordinator: `main.dart`, the saved-server card, and the app-level registrations (the report hook and the 21 capability enable flows).
- **2c, the chat chain:** 9 links, parts first and the host last. `chat_screen.dart` is cut into three regions: first half, second half, and `build()`. The chain starts after 2a is integrated and runs alongside 2b through the same integrator queue. Each link may edit call sites anywhere in the chat library, because the links run in series (R03).
- **2d, kit-hygiene:** deletes the wrappers nobody calls any more, completes `kit.dart`, and lists the wrappers that wait for their wave-3 slice.

A wave-2 unit:

- rebuilds its files from kit parts only: G1, G16, G7 and the look patterns for its files reach 0 (R14);
- applies the look;
- fixes what the map asks for its pages (missing states, actions, "explain instead of vanish");
- carries the acceptance of the wave-3 slices it absorbed (drafts that survive, archive with Undo, one file viewer, answers in place and others). Each carry is anchored to a file, so a regenerated cut keeps it;
- re-renders the goldens it owns and looks at them.

Files whose pages are all remove or merge are not in wave 2 at all. They go to the wave-3 slice that deletes them (C33).

### Wave 3: behaviour (45 programme slices)

This is P0.7, and P1, P3, P4, P5, P6, P7.2, P8, P9.4, P9.10 and P10. P2 is not included: the owner deferred it.

- **Absorbed earlier:** P1.1, P4.1a, P7.1, P7.3–P7.6, P8.3, P9.5 and P9.6 are carried by wave-1 and wave-2 units. P3.8, P3.12, P4.1b, P4.3 and P7.7 are merged into wave-2 units. P3.11 and P6.6 keep only their non-chat halves (P3.11a, P6.6a).
- **Order:** every slice has slice-level `after` edges, on top of the owner's programme floor: P1 and P3 after P0 (only P0.7 is left); P5 after P3; P6 after P4 and P5; P10 after P4. Every slice also comes after the last chain link. P9.10 comes after every other unit.
- **Scope:** each slice first names the existing files it will edit or delete, and the files it creates, by reading the code, and checks feasibility (AGENTS.md rule 2). Slices seeded by the cut keep their seeded files. A blocked slice is logged, not worked around, and its dependants are blocked too.
- **Packing:** write sets expand into lock groups: CHAT (the chat library and `lib/ui/kit/chat/`), NATIVE (`android/**/*.kt` and every Dart file that opens a platform channel), API2 (`lib/api2/`) and four single-file locks (`main.dart`, `connection.dart`, `server_gateway.dart`, `product_repository.dart`). Hotspots are stripped first. A slice joins a batch only after the batches of everything it depends on, a batch holds at most one NATIVE slice, and the CHAT slices run as one serial lane alongside the batches.

**Gated slices (C50):**

- **P0.7**: can projects be kept when This phone is removed? The scope pass reads `lib/builtin/builtin_folders.dart`. If they cannot, the sheet offers "Export projects first".
- **P6.3**: does the Gas City client in `lib/orchestration` expose a dispatch trigger? If not, P6.3 is blocked and reported. The "< 5 s" measurement is coordinator work at the §7 checkpoint.
- **gate-P1.6a** (coordinator, on device): does Claude Code run under the in-app Linux? P1.6b runs only on "go". On "no-go", `local_agent_onboarding.dart` gets a kit-only restyle in P1.5 instead.
- **P2 deferred:** there is no P2.x unit, and the KitRequestCard change variant is not built.

## 5. How one unit runs (the workflow's pipeline)

1. **Admit.** A unit whose `after` ids are not all merged is deferred and reported with what it waits for. It is never built on a partial branch. A kit unit without a frozen spec is refused. `coord-main` is handed to the coordinator.
2. **Build.** A fresh git worktree and branch `revamp/<unit id>` from the integrated base (no merging other revamp branches). The builder follows the unit's spec, acceptance and pages, runs its tests with `-j 1`, commits, and writes a QA record at `docs/qa/revamp-<unit id>/README.md` from the STANDARDS.md §16 template. It reports shared tests it broke in `sharedTestsBroken`.
3. **Review.** A different agent, read-only, works through the STANDARDS.md §17 checklist. It tries to find what is wrong:
   - raw widgets, colours or type not from tokens, soft edges;
   - missing states, broken RTL or 200 % text, engine words, lost typed input;
   - an API that differs from the frozen spec, edits outside the write set, staged shared files;
   - removed or renamed public APIs, local substitutes for planned parts;
   - map records ignored, goldens that don't match the approved renders.
4. **Fix.** The builder fixes the findings in the same worktree. A "reject" goes back to the coordinator.
5. **Integrate.** One integrator, one FIFO queue, merges the passing branches into `feat/phone-setup-v2` in order and runs the gates (§6).

Units that fail tests, analyze or review are not merged. The wave result lists merged, deferred (and what they wait for), refused, blocked, not merged, and coordinator work.

## 6. Rules every agent gets

AGENTS.md and STANDARDS.md apply. The workflow gives every agent these rules (R01–R24, condensed):

**Order and ownership**

- **R01.** One integrator at a time, through one FIFO queue in one workflow run. It stops if `git status --porcelain` is not empty.
- **R02.** Wave 1 runs tier by tier; each tier is integrated before the next branches from the base. Nobody merges another unit's branch.
- **R03.** 2c starts after 2a is integrated and runs alongside 2b only. Each `lib/ui/kit/chat/<part>.dart` belongs to the link that uses it.
- **R17.** Wave 3: dependency-aware batches, blocked dependencies propagate, lock groups, hotspots stripped, one serial CHAT lane.
- **R18.** `main.dart` and `connection.dart`: coord-main (the coordinator) in wave 2; in wave 3 the slice that holds the lock owns the file and keeps the edit minimal.
- **R19.** A batch holds at most one slice that edits `android/**/*.kt`. The integrator runs `flutter build apk --release` on it before merging; a failure at `validateSigningRelease` is acceptable. Units never run Gradle.
- **R20.** On-device proof is coordinator work at the §7 checkpoints.

**Shared files**

- **R04.** Copy: `lib/l10n/*.arb` merge by key union (`tool/l10n/arb_merge.py`, which fails only when one key gets two values). Generated `app_localizations*.dart` take ours. The integrator runs gen-l10n after each merge. New keys are prefixed with the part or screen stem; no key is renamed or deleted in waves 1–2d; a dead-key sweep runs after 2d.
- **R05.** Units never stage `test/kit_ratchet_baseline.json` or the l10n `_baseline`; the integrator regenerates both once per integration. Only `kit-gates-ratchet` may commit the ratchet baseline.
- **R06.** Units never edit `lib/ui/kit/kit.dart`. Tests import parts directly; the integrator adds the exports after each tier.
- **R07.** Goldens have owners (the golden-owner table in work-units.json). Multi-unit golden tests, `test/support/`, `tool/capture/census/` and `docs/qa/screen-census/` belong to the integrator, which regenerates and reviews them once per tier or wave. Units never stage `test/**/failures/`.
- **R08.** Each unit has a `tests` write set: the tests whose imported lib files are all its own. Every other test is the integrator's; a unit reports what it broke in `sharedTestsBroken`.
- **R09.** UI ledger: units append to `docs/design/ui-ledger/parts/<area>.json` only; the integrator rebuilds `ledger.json`, `pages.md` and `navigation.md`.
- **R10.** `test/design_standard_test.dart` is the integrator's; renamed classes go in `sharedTestsBroken`.

**Kit and code**

- **R11.** In waves 1–2d, public APIs are additive only; old ones stay as `@Deprecated` wrappers until kit-hygiene or a named slice removes them.
- **R12.** A file a kit part replaces moves into that kit unit and becomes a thin wrapper, never a duplicate.
- **R13.** No unit creates a file or class named after a planned kit part. A missing part defers the unit.
- **R14.** A wave-2 unit brings G1, G16, G7 and the look patterns for its files to zero.
- **R16.** Kit units build to their frozen API block; the workflow refuses a kit unit without one.
- **R23.** Tooltip only through KitIconButton, KitTerm or `KitTappable.tooltip`. FloatingActionButton becomes the KitScreen bottom primary. Theme and DefaultTextStyle overrides only in `app_theme.dart`. Positioned becomes PositionedDirectional.

**Contracts and the cut**

- **R15.** When sources disagree, the owner's later decision wins; visual-language §6 overrides target-ia §4 on glass. An agent reports a wrong contract and does not work around it.
- **R21.** `build_units.py` discovers its files as §4 says and asserts disjoint write sets, resolvable `after` ids, full coverage and a spec on every kit unit.
- **R22.** After `feat/visual-language-v1` merges, kit titles drop what it delivered, and the cut is regenerated before wave 1.
- **R24.** This section's numbers come from the regenerated cut.

The everyday rules stay: kit only, theme roles only, integer type sizes, copy in English and Arabic, tests with `-j 1`, no Gradle, emulator, adb, pushes or phone, and a goldens change only after looking at the new image.

## 7. Checkpoints for the owner

After each wave the coordinator:

1. builds one APK;
2. runs the emulator proof at phone and tablet size;
3. sends before/after images;
4. updates this plan with what merged, what didn't and why.

The coordinator also does the on-device work no agent may do (R20):

- gate-P1.6a before wave 3;
- the P6.3 "task reaches a worker in under 5 s" measurement;
- the TalkBack walk (from P9.5);
- the emulator proofs of the slices merged into wave-2 units: P3.8, P3.12, P4.1b, P4.3 and P7.7.

Nothing is pushed or released without the owner's word.

## 8. Before wave 1 (the checklist)

- [ ] Merge `feat/visual-language-v1` (76095bd3, f5370bd3, 510f601d) into `feat/phone-setup-v2`.
- [ ] Commit or restore the 4 modified `docs/qa/screen-census` PNGs, so the integrator starts from a clean tree (R01).
- [ ] Untrack the golden failure images: `git rm -r --cached test/goldens/failures`, and add `test/**/failures/` to `.gitignore`.
- [ ] Set the merge drivers in the repo's own git config (never the global config):

  ```bash
  git config merge.arbunion.name "ARB 3-way key union"
  git config merge.arbunion.driver "python3 tool/l10n/arb_merge.py %O %A %B %P"
  git config merge.ours.name "keep ours (regenerated after the merge)"
  git config merge.ours.driver true
  python3 tool/l10n/arb_merge.py --self-test
  ```

- [ ] Freeze the API blocks in `docs/ux-system/kit-api/<Part>.md` for every kit unit (C02), including the pane widths, KitIcon sizes and the `tooltip`/`label` decision.
- [ ] Amend the contracts: kit-v2.md:1290 (chat parts write only their own files, C03), kit-v2.md §9.1 and §9.3 (the plumbing allowlist and the G16 scan over `lib/**`, C21), target-ia §4 (glass follows visual-language §6, C27).
- [ ] Freeze `docs/ux-system/revamp/STANDARDS.md`.
- [ ] Regenerate the cut: `python3 docs/ux-system/revamp/build_units.py`. It must print "assertions: all passed", no unit may still be `provisional`, and every kit unit must have `specFrozen: true`.
- [ ] Owner: in `/config` › "Dynamic workflow size", raise the limit; the session default is "medium", under 10 agents. Then turn on ultracode.
- [ ] Emulators: both proof emulators currently fail to finish booting (Android's watchdog kills the system process). Fix them before the first checkpoint; waves 1–2 can start without them.
- [ ] Disk: 6 worktrees at once need about 12 GB free on Storage.

## 9. How to run a wave

The coordinator, with ultracode on, passes the whole cut and the ids already merged:

```text
Workflow({ scriptPath: "docs/ux-system/revamp/revamp.workflow.js",
           args: { wave: "1", cut: <work-units.json>, merged: [] } })
```

Then, each time passing `merged` as the union of every earlier run's `merged`:

1. `wave: "2a"`;
2. `wave: "2b"`, which runs 2b and the 2c chain together through one integrator queue;
3. the coordinator does coord-main and adds `"coord-main"` to `merged`;
4. `wave: "2d"`;
5. the coordinator runs gate-P1.6a;
6. `wave: "3"` with `gates: { "gate-P1.6a": "go" }` or `"no-go"`.

Before each wave, read the previous result: deferred units wait for a dependency, refused ones for a spec, blocked ones for a decision. Fix any contract the result exposed, regenerate the cut, and rerun the wave to pick up what did not merge.
