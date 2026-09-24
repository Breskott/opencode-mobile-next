# Design regressions and open UI issues (ledger)

Every place where a redesign made something worse, or an owner complaint is still open, gets a row here with its before/after evidence. A row closes only with a fix commit and new evidence; closed rows stay for the audit trail. Renders are widget-test captures at 412×915 (dark). **Nothing here has been viewed on a device yet** unless the row says so.

| # | Where | Worse / open | Evidence (before → after) | Found by | Status |
|---|---|---|---|---|---|
| 1 | Phone setup, start screen | The phone illustration is gone. The content floats mid-screen under a large empty top, so the first run feels bland. | `design-standard-setup-2026-09-24/before-01-setup-start.png` → `after-01-setup-start.png` | Coordinator review of the renders | **Open.** Plan: allow a first-run illustration exception in the standard, and anchor the content to the top. |
| 2 | Phone setup, progress screen | Dead space above the title. | `design-standard-setup-2026-09-24/before-07-setup-progress-running.png` → `after-07-…` | Coordinator review | **Open.** Same fix as #1. |
| 3 | Servers list | The server you are connected to is no longer highlighted; all rows look the same. | `design-standard-settings-2026-09-24/before-9-servers_list.png` → `after-9-servers_list.png` | Coordinator review | **Open.** Plan: a current-server mark in the row (`KitRow` leading or trailing), per standard §6 "state lives in the row". |
| 4 | Chat, permission card | "Review" became a full-width filled button. Consistent with the standard, but heavier on screen than before. | `design-standard-chat-2026-09-24/before-7-permission.png` → `after-7-permission.png` | Coordinator review | **Needs owner's eye.** Keep, or make it a compact button. |
| 5 | AI Team home and Work tab card | The owner: "This is very ugly". Engine jargon (convoy, formula, city, 127.0.0.1), dashboard controls, a card with six indicators. | `design-standard-aiteam-2026-09-24/after-*.png`; `test/goldens/team_*_phone_*.png` | Owner | **In progress:** `ds/aiteam-redesign` (spec `docs/design/aiteam-redesign-2026-09-24.md`). |
| 6 | AI Team, "Give the team a task" sheet | Send, the sheet's main action, sat at the end of the scrolling form, so on a shorter phone it is off screen (y=928 on a 900 px screen in the test). | `team_controls_test` › "sends objective…" | A test that failed after the redesign, treated as a product bug rather than rewritten | **Fix in progress** on `ds/aiteam-redesign`: the form scrolls and the actions are pinned below it. |
| 7 | Work tab | "Isolated task" still sits beside New conversation; the standard would move it into the Recent section's menu. | `work-tab-cleanup-2026-09-24/after-4-loaded.png` | Work tab agent | **Owner decision.** |
| 8 | Work tab and connection screen | The owner: "a mess"; the chooser flashed, three loading bars, the endless "Connecting…". | `work-tab-cleanup-2026-09-24/before-phone-*.jpg` → `after-*.png` | Owner | **Fixed** (merged `dca366f1`). Not yet seen on a device. |
| 9 | Stopped-server card | Four button styles, and a disabled button standing in for "Starting…". | `work-tab-cleanup-2026-09-24/before-phone-5-stopped-card.jpg` → `after-8/9-*.png` | Owner | **Fixed** (merged). Not yet seen on a device. |

## How rows get added

- Every before/after set in `docs/qa/design-standard-*` is reviewed pair by pair. Anything worse becomes a row, even if the standard "requires" it.
- The owner's complaints about a screen become rows immediately.
- A test that fails after a redesign is checked for a product bug before its expectation is changed (the `test-audit` rule: a failing retained test may be a real bug). A real bug becomes a row.
