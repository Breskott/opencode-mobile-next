# App revamp: the whole redesign as parallel agent work (2026-09-26)

The owner asked: "plan work in a way that I can enable ultramode and you run hundreds of agents in parallel to finish in an hour the whole app revamp and redesign … save in a document for everyone."

This document is that plan. Everything it relies on is committed on `feat/phone-setup-v2`:

| File | What it is |
|---|---|
| `docs/ux-system/revamp/work-units.json` | the cut: 163 units |
| `docs/ux-system/revamp/build_units.py` | regenerates the cut from the data |
| `docs/ux-system/revamp/revamp.workflow.js` | the ultracode workflow that runs one wave |

## 1. What "done" means

Done is every screen of the app:

- **Built from the kit only.** The G16 ratchet reaches zero and becomes absolute.
- **In the approved look** (`docs/design/visual-language-2026-09-26.md`):
  - Geist type;
  - colours from a theme the person can change;
  - liquid glass on the floating navigation layer;
  - everything sharp and crisp.
- **Adaptive** for phone, tablet and PC (kit-v2.md §8). Android is the target.
- **On its target journey** (`docs/ux-system/target-ia.md`): the 11 programmes the owner approved, except P2, which is deferred.

Every change carries tests. Every wave ends with emulator proof and a QA record.

## 2. The honest numbers

- **Concurrency on this PC.** A workflow runs at most min(16, CPUs − 2) agents at once. This PC has 8 CPUs, so that is **6 agents at a time**. Hundreds of agents run in total, one after another in those 6 slots; hundreds at the same moment would need more machines.
- **Machine limits:** 15 GB RAM, one Gradle build at a time, and a serial test suite of 27–40 minutes.
- **Estimate** (average unit ≈ 45–75 min from build through review and fix):

  | Wave | Units | Agent-hours | Wall-clock at 6 slots |
  |---|---|---|---|
  | 1 Kit | 51 | ≈ 38 | ≈ 6–7 h |
  | 2a Shared widgets | 17 | ≈ 17 | ≈ 3 h |
  | 2b Screens | 28 | ≈ 33 | ≈ 5–6 h |
  | 2c Chat chain | 6 | ≈ 9 | ≈ 9 h in series; runs alongside 2a/2b |
  | 3 Behaviour | 61 | ≈ 86 | ≈ 14–16 h, in conflict-free batches |
  | Integration and proof | per wave or batch | — | ≈ 6–10 h |

  **Total: about 1.5–2 days of unattended running, not one hour.** The waves can run overnight. The owner looks at results at each wave's checkpoint.
- **What would make it faster:** more machines, meaning cloud agents with the branch pushed. That needs the owner's OK to push, and a cloud image with the pinned Flutter. Goldens would still have to be regenerated on one machine so they match.

## 3. What is frozen before any agent starts (the contracts)

| Contract | File | State |
|---|---|---|
| Vocabulary | `docs/ux-system/taxonomy.md` | frozen |
| Every page, its journey and proposal | `docs/ux-system/map/all.json` | frozen |
| Where each job lands (264 pages) | `docs/ux-system/target-ia.md` | frozen |
| Kit parts, APIs, rules, adaptive, kit only | `docs/ux-system/kit-v2.md` | frozen |
| Look, glass, crispness, theme roles | `docs/design/visual-language-2026-09-26.md` | frozen; its implementation `feat/visual-language-v1` is being built now and **must be merged before wave 1** |
| Programmes and slices | `docs/ux-system/programmes.json` + the owner's decisions (`programme-decisions-2026-09-26.json`) | frozen |

An agent that finds one of these wrong reports it and does not work around it. The coordinator changes the contract, and the next wave uses it.

## 4. The cut: 163 units

In each wave, no two units write the same file. `build_units.py` asserts this, and the workflow re-checks it for wave 3.

### Wave 1: the kit (51 units)

- **25 new parts:**
  - kit-v2 §1: dialog, field, search field, segmented, choice list, details fold, code block, log panel, checklist, progress row, viewer, diff view, receipt, undo, top bar, jump pill, term, needs-you marker;
  - §9: icon, surface, tappable, divider, scaffold, page route, date/time picker.
- **8 chat parts:** turn, message, markdown, tool row, work line, composer, queued message, agent strip.
- **10 one-off surfaces:** terminal view, scanner, work graph, nav rail, level meter, board lane, task card, swatch, QR, breadcrumb.
- **8 changed parts:** request card, state view, status line, notice, row, action, progress, tab switcher.

Each unit is one file in `lib/ui/kit/`, with its tests and galleries at five sizes and DPR 3. A unit that builds on another part merges that part's branch first; the dependencies are listed in `after`.

### Wave 2: every screen file (51 units)

The 189 files that still hand-build UI (5,118 raw widgets) are grouped by module, at most about 3,200 lines per unit:

- **2a, shared widgets:** 17 units.
- **2b, screens:** 28 units.
- **2c, the chat library:** 6 links. AGENTS.md makes it one editor at a time, so the links run in order and each is merged before the next starts.

A screen unit:

- rebuilds its files from kit parts only;
- applies the look;
- fixes what the map asks for its pages (missing states, actions, "explain instead of vanish");
- re-renders its goldens and looks at them.

Pages marked remove or merge are only restyled in wave 2. Their behaviour changes in wave 3.

### Wave 3: behaviour (61 programme slices)

This is the rest of P0, and P1, P3, P4, P5, P6, P7, P8, P9 (search, accessibility, RTL) and P10. P2 is not included: the owner deferred it.

- **Scope:** each slice first names its write set by reading the code. It also checks feasibility (AGENTS.md rule 2); a blocked slice is logged, not worked around.
- **Batching:** the script packs slices into conflict-free batches in programme order (P0, P9, P7, P8, P4, P1, P3, P10, P5, P6), and integrates after each batch.
- **Gated slices:** four slices start with a go/no-go check:
  - P0.7: can projects be kept when This phone is removed;
  - P1.6a: does Claude Code run under the in-app Linux;
  - P2.5: is there an MCP registry (deferred with P2);
  - P6.3: can the team start work at once.

## 5. How one unit runs (the workflow's pipeline)

1. **Build.** A fresh git worktree, branch `revamp/<unit id>`, the unit's specs, tests with `-j 1`, a commit, and a QA record at `docs/qa/revamp-<unit id>/README.md`.
2. **Review.** A different agent, read-only, tries to find what is wrong:
   - raw widgets, colours or type not from tokens;
   - soft edges, missing states, broken RTL or 200 % text;
   - engine words, lost typed input;
   - map records ignored;
   - goldens that don't match the approved renders.
3. **Fix.** The builder fixes the findings in the same worktree.
4. **Integrate.** One integrator merges the passing branches into `feat/phone-setup-v2` in order. It resolves ARB files, kit exports and goldens by rule, then runs analyze, the ratchet, the design-standard, l10n and ledger tests, and every touched test.

Units that fail tests or analyze are not merged; the wave result lists them for a retry.

## 6. Rules every agent gets

AGENTS.md applies, plus:

- Kit only.
- Theme roles only.
- Integer type sizes.
- Copy in English and Arabic.
- Tests with `-j 1`.
- No Gradle, emulator, adb, pushes or phone.
- Stay inside the write set; a new kit file is allowed.
- `main.dart` and `connection.dart` go to the coordinator.
- A goldens change is accepted only after the agent has looked at the new image.

## 7. Checkpoints for the owner

After each wave the coordinator:

1. builds one APK;
2. runs the emulator proof at phone and tablet size;
3. sends before/after images;
4. updates this plan with what merged, what didn't and why.

Nothing is pushed or released without the owner's word.

## 8. Before ultramode can start

- [ ] Merge `feat/visual-language-v1` (the look and the theme roles) into `feat/phone-setup-v2` and regenerate `work-units.json`.
- [ ] Owner: in `/config` › "Dynamic workflow size", raise the limit; the session default is "medium", under 10 agents. Then turn on ultracode.
- [ ] Emulators: both proof emulators currently fail to finish booting (Android's watchdog kills the system process). Fix them before the first checkpoint; waves 1–2 can start without them.
- [ ] Disk: 6 worktrees at once need about 12 GB free on Storage (22 GB free now).

## 9. How to run a wave

The coordinator, with ultracode on:

```text
Workflow({ scriptPath: "docs/ux-system/revamp/revamp.workflow.js",
           args: { wave: "1", units: <work-units.json units where wave == "1"> } })
```

Then run waves 2a and 2b, with 2c alongside them (it takes one slot), then 3. Before each wave, read the previous result, fix any contract it exposed, and regenerate the cut.
