# PRD — "AI Team" (Gas City plugin)

## 1. One sentence

Let a developer supervise a Gas City–orchestrated team of coding agents from
the phone — see runs, work, agents and what needs them, answer decisions and
steer — as an optional add-on to a saved OpenCode server, with an optional
"run it on this phone" path for people who already host OpenCode in Termux.

## 2. Why now

- The app already does the individual-session job well (chat, files,
  review, background subagents proven 2026-09-10).
- The research sprint found that Gas City (not Gas Town) exposes a typed
  HTTP+SSE supervisor API with runs, beads, agents, sessions, pending
  interactions and a resumable event bus. That is enough for a read-first
  control plane without inventing a backend.
- The BRD's biggest risks (unauthenticated read plane, heavy host
  requirements, `v0` API) are all containable by making the feature optional,
  provider-gated and read-first.

## 3. Users and jobs

**Primary — AI-native developer with a dev PC.** Runs Gas City on the
Ubuntu host that already serves OpenCode. Job: "while away from the desk,
know whether the team is stuck, answer what it asks, and stop it if it goes
wrong."

**Secondary — phone-first tinkerer.** Hosts OpenCode in Termux (proot) and
wants to try a small team on the phone. Job: "try it in ten minutes without
breaking my working OpenCode setup, and turn it off cleanly."

**Non-user (explicitly):** anyone who wants a Gas City admin console. The
dashboard exists; we do not rebuild it.

## 4. Goals (measurable)

| # | Goal | Measure |
|---|---|---|
| G1 | Answer the BRD's five Run questions in one screen | Run detail shows objective, progress, current activity, blockers, needs-you within one fetch; usability check: 5/5 testers answer all five in under 20 s |
| G2 | Nothing needed from the desktop for routine supervision | Answer a pending interaction, nudge an agent, stop an agent, cancel a run from the phone (Sprint 3) |
| G3 | Zero regressions for users who never enable it | With the plugin off, no new UI, no new network calls, unchanged test suite |
| G4 | Honest availability | Every "can't" state names the reason and the fix; no dead ends |
| G5 | Optional on-device path is real or hidden | The Termux step appears only if the feasibility spike passed on the pinned rootfs and the runtime advertises it |

## 5. Non-goals

- Objective → plan → work-graph *editor* (the Mayor does planning; v1 lets
  you send it an objective and watch beads appear).
- Force-merge, branch reset, worktree deletion (BRD §40 list). A normal
  Merge behind two-step confirmation **is** in scope (Sprint B, owner
  decision 2026-09-10).
- Provider/model routing *editing* (display only).
- A fifth navigation tab, a "Gas Town" mode, or exposing every `gc`
  primitive.
- Offline queueing of orchestration mutations (disabled offline, never
  queued).
- Gas Town (legacy) support.

## 6. Feature summary by sprint

**Sprint A — See (read-only).** Plugin toggle per server; discovery; AI Team
card on Workspace; Run list; Run detail (Overview, Work, Agents, Timeline);
Agent detail with live output; gates surfaced in Activity as "needs you"
(read-only); usage labelled estimated; fixture-backed tests; real read proof
against a Gas City on the PC.

**Sprint B — Answer, steer, merge (writes through the front).** Host-side
front; answer pending interactions and close gates from Activity; nudge /
message an agent; stop / wake an agent; cancel a run; assign ready work;
start a run by sending an objective to the Mayor; merge readiness card,
approve a merge request, and a Merge button behind two-step confirmation and
the host's boundaries; all idempotent and confirmed; supervision policy
display.

**Sprint C — On this phone (experimental).** Optional Termux onboarding
step; managed install of `gc` (linux/arm64) inside the existing proot
rootfs with the file beads store; start/stop/health in Settings; the same
UI as the computer host; explicit battery and background-kill truth.

Sprint C is gated on the spike CP-000 (see 05-beads). If the spike fails,
Sprint C collapses to "Not available on this phone" copy and nothing else.

## 7. User stories (top level; beads in 05-beads.md)

1. As a user with a saved server, I can turn **AI Team** on for that server
   in More › Plugins, and the app finds the supervisor by itself when the
   host advertises it, or lets me type its address.
2. As a user, Workspace shows one **AI Team** card: agents working / idle /
   blocked, active runs, items that need me. Tapping opens the team.
3. As a user, a **Run** screen tells me what we are building, how far along,
   what is happening now, what is blocked, and what needs me — with Work,
   Agents and Timeline tabs.
4. As a user, an **Agent** screen shows who it is (provider, model, role),
   what it is doing, its context use, its recent activity, and its live
   output; I can open the underlying OpenCode session when the link exists.
5. As a user, **Activity** lists every decision, blocked agent, failed run
   and review-ready item across servers, in the BRD's priority order, and
   answering one routes back to exactly the requesting agent.
6. As a user, I can **nudge, steer, pause, stop, restart** an agent and
   **pause / resume / cancel** a run, with confirmation for anything
   destructive and a visible "sent, awaiting confirmation" state.
7. As a phone-first user, the Termux setup offers **"Also run an AI team on
   this phone (experimental)"** as an optional last step, installs it into
   the rootfs I already have, and I can remove it from Settings.
8. As any user, turning the plugin off removes its card, its Activity
   items, its cached data and its secrets, and the app behaves as before.

## 8. Success criteria for "functionally complete" (BRD §54, scoped)

From the phone, against a Gas City on the PC, the user can: enable the
plugin, see the run the Mayor created from an objective sent from the phone,
inspect its work and dependencies, see two agents on different providers
working, get a notification for a pending interaction, answer it from
Activity, watch the agent continue, open the agent's live output, see the
run reach Completed. Changes/verification/merge are Sprint 3+ of the
research plan and are not part of this completion bar.

## 9. Risks and mitigations

| Risk | Mitigation |
|---|---|
| `v0` API changes weekly | Pin the OpenAPI snapshot in `contracts/`, generate only the ~25 DTOs used, fixture recorded from the same build, "unknown shape" tolerant parsing |
| Unauthenticated read plane leaks to the tailnet | Refuse plain `http://` to non-loopback; require `tailscale serve` TLS; show host identity on the card; document the exposure in PRIVACY.md |
| Phone-hosted supervisor is flaky | Experimental label, battery/background truth, one-tap stop, spike gate before showing the step |
| Vocabulary drift | Product terms in UI; raw provider objects kept on models for the Technical details expander |
| Attention spam | Only supervisor-declared interactions, gate beads, run failures and completions notify; everything else is timeline |
