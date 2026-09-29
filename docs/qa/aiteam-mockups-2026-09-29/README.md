# AI Team mockups (2026-09-29)

Rendered from `docs/design/aiteam-requirements-2026-09-29.md` (sections 4.1, 5, 8) with existing kit parts only. Dark theme, Android, 412x915 dp at 2x, fake data. Nothing in `lib/` changed.

Drafted in the throwaway test (deleted): plan card, findings card, promote card, phase header, lane stepper. They use KitPanel, KitRow, KitButton, KitChip and kit tokens. They are candidates for `KitPlanCard`, `KitFindingsCard` and a merge/promote card.

| File | Screen |
|---|---|
| 1-projects.png | Projects list |
| 2-project-overview.png, 2c-...-full-scroll.png, 2b-...-wide.png | Overview: phone viewport, the whole page, 1280x800 |
| 3-new-project-sheet.png, 3b-...-full-scroll.png | New project sheet: phone viewport and the whole scroll |
| 4-plan-card.png | Task conversation with the plan card, composer edge "Waiting for you" |
| 5-findings-card.png | Findings card plus the Passed state |
| 6-promote-card.png | Promote dev to main |
| sheet.png | Contact sheet |

Open points: the wide overview is a two-column arrangement, not the spec's three panes. The merge queue, digest and server lane parts are not drawn. Preselecting Parallel on the sheet is shown for the mockup only (open question A).
