# slice-final-fixes — the last 39 failures of the final suite (2026-09-28)

Base: `ef405759` (final full suite: 14,333 pass / 39 fail). Branch
`revamp/slice-final-fixes`.

## Regressions found and fixed (product, tests unchanged)

| # | Symptom | Causing commit | Fix |
|---|---------|----------------|-----|
| R1 | The composer's editor (`EditableTextState`) was rebuilt from scratch whenever the "open in editor" corner button came or went: first typed letter, a run finishing, the draft clearing, a restore. Focus, selection and the keyboard connection were lost; goldens showed the typed composer with no caret. | `23f2d0ce` feat(chat): close the chat lane's review-board leftovers ("editor in the field corner": `field` swapped between a bare field and `Stack[Padding(field), button]`, so the field was reparented) — found by running `composer_layout_test` on each commit (`23f2d0ce^` green, `23f2d0ce` red) | `lib/ui/kit/chat/kit_composer.dart`: the field always sits in the same `Stack` → `Padding`; only the padding and the corner button change. |
| R2 | Light theme, rail/sidebar layouts: nav labels and icons washed out (Inbox 2.24:1, Work 3.07:1). The page's ambient fields were painted unclipped, spilled onto the rail/sidebar laid out before the page, and were drawn **over** their words. Harmless at the old 6 % alpha; at Moderate (mint at .85) the wash covered the text. | `6ae40ca8` feat(theme): Moderate ambient fields (merge `138f8216`) — bisected: `138f8216^` green, `138f8216` red | `lib/ui/kit/kit_screen.dart` `_AmbientPainter` clips to the page. The contrast rule (`ambientFields`) holds for text on a field; now nothing else can end up under one. |

`prompt_shelf_test` (stash/restore at 411 and 320) had the same cause as R1:
`23f2d0ce^` green, `23f2d0ce` red; green with the R1 fix.

## Verdict per failing test (39 at ef405759)

| Test | Verdict | Fix / reason |
|------|---------|--------------|
| composer_layout: finishing a run preserves the editor state and selection | PRODUCT BUG (R1) | kit_composer stable field tree |
| composer_layout: composer grows … at 1.0x / 2.5x (2) | PRODUCT BUG (R1) | same |
| composer_layout: keyboard resizing preserves the editor and draft selection | R1 + STALE assertion | Editor identity was R1. After the fix, the only failure left was `_editingShare >= 0.85`: with text, the editor button now takes the field's top-end corner beside the words on purpose (owner Fix in `23f2d0ce`; `kit_composer_test` asserts `editor.left >= field.right`). The assertion now measures the words' column plus that corner (`_wordsColumnShare >= 0.85`); the empty-field check (`_editingShare >= 0.85` at 2.5x) is unchanged. |
| accessibility_guidelines: light: the home shell meets the guidelines | PRODUCT BUG (R2) | ambient clipped to the page |
| prompt_shelf: stash and restore … at 411 / 320 (2) | PRODUCT BUG (R1) | kit_composer stable field tree |
| kit_states_scenes (6), servers_scenes (5), setup_scenes (8) — all dark | INTENDED | `0c3f5718` dark `text3` #8A8D94 → #8C8F96 (disabled buttons at 4.5:1). Scenes draw lines and the wide neutral wash from `text3`, so the 7–14 % on stopped/unplugged/paused is the whole wash disc moving by 1–2/255: every one of the 19 is identical at 1.2 % fuzz. |
| screen_servers_1 (8) | INTENDED | `d163a22c` KitCodeBlock caption starts at the block's edge ("On your computer, run:" moves 8 dp to line up with the command). |
| kit_top_bar_r1 sidebar_296 (2) | INTENDED | `2f96633b` glass-crisp: tight outside-only shadow, pixel-snapped rims on the pills; zero pixels differ at 10 % fuzz. |
| kit_viewer_r1 header (2) | INTENDED | `4e49ccde` R5: an enabled tertiary action is accent ("Add to prompt"). |
| shared_team_2 team-host-details-sheet open · dark | INTENDED | 36×5 px on the sheet's drag handle edges (anti-aliasing, glass-crisp pixel snap `2f96633b`); position, size and colour unchanged. |

Counts: product bugs 8 tests (2 root causes), stale 1 assertion, intended goldens 32.

## Goldens the two fixes change (reviewed, refreshed)

A run of every golden test file (209 files) after the fixes found 20 more
changed goldens, all explained by R1/R2:

- R1 (10): `chat_3_composer_{text,busy}[_1280x800]_{light,dark}`,
  `close_chat_working_composer[_1280x800]_dark` — the only difference is the
  caret (2×24 px): the composer keeps focus after typing. The old goldens
  recorded the bug.
- R2 (10): `shell_{home_shell_work,command_palette_open,shortcuts_help_open}_1280x800_*`,
  `p66a_work_project_1280x800_*`, `work_workspace_loaded_1280x800_*` — only the
  296 dp sidebar differs: labels, icons and the server pill are no longer
  under the mint wash. The page's own fields are unchanged.

Owner eyeball: the sidebar and rail now sit on the plain ground; the ambient
fields show on the page only (sheet 02).

## Contact sheets (before | after)

- `01-composer-keeps-focus-caret.png` — R1
- `02-ambient-stays-on-the-page-sidebar.png` — R2
- `03-code-block-caption-edge.png` — servers, `d163a22c`
- `04-dark-text3-scenes.png` — scenes, `0c3f5718`
- `05-kit-r5-glass-crisp-sheet-handle.png` — viewer R5, top bar glass-crisp, team sheet handle

## Verification (this worktree, after the fixes)

- The 10 listed files: 202 tests pass (`accessibility_guidelines`,
  `composer_layout`, `prompt_shelf`, `kit_top_bar_r1`, `kit_viewer_r1`,
  `kit_states_scenes`, `screen_servers_1`, `shared_team_2`, `servers_scenes`,
  `setup_scenes`).
- Refreshed plus related files (`chat_3_golden`, `slice_close_chat_golden`,
  `work_parts_golden`, `screen_work_1_golden`, `slice_p6_6a_defaults_golden`,
  `kit_composer`, `theme_roles`, `glass_surface`): 220 pass.
- Gates `kit_ratchet`, `redaction`, `ui_glossary`, `no_raw_error_text`,
  `kit_manifest`, `kit_draft_manifest`, `architecture_boundaries`,
  `golden_harness`, `kit_motion`: 299 pass.
- 57 other files that use the composer, the bottom inset or ambient: 1,995 pass.
- Every golden test file (209) was run once before the refresh; the 52
  failing goldens are exactly the ones refreshed here.
- `flutter analyze` (whole project): no issues.
- No emulator used.
