# Open questions for the owner (2026-09-10)

Only the owner can answer these. Each one blocks a specific part of the plan; the "default if unanswered" is what the sprint plan assumes.

## Orchestrator choice

1. **Which orchestrator will actually run?** Gas City (typed API, heavy host), Gas Town (legacy, shell-out dashboard), ralph-tui (sequential, no API), plain OpenCode 2 subagents, or a mix?  
   Default: Gas City supervisor API v0 as the first adapter; ralph-tui observed only via the Beads events journal later; Gas Town not targeted.
2. **Gas Town pack or a custom pack?** The Gas Town pack gives Mayor/Polecats/Witness/Refinery semantics; a custom pack means the BRD's glossary is decorative.  
   Default: Gas Town pack (Gas City's default).
3. **Which BRD "Run" is primary — formula runs (`/runs`) or convoys (`/convoys`)?** Ad-hoc Mayor work produces convoys; `gc sling --formula` produces runs.  
   Default: show both as Runs, with a "batch" subtitle for convoys.
4. **Is "objective → plan → work graph" expected in v1?** Gas City offers no planning API; the Mayor does it in a session.  
   Default: v1 = sling text to the Mayor, show resulting beads; no plan editor.

## Hosts and network

5. **Which host(s)?** The Ubuntu dev PC (docs/ubuntu-host.md) is the obvious candidate. Any Mac/Windows/WSL host?  
   Default: one Ubuntu host.
6. **Is Termux hosting in scope?** Gas City needs tmux, git, jq, lsof, pgrep and (by default) Dolt ≥ 2.1.0 + `bd` ≥ 1.0 + `flock`; `GC_BEADS=file` removes the Dolt/bd dependency. Whether `gc` and Dolt run under Termux/proot is **unverified**.  
   Default: out of scope for these three sprints.
7. **How will the supervisor be exposed on the tailnet?** `tailscale serve` (TLS + identity headers, recommended), plain `bind = 0.0.0.0` behind Tailscale ACLs (read-only by default; no TLS → the app must refuse), or a reverse proxy with a private CA?  
   Default: `tailscale serve` fronting `127.0.0.1:8372`.
8. **Is the unauthenticated read plane acceptable on your tailnet?** Anyone who can reach the port reads all beads, mail, transcripts and events. Mitigation is ACLs + `tailscale serve` identity checks in the sidecar.  
   Default: acceptable for a single-user tailnet; revisit before any shared tailnet.

## Write path and sidecar

9. **Who owns the host-side sidecar ("control-plane front")?** Language (Go, sharing Gas City's generated client and grant code, vs Python stdlib like the Codex fixture), repo location (`tool/host/` here vs a separate repo), packaging (systemd unit).  
   Default: Python stdlib in `tool/host/cp_front/`, systemd user unit, documented like `docs/ubuntu-host.md`.
10. **Write authorisation model:** Tailscale identity allowlist only, or identity + an app-side bearer stored in secure storage as a second factor?  
    Default: identity allowlist; bearer optional.
11. **Grant minting:** are you comfortable keeping the ed25519 city write key on the same host as the supervisor (Gas City's "same-user grant trust" residual risk)?  
    Default: yes, single-user host.

## Providers, keys, sessions

12. **Which harnesses will the agents run?** Built-ins exist for claude, codex, gemini, kimi, opencode, cursor, copilot, amp, kiro, grok, pi, omp, antigravity. Which API keys/subscriptions are available on the host?  
    Default: opencode + claude + codex.
13. **Should Gas City's `opencode` harness point at your long-running OpenCode server, or run its own `opencode acp` per session (Gas City's default transport for opencode)?** This decides whether "Run → Agent → raw session" can land in the existing chat UI.  
    Default: unknown; Sprint 2 CP-207 measures what linkage exists.
14. **Routing rules (BRD §18)** are pack/agent config in Gas City (`provider`, `option_defaults.model`, pools). Do you want the app to *display* them (read `/config`) or *edit* them?  
    Default: display only.

## Review, verification, merge

15. **Where do diffs come from?** OpenCode server's VCS/worktree surface on the same host (reuse), or the sidecar running `git diff` in agent worktrees?  
    Default: reuse OpenCode VCS when same host; sidecar `git diff` otherwise (Sprint 3).
16. **What is "verification" for your projects?** `flutter analyze` + serial `flutter test` (AGENTS.md gates) run by a Gas City *order* or by the Refinery formula? Who defines the check step?  
    Default: an exec order per rig running the AGENTS.md gates; results surfaced as run steps.
17. **Merge strategy:** `sling.merge = direct | mr | local`; Gas Town-style merge queue via the pack; or GitHub PRs with `gh` gates? Is any automatic merge ever acceptable?  
    Default: `mr` + human approval; no auto-merge; "Merge" button not built in these sprints.
18. **Review state:** Gas City has no review status on beads. Use a label (`review`) or metadata key convention?  
    Default: label `needs-review` set by the formula; app maps it to `WorkState.review`.

## Product

19. **Should Gas City vocabulary (city, rig, convoy, sling) be visible behind an "advanced terminology" toggle, or fully hidden?**  
    Default: hidden, with a "technical details" expander on detail screens.
20. **Notifications:** which gate kinds should push (BRD §22)? Requires the existing notification plumbing to accept orchestration deep links.  
    Default: pending interaction, run failed, gate opened, run completed.
21. **Multiple projects/hosts:** one supervisor per host with many rigs, or several hosts? Cross-host aggregation is app-side either way.  
    Default: one host, many rigs.

## Fact checks the owner can do in minutes on the dev PC

- `brew install gascity` / `gc version`; `gc doctor` to see which prerequisites are missing on the Ubuntu host.
- `gc supervisor start` then `curl -s http://127.0.0.1:8372/health` and `curl -s http://127.0.0.1:8372/v0/cities` to confirm the shapes in gas-town-findings.md §2.2.
- `curl -N http://127.0.0.1:8372/v0/city/<city>/events/stream` while `bd create "hello"` runs, to confirm `event: event` frames and `seq`.
- Try `tailscale serve --bg 8372` and load `https://<host>.<tailnet>.ts.net/health` from the phone.
