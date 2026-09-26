# Visual language v1: the foundation (2026-09-26)

Branch `feat/visual-language-v1`, from `d4f7bdbc` (plus the spec's §6–§7
commit). Spec: [`docs/design/visual-language-2026-09-26.md`](../../design/visual-language-2026-09-26.md)
and its renders in `docs/design/visual-language-2026-09-26/`.

**Finish line of this slice:** every screen changes at once through the theme and
the kit tokens (Geist type, Graphite colour roles, the kit parts' new look), with
galleries, goldens and a before/after record.

**Non-goal:** moving screens onto the new patterns. No screen was rearranged into
grouped panels or large titles, and `Text` was not migrated to `KitText`.

## What changed

| Area | Change |
|---|---|
| Fonts | Geist and Geist Mono v1.7.2 variable TTFs in `assets/fonts/geist/`, with `OFL.txt` and `LICENSES/OFL-1.1-Geist.txt`. Families are `AppSans` and `AppMono`. The pinned engine maps `FontWeight` onto the `wght` axis: measured widths at w400–w700 match the static cuts, so `FontWeight(650)` is real. Space Grotesk and JetBrains Mono were removed, together with their licence files and notices. Arabic still falls back to the system face (`AppTheme.forLocale`); the kit tokens follow that face. |
| Colour | `ThemeRoles` (`lib/ui/theme_roles.dart`) is a ThemeExtension. Its roles are ground, surface1–3, hairline, text1–3, accent/onAccent, attention (+fill, onFill, surface, line), danger/dangerFill/onDangerFill, success, scrim, code keyword/string/type and ambient fields. |
| Themes | **Graphite**, the spec palette, is the default pack. It keeps the stored id `opencode` and is relabelled "Graphite". Every other pack (29 static, plus Material You) gets the whole role set from `deriveRoles(accent, ground, brightness, text?, danger?, success?)`, which has contrast floors built in. `AppTheme.fromRoles(roles)` and `ThemeRoles.withAccent()` are the seams for a custom theme (no editor UI in this slice). `graphiteAccents` lists the canvas's green, blue, orange and violet. |
| Material mapping | `schemeFromRoles` maps the roles onto the scheme, as follows. `primary` = accent. `surface` = ground. `surfaceContainerLow`/`Container`/`Highest` = surface1/2/3. `secondaryContainer` = surface3, so tonal buttons are neutral. `tertiary` = attention. `error` = danger. `outlineVariant` = hairline over surface1. Component themes (app bar, card, dialog 24, sheet 30, chips 999, menus, snackbar, switch, badge, inputs, tab bar) read the roles. Dividers are `thickness: 0`, which is one physical pixel. |
| Type | `KitText(role, tone)` in `lib/ui/kit/kit_text.dart` (P9.7's first part), with `KitText.textTheme` mapping Material's scale onto the roles. Sizes are integers and text colours are opaque. For layouts not yet on KitText, `bodyMedium`, `titleSmall`, `labelLarge` and `titleMedium` keep Material's 14/20 and 16/22 (see "Deviations"). |
| Tokens | `KitTokens` now carries the roles plus the fixed shape and space: panel 18, card 22, sheet 30, dialog 24, button 14 radius / 50 tall, icon tile 30/9, rows 54/60, gutter 16, section gap 22, label gap 8, tab bar 60/22. It also carries the row, label and card text styles. |
| Kit parts | **KitButton:** accent primary, surface3 secondary, text2 tertiary, dangerFill only for a confirmed destroy/stop, opaque disabled state. **KitRow:** 54/60 rows with icon tiles; new KitRowValue and KitRowGroup. **KitPanel:** surface1 with no border; attention is the 22 dp amber card. **KitNotice.card:** the needs-you card with answers in place. **KitConfirmSheet:** icon tile, consequences as an inset panel of rows, stacked answers on a phone and a right-aligned row on a PC. **KitRequestCard:** solid needs-you card, LTR command block, capped with its words scrolling at ≥ 2x text. **KitActionBlock:** its wide row wraps. **KitStatusLine:** hairline. **KitGlass:** surface2 at 82 % (88 % when it holds words), a 1-physical-pixel rim (light top, dark bottom), one tight shadow (y6 blur16 30 %); glass off is surface2 at 94 %. **Shell tab bar:** 60 dp, 22 dp corners, a clear lens behind the active icon. |
| Amber discipline | Inline code and terminal strings no longer use Material's `tertiary`, which is now attention: they are text1 on surface3 and `codeString`/`codeType`. |

## Token table (Graphite)

| Role | Dark | Light |
|---|---|---|
| ground | `#0B0C0E` | `#F3F3F1` |
| surface1 / 2 / 3 | `#141518` / `#1B1C20` / `#26282D` | `#FFFFFF` / `#FFFFFF` / `#E9E9E6` |
| hairline | white 7 % | black 8 % |
| text1 / 2 / 3 | `#F3F3F1` / `#A3A5AB` / `#8A8D94` | `#111214` / `#50535A` / `#62656C` |
| accent / onAccent | `#3DDC8A` / `#03140B` | `#087F43`* / `#FFFFFF` |
| attention | `#FFB547` (fill `#FFB547`, text on fill `#1A1000`) | `#9A5700` (fill `#FFB547`) |
| attentionSurface / Line | `#FFB547` 9 % / 30 % | `#FFA600` 12 % / `#BE6E00` 30 % |
| danger / dangerFill | `#FF7A7A` / `#D93B40`* + white | `#C62828`* / `#D93B40`* + white |
| success | `#3DDC8A` | `#087F43` |
| scrim | black 58 % | black 58 % |
| code keyword / string / type | `#C7A6FF` / `#FFB88A` / `#7FD1FF` | `#6D4AFF` / `#B4480B` / `#0B6BA8` |

\* Deviations from the spec, each made to meet a contrast floor:
- The light accent `#0B8A4A` reads at 4.0:1 on the ground and carries white at only 4.4:1, so it moves one step deeper.
- `dangerFill` `#E5484D` carries white at 3.9:1.
- The spec gives no light `danger`; `#C62828` was chosen.

`test/theme_roles_test.dart` holds every theme to these floors: text1 ≥ 7 on every surface and on the needs-you card; text2, text3, accent, attention, danger, success and the code colours ≥ 4.5; onAccent and onDangerFill ≥ 4.5. It also checks an 8 × 10 grid of custom accents and grounds.

## Deviations and decisions

- **Ambient text keeps Material metrics.** A chunked run of the full suite found about ten layouts tuned to 14/20 text at 320 dp and 2.5x. These are the tools header, the team message sheet, the plugins list and the 390 dp work dock. `bodyMedium`, `titleSmall`, `labelLarge` and `titleMedium` therefore keep 14/20 and 16/22. The spec's larger sizes live in the kit roles: body 16/24, rowTitle 16/22, headline 17/22, title 24/30.
- **Buttons are 15/20 w600** (the spec allows 15–16) with 16 dp sides.
- **No blur behind sheets.** §3 asks for a σ3 blur behind sheets, but §7 says "Blur only behind glass, never on content", and `showModalBottomSheet` has no barrier-blur hook. The scrim is 58 % with no blur.
- **The top bar stays 64 dp**, as before; the spec sets no height.

## Commands and results

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F analyze                                                     # No issues found
$F test -j 2 test/theme_roles_test.dart test/theme_packs_test.dart test/app_theme_test.dart \
  test/kit/ test/kit_glass_test.dart test/glass_surface_test.dart test/kit_ratchet_test.dart \
  test/accessibility_guidelines_test.dart test/design_standard_test.dart \
  test/text_scale_overflow_test.dart test/home_navigation_test.dart   # all pass
# goldens (kit galleries now at the device pixel ratio: 3x phone, 2x tablet, 1x PC)
$F test -j 2 --update-goldens test/goldens/kit/ test/goldens/*_golden_test.dart \
  test/kit_illustration_test.dart test/kit_states_scenes_test.dart \
  test/servers_scenes_test.dart test/setup_scenes_test.dart
# before/after census (new CENSUS_OUT / CENSUS_LIGHT defines)
$F test tool/capture/census_test.dart --dart-define=CENSUS_AREA=a-shell,b1-chat-screen,j1-settings-more,g-servers,h-termux \
  --dart-define=CENSUS_PAGE=home-shell,chat,settings,confirm-sheet,servers,phone-setup-start \
  --dart-define=CENSUS_OUT=<dir> [--dart-define=CENSUS_LIGHT=true]
```

- **Goldens.** 358 existing images were re-rendered and 10 added:
  - 58 kit gallery images;
  - the new `kit_foundation` gallery (type, buttons, rows, cards; dark and light, 412 at 3x and 1280, 2.0 text, Arabic 1.3x);
  - 300 screen and scene goldens.

  Samples were compared against the approved renders before the images were accepted.
- **Suite.** All 454 test files ran in 10 serial chunks with `-j 2`. This is not a formal gate: the chunks span three revisions of this branch, and after the last fixes only chunks 2 and 3 and the affected files were re-run. Six tests still fail. Each also fails on the base commit `d4f7bdbc` when run there:
  - `first_run_welcome_test` "the phone choice and the demo…" (a timer is left pending);
  - `motion_setup_test` ×2;
  - `oc2_server_discovery_test` "known OC1 user…";
  - `phone_setup_welcome_entry_test` "coming back…";
  - `team_run_screen_test` "the home's run row…".
- **Kit-only ratchet (G16).** Green. The baseline was re-committed smaller:
  - `product_states.dart`: Text 16 → 15;
  - two files whose counts had already dropped on the base.

  No counts rose.

## Contact sheets

- [`contact-dark.png`](contact-dark.png) and [`contact-light.png`](contact-light.png): before (top) and after (bottom) for Work, Chat working, Chat needs you, Settings hub, a confirm sheet, Servers and Phone setup start, at 412 × 915.
- The kit parts as the spec draws them: `test/goldens/kit/kit_foundation_work_412x915_{dark,light}.png`, `…_type_…`, `…_ar_…` and `…_text2_…`.

## Font source

- **Download:** `https://github.com/vercel/geist-font/releases/download/v1.7.2/geist-font-v1.7.2.zip`, the official Vercel release, published 2026-06-01.
- **Zip sha256:** `7fc800d2ac6b92844895196e5041aca55d814c15db70c44f79b3b83ab82b04e2` (matches the release's digest).
- **Local copies:** only woff2 subsets were found, which Flutter cannot load.

The bundled files are the release's `variable/` TTFs, renamed:

| File | sha256 |
|---|---|
| `Geist-Variable.ttf` (`Geist[wght].ttf`) | `cdcc4815cbf5f9882fa74e48f8ab410a0495781a58ff7316570f664e7e987753` |
| `Geist-Italic-Variable.ttf` | `c5db6397dae7993afb72e397277c5a5308ba32de010eb19ec2b8b73f5e9d3ec4` |
| `GeistMono-Variable.ttf` | `0e1af3f507a1c8dfbb03d13ffad585834cd45ed7ccb78c756c7ce7873d180d30` |
| `GeistMono-Italic-Variable.ttf` | `e5800990ff5069667f4ff0a5dc582b260597e0adc022a887d9d103fc4cdd2cf2` |
| `OFL.txt` | `c683bfbcc7e087f5d37a54ef628f10387c451a83ddc459b151403a164ac46c90` |

## What still looks old, and why

The screens are still arranged the old way. Tokens change colour, type and the kit parts, but a screen that builds its own widgets keeps its shape. The contact sheets show the result: the new colours and type are there, but not yet the spec's grouped panels, large titles and needs-you cards.

- **Rows sit on the ground with per-row ⋮ menus.** Work, Servers and Settings build `KitRow`s in a plain `ListView`, not in `KitRowGroup` panels. KitRowGroup and KitRowValue exist now, but no screen uses them yet.
- **No large titles and no needs-you card on Work.** Work shows "Needs you" as a row, not as `KitNotice.card` with answers in place. `KitNotice.card` is ready.
- **The chat transcript and composer are unchanged in structure.** The prompt is still a quoted bar, not a surface2 bubble. The composer has an accent outline and square buttons, not the surface2 pill with an accent send circle. There is no folded work chip, and no code header with +n −n. These belong to the chat library (single owner) and to P9's `lib/ui/kit/chat/` parts. Syntax colours exist as roles (`codeKeyword`, `codeString`, `codeType`), but there is no highlighter yet.
- **Glass beyond the tab bar.** The server pill, the search button, the composer glass with its dimming layer and the PC sidebar glass are not built. The tab bar's lens is Material's 64 × 32 indicator behind the icon, not a pill around icon and label. Ambient ground fields are a role but are not painted.
- **Hand-built widgets outside the kit** (G16 baseline: 5,109 constructions in 189 files). The top offenders are:

  | File | Constructions | Largest counts |
  |---|---:|---|
  | `review_workspace.dart` | 155 | Text 51, Icon 20, Container 18 |
  | `chat_screen.dart` | 136 | Text 46, Icon 20, SnackBar 18 |
  | `chat/composer.dart` | 121 | Text 40, Icon 29, ListTile 13 |
  | `workspace_screen.dart` | 119 | Text 39, Icon 23, PopupMenuItem 12 |
  | `chat/message_view.dart` | 111 | |
  | `files_screen.dart` | 109 | |
  | `external_agents_screen.dart` | 100 | |
  | `widgets/pickers.dart` | 96 | |
  | `termux_setup_screen.dart` | 92 | |
  | `widgets/tool_card.dart` | 91 | |
  | `usage_screen.dart` | 91 | |
  | `library/integration_tiles.dart` | 82 | |
  | `activity_screen.dart` | 72 | |
  | `provider_quota_screen.dart` | 70 | |
  | `widgets/local_agent_onboarding.dart` | 68 | |

  Their `Container`, `Card` and raw `ListTile` styling follows the theme only partly.
- **Colour-only packs from the canvas.** Graphite blue, orange and violet are available as `graphiteAccents` but have no `ThemePackId` yet. Adding them changes the stored enum in `lib/state/profiles.dart`.
