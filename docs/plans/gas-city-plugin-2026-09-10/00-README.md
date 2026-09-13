# Gas City as an optional plugin — the plan

Status: **plan, no code.** Goal set 2026-09-10: integrate Gas City as an
optional feature, optional in the on-device (Termux) onboarding, planned to
the point where UI, UX and behaviour are fully specified before any code.

This folder is the single source of truth for that work. It builds on the
research sprint in [../../research/control-plane-2026-09-10/](../../research/control-plane-2026-09-10/README.md)
and the BRD ("OpenCode Mobile — AI Development Control Plane").

| Doc | What it settles |
|---|---|
| [01-prd.md](01-prd.md) | What the feature is, who it is for, what "done" means, what is out |
| [02-ux-flows-and-screens.md](02-ux-flows-and-screens.md) | Every screen, state, copy and interaction |
| [02a-design-references.md](02a-design-references.md) | Mobbin patterns the second canvas follows, and the restraint rules |
| [03-onboarding-on-device.md](03-onboarding-on-device.md) | The optional step in the Termux flow, the desktop-host path, and what happens when the host can't run it |
| [04-plugin-architecture.md](04-plugin-architecture.md) | How a plugin fits the codebase without touching the OpenCode gateway |
| [05-beads.md](05-beads.md) | Epic + 17 beads with impact tables, acceptance criteria, dependencies |
| [06-decisions-and-readiness.md](06-decisions-and-readiness.md) | The decisions only the owner can take, and the checklist that gates the first line of code |
| [Design canvas](https://claude.ai/code/artifact/bcd92bef-8693-411e-959d-1da042b64e87) | Seven phone mockups (v2, calm: one number, one sentence, one action); sources in [design/](design/) |

## The five decisions this plan makes

1. **Product name: "AI Team · Gas City".** The provider is named openly in
   headers and settings. No new navigation tab; the feature lives inside
   Workspace, Activity and More (BRD §9). Vocabulary is shown side by side:
   product term first, Gas City term small ("Work · bead").
2. **It is a plugin in every sense the app already has.** Off by default,
   enabled per saved server, discovered automatically when the host
   advertises it, removable without a trace, gated by capability flags, and
   never embedded in `lib/api` / `lib/api2`.
3. **Any host, one UX, visible disclaimers.** *Computer host* (Ubuntu PC
   or any Mac/Windows/WSL machine: reads direct over tailnet TLS, writes
   through a thin front), *On this phone* (Gas City inside the existing
   proot rootfs with the file beads store, experimental, spike-gated), *Not
   available* (honest, never a dead end). Every host shows a performance
   disclaimer appropriate to it.
4. **Read-only first, controls second, merge third, on-device after the
   spike.** The first slice answers the BRD's five Run-detail questions with
   zero write authority. Decisions and controls follow, then merge
   readiness, MR approval and a two-step Merge button. The phone-hosted
   supervisor is gated behind a feasibility spike that must pass before its
   onboarding step is ever shown.
5. **Nothing is inferred from chat.** Run, Work and Agent states come from
   the supervisor's own state machine; attention items come from the
   supervisor's pending interactions and gate beads; costs are labelled
   estimated.

## Readiness rule (from the goal)

Code starts only when every box in
[06-decisions-and-readiness.md](06-decisions-and-readiness.md) is ticked.
That checklist includes the owner's answers to the open questions, a
recorded supervisor fixture, the pinned API spec, and sign-off on the design
canvas. Until then, the only allowed engineering work is the two spikes in
`05-beads.md` (CP-000 and CP-001), which produce evidence, not product code.
