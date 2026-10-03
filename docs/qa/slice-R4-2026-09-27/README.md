# slice-R4 — Row groups on one inset (2026-09-27)

Definition: `docs/ux-system/revamp/leftover-units.json` id `slice-R4`. Kit-only
unit: write set `lib/ui/kit/{kit_row,kit_row_parts,kit_section_label,kit_sliver_row_group,kit}.dart`
and `test/kit/kit_overflow_scenes.dart`. Built on the crashed builder's WIP
(`d4a29a4f`), merged with `feat/phone-setup-v2` twice (no conflicts).

## What changed

- **One inset** (`KitRowGroup`): the group label is now a `KitSectionLabel`
  whose words start at the group's own edge: the gutter on a page, the sheet
  padding with `margin: EdgeInsets.zero`. That is the same x as a `KitField`
  label and a `KitDetailsFold` title. Before, it sat 4 dp further in
  (`space1`). Every screen with a labelled row group moves its label 4 dp to the
  start.
- **Section gap** (`KitRowGroup.gapBefore`, `KitSectionLabel.gapBefore`):
  when it is null and the group has a label, the group keeps
  `KitTokens.sectionGap` (22) from what is above it. It gets none as the first
  thing in a scroll view or on a page. Space the caller already put above
  counts toward the gap and never doubles it. That space can be a fixed
  `SizedBox` spacer, or the top of a `Padding`/`SliverPadding` the label sits
  first in (Work's "Other projects" uses one). An unlabelled group adds no gap
  unless asked.
- **`labelTerm`** on `KitRowGroup` / `KitSliverRowGroup` and **`explanation`**
  on `KitSectionLabel` turn the label words into a `KitTerm`. The 48 dp target
  reaches into the gap above and the label gap below instead of pushing the
  section apart, so an explained label keeps a plain label's place.
- **New `KitSectionLabel`** (`lib/ui/kit/kit_section_label.dart`): it replaces
  `widgets/product_states.dart` `SectionLabel` for new code. It supports a
  trailing part, which drops under the words at large text.
- **New `KitSliverRowGroup`** (`lib/ui/kit/kit_sliver_row_group.dart`): rows on
  one `surface1` panel with `panelCornerRadius` corners and text-inset
  hairlines, in a lazy `SliverList`. It takes head `children` followed by
  `itemCount` rows from `itemBuilder`. Work's head and recent rows can now be
  one panel.
- **`KitExpandRow.titleMaxLines`** (default 1), so error titles can use 2.
- `kit.dart` exports and doc rows; `kit_overflow_scenes.dart` has a scene for
  each new part. Each gallery has a text-2x shot, which G4 required.

## Screens (not in this unit; adoption is in later leftover units)

R4 changes no screen source. Screens pick up the inset and the gap through
`KitRowGroup`. The later units that adopt the new parts are listed in
leftover-units.json:

- project_health / managed_workspaces: `SectionLabel` becomes `KitSectionLabel`,
  and the ad-hoc `SizedBox(sectionGap)` spacers go.
- session_export: `KitSectionLabel`. `product_states.dart` `SectionLabel`
  forwards to `KitSectionLabel` and is retired later.
- integrations: Providers / MCP servers / Resources explanations through `labelTerm`.
- workspace_screen: head plus recent rows as one `KitSliverRowGroup`.
- Report a problem: `titleMaxLines: 2`.

These screen areas were owned by other agents and left alone: Settings hub
pages (P3.10), quota/usage (P5.4), setup / phone setup / team phone
onboarding (P1.7) and background/automation (P6.1). Their goldens still moved
with the kit change (see below).

## Tests

New behaviour tests:
- `test/kit/kit_row_group_inset_test.dart`: 'Planner' and 'Supervision'
  share an x with the Details title in a sheet; the gutter on a page; three
  labelled groups measured (no gap first, then the section gap); spacers are
  not doubled; `labelTerm`; two-line fold titles.
- `test/kit/kit_section_label_test.dart`: heading semantics; inset; gaps;
  lists; first on a page that does not scroll; padding above collapses; an
  explained label keeps a plain label's rhythm; the trailing part wraps.
- `test/kit/kit_sliver_row_group_test.dart`
- `test/kit/kit_row_group_test.dart`: the inset case.

To confirm the padding-collapse test guards the fix, the fix was reverted: the
test then failed (44 vs 22).

Run: the files above plus kit_row_test, kit_row_parts_test,
kit_manifest_test (G4), kit_ratchet_test, text_scale_overflow_test (G6) and the
kit_row / kit_row_parts / kit_section_label / kit_sliver_row_group galleries.
G6: at 320 and 360 dp with text 2.0, `KitRowGroup/default` no longer
overflows, because the label now wraps. `test/text_scale_overflow_baseline.json`
is tightened to `{}`. The KitRowGroup, KitSectionLabel, KitSliverRowGroup and
KitExpandRow scenes pass. `flutter analyze` is clean. Pre-existing failures on
the integration tip
`52ab78c4` are not R4's: G4 (manifest backlog), G17
(integration_tiles, quota_monitor_section), G21 (kit_choice_list, task_card,
board_lane, log_panel, checklist, viewer, nav, top_bar), 3 KitSwitchRow
goldens, and two text_scale_overflow tests: "home shell at 2.5x" and "every
exported kit part has a scene" (KitScrollBehavior, KitNumberFormatter,
KitLogBuffer).

## Goldens

All 143 golden test files ran on R4 and on the integration tip. 822 golden
tests already failed on the tip (stale from earlier merges) and were **not**
regenerated. 189 tests failed only with R4. I checked samples of their diffs:
the label moves 4 dp to the gutter, and where a labelled group sat right under
other content the section gap is added. Only those 189 were regenerated
(34 files): chat_form_sheet, kit_date_time_picker, kit_group_note, settings,
team_agent, work_parts, work_tab, chat_4, screen_chat_1-3,
screen_library_1-3, screen_phone_1, screen_review_2, screen_settings_1,
screen_system_1, screen_usage_1-2, screen_work_1-4, shared_phone_1,
shared_review_1, shared_servers_1, slice_p310_settings_ia, slice_p34,
slice_p54, slice_p6_6a_defaults, slice_r17, team_phone_v2, undo_from_here.
The kit_row / kit_swipe_action goldens (label inset) and the R4 galleries were
regenerated as well. Any golden that was already stale and also moved with R4
still shows both changes until its owner regenerates it.

## Images

- `kit_row_default_light_before_after.png` (phone),
  `kit_row_default_1280x800_dark_before_after.png` (wide): the label moves
  to the gutter.
- `work_loaded_light_before_after.png`: "Other projects" on the gutter, with
  the gap unchanged (the SliverPadding collapses into it).
- `work_managed_workspaces_error_light_before_after.png`,
  `…_1280x800_dark_before_after.png`: "Providers" on the gutter, one section
  gap under "Try again".
- New parts: `kit_section_label_page_{dark,1280x800_light,text2_light}_new.png`,
  `kit_sliver_row_group_default_{light,1280x800_dark,text2_dark}_new.png`.

## Still needs a device

Tapping an explained label (the `KitTerm` target reaching into the gap) with
TalkBack and a real finger; RTL placement of the explained label.
