# slice-close-security — pinned, checksummed host commands (2026-09-28)

Source: `docs/qa/review-board-closure-2026-09-28/README.md` gap 13
(host-management, the only security-shaped gap) and gap 16
(team-host-guide-sheet).

## Finish line and non-goal

Finish line: every host command the app shows downloads from one published
commit and checks a SHA-256 before anything runs, with the pin and checksum
in one place that a test keeps in step with the script in the repository.
Non-goal: changing the host scripts themselves (a new script needs a new
published commit to pin, which needs a push).

## What changed

**Single source of truth** — `HostScripts` / `HostScript` in
`lib/ui/setup_commands.dart`:

- `commit = c62f159ae3c1741cb4ec0ef92b4941c0ddfc0a18`, the commit of release
  1.0.44 (tag `v1.0.44+50`), published on GitHub. A commit, not a branch or
  a tag, so the bytes behind it cannot move.
- `ubuntu` (`scripts/host/ubuntu-opencode.sh`, sha256 `1f42642f…d721`) and
  `front` (`tool/host/cp_front/front.py`, sha256 `b6722549…cd47`).
- `verifiedDownload`: `curl -fsSLo <file>.part <pinned url> &&
  echo '<sha256>  <file>.part' | sha256sum -c - && mv <file>.part <file>`.
  Every line ends in `&&`, so a pasted block stops at the first failure,
  and a failed check never leaves an unchecked copy under the real name for
  the later `bash ubuntu-opencode.sh …` commands.

**Linux service page (host-management)** —
`lib/ui/screens/host_management_screen.dart`:

- Before: `curl -fsSL …/master/scripts/host/ubuntu-opencode.sh -o
  ubuntu-opencode.sh && OPENCODE_PORT=<port> bash ubuntu-opencode.sh
  install` (unpinned, unchecked).
- After: `HostScripts.install(port)`, the pinned, checked download followed
  by `OPENCODE_PORT=<port> bash ubuntu-opencode.sh install`.
- Supporting line: "Downloads the script from release 1.0.44 and checks its
  SHA-256 checksum first. If the file was changed, nothing runs."
- New "What this does" fold under the command: Linux with systemd only (not
  macOS or Windows), installs OpenCode with its official installer if
  missing, adds a service for the account that listens on that computer
  only, makes a password kept in a file only the account can read; then the
  Script version (commit) and SHA-256 checksum as copyable technical values.
- A command of several lines reads "Copy command" in its header instead of
  repeating the row title.
- The full walkthrough still opens through `openExternalLink`
  (`HostScripts.ubuntuGuideUrl`).

**Team host guide sheet** — `showTeamHostGuideSheet` in
`lib/ui/widgets/team_host_form.dart`:

- Each of the four steps is one sentence plus its exact command in
  `KitCodeBlock` with Copy: `command -v gc bd dolt`; `gc init … / gc rig add
  … / gc import install`; `gc start && curl -s …/health`; the front
  downloaded from the pinned commit, checked, then
  `python3 opencode-mobile-front.py --supervisor … --port 8373 --allow …`.
- The closing line that pointed at `docs/ai-team-host.md` in the repository
  is gone (string `teamUiHostGuideDocs` deleted); "Open the full guide"
  opens the published guide through `openExternalLink`.
- Step 4 now matches the guide (the front on 8373), not the stale "expose
  8372".
- Not done here: "Enter the address" as the sheet's primary. The sheet has
  seven hosts, one of which is the address form itself; that needs a slice
  that owns them.

**Guides** — `docs/ubuntu-host.md` and `docs/ai-team-host.md` §5 show the
same pinned, checked commands (the test checks they contain them). They are
linked on `master` because they are read, not run.

**Arabic** — the stale Arabic step lines and the deleted key were removed
from `app_ar.arb` (English falls back), per the Arabic-dropped rule.

## Sweep of `lib/` for piped downloads shown to people

| Where | Before | After |
|---|---|---|
| `lib/ui/screens/host_management_screen.dart` install row | download from `master`, no checksum, then run | pinned commit + `sha256sum -c` + `mv` + run |
| `lib/ui/widgets/team_host_form.dart` guide step 4 | prose; pointed at `tool/host/cp_front/front.py` in the repo via the docs line | pinned commit + `sha256sum -c` + `mv` + `python3` |

No other `curl … | bash` / `| sh` instruction is shown to people anywhere in
`lib/` or `app_en.arb`; the new test keeps it that way. The `curl` uses in
`lib/termux/`, `lib/builtin/` are scripts the app runs itself, not
instructions, and none pipe into a shell.

Found outside `lib/`, not changed (follow-ups):

- `scripts/host/ubuntu-opencode.sh` itself runs `curl -fsSL
  https://opencode.ai/install | bash` when OpenCode is missing (the upstream
  official installer, which publishes no checksum). Changing it needs a new
  published commit and a new pin.
- `docs/ai-team-host.md` §1a/§1d: `curl -fsSL https://tailscale.com/install.sh
  | sh` (Tailscale's official installer; no published checksum).
- `teamUiAddAddressHint` still reads `http://100.x.x.x:8372` while the guide
  says the phone reaches the front on 8373.

## Security notes

- No new URL is launched outside `openExternalLink`.
- The commands carry no secrets; the password stays in the script's 0600
  file and is printed, never typed into a command line or shell history.

## Proof the command works (live, 2026-09-28)

`git ls-remote` shows `refs/tags/v1.0.44+50^{}` =
`c62f159ae3c1741cb4ec0ef92b4941c0ddfc0a18` on GitHub, and the pinned raw URL
serves bytes with sha256 `1f42642f…d721`. Running the download part of the
command in a scratch folder:

```
ubuntu-opencode.sh.part: OK
WOULD-RUN-INSTALL            # (install replaced by an echo)
```

With one checksum digit changed:

```
ubuntu-opencode.sh.part: FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
exit=1                       # nothing ran; no ubuntu-opencode.sh left
```

## Tests

New:

- `test/host_script_pin_test.dart` (12): the pin is a 40-hex commit; each
  script's checksum matches the file in this checkout (proved failing by
  appending one line to the script: "scripts/host/ubuntu-opencode.sh
  changed. Publish a commit that holds it, then move HostScripts.commit and
  its sha256 … together."); the pinned commit holds exactly those bytes
  (`git cat-file`, skipped when the commit is absent); the command shape
  (`.part`, `sha256sum -c -`, `mv`, `&&` on every line); both guides show
  the same commands and no `/master/` script paths; nothing in `lib/` or
  `app_en.arb` pipes a download into a shell.
- `test/team_host_guide_sheet_test.dart` (3): four kit code blocks with the
  exact commands; Copy on step 4 gives the checked front command; no repo
  path; "Open the full guide" goes through the external-link confirm.
- `test/host_management_screen_test.dart`: "install copies the pinned,
  checked command" (clipboard equals `HostScripts.install(4747)`, no `| sh`
  or `/master/` on the page, the fold shows Linux, commit and checksum).

Run: the files above, `test/host_management_screen_test.dart`,
`test/team_plugins_screen_test.dart`, `test/team_plugins_layout_test.dart`,
`test/e7_setup_layout_test.dart`, `test/desktop_platform_gating_test.dart`,
the two golden files, and the gates `kit_ratchet`, `redaction`,
`ui_glossary`, `no_raw_error_text`, `kit/kit_manifest`,
`kit/kit_draft_manifest`: all pass except 8 failures that fail the same way
at the base commit `ee0fdb7a` (checked in a temporary worktree):
`team_plugins_screen_test` "manual add host kind" ×6 and
`e7_setup_layout_test` "setup servers at 320dp 2.5x" LTR/RTL.

Goldens: `test/revamp/screen_servers_2_golden_test.dart` and
`test/revamp/shared_team_1_golden_test.dart` fail 18 shots at the base when
the whole files run (order-dependent drift: board sheets, pairing scanner,
switch-server question, and the old host guide sheet). The host-management
and host-guide goldens here were regenerated from whole-file runs; after
this slice the same 17 unrelated shots fail and every shot this slice owns
passes. The unrelated goldens were not rewritten.
`flutter analyze`: clean.

## Images

| | Before | After |
|---|---|---|
| Linux service page, phone | `before-servers_host_management_loaded_dark.png` | `after-servers_host_management_loaded_dark.png` |
| Linux service page, wide | `before-servers_host_management_loaded_1280x800_dark.png` | `after-servers_host_management_loaded_1280x800_dark.png` |
| "What this does" open | — | `after-servers_host_management_install_what_dark.png` |
| Team host guide, top | `before-team_host_guide_sheet_dark.png` | `after-team_host_guide_sheet_dark.png` |
| Team host guide, end | — | `after-team_host_guide_sheet_end_dark.png` |

## Still needs a device

Copy on a phone and paste into a real Linux terminal on the host, then run
the install end to end (the download-and-check half was proven live above).
