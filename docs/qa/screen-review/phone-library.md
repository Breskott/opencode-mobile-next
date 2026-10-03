# Screen review: On this phone and Library (`h-termux`, `j2-library`)

70 pages: 45 in `h-termux` and 25 in `j2-library`. 65 are rendered (104 images) and 5 are not. The per-page verdicts, scores and fixes are in [`phone-library.json`](phone-library.json).

**Verdicts:** 13 keep · 51 fix · 6 rethink.

- The rethinks are `builtin-server-setup`, `development-services`, `termux-setup-get-termux` and `integrations`.
- Two not-rendered pages are also rethinks, on their copy alone: `command-auth-sheet` and `integrations-forget-uncertain-auth-sheet`.

Motion is scored nowhere: the census shows settled frames with loops off. Phone setup v2 does use `KitMotion` for its hero, ambient loop and celebration, and those need a device recording.

## The five most important problems

1. **Three front doors to one phone server** (`builtin-server-setup`, `termux-setup-get-termux`, `termux-setup-choose`, `termux-setup-checking`, `termux-setup-connected`, `termux-setup-connect-termux`).
   - Phone setup v2 (`phone-setup-start` → `-progress` → `-ready`) is the best work in this area.
   - Beside it are:
     - the old `BuiltinServerScreen`: four steps, half-width buttons and `127.0.0.1:4097` on screen. It is reached from the connection-failure card and from the Termux wizard.
     - the Termux wizard, which puts "Run OpenCode inside the app — no Termux · Set it up" at the foot of every state.
   - A person choosing "On this phone" can land on any of the three, and each has its own step names, time estimate (4 min vs 10–15 min) and OpenCode 1/2 control.
   - Fix: route every entry to phone setup v2 and delete `BuiltinServerScreen`. Keep Termux as one "Other ways" row that leads into a wizard with no in-app footer.
2. **The Termux wizard and install contradict themselves** (`termux-setup-failed`, `termux-setup-installed`, `termux-setup-update-sheet`, `termux-setup-replace-installed-sheet`, `termux-setup-installing`).
   - "OpenCode installation failed" is followed by "No managed Ubuntu installation found", while the log says Ubuntu is ready. The primary is then "Retry — resumes where setup left off".
   - "Termux is too old" sits over a panel that waits for Termux output.
   - An update sheet offers 1.18.29 → 1.18.29, and a replace sheet offers 2.0.10 with 2.0.10.
   - "Needs attention" says the install failed, then offers "Start installed OpenCode".
   - A switch installs "0.0.0-beta-18600" while the rest of the app says 2.0.10.
3. **Logs as content, not Details** (`termux-setup-installing`, `embedded-setup-terminal`, `local-agent-page`, `embedded-local-agent-onboarding-block`, `termux-storage`, `builtin-server-log-sheet`).
   - Phone setup v2 fixed this with a checklist, a determinate bar, "about N min left" and a folded log (regression row 16).
   - The Termux install, the Claude Code installer and the storage scan still make a raw, wrapping log the whole screen, with lines like "[oc] Installing proot-distro" and "/data/data/com.termux/files/…".
   - Their headers read "LIVE OUTPUT" / "LAST OUTPUT" with an audio-waveform icon.
4. **Library integrations repeat actions on every row and open with internals** (`integrations`, `credential-management-sheet`, `integrations-remove-mcp-sheet`, `integrations-forget-pending-auth-sheet`, `integrations-disconnect-provider-sheet`).
   - Every provider row has Connect plus its own "Manage accounts" line. That is the Plugins pattern the owner called "Wttf" (regression row 10).
   - The page opens with "Legacy sign-ins work only while their original screen and connection remain available."
   - The screen has three titles: Providers, MCP, and MCP and integrations.
   - Accounts show "Active account unknown" and three side-by-side text buttons, including Remove.
   - "Remove docs?" admits the server "may return after a server restart".
   - The confirm sheets talk of a "recovery record", a "provider runtime" and an "uncertain start".
5. **One secret in clear and one cut-off instruction** (`mcp-setup`, `integrations-mcp-oauth-code-dialog`). These are the two critical findings.
   - The MCP form's "HTTP headers" field is plain multi-line text, and its hint is "Authorization=Bearer token". The API-key dialog obscures its field; this one does not.
   - The OAuth code dialog's only instruction is cut to "Paste the complete callback URL whe…" at 100 % text.

## Recurring patterns

- **Engine words above the fold.** Examples: Paseo daemon, 127.0.0.1, `/work/shopfront`, "managed", "runtime", "Orphans", "bridge-unlocked", "Bounded log tail", "Persisted configuration", "Timeout in milliseconds", and raw model ids (`anthropic/claude-sonnet-4`).
- **Unmigrated layouts.** They show up as:
  - cards wrapping whole pages: Claude Code, Development services, the Termux paste guide (cards inside cards);
  - right-aligned button clusters: Claude Code states, dialogs;
  - half-width primaries: the built-in server, storage and process details;
  - uppercase letter-spaced section labels: Integrations;
  - dividers that run past the 16 dp rails: Commands, Skills, References, Tools, the setup terminal.
- **One action, many names.**
  - Cancel → "Stop setup?"; Clean → "Delete 700 MB".
  - The way out of a confirm is called Keep, Keep going, Keep running, Keep it or Cancel.
  - "Continue to app", "Continue", "Set up", "Open" and "Done" do not say where they lead.
- **Confirmations in the wrong places.** Starting a dev command and starting an installed server both ask first. Removing an MCP server removes nothing permanent, while "Forget saved sign-in" is not styled as destructive.
- **Colour that says the opposite.**
  - In the phone setup Customize sheet, required switches are ON but painted grey, so they look OFF.
  - In the skill sheets, "Raw" is shown in the accent colour while it is the unselected tab.
  - Stop controls are pink squares that look like colour swatches.
- **Kept well (use as reference):**
  - phone setup v2: its progress, ready and stop sheet;
  - the Claude Code stop, restart and remove confirms;
  - the process stop confirm ("a polite stop, then a forced one after 5 seconds");
  - the authorization launch dialog, which shows the host before leaving;
  - the Servers-list rows for the phone and Claude Code.

## Quick wins (copy or single-widget changes)

- Update and replace sheets: when nothing is newer, don't offer an update; call the reinstall "Reinstall OpenCode 2.0.10?" (`termux-setup-update-sheet`, `termux-setup-replace-installed-sheet`).
- Attention line: blame the leftover helper, not OpenCode, and add "Stop it" (`embedded-termux-attention-line`).
- OAuth code dialog: move the instruction into the body; add a paste button (`integrations-mcp-oauth-code-dialog`).
- Customize sheet: one "Always included: …" line instead of grey locked switches (`phone-setup-customize-sheet`).
- Phone setup progress: "Cancel" → "Stop setup"; "Setting up OpenCode"; "About 2 min left" (`phone-setup-progress`).
- Claude Code block with no Ubuntu: replace the lone "Refresh" with "Set up this phone" (`embedded-local-agent-onboarding-block`).
- Rewrite the internal-sounding confirm bodies for disconnect, remove account, forget sign-in, clean caches and unchecked install. Each is one string in `app_en.arb`.
- Rendered/Raw toggle: use the kit segmented control, and strip the duplicate H1 (`skill-activation-sheet`, `skills-preview-sheet`).
- Credential sheet: move the account actions into a row menu, with Remove error-coloured (`credential-management-sheet`).
- Catalog: hide "200K context" when the server's catalog has none (`catalog`).
