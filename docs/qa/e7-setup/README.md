# E7-SETUP — localized setup journeys

Base: a4b2433. Owner: onboarding_journey. Branch: fix/e7-setup-language.

Finish line: every app-authored visible message in server setup, Termux management, terminal, pairing, connection help, Tailscale and host instructions uses the localization catalog; controls remain reachable in RTL at 320dp and 2.5× text, with URLs, commands and paths displayed LTR.

Non-goals: runtime installation, authentication, switching or profile behavior changes; new native APIs; redesigning these screens. Other agents own other worktrees and locale plumbing. No live service actions.

Findings: E7-SETUP-01 missing terminal, pairing and failure copy; E7-SETUP-02 technical field/output direction; E7-SETUP-03 narrow large-text reachability. Evidence and focused checks pending implementation and serialized tool slot.
