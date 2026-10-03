# slice-goldens-kit — reviewed refresh of the kit galleries (2026-09-28)

Scope: the 77 kit gallery files `test/goldens/kit/*_golden_test.dart` (DPR 3),
on branch `revamp/slice-goldens-kit` from `feat/phone-setup-v2` at 138f8216.

## Method

1. Ran all 77 files (4 serial chunks through `tool/qa/machine_lock.sh`):
   **228 failing goldens, all pixel diffs** (no G5, overflow or layout
   exceptions) in 38 files.
2. Classified every failure by the largest per-channel difference between the
   master and the test image. **122** differ by at most 2/255 and only in
   dark themes: they are the R9 dark `text3` change (#8A8D94 -> #8C8F96, so
   a disabled button passes AA, 0c3f5718). A diff amplified 33x shows only
   text3 glyphs (`r9-dark-text3-samples.png`).
3. The other **106** were looked at one by one (crop of the changed region,
   master vs test), attributed to the merged change that explains them with
   `git log` on the part, and grouped below.
4. One finding was a product defect (below); fixed in the kit, then
   `--update-goldens` on exactly the 38 failing files. The changed PNG set
   equals the failing set plus the two request-sheet shots the fix changes
   (`kit_request_sheet_permission_always_{dark,light}`).
5. Re-ran all 77 files: green (4 skipped as before). `flutter analyze`: clean.

## Regression found and fixed

- **Request sheet hid the tail of the command to allow.** KitRequestSheet.md
  says the permission's full text "wraps and never truncates"; the sheet
  passed the command to KitCodeBlock without `wrap`, so it scrolled sideways
  behind an edge fade. After R3 put Copy on the line, even a 1280 sheet cut
  `…offline_queue_test.da`. For a command the person is asked to allow,
  a hidden tail is a safety problem. Fix: `lib/ui/kit/kit_request_sheet.dart`
  `_command` passes `wrap: true` (continuation lines hang past the `$`).
  Test: `test/kit/kit_request_sheet_test.dart` "10b" at 412 and 1280 (no
  sideways scroller in the block, the text stays inside it and wraps). Both
  cases fail on the base and pass with the fix.

Outside this slice's goldens: `lib/ui/screens/chat/permission_sheet.dart`
uses the same sheet, so chat permission-sheet goldens that show a long
command will wrap it too (recorded in lane-notes).

## Kit hand-offs from the other golden lanes (after merging feat/phone-setup-v2)

- **KitCodeBlock caption pushed in beside a labelled copy** (revamp-B,
  98c064bd). The copy flexed beside the caption; both took half the header
  and the unused rest landed before the caption (~70 dp in on 1280). Fix:
  `lib/ui/kit/kit_code_block.dart` `_buildHeader` caps the labelled copy at
  60 % of the header beside a name and never flexes it; alone it still fills.
  Tests: `test/kit/kit_code_block_r3_test.dart` pins the caption edge at 412
  and 1280, LTR and RTL (1280 fails on the base), and a long label at 2.0
  text. Held goldens: the 4 `chat_continue_on_computer_sheet_available*`
  refreshed (caption back at the edge, `$` prompt with hanging wrap
  intended); the 4 `chat_continue_on_phone_sheet_qr*` match their committed
  images again, so they are unchanged. Sheet: `kit-code-header-caption-fix.png`.
- **KitSkeletonRows invisible on a light grouped card** (app lane). Bars were
  `surfaceContainer`/`surfaceContainerHigh`, the card's own white in light.
  Fix: `lib/ui/kit/kit_progress.dart` paints the shapes as `text1` at 12 %
  (mark, title) and 9 % (supporting), laid over whatever surface they sit on.
  Test: `test/kit/kit_skeleton_rows_test.dart` checks every shape against
  ground, surface1, surface2 and surface3 in light and dark (>= 1.15:1; 7 of
  8 fail on the base). G4 allowlist shrinks by KitSkeletonRows (it now has a
  behaviour test). Sheet: `skeleton-rows-visible.png` (the folder browser's
  slow state on a wide light card was an empty white box before).

### Goldens outside the kit changed by these three fixes (47, refreshed)

All 170 golden files were run after the fixes; 57 failed. 47 are these
fixes and were refreshed after review:

- skeleton rows now visible (37): kit_diff_view_loading*, kit_viewer_loading*,
  kit_choice_list_loading*, kit_board_lane_loading*, team_board_loading*,
  folder_browser_{loading,slow}{,_wide}*, work_{loading,restoring}*,
  settings_about_light;
- request-sheet command wraps (4): chat_permission_sheet_{dark,light},
  chat_5_permission_sheet_{dark,light};
- caption at the block edge (6+): add_server_{manual,codex,paseo,paired,testing}*,
  first_run_connect*, sessionlink_send_address_off*.

Sheet: `fix-consequences-wrap-and-caption.png`.

Not mine, left failing and handed off (lane-notes): `team_home_loaded*` and
`team_home_search*` (6) render "waiting 16 d 23 h" vs "17 d": the test has no
pinned clock, so the golden drifts with the date; `work_workspace_context_sheet*`
and `work_workspace_folder_chooser*` (4) still show "This device (Termux)",
the copy 2fec0fc3 changed to "This phone · Termux" on purpose.

## Counts

| Verdict | Goldens |
|---|---|
| Intended — R9 dark text3 | 122 |
| Intended — other merged changes (sheets below) | 104 |
| Intended after the product fix (request sheet) | 4 (+2 not failing before) |
| Regressions fixed in the kit | 3 (request-sheet command wrap; code-block caption edge; skeleton rows contrast) |
| Other goldens refreshed as consequences of the fixes | 47 (+4 held shared_chat_1) |
| Handed off (not kit) | 10 goldens: team_home clock drift (6), work_workspace copy (4) |

## Contact sheets (before | after)

| Sheet | Change |
|---|---|
| `r9-dark-text3-samples.png` | R9 dark text3, with a 33x diff (0c3f5718) |
| `r2-input-dialog-sheet.png` | R2: input dialog is a bottom sheet on a phone (24be364a) |
| `r3-code-block-and-request-wrap.png` | R3 code block without the empty header band (e55a23f9) + the wrap fix |
| `r3-code-block-markdown.png` | R3 code blocks in markdown and the viewer |
| `r1-top-bar-flat.png` | R1 KitTopBar flat on the gutter on PC (9413f93d) |
| `kitrow-v2-two-line-titles.png` | KitRow v2 two-line titles from 1.3x text (08a7741e); foundation cards |
| `kitstateview-v2-empty.png` | KitStateView v2 empty look (97fc4f57) |
| `r4-section-label-and-row-inset.png` | R4 section label and row inset (ba9d7088) |
| `r5-accent-tertiary-link.png` | R5 accent tertiary on the "Why" action (4e49ccde) |
| `small-kit-changes.png` | KitIconButton v2 disabled glyph and close glyph; LOOK-6 neutral confirm tile; R5 spinner; "2,500" |

## Owner eyeball

- `kit_markdown_streaming_dark`: with the controls trailing the first line,
  a long Kotlin line wraps mid-identifier (`getStringExt|ra`). Wrap on a
  phone was already the default; the narrower text column makes it more
  visible.
- `kit_request_sheet_permission_*`: the command now wraps at `/` even in
  a 560 dp sheet; the copied command is still the source text.
- `kit_foundation_work_text2_*`: row supporting lines still cut at 2.0 text
  (`Editing workflow fil…`); titles now wrap. By design (KitRow v2 keeps the
  supporting line to its max lines), worth a look.

## Table

| Golden | Diff % | Verdict | Reason / commit | Sheet |
|---|---|---|---|---|
| kit_action_block_disabled_dark | 0.14 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_action_stack_disabled_dark | 0.11 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_agent_strip_mixed_1280x800_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_agent_strip_mixed_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_agent_strip_overflow_1280x800_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_agent_strip_overflow_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_arrival_marked_1280x800_dark | 0.03 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_arrival_marked_1280x800_light | 0.03 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_arrival_marked_dark | 0.09 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_arrival_marked_light | 0.09 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_arrival_marked_text2_1280x800_dark | 0.11 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_arrival_marked_text2_1280x800_light | 0.11 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_arrival_marked_text2_dark | 0.31 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_arrival_marked_text2_light | 0.31 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_board_lane_loaded_1280x800_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_breadcrumb_collapsed_dark | 0.04 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_breadcrumb_default_1280x800_dark | 0.02 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_breadcrumb_default_dark | 0.04 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_breadcrumb_focused_dark | 0.04 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_breadcrumb_truncated_dark | 0.02 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_checklist_before_start_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_checklist_before_start_text2_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_checklist_compact_dark | 0.02 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_checklist_failed_dark | 0.1 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_checklist_failed_text2_dark | 0.1 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_checklist_paused_dark | 0.1 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_checklist_person_step_dark | 0.02 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_checklist_working_1280x800_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_checklist_working_dark | 0.03 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_choice_list_empty_dark | 2.22 | intended | KitStateView v2 empty look: square icon tile, title role (97fc4f57); goldens were made on branches before its merge | kitstateview-v2-empty.png |
| kit_choice_list_empty_light | 2.22 | intended | KitStateView v2 empty look: square icon tile, title role (97fc4f57); goldens were made on branches before its merge | kitstateview-v2-empty.png |
| kit_choice_list_picker_row_dark | 1.04 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_choice_list_picker_row_light | 0.85 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_confirm_discard_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_confirm_neutral_dark | 0.55 | intended | LOOK-6: the accent is never a mark colour — a neutral confirm tile is surface3 (15ae4d86) | small-kit-changes.png |
| kit_confirm_neutral_light | 0.49 | intended | LOOK-6: the accent is never a mark colour — a neutral confirm tile is surface3 (15ae4d86) | small-kit-changes.png |
| kit_confirm_stop_working_dark | 0.25 | intended | R5 spinner tokens: the working spinner arc (4e49ccde) | small-kit-changes.png |
| kit_confirm_stop_working_light | 0.19 | intended | R5 spinner tokens: the working spinner arc (4e49ccde) | small-kit-changes.png |
| kit_date_time_picker_row_disabled_dark | 0.36 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_date_time_picker_row_empty_set_dark | 0.5 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_date_time_picker_row_error_dark | 0.13 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_date_time_picker_time_12h_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_date_time_picker_time_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_date_time_picker_time_invalid_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_details_fold_technical_details_sheet_dark | 0.05 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_dialog_input_discard_dark | 62.58 | intended | R2: the input dialog is a bottom sheet on a phone, the discard question a confirm sheet (24be364a); golden predated R2 | r2-input-dialog-sheet.png |
| kit_dialog_input_discard_light | 62.58 | intended | R2: the input dialog is a bottom sheet on a phone, the discard question a confirm sheet (24be364a); golden predated R2 | r2-input-dialog-sheet.png |
| kit_dialog_input_working_dark | 62.96 | intended | R2: the input dialog is a bottom sheet on a phone, the discard question a confirm sheet (24be364a); golden predated R2 | r2-input-dialog-sheet.png |
| kit_dialog_input_working_light | 62.96 | intended | R2: the input dialog is a bottom sheet on a phone, the discard question a confirm sheet (24be364a); golden predated R2 | r2-input-dialog-sheet.png |
| kit_field_default_1280x800_dark | 0.03 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_field_default_dark | 0.08 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_field_default_text2_1280x800_dark | 0.09 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_field_default_text2_dark | 0.24 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_field_disabled_dark | 0.1 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_field_focused_dark | 0.07 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_foundation_work_1280x800_dark | 2.71 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_foundation_work_1280x800_light | 2.64 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_foundation_work_ar_dark | 5.6 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_foundation_work_ar_light | 5.27 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_foundation_work_dark | 7.81 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_foundation_work_light | 7.62 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_foundation_work_text2_dark | 9.86 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_foundation_work_text2_light | 9.86 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_group_note_default_1280x800_dark | 0.09 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_1280x800_light | 0.09 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_1600x1000_dark | 0.06 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_1600x1000_light | 0.06 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_360x800_dark | 0.31 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_360x800_light | 0.31 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_800x1280_dark | 0.09 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_800x1280_light | 0.09 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_915x412_dark | 0.24 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_915x412_light | 0.24 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_dark | 0.24 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_light | 0.24 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_text2_1280x800_dark | 0.31 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_group_note_default_text2_dark | 0.85 | intended | R5 accent tertiary: the "Why" action takes the accent (4e49ccde); R4 section label inset | r5-accent-tertiary-link.png |
| kit_icon_button_disabled_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_image_zoom_rest_ar_1280x800_dark | 0.02 | intended | KitIconButton v2: disabled glyph is solid text3, never partial opacity (bdbec9f4) | small-kit-changes.png |
| kit_image_zoom_rest_ar_dark | 0.06 | intended | KitIconButton v2: disabled glyph is solid text3, never partial opacity (bdbec9f4) | small-kit-changes.png |
| kit_image_zoom_rest_dark | 0.06 | intended | KitIconButton v2: disabled glyph is solid text3, never partial opacity (bdbec9f4) | small-kit-changes.png |
| kit_image_zoom_rest_light | 0.06 | intended | KitIconButton v2: disabled glyph is solid text3, never partial opacity (bdbec9f4) | small-kit-changes.png |
| kit_image_zoom_rest_text2_1280x800_dark | 0.02 | intended | KitIconButton v2: disabled glyph is solid text3, never partial opacity (bdbec9f4) | small-kit-changes.png |
| kit_image_zoom_rest_text2_dark | 0.06 | intended | KitIconButton v2: disabled glyph is solid text3, never partial opacity (bdbec9f4) | small-kit-changes.png |
| kit_markdown_default_1280x800_dark | 4.45 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_markdown_default_1280x800_light | 0.5 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_markdown_default_dark | 5.76 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_markdown_default_light | 1.85 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_markdown_streaming_1280x800_dark | 4.12 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_markdown_streaming_1280x800_light | 0.94 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_markdown_streaming_dark | 5.75 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_markdown_streaming_light | 2.87 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_menu_checked_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_1280x800_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_1600x1000_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_360x800_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_800x1280_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_915x412_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_ar_1280x800_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_ar_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_text2_1280x800_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_default_text2_dark | 12.69 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_menu_default_text2_light | 10.71 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_menu_destructive_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_disabled_dark | 0.18 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_groups_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_menu_icons_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_message_default_1280x800_dark | 0.03 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_message_default_dark | 0.08 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_message_default_text2_1280x800_dark | 0.08 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_message_default_text2_dark | 0.23 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_message_marker_dark | 0.08 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_message_prompt_attachments_dark | 0.08 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_message_prompt_dark | 0.08 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_progress_stopped_dark | 0.18 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_queued_message_offline_dark | 0.13 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_request_sheet_form_dark | 0.11 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_request_sheet_form_discard_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_request_sheet_gate_confirm_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_request_sheet_gate_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_request_sheet_permission_1280x800_dark | 15.76 | intended + fix | R3 KitCodeBlock without the empty header band, copy on the line (e55a23f9); command wraps whole (this slice) | r3-code-block-and-request-wrap.png |
| kit_request_sheet_permission_1280x800_light | 11.99 | intended + fix | R3 KitCodeBlock without the empty header band, copy on the line (e55a23f9); command wraps whole (this slice) | r3-code-block-and-request-wrap.png |
| kit_request_sheet_permission_always_dark | - | intended (fix in this slice) | Command in the request sheet now wraps whole (KitRequestSheet.md: full text never truncates) — this slice, kit_request_sheet.dart | r3-code-block-and-request-wrap.png |
| kit_request_sheet_permission_always_light | - | intended (fix in this slice) | Command in the request sheet now wraps whole (KitRequestSheet.md: full text never truncates) — this slice, kit_request_sheet.dart | r3-code-block-and-request-wrap.png |
| kit_request_sheet_permission_change_1280x800_dark | 14.68 | intended + fix | R3 KitCodeBlock without the empty header band, copy on the line (e55a23f9); command wraps whole (this slice) | r3-code-block-and-request-wrap.png |
| kit_request_sheet_permission_change_1280x800_light | 13.19 | intended + fix | R3 KitCodeBlock without the empty header band, copy on the line (e55a23f9); command wraps whole (this slice) | r3-code-block-and-request-wrap.png |
| kit_request_sheet_permission_change_dark | 35.9 | intended + fix | R3 KitCodeBlock without the empty header band, copy on the line (e55a23f9); command wraps whole (this slice) | r3-code-block-and-request-wrap.png |
| kit_request_sheet_permission_change_light | 32.61 | intended + fix | R3 KitCodeBlock without the empty header band, copy on the line (e55a23f9); command wraps whole (this slice) | r3-code-block-and-request-wrap.png |
| kit_request_sheet_permission_dark | 19.32 | intended + fix | R3 KitCodeBlock without the empty header band, copy on the line (e55a23f9); command wraps whole (this slice) | r3-code-block-and-request-wrap.png |
| kit_request_sheet_permission_light | 19.33 | intended + fix | R3 KitCodeBlock without the empty header band, copy on the line (e55a23f9); command wraps whole (this slice) | r3-code-block-and-request-wrap.png |
| kit_request_sheet_question_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_request_sheet_question_many_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_request_sheet_reply_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_scanner_error_dark | 0.34 | intended | R1 KitTopBar flat on the gutter: title inset moves (9413f93d); dark corners R9 text3 | r1-top-bar-flat.png |
| kit_scanner_error_light | 0.34 | intended | R1 KitTopBar flat on the gutter: title inset moves (9413f93d); dark corners R9 text3 | r1-top-bar-flat.png |
| kit_scanner_error_text2_dark | 1.22 | intended | R1 KitTopBar flat on the gutter: title inset moves (9413f93d); dark corners R9 text3 | r1-top-bar-flat.png |
| kit_scanner_loading_dark | 0.56 | intended | R1 KitTopBar flat on the gutter: title inset moves (9413f93d); dark corners R9 text3 | r1-top-bar-flat.png |
| kit_scanner_loading_light | 0.34 | intended | R1 KitTopBar flat on the gutter: title inset moves (9413f93d); dark corners R9 text3 | r1-top-bar-flat.png |
| kit_scanner_paused_dark | 0.56 | intended | R1 KitTopBar flat on the gutter: title inset moves (9413f93d); dark corners R9 text3 | r1-top-bar-flat.png |
| kit_scanner_paused_light | 0.34 | intended | R1 KitTopBar flat on the gutter: title inset moves (9413f93d); dark corners R9 text3 | r1-top-bar-flat.png |
| kit_scanner_scanning_1280x800_dark | 8.59 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_scanner_scanning_1280x800_light | 8.59 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_scanner_scanning_dark | 0.34 | intended | R1 KitTopBar flat on the gutter: title inset moves (9413f93d); dark corners R9 text3 | r1-top-bar-flat.png |
| kit_scanner_scanning_light | 0.34 | intended | R1 KitTopBar flat on the gutter: title inset moves (9413f93d); dark corners R9 text3 | r1-top-bar-flat.png |
| kit_scenes_mirrored_ar_1280x800_dark | 0.04 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_scenes_mirrored_ar_dark | 0.12 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_scenes_servers_dark | 0.1 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_scenes_setup_dark | 0.94 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_scenes_states_dark | 0.24 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_scenes_team_dark | 0.16 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_scenes_team_discover_dark | 0.03 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_screen_default_1280x800_dark | 8.43 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_screen_default_1280x800_light | 8.43 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_screen_search_dark | 0.25 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_screen_three_pane_1280x800_dark | 6.96 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_screen_three_pane_1280x800_light | 6.96 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_screen_two_pane_empty_1280x800_dark | 3.05 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_screen_two_pane_empty_1280x800_light | 3.05 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_screen_two_pane_selected_1280x800_dark | 7.27 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_screen_two_pane_selected_1280x800_light | 7.27 | intended | R1 KitTopBar flat on the gutter on PC with a hairline, glass only on the floating layer (9413f93d) | r1-top-bar-flat.png |
| kit_search_field_disabled_dark | 0.2 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_search_field_empty_dark | 0.19 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_search_field_filtered_dark | 0.02 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_search_field_nomatch_dark | 2.27 | intended | KitStateView v2 empty look: square icon tile, title role (97fc4f57); goldens were made on branches before its merge | kitstateview-v2-empty.png |
| kit_search_field_nomatch_light | 2.24 | intended | KitStateView v2 empty look: square icon tile, title role (97fc4f57); goldens were made on branches before its merge | kitstateview-v2-empty.png |
| kit_search_field_partial_dark | 0.02 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_search_field_results_dark | 0.02 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_search_field_typing_dark | 0.02 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_segmented_disabled_dark | 0.21 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_segmented_segment_disabled_dark | 0.07 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_sheet_consequences_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_sheet_discard_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_1280x800_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_1600x1000_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_360x800_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_800x1280_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_915x412_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_ar_1280x800_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_ar_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_text2_1280x800_dark | 0.0 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_all_text2_dark | 9.39 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_status_mark_all_text2_light | 9.38 | intended | KitRow v2: titles take two lines from 1.3x text instead of an ellipsis (08a7741e); foundation 1x: needs-you card and request card look (f5370bd3 tokens, R4 insets) | kitrow-v2-two-line-titles.png |
| kit_status_mark_labelled_ar_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_status_mark_labelled_dark | 0.01 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_switch_row_default_1280x800_dark | 0.37 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_switch_row_default_1280x800_light | 0.37 | intended | R4 row groups on one inset: KitSectionLabel aligns with the group edge, hairline inset follows the text (ba9d7088); dark R9 text3 | r4-section-label-and-row-inset.png |
| kit_switch_row_locked_dark | 0.17 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tappable_disabled_1280x800_dark | 0.12 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tappable_disabled_dark | 0.33 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_terminal_view_disabled_dark | 0.31 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_terminal_view_empty_dark | 0.1 | intended | KitIconButton v2 close glyph placement (bdbec9f4); dark R9 text3 | small-kit-changes.png |
| kit_terminal_view_empty_light | 0.03 | intended | KitIconButton v2 close glyph placement (bdbec9f4); dark R9 text3 | small-kit-changes.png |
| kit_terminal_view_output_all_dark | 1.09 | intended | KitIconButton v2 close glyph placement (bdbec9f4); dark R9 text3 | small-kit-changes.png |
| kit_terminal_view_output_all_light | 0.03 | intended | KitIconButton v2 close glyph placement (bdbec9f4); dark R9 text3 | small-kit-changes.png |
| kit_terminal_view_output_too_long_dark | 0.19 | intended | Line count formatted "2,500" (decimalPattern, ebfeec48); close button per KitIconButton v2 | small-kit-changes.png |
| kit_terminal_view_output_too_long_light | 0.19 | intended | Line count formatted "2,500" (decimalPattern, ebfeec48); close button per KitIconButton v2 | small-kit-changes.png |
| kit_term_open_sheet_dark | 0.08 | intended | KitIconButton v2 close glyph placement (bdbec9f4); dark R9 text3 | small-kit-changes.png |
| kit_term_open_sheet_light | 0.03 | intended | KitIconButton v2 close glyph placement (bdbec9f4); dark R9 text3 | small-kit-changes.png |
| kit_text_type_1280x800_dark | 0.09 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_text_type_1600x1000_dark | 0.06 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_text_type_360x800_dark | 0.32 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_text_type_800x1280_dark | 0.09 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_text_type_ar_1280x800_dark | 0.05 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_text_type_ar_dark | 0.14 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_text_type_dark | 0.25 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tool_row_default_1280x800_dark | 0.03 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tool_row_default_text2_1280x800_dark | 0.1 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tool_row_default_text2_dark | 0.26 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tool_row_done_dark | 0.16 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tool_row_edit_open_dark | 0.16 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tool_row_failed_dark | 0.09 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tool_row_not_run_dark | 0.13 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tool_row_running_dark | 0.09 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_tool_row_waiting_for_you_dark | 0.1 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_turn_default_1280x800_dark | 0.09 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_turn_default_text2_1280x800_dark | 0.26 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_turn_default_text2_dark | 0.71 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_turn_finished_latest_dark | 0.24 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_turn_interrupted_dark | 0.24 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_turn_stopped_dark | 0.24 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_viewer_markdown_1280x800_dark | 5.99 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_viewer_markdown_1280x800_light | 0.49 | intended | R3 KitCodeBlock: no empty header band, controls trail the first line, wrap toggle only when a line overflows (e55a23f9) | r3-code-block-markdown.png |
| kit_work_graph_auto_1280x800_dark | 0.04 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_work_graph_empty_dark | 0.64 | intended | KitStateView v2 empty look: square icon tile, title role (97fc4f57); goldens were made on branches before its merge | kitstateview-v2-empty.png |
| kit_work_graph_empty_light | 0.64 | intended | KitStateView v2 empty look: square icon tile, title role (97fc4f57); goldens were made on branches before its merge | kitstateview-v2-empty.png |
| kit_work_graph_layers_dark | 0.12 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_work_graph_rows_blocked_dark | 0.03 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
| kit_work_graph_rows_dark | 0.12 | intended | R9 dark text3 #8A8D94 -> #8C8F96 so disabled text passes AA (0c3f5718); max channel delta 2 | r9-dark-text3-samples.png |
