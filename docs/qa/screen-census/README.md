# Screen census

Every page of the UI ledger (`docs/design/ui-ledger/ledger.json`: screens,
tabs, sheets, dialogs, overlays and onboarding steps), rendered from the real
widgets for the owner's one-by-one review against
[`docs/design/principles.md`](../../design/principles.md).

- **Images:** `<area>/<page-id>.png`, or `<page-id>--<state>.png` when a page
  has several meaningful states (at most 4). `<area>` is the ledger part
  (`a-shell`, `b1-chat-screen`, … `k-session-misc`, see
  `docs/design/ui-ledger/parts/`).
- **Manifest:** [`manifest.json`](manifest.json) has one entry for every
  ledger page: area, kind, title, file, widget, `reachedFrom` (from the
  ledger), and either `states` (image paths plus an optional reviewer `note`
  and render `warnings`) or `notRendered` with the reason.
- **How each image is drawn:** dark theme, 412×915 dp at device pixel ratio 2
  (824×1830 px), with the app's real fonts (Roboto, Space Grotesk, JetBrains
  Mono, Phosphor icons), no server. Sheets, dialogs and menus are drawn open
  over the screen they belong to, as the person sees them.

## Re-render

With the pinned Flutter (see `AGENTS.md`):

```bash
# everything: 533 shots, about 2 minutes plus the compile on this machine
flutter test -j 1 tool/capture/census_test.dart

# one area
flutter test tool/capture/census_test.dart --dart-define=CENSUS_AREA=a-shell

# some pages of an area
flutter test tool/capture/census_test.dart \
  --dart-define=CENSUS_AREA=a-shell --dart-define=CENSUS_PAGE=activity,demo
```

When a whole area is rendered, its old PNGs are removed first, so a state that
is gone from the scenes does not linger. Each run writes
`.results/<area>.json` (per shot: image, error, warnings). `manifest.json` and
the counts below are then rebuilt from the ledger and every area's last
results. If one shot fails, the run records its error and moves on. The page
then shows `notRendered: "render failed: …"` until it is fixed. A shot also
fails if the screen it shows is not the one it names (each shot has a guard
such as "the sheet's title is on screen"). That keeps a wrong image out of
the census.

## Harness

- `tool/capture/census_test.dart`: the entry point, which lists the areas.
- `tool/capture/census/census_core.dart`: the kit (`CensusKit`) and the run.
  The kit covers pumping the app shell, the connected sample controller,
  platform-channel defaults, taps, `present(show…)`, `push`, settling and
  guards. The run covers the filters, the 2× capture of the whole view,
  results and manifest.
- `tool/capture/census/areas/<part>.dart`: one `CensusArea` per ledger part,
  with its shots and its `notRendered` reasons.
- `tool/capture/census/support/`: shared fakes some areas need.

Scenes reuse the capture fixtures (`tool/capture/fixtures.dart`: the invented
"shopfront" project), the golden scenes (`test/support/*_scenes.dart`,
`*_fixture.dart`) and the fakes in the golden and capture tests. They build
minimal fakes only where none existed. Nothing in `lib/` was changed to render
a page. A page that would need a product change is listed as not rendered.

To add or fix a page, edit its area file and render that area with
`CENSUS_AREA` (and `CENSUS_PAGE`). Then look at the image before committing
it.

## Counts

<!-- census-counts:start -->

335 of 347 ledger pages rendered, 533 images; 12 not rendered (reasons in `manifest.json`).

| Area | Rendered | Not rendered |
|---|---:|---:|
| `a-shell` | 22 | 4 |
| `b1-chat-screen` | 9 | 0 |
| `b2-chat-screen` | 8 | 0 |
| `c-chat-compose` | 19 | 1 |
| `d-chat-sheets` | 21 | 2 |
| `e-workspace` | 38 | 0 |
| `f-files-review-terminal` | 18 | 0 |
| `g-servers` | 32 | 0 |
| `h-termux` | 44 | 1 |
| `i1-team-core` | 24 | 0 |
| `i2-team-sheets` | 27 | 0 |
| `j1-settings-more` | 35 | 0 |
| `j2-library` | 21 | 4 |
| `k-session-misc` | 17 | 0 |

| Kind | Rendered | Not rendered |
|---|---:|---:|
| dialog | 47 | 3 |
| onboarding-step | 15 | 0 |
| overlay | 44 | 6 |
| screen | 79 | 0 |
| sheet | 134 | 3 |
| tab | 16 | 0 |

<!-- census-counts:end -->

## What the renders cannot show

- **Motion.** Each image is one settled frame. Ambient loops are off
  (`KitMotion.loops = false`), and entrances are shown finished. Page
  transitions, sheet slides, drawings drawing themselves in and celebrations
  have to be judged on a device or a screen recording (principles §5, review
  items M1–M5).
- **Glass.** The frosted dock (`GlassSurface`, a backdrop blur) is drawn by
  the test renderer over a still frame. How it reads over scrolling content,
  and the phone GPU's own blur, show only on a device.
- **Real data and timing.** The data is the invented "shopfront" sample.
  Server replies, long waits, streaming, real errors, a real phone's Termux,
  and real provider lists and plugins differ in length, wording and pace.
- **The device.** No status bar, gesture bar, notch, keyboard, system dialogs
  (permissions, pickers, share sheet), notifications or home-screen
  shortcuts. Safe-area padding is zero.
- **Light theme, other sizes and text scale.** Only dark at 412×915 and 100 %
  text is rendered. Light mode, 200 % text (principles §9), landscape,
  tablets and desktop layouts are not in the census. The design goldens in
  `test/goldens/` cover light for migrated screens.
- **Arabic and right-to-left layouts.** English only.
- **Interaction.** Pressed and focus states, haptics, gestures, and what
  happens after a tap. The ledger (`docs/design/ui-ledger/pages.md`,
  `navigation.md`) records every element and where it leads.

### Harness artefacts, not product bugs

- **Missing glyphs.** The test fonts lack a few symbols, which draw as boxes:
  the `›` in "Settings › …", the terminal key bar's ↑ ↓ arrows, and the
  Arabic language name in the language picker. A phone's system fonts have
  them.
- **Wall-clock text.** Relative times and dates ("3h ago", timeline dates)
  come from the real clock at render time, and AI Team times are shown in the
  machine's time zone. They change between runs.
- **Stand-in hosts.** A few embedded pieces are shown inside a plain host
  screen because no real screen hosts them in the sample: the shared
  empty/error states, the info label and the desktop context menu. Each of
  these carries a `note` in the manifest.
- **Removed ledger pages.** The ledger predates some cleanups. Pages whose
  widget no longer exists are listed as not rendered with that reason:
  the return brief panel and its dialog, and `ManagedServerHealth`.

## Observations made while rendering

The area workers noted these while checking every image. They are
observations, not review verdicts, and they are input for the one-by-one
review. Each is also in the shot's `note` where it applies.

- **Chat** (`b1`, `b2`, `c`, `d`):
  - The two model labels disagree: the line under a reply shows the raw
    `anthropic/claude-sonnet-4`, while the composer chip says "Choose model".
  - A finished turn folds its opening paragraph under the work line.
  - Long-press on a reply opens nothing; only the ⋯ button does.
  - The command launcher is titled "Composer tools" even when it was opened
    as Commands.
  - "1 of 12 matches" is shown twice in the find bar.
  - The pending-sends strip slides under the composer.
  - A 41-line shell output renders in full inside the tool card, with no cap.
  - The full-screen form's pinned Send bar floats mid-screen.
  - Voice notices show raw Markdown.
- **Work and projects** (`e`):
  - The switch-organization sheet lists the same account twice, and its
    confirmation ends in a doubled period.
  - All conversations says "1 conversations".
  - The Projects error state shows "0 of 0".
  - Error states come in two styles: the old centred icon, and the kit
    illustration.
  - The task-list card says "2/5" in its header and "2 of 4" in its body.
- **On this phone** (`h`):
  - The replace sheet offers to replace 2.0.10 with 2.0.10.
  - The failed setup step says it failed, then "No managed Ubuntu", then
    offers a Retry that "resumes".
  - The Termux-too-old state shows an empty output panel.
  - The protected process row has two different names.
- **AI Team** (`i1`, `i2`):
  - Two agents have the same name, "Worker".
  - The agent screen says "waiting on one other step" after that step is
    done.
  - The adb commands in "Keep it running" run off screen.
  - The stop sheet reads "Stop shopfront/ gastown.furiosa?".
  - The host guide points to a repository file.
- **Files and sessions** (`f`, `k`): the file viewer defaults to unwrapped
  lines that run off the sheet.
