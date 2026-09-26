# Screen review: shell and Work (areas `a-shell`, `e-workspace`)

*2026-09-26. Every rendered state of all 64 ledger pages in these two areas was
checked against `docs/design/principles.md` and scored.
Per-page scores and issues are in [`shell-work.json`](shell-work.json).
Motion is unscored (null) everywhere: the census stills can't show it, and no
page's source showed a motion defect worth flagging.*

**Verdicts:**

| Verdict | Pages | Count |
|---|---|---:|
| Keep | Mostly well-built dialogs and confirm sheets, plus the 4 unrendered non-surfaces | 17 |
| Fix | | 40 |
| Rethink | `workspace`, `activity`, `attention-overview`, `isolated-task-sheet`, `managed-workspaces`, `workspace-session-details-sheet`, `embedded-product-states` | 7 |

No page in these areas meets the "done" bar on every dimension, apart from a
handful of small dialogs.

## The five most important problems

1. **The Work tab starts work three ways at once** (`workspace`, `home-shell`).
   - The pinned block above the dock holds three things: a Solo · Team switch, a half-width "New conversation", and an "Isolated task" text button beside it. Together they take about a fifth of the screen.
   - The AI Team also appears twice on the page: the promo card, and the Team segment right under it.
   - Fix: one full-width "New conversation". Its chevron opens a choice of Conversation, Team task, or In a separate copy. Show the AI Team promo only until first use.
2. **The Inbox counts every request twice and keeps showing work it can't see** (`activity`, `embedded-connection-status-banner`).
   - Next to the listed requests, "Saved servers · 2 pending · Watched in each server's current project" counts the same requests again.
   - "Completion digests" and "1 unknown" are engine words.
   - The Running spinner keeps turning after the connection is lost. Work's green "Working" dot does the same while the line above says "Laptop isn't answering".
3. **Old error and empty states are still used by about 18 screens** (`embedded-product-states`, `projects`, `managed-workspaces`, `capabilities`, `running-work-sheet`, `global-sessions`).
   - They use a centred small icon, show the raw error as the only text ("Cannot reach http://192.168.1.20:4096: timed out"), and offer "Report a bug" for a timeout.
   - This is the owner's "two error styles".
   - Fix: reimplement `ProductErrorState`/`ProductEmptyState` as thin wrappers over `KitStateView`. That migrates every caller in one change.
4. **Engine words and raw paths above the Details fold** (`managed-workspaces`, `session-destination-sheet`, `global-sessions`, `isolated-task-sheet`, `attention-overview`, `connection-status-details-sheet`, `root-connecting`). Examples:
   - "opencode/ci-sandbox · daytona · Connected · /workspace/shopfront"
   - "/home/dev/.local/share/opencode/worktree/…"
   - "dev/shopfront"
   - "adapter-backed"
   - "Source: selected server's local cache"
   - "errno = 111"
   - "Something is at 100.64.0.7"

   The same feature also changes name from screen to screen: Isolated task, Worktree, directory, Workspace, Cloud environment.
5. **Dead ends and words that contradict the state** (`isolated-task-sheet`, `workspace-folder-chooser`, `bootstrap-gate`, `project-health`, `share-session-failed-banner`):
   - A failed worktree setup offers only "Close", even though the worktree exists and could be used.
   - The creating line is garbled: "Stopping now cannot undo a create the server may already be running."
   - The folder chooser keeps its happy title on error and hides Retry behind a lone "…".
   - The first-launch failure says "Secure storage is locked" with no next step.
   - "0 changed" appears next to "Git is not initialized".
   - "Retry when the connection is ready" appears while the header shows the server connected.

## Recurring patterns

- **Two ways to mark "current".** Several lists paint the whole current row accent and add a check or a greyed radio: Projects, Cloud environments, the Worktrees primary, the Move and organization sheets, and the server switcher. The standard's `KitRowIcon(current)` with a "Current ·" / "Connected ·" line exists and is barely used here.
- **Rows with two trailing controls.** Examples are pencil + chevron (Projects), radio + chevron (Move, Switch organization), and "Try again" + "⋯" (status lines). The standard allows one trailing action per row.
- **Buttons outside the kit:**
  - An outlined extended FAB on Worktrees and Cloud environments.
  - Right-aligned compact buttons (isolated task, question sheet, move confirmation with Cancel on top).
  - Side-by-side tertiary buttons (root stopped state, folder chooser, shell output, task list).
- **Confirmation containers are split.** Conversation delete and archive use the good `confirm-sheet`. Worktrees, cloud environments, the stop command, request dismissal and organization switch use AlertDialogs. Archive, which can be undone, asks first where the standard says to act and offer Undo.
- **One state, many wordings.** For example "Choose another server" and "Change server", or "Reconnecting to Laptop…", "Connection lost" and "Laptop isn't answering". Each should get one name and one `KitStatusLine`.

## Quick wins (small changes, large effect)

- Rename the update snackbar to "Update ready. Restart to use it.", give it a Restart action, and lift snackbars above the pinned action block. Today the notice covers New conversation.
- Use one name for the server-switch action ("Switch server") in every connection state. Drop "Try again" from the stopped state and remove the raw IP from the remote-failure body.
- Rewrite the isolated-task creating line.
- Fix the text defects:
  - "1 conversations"
  - "Shopfront Inc.." (doubled period)
  - "0 of 0" / "3 of 3"
  - the cut-off worktree helper ("URL-safe …")
- Collapse the task-list tool card's three progress readouts into one "2 of 4 done", and delete the "Server-reported tasks · mobile view" label.
- Label the session details sheet's values (Folder, Cost, Changes, Shared link), make them copyable, and use the full width.
- Make the Projects rows' rename a menu item, and mark the current project with the kit's current mark.
- Replace "Load more conversations" with loading on scroll.
