# Onboarding — the optional AI Team step, on-device and on a computer

## 1. Where onboarding branches today

The Termux setup screen (`lib/ui/screens/termux_setup_screen.dart`) walks
three steps — install Termux, unlock the bridge, install & start OpenCode —
and then connects. The managed runtime is a proot-distro glibc Ubuntu
rootfs (`docs/opencode2-termux.md` §3, path #1) that already runs `opencode`
or `opencode2`, managed by `~/.oc/manager.sh` with a state file
(`phase=ready … runtime=opencode1`).

Two facts decide the design:

- Gas City publishes `gascity_<ver>_linux_arm64.tar.gz` (24 MB). **TEAM-001
  showed the file beads store (`GC_BEADS=file`) cannot run the Gas Town
  pack**: agent work queries, the claim protocol and the formulas call `bd`,
  which needs a Dolt database. The on-device path therefore needs `bd`
  (≥ 1.0.4, arm64 build exists) and `dolt` (arm64 build exists, ~100 MB)
  inside the rootfs, plus tmux, git, jq, procps, lsof from apt. The
  "about 60 MB" figure below becomes roughly 200 MB.
- Whether `gc supervisor` and tmux behave under proot on Android is
  **unverified**. The plan therefore treats on-device as *experimental and
  spike-gated* (CP-000).

## 2. The optional step (Termux flow)

After step 3 succeeds ("OpenCode is ready · connected"), the screen adds a
fourth, clearly optional block:

```
┌────────────────────────────────────────────────────┐
│ Optional · experimental                            │
│ Also run an AI team on this phone                  │
│ Lets several coding agents work on your project     │
│ while you supervise from Workspace. Uses the same   │
│ Linux environment you just set up. About 60 MB.     │
│                                                    │
│ ⚠ Android may stop it when the screen is off.      │
│   Nothing is lost; runs resume when you start it.  │
│                                                    │
│ [ Skip for now ]                 [ Set up AI team ] │
└────────────────────────────────────────────────────┘
```

Rules:

- Shown only when `TermuxRuntime.supportsAiTeam` is true — i.e. the spike
  passed for this rootfs image and the pinned `gc` version — and the device
  is arm64. Otherwise the block is absent (not disabled) and Settings shows
  "Not available on this phone: <reason>".
- "Skip for now" is the primary path; the step is re-offered once from
  Settings › Plugins, never by a modal.
- Setting up runs the same visible step list the OpenCode install uses:
  1. Download `gc` (checksum verified against the pinned SHA-256)
  2. Install prerequisites in the Linux environment (`tmux git jq procps
     lsof`)
  3. Create a city next to the project folder (`gc init`, managed Dolt beads
     store, Gas Town pack, harness = the on-device OpenCode via ACP); the
     project needs a git `origin` (a local bare repo is enough)
  4. Start the supervisor on loopback (`127.0.0.1:8372`)
  5. Connect (health → cities → running)
- Live output panel identical to the OpenCode install (LTR mono, copyable),
  "You can leave this screen and return to check progress."
- Success card: "AI team is running on this phone · 1 agent ready" with
  [Open Workspace]. Workspace now shows the AI Team card for the Termux
  server profile.

## 3. What "on this phone" means for the model

- Host mode `phone` on the profile; orchestration URL is loopback; no
  front and no grant: the supervisor runs as the same user as the app's
  bridge, so writes use the local write path the spike validates (Gas
  City's loopback trust). If the spike shows loopback writes still require
  a grant, the manager script mints it on-device and stores it in secure
  storage; the phone is both host and client, which is the one case where
  that is acceptable.
- Agents run through the on-device OpenCode (`opencode acp`), so "Open
  session" links can resolve to the app's own chat when the session is
  visible on the managed server; the spike measures this.
- Battery and lifecycle truth (mirrors the managed OpenCode copy): no
  promise of overnight runs; the existing "keep the mobile connection
  alive" note gains one sentence about the team; recovery attempts follow
  the same 3-attempt opt-in as the server.
- Removal: Settings › Plugins › AI Team › Remove from this phone: stops the
  supervisor, deletes `gc`, the city directory and the file beads store,
  keeps the project files, and turns the plugin off for the profile.

## 4. The computer-host path (any computer)

When the saved server is a computer, onboarding is one card and one guide:

- Server editor gains an **AI Team (optional)** section: "If this computer
  runs Gas City, the app can find it automatically. [Learn how]". No fields
  until the user taps Add manually.
- `docs/ai-team-host.md` (new guide, Sprint A) shows the four host commands
  for Linux, macOS, Windows (WSL): install Gas City, `gc supervisor start`,
  `tailscale serve --bg 8372`, and (Sprint B) run the control-plane front;
  plus the fact-check curls from the research doc.
- Every host mode shows a one-line performance disclaimer on its card and in
  Settings: PC "Runs as fast as your computer; keep it awake"; laptop/WSL
  "Sleep and lid-close pause the team; runs resume on wake"; phone "Android
  may stop it when the screen is off; slower than a computer".
- Discovery card on Workspace after connect (02-ux §1.2).

## 5. Honest unavailability copy

| Situation | Copy |
|---|---|
| Host has no supervisor | "This server doesn't run an AI team yet. Set one up on the computer — it takes a few minutes." [How] |
| Plain HTTP to a non-loopback address | "AI Team needs HTTPS for remote hosts. Use `tailscale serve` on the computer, then try again." |
| Supervisor reachable, city not running | "The team host is starting. Try again in a moment." |
| Read-only (no front) | "You can watch this team from the phone. Answering and steering need the front on the computer." [How] |
| Phone: spike not passed / not arm64 | "Not available on this phone. Running a team needs the 64-bit Linux environment; this device or build can't provide it." |
| Phone: supervisor stopped by Android | "Android stopped the team while the app was away. Nothing is lost." [Start again] |

## 6. First-run (welcome) touchpoint

The welcome/pairing flow does not mention AI Team. The first time the user
sees the feature is either the discovery card (computer) or the optional
Termux step (phone). This keeps the three-step "first session" promise
intact.
