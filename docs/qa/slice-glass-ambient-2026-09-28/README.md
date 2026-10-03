# slice-glass-ambient — "Moderate" ambient fields (2026-09-28)

Branch `revamp/slice-glass-ambient`, worktree `oc_app-slice-glass-ambient`, base
`2ea71490` (feat/phone-setup-v2, which has slice-glass-crisp).

The owner looked at the slice-glass-crisp images and chose **"Moderate"** strength for
the ambient fields. That sits between the first 6–8 % and the canvas's strong green.
The goal: the glass visibly bends colour at its edges, on light and dark, while text
stays calm and readable.

- **Finish line:** fields on every theme are as strong as Moderate allows, and no text role drops below 4.5:1 over them.
- **Non-goals:** changing where the fields sit, and adding fields outside the shell.

## Values

The rule lives in `ambientFields` in `lib/ui/theme_roles.dart`. There are three
fields per theme: top start (behind the server pill), end middle, and bottom start
(behind the dock).

**Dark.** A field is the hue itself, laid over the ground. Its target strength is
`ambientStrengthDark` = .15 / .11 / .09 alpha. The weakest light text caps it.

**Light.** A darker hue would dim dark text: Graphite light's accent sits at 4.58:1,
and the old 6 % field already dropped it to 4.26:1. So on light each field is a
pale, fully saturated tint that is at least as bright as the ground. Its target
strength is `ambientStrengthLight` = .85 / .70 / .60 alpha.

Some grounds are so white that no tint of that brightness is still a colour. There,
the rule uses the hue itself, as far as the text's headroom allows, and picks
whichever of the two shows more.

**The cap.** Every field is cut back until every text role on the ground keeps
4.5:1. The roles checked are text1, text2, text3, accent, attention, danger and
success. The check covers each field at its centre and the first two fields
overlapping (about 60 % each). A field that cannot show without costing contrast is
left out. An empty list (no fields) is still valid.

| Theme | Fields (ARGB) |
|---|---|
| Graphite dark | green `0x263DDC8A` (.15), blue `0x1C5AB0FF` (.11), green `0x173DDC8A` (.09); was `0x143DDC8A`, `0x0F5AB0FF` |
| Graphite light | mint `0xD9CDFFE6` (.85), pale blue `0xB3F1F6FF` (.70), mint `0x99CDFFE6` (.60); was `0x0F0B8A4A` |
| Every other pack | three fields in its own accent, derived by the same rule (was one accent field at .08 dark / .06 light) |

Some examples of derived packs:

| Pack | Dark | Light |
|---|---|---|
| Catppuccin | mauve at .12 / .11 / .09 | pale lavender `F6F0FF` at .85 / .70 / .60 |
| Tokyo Night | blue at .15 / .11 / .09 | pale blue `D5E7FF` at .85 / .70 / .60 |
| GitHub | blue at .15 / .11 / .09 | near-white ground: the accent itself at .07 |
| Solarized | blue at .05 (text3 has little headroom) | pale blue `EFF8FF` |

Honest limit: on light packs whose ground is almost white, the rule allows only a pale
field, so Moderate is fainter there than on Graphite. Catppuccin light is now a paler
lavender than before. The old 6 % mauve was darker but cost its accent text contrast.

## Images

All renders are Impeller (`flutter test --enable-impeller`), made with
`tool/capture/glass_crisp_test.dart`. It now also renders the Catppuccin pack. The
same script ran on the base (`renders/before/`) and on this branch (`renders/after/`).

- `contact-sheet-light.png` and `contact-sheet-dark.png`: Graphite and Catppuccin; Work at rest with the pill and dock, and the list scrolled under the dock; before and after.
- `crops-before-after.png`: the pill, search and dock over the fields, before | after, for each theme and brightness.
- `work-goldens-before-after.png`: the Work goldens (Skia), light and dark.

## Tests

`test/theme_roles_test.dart` has a new group, "ambient fields":

- Graphite's constants are exactly what `ambientFields` gives for its own text roles, and they change the ground visibly (Moderate, not 6–8 %).
- No field costs any text role its 4.5:1, for every theme pack in light and dark: each field at its centre, and two fields overlapping.
- A theme may have no fields.

The old Graphite light value would have failed the contrast test: its accent dropped
to 4.26:1.

**Gates, all passing:** kit_ratchet, kit_manifest, kit_motion, glass_surface
(contrast), app_theme, redaction, ui_glossary, no_raw_error_text, plus theme_roles,
kit_glass, kit/kit_glass, kit_screen and kit_nav. `flutter analyze` on the whole
project: no issues. All heavy commands went through `tool/qa/machine_lock.sh`.

**Goldens.** I ran all 208 golden test files on the base and on this branch and
compared by test name:

- 25 tests failed only here. All are in `work_parts`, `work_tab` and `revamp/screen_work_1`, which are shell pages whose ground now carries the fields.
- I regenerated those. Any image whose golden also fails on the base was reverted.
- Afterwards those files fail only tests that fail on the base.
- The refreshed images are `shell_*` (command palette, home shell work and project-unavailable, shortcuts help), `work_*` and `work_workspace_*`.
