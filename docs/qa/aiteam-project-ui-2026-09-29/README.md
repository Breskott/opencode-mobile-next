# Project-level AI Team UI — 2026-09-29

Finish line: the person can create, review and steer a persisted simulated project through the domain controller, including decisions, task checks and protected promotion.

Non-goal: choosing or connecting a real execution engine. Every displayed project demonstration is labeled Demo; its numbers are simulated.

## Ownership

- Main project/overview, board/graph, timeline, servers and journey harness: `build/aiteam-screens`.
- New/quick project, spec/plan/history, settings and role forms: `build/aiteam-editors`.
- Task transcript, findings, review and promotion: `build/aiteam-conversation`.
- Domain/controller/fixture and kit components are separately owned and integrated by the coordinator.

Each branch has its own worktree. The screen files import domain/state and kit only. Snapshot actions include the reviewed revision and a unique request ID. Promotion confirms the reviewed dev and main commits.

## Surface and behavior

Projects are ordered by unresolved decisions, running work, waiting and completed work. Phone selection opens a route; tablet selection fills the overview; desktop adds a task conversation as the third pane. Entry navigation accepts a project/task ID for Work, Inbox and notification routing.

The overview connects spec and plan review, milestones, lanes by server, merge queues by repo, recent decisions, budget reporting, board, timeline and placement. Board/graph share milestone, repo and server filters. Timeline groups days and filters decisions, merges and problems. Server placement sends the task and hand-off note through the controller.

The editors retain form drafts, require an explicit execution-mode and budget decision, and submit edited criteria and review gates. Task conversations preserve a failed send, distinguish team instructions from the person's message, select findings, and confirm protected promotion. Embedded conversation actions use neutral buttons, leaving New project as the screen's one primary.

## Visual evidence

Approved before-direction images: [projects](../aiteam-mockups-2026-09-29/1-projects.png), [overview](../aiteam-mockups-2026-09-29/2-project-overview.png), [wide overview](../aiteam-mockups-2026-09-29/2b-project-overview-wide.png). These are design mockups, not captures of a previous implementation.

After capture harness: `test/goldens/team/team_projects_golden_test.dart` renders the actual legacy Team home plus the new overview, new-project sheet, plan, findings and promotion conversation at 412×915 and 1280×800 in both themes. Additional 2× text frames cover 360×800, 412×915 and 1280×800. All render as Android.

The corrected capture checkpoint passed **27/27 gallery tests**, including tap target, label, contrast and pane-aware reading-order checks. All 27 frames were inspected in a contact sheet, with full-size inspection of phone plan/findings/new/promotion, the three-pane overview, and 360/1280-wide 2× text. The review found and corrected premature promotion, false completed marks, missing card spacing, enabled incomplete creation, and excessively wide standalone transcripts. The final acceptance-readiness correction (`57bac06d`) hides phase/milestone approval until merged work is ready. Its rerender and affected tests passed **34/34** (`gallery-final-2.log`); the updated overview, plan and findings frames were inspected again at full size. Visual signoff covers all 27 final images, with no observed overflow or premature approval actions. The integration source is frozen at `0c4bbd12` for the coordinator's full serial suite.

Selected captured artifacts (owned by the integration candidate):

- [Before, phone dark](../../../test/goldens/team/kit_teamprojects_before_dark.png)
- [Before, wide light](../../../test/goldens/team/kit_teamprojects_before_1280x800_light.png)
- [Overview, phone dark](../../../test/goldens/team/kit_teamprojects_overview_dark.png)
- [Overview, wide light](../../../test/goldens/team/kit_teamprojects_overview_1280x800_light.png)
- [New project, phone dark](../../../test/goldens/team/kit_teamprojects_new_dark.png)
- [Findings, phone light](../../../test/goldens/team/kit_teamprojects_findings_light.png)
- [Promotion, wide dark](../../../test/goldens/team/kit_teamprojects_promote_1280x800_dark.png)
- [Three panes, 2× text](../../../test/goldens/team/kit_teamprojects_scaled_text2_1280x800_dark.png)

Layout: `KitScreen.padding` supplies the one 16 dp phone gutter. `KitSectionLabel.inline` adds no second side inset. Team rows add no side inset. Cards apply their internal token padding, not another screen gutter. Screen code does not specify numeric padding, color, radius or typography sizes.

## Verification

- Pinned Dart format: passed for the submitted source and focused tests.
- `git diff --check`: passed before commits.
- Focused tests supplied: `team_projects_screen_test.dart`, `team_project_editors_test.dart`, `team_project_conversation_test.dart`.
- Integrated focused checkpoint: **74 tests passed**, including project fixture/controller/integration, editor, conversation, overview and existing targeted coverage. Evidence: coordinator log `focused-ui-2.log`.
- Integrated analyzer checkpoint: **No issues found** (`analyze-final.log`).
- Corrected Android gallery checkpoint: **27 tests passed** (`gallery-final.log`), run with `--update-goldens` through the shared machine lock.
- Final phase/milestone readiness assertions and all regenerated gallery scenes: **34 tests passed** (`gallery-final-2.log`); final analyzer remained clean. Repository-wide gates and the complete 973-file serial suite remain coordinator-owned and were running on frozen source `0c4bbd12` when this evidence was recorded; this document does not claim completion of that gate.

## Accessibility and device follow-up

All input, action and transcript visuals come from kit parts, retaining labeled controls, keyboard operation and kit target sizes. The approval/promotion action is pinned on the standalone conversation. The gallery checked overflow/contrast and 2× text in the integrated build; no overflow was observed in the inspected frames. TalkBack, keyboard navigation on physical hardware, Android interruption, notification delivery and engine costs require device validation; fixture rendering cannot establish them.

No credentials are accepted by these forms. File/path text and role instructions remain local demo data. Profile-scoped drafts use the controller profile ID, and engine persistence/deletion is owned by the controller slice.
