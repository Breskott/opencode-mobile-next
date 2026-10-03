# Screen review: how verdicts become work

Each screen of the app was rendered in `docs/qa/screen-census/` and critiqued against `docs/design/principles.md` (six critics; `*.json` and `*.md` in this folder). The owner reviews each screen, one at a time, on the review board: https://claude.ai/artifact/7MTABNvxMtmn3nnqN2Ncx4 (private). The board stores his verdicts in the artifact's `verdicts` collection.

## What each verdict means

- **Keep.** The screen stays as it is, and no work is scheduled.
- **Fix.** Apply the critic's issues for the screen, and the owner's note first where the two disagree. It stays a fix pass: the page's purpose and structure do not change. A Fix whose note questions the page ("Do we even need this?", "Kill if not needed") is handled as a Rethink.
- **Rethink.** The owner's rule (2026-09-26) is: "at a higher level than UI fixes: do we need this page, are we considering all user states, do we have enough tools/info/actions, plus the fixes if applicable." For every Rethink:
  1. **Purpose.** Does the page need to exist? It could merge into another page, shrink to a row, tooltip or sheet, or go. Check how people reach it (`docs/design/ui-ledger`, `reachedFrom`) and what would break without it.
  2. **People and situations.** Cover every persona and every state:
     - first run, returning, empty, loading, slow or not answering, offline, error, success;
     - the phone's own server (built-in or Termux) and a computer;
     - large text, Arabic right to left, one hand.
  3. **Job, information, actions.** Decide what the person is trying to do here. Check whether they have the information to decide and every action they need, including undo and recover. List what is missing and what is noise.
  4. **Flow.** Map how the person arrives and leaves: entry points, back, notifications, deep links.
  5. **Then the UI, motion and copy fixes** from the critique, where they still apply.

  The output is a short proposal (keep, merge, remove or redesign, with a sketch or render). The owner approves it before a page is removed or a redesign is built.

## From verdicts to work

- Verdicts are read from the board, grouped by area and ordered by severity.
- Each batch lands on its own branch with before and after renders. The screens are then re-rendered in the census and republished on the board.
