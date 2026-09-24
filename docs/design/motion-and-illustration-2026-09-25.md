# Motion and illustration (2026-09-25)

The owner, on build 2052/2053: "be more creative — add animations, cool graphics that you create with svgs or whatever (they could even move etc), etc, be creative! This in general see where we need". Also, on the Add server form: "This bs?" (`docs/qa/design-regressions-2026-09-24/phone-6-add-server.jpg`, ledger row 15).

The design standard (`design-standard.md` §1–§9) made screens consistent but plain: every waiting, empty and finished moment is the same icon in a tonal circle. Ledger rows 1–2 already record a lost setup illustration and dead space above titles. §10 now says how the app draws and moves. This spec says where, and splits the work.

## The foundation (done, on `feat/phone-setup-v2`)

Frozen: build on it, do not change it without the coordinator. Additions go into your own files.

- `lib/ui/kit/kit_motion.dart`, `KitMotion`:
  - durations `quick` 150 ms, `standard` 250 ms, `entrance` 900 ms, `celebration` 1.4 s, `breath` 4 s;
  - curves `enter`, `exit`, `emphasized`;
  - `loops` (false in tests);
  - `reduced(context)` and `loopsIn(context)`.
- `lib/ui/kit/kit_illustration.dart`:
  - `KitScene` paints one frame into its `box` (120 × 120 scene units by default) from a `KitSceneFrame`. The frame carries `entrance` 0→1, `loop` 0→1 repeating, `looping`, and `palette`.
  - `KitPalette.of(theme)` gives `accent`, `accentSoft`, `ink`, `muted`, `line`, `surface`, `success`, `warning`, `failure` and `progress`.
  - `KitDraw` gives `pen` / `fill` (stroke 5, hairline 2.5 in scene units), `interval` (stage a part of the entrance), `wave` (a smooth loop), `partialPath` (a line drawing itself in) and `fade`.
  - `KitIllustration(scene:, width:, ambient:, loopPeriod:, animateEntrance:, semanticLabel:)` plays the entrance once. It then loops only when `ambient` is set and `KitMotion.loopsIn` allows it, and shows the finished frame under reduced motion. It is decorative unless labelled.
  - A scene with data (a progress, a step) overrides `differs` so it repaints when the data changes.
- `KitStateView(illustration: scene, illustrationAmbient: bool)` puts a drawing in place of the icon circle: 140 dp on a page, 88 dp inline.
- `lib/ui/kit/scenes/portal_scene.dart`, `KitPortalScene`, is the reference scene: the brand mark's two brackets draw themselves in, a spark lands in the middle, and while waiting the brackets breathe and the spark circles. Golden: `test/goldens/kit_portal_{dark,light}.png`.
- Tests: `test/kit_illustration_test.dart`.

## Style rules for every scene

- **Line art in the brand's stroke.** Rounded caps and joins; `KitDraw.stroke` for main shapes, `hairline` for detail. One accent for the thing that matters, `muted`/`line` for everything else, `accentSoft` washes for fills. Never literal colours. Draw it well in both dark and light.
- **Recurring cast** (so the drawings read as one family):
  - the portal brackets (OpenCode itself);
  - a phone outline with a rounded screen;
  - a laptop outline;
  - small rounded "agent" figures (a circle head, a rounded body; no faces beyond two dots) for the AI Team;
  - a terminal window with a `>_` prompt;
  - sparks and dots for energy;
  - a folded sheet for files and conversations.
- **Movement vocabulary:**
  - lines draw themselves in (`partialPath`), staged with `interval`, and finish within `KitMotion.entrance`;
  - a one-time celebration may overshoot (`Curves.easeOutBack`) and throw a few short spark strokes, within `KitMotion.celebration`;
  - an ambient loop is slow and small: breathing (a scale or offset of a few units), a dot travelling a path, a cursor blinking. Never spinning or bouncing.
- **Where the drawing sits.** It sits at the head of a `KitStateView` (start-aligned like its text) or as a hero on the few screens with room (setup start, setup ready, welcome): 140–200 dp, never pushing the primary action off a 412 × 915 screen, and fitting at 320 dp wide and at 2× text.
- **Performance.** Paint and transforms only. Build `Path`s once (static or cached), not per frame, and do no allocation-heavy work in `paint`. One ambient loop per screen at most.

## Slices

One agent each, in its own branch and worktree off `feat/phone-setup-v2` at the foundation commit. Read sets are free; each write set is exclusive. New scenes go in `lib/ui/kit/scenes/<slice>_*.dart` (your own files; do **not** edit `kit.dart`, import your scene files directly). Strings go in `app_en.arb` and `app_ar.arb` (the coordinator merges ARBs key by key). Update `test/design_standard_test.dart` and `docs/design/ui-ledger/parts/*.json` only for your own files.

### A: Setup and connecting (`phone_setup/*`, `builtin_server_screen.dart`, `widgets/setup_progress_view.dart`, `widgets/saved_server_connection_card.dart`, `termux_setup_screen.dart`)

- **Setup start:** a hero drawing (a phone whose screen becomes a terminal, the portal forming on it). It fixes ledger rows 1–2: the lost illustration, and the empty top with content floating mid-screen.
- **Setup progress:** a scene tied to the real step (download → unpack → install → start), with its parts drawing in as steps complete, ambient while working.
- **Setup ready:** a celebration, with the portal opening and sparks. It replaces the lone check, keeping its meaning.
- **Setup progress's Details (ledger row 16):** one box, not a box in a box (`TerminalView` inside `KitStateView`'s details panel); log type small enough that an apt line fits one line at 412 dp (mono `bodySmall`), with long lines scrolling sideways or wrapping with a hanging indent; Cancel placed in the action hierarchy, not floating above Hide details; the title and progress stay in view while the log is open.
- **"Starting OpenCode on this phone…" / connecting / not answering:** the portal breathing while it connects; an unplugged cable or a quiet portal when it is not answering; On this phone's stopped state.

### B: Add server and Servers (`servers_screen.dart` form and welcome, `pairing_scanner_screen.dart`, `connection_help_screen.dart`, `tailscale_setup_screen.dart`)

- **Rebuild Add server (ledger row 15)** on the kit and the standard:
  - the connection type as one clear choice (rows or a segmented control with a line each: "OpenCode on a computer", "Codex", "Claude Code or Pi (Paseo)"), with no "(experimental)" noise in the choice itself;
  - pairing first: Scan as the main path, Paste code next to it in the same style;
  - the address and password folded under "Enter the address instead";
  - "Save & connect" tests by itself, so Test connection disappears as a big button (a tertiary at most);
  - no raw backticks in copy, and no dead space above the pinned primary.
- **Drawings:** a phone and a laptop that link up with a line drawing between them while testing (ambient during the test), and a success spark when paired.
- **Servers welcome** (no servers yet): a hero drawing.
- Keep every behaviour (pairing formats, Codex and Paseo fields, validation, credentials handling). Security invariants hold: the password is never logged.

### C: Empty and quiet states (`workspace_screen.dart`, `attention_overview_screen.dart`, `global_sessions_screen.dart`, `files_screen.dart`, `terminal_screen.dart`, `local_terminal_screen.dart`, `chat_screen.dart` **and every `chat/*.dart`** as one library, search)

- **Work tab:** no project yet, empty project, not answering.
- **Inbox:** all caught up.
- **All conversations:** none yet; search with no results.
- **Files:** empty folder.
- **Terminal:** not set up, and shell ended.
- **Chat:** the empty conversation (keep the alive start from `feat/alive-empty-chat`: its caret and context), the "working" indicator while a reply streams (a small drawn mark, calm), could not load, offline.
- One drawing per kind of state, reused where the state is the same.

### D: AI Team (`screens/team/*`, `widgets/team_*.dart`, `lib/builtin/team` UI only)

- **Home with no tasks:** the agents around a board, and the empty state teaching in one sentence.
- **The planner planning ("Planning the steps…"):** agents passing a card, ambient.
- **The team starting on the phone:** ambient.
- **A task merged:** a celebration on the task's Overview, shown once per task.
- **Needs you:** a one-time attention nudge on the block, not a loop.
- **Agents list empty,** and **the Work tab card "Nothing running":** a small inline drawing at most.

### E: Motion across the app (`lib/ui/app_theme.dart` page transitions, `home_screen.dart` shell and tabs, `lib/ui/kit/*` parts other than `kit_illustration.dart`/`kit_motion.dart`)

- **Page transitions:** one family through `pageTransitionsTheme` (Material 3 shared-axis or fade-through), tuned to `KitMotion`.
- **Tabs:** a switch that does not jump.
- **Kit parts:** `KitStateView` content, `KitNotice` and `KitStatusLine` appear and leave with `standard`; `KitExpandRow` unfolds smoothly; a button's working state crossfades.
- **Lists:** new rows (a conversation appearing, a task added) slide in gently, and removed rows collapse.
- **Pull to refresh:** a drawn indicator (the portal spark) instead of the stock spinner, if it stays smooth.
- **Haptics:** a light tick on send and on a finished moment, where Android supports it.
- Measure: `dumpsys gfxinfo` on the emulator before and after for the Work tab and a chat scroll, recorded. No regression.

## Proof (the owner's audit rule)

Each slice delivers:
- goldens of every new scene (dark and light, finished frame);
- before/after renders at 412 × 915 in `docs/qa/<slice>-2026-09-25/`, with a README in the `docs/qa/README.md` format and a row in its index;
- tests that assert behaviour (the right drawing for the state; reduced motion shows the finished frame; nothing loops on a resting screen; Add server's pairing-first flow), at least one failing without the change;
- `flutter analyze` clean, the affected test files passing, and an update to the design-regressions ledger for rows it fixes.

On-device proof (a short video of the moments) is the coordinator's integrated run afterwards.
