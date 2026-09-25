# Design principles

*First draft, 2026-09-25. For the owner's one-by-one review of every screen
(`docs/qa/screen-census/`). The design standard (`design-standard.md`) says
which parts to build with; these principles say what the parts are for and how
we judge the result.*

OpenCode Mobile is a phone for directing coding agents. One person, often one
hand, often away from the desk. The work takes minutes, the server sometimes
stops answering, and the data underneath is technical. The app's job is to make
all of that feel calm, clear and safe.

Each principle is one sentence, then rules that can be checked on a single
screen. A screen that breaks a rule needs a reason written down, or a fix.

---

## 1. One thing at a time

**Every screen is for one thing, and the person can tell what it is in a
second.**

- At most one primary (filled) button is visible per screen or state
  (standard §2). If two things compete, one becomes secondary or moves into the
  overflow.
- The title names the place in the person's words. Directly below it comes the
  content or the state, not a toolbar.
- The same thing appears once per screen. Two rows or cards for one server, one
  team or one state is a defect (see regression rows 12, 14 and 18).
- A row carries at most one trailing action. Rarer actions go in its menu.

## 2. Plain words

**Say what is true, in the person's words, in as few of them as it takes.**

- Titles are at most four words, in sentence case. A body is at most two short
  sentences.
- No paths, ports, IDs, status codes, plugin ids or engine words (convoy,
  formula, city, PTY, SSE, `127.0.0.1`) above the Details fold.
  `test/ui_glossary_test.dart` passes.
- A button is a verb that says what will happen: "Stop the server", "Send
  anyway", not "OK" or "Continue".
- Words never contradict what is on screen. It says "Starting OpenCode…", never
  "Stopped" while a start is running (standard §3).

## 3. Honest waiting

**Every wait, empty list, error and lost connection is a designed moment that
says what is happening and what the person can do.**

- Every "not the normal content" moment uses `KitStateView` or `KitNotice`: the
  title is the state now, the body what happened and what next, then the §2
  actions.
- No spinner runs silently for more than 8 s. After that the screen says so in
  plain words and offers the way out: Retry, Restart, or Leave it running.
- A long job sets its expectation before it starts ("about 8 minutes the first
  time") and shows real progress while it runs: stages, "29 of 30 MB · about
  1 min left". A disabled button never stands in for progress (row 19).
- An empty screen says what will be here and offers the first step.

## 4. Detail on request

**The technical truth is always one tap away and never in the way.**

- Addresses, logs, raw errors and identifiers live in a collapsed Details row,
  in mono, below the actions (standard §3.6).
- Any technical value can be copied with one tap.
- Nothing is thrown away to look simpler. It is folded, labelled and kept
  reachable.

## 5. Motion with meaning

**Movement explains a change (where something came from, that something is
working, that something finished). Otherwise the screen is still.**

- Only `KitMotion` timings and curves: 150 ms for a control answering a touch,
  250 ms for a part appearing, 900 ms for an entrance, 1.4 s for a celebration,
  4 s per ambient loop (standard §10).
- An entrance plays once. At most one ambient loop per screen, and only while
  the person waits. A screen at rest is still.
- Animate paint and transforms only, never layout, blur or shadow. No dropped
  frames on the emulator's `gfxinfo`.
- With "remove animations" on, or Effects set to Off, every drawing shows its
  finished frame and nothing loops.

## 6. Made for one hand

**The main action sits where the thumb already is, and every target is easy to
hit.**

- Touch targets are at least 48×48 dp, with at least 8 dp between neighbours.
  If the icon is smaller, the hit area is bigger than the icon.
- On a phone the primary action is pinned at the bottom or sits in the lower
  half of the screen. It is never at the end of a long scroll (row 6).
- A destructive action never sits next to a frequent one (`KitActionStack`),
  is coloured as an error, and asks first.
- Every gesture (swipe, long-press) has a visible alternative.

## 7. One kit, one language

**The same thing looks and behaves the same everywhere, because it is built
from the same parts.**

- Screens are built from `lib/ui/kit/`: `KitScreen`, `KitRow`, `KitStateView`,
  `KitNotice`, `KitStatusLine`, `KitActionStack`. A missing part is added to the
  kit, never built as a one-off (standard, intro).
- One action has one name, one icon and one place on every screen.
- Choose the container by the task. A screen is a place. A sheet is a choice
  or a confirmation. A dialog is a short text entry or an alert that has to
  block. A snackbar is a done-with-undo.

## 8. Craft in the details

**Spacing, type and alignment follow one system, so the eye never has to
correct.**

- 16 dp side rails. Spacing comes from the 4 dp scale (4, 8, 12, 16, 24, 32).
- Type comes from the theme's scale, with at most three sizes on a screen. Mono
  is only for technical values.
- A block has one leading edge. Lists are never centred. Nothing is cut down to
  a few letters.
- The last content scrolls clear of anything pinned below it: the dock, the
  primary button, the keyboard.

## 9. For everyone

**Anyone can use every screen: in the sun, at 200 % text, with a screen reader
or with motion turned off.**

- Text contrast is at least 4.5:1, or 3:1 for large text and icons. A state is
  never shown by colour alone: pair it with a word or a mark.
- At 200 % text the screen reflows without clipping or overlapping. Only the
  person's own titles may wrap to extra lines.
- Every control has a semantic label. A status change is announced once, as
  one live region. Drawings are excluded from semantics.
- The person's Effects choices (glass, motion, celebrations, vibration) are
  obeyed everywhere.

## 10. Earn trust

**Never lose the person's work, never surprise them and never expose a
secret.**

- Before anything irreversible, say exactly what will happen, to what, and
  whether it can be undone. Offer Undo where the server allows it.
- Drafts, queued prompts and attachments survive a crash, a restart and a
  server that went away.
- Credentials never appear in screen text, logs, notifications or screenshots.
  A link the app did not write opens through `openExternalLink`, which shows
  the host first.
- The app says what it runs on the phone and what that costs: battery,
  Android's background limits, disk.

---

## How we review a screen

Every census image (`docs/qa/screen-census/<area>/<page>.png`) is reviewed on
five dimensions, in this order: UI, UX flow, motion, copy, principles. Each
finding goes into the review ledger with the page id, the dimension, the item
below and a severity:

- **Blocker:** wrong, unsafe, inaccessible, or loses work. Fix before
  anything else.
- **Major:** breaks a principle.
- **Minor:** craft.

The item's priority is its default severity: a failed **critical** item is a
blocker, **high** is major, **medium** is minor. The reviewer can raise a
severity but never lower it.

The `[…]` ids are the matching rules in the ui-ux-pro-max checklist
(`references/quick-reference.md` and `pro-rules.md` in the skill, used as a
cross-check). Where that checklist and our standard disagree, ours wins. The
differences are listed at the end of this section.

### Checklist

**UI: how it looks**

| # | Check | Priority | Source |
|---|---|---|---|
| U1 | Text contrast is 4.5:1 or more (3:1 for large text and icons), in dark and in light | critical | P9 · [color-contrast, color-dark-mode] |
| U2 | State is never shown by colour alone | critical | P9 · [color-not-only] |
| U3 | Nothing is clipped, overlapping or hidden under the dock, a pinned button or the keyboard | critical | P8 · [fixed-element-offset, safe-area-awareness] |
| U4 | One focal point and at most one primary button | high | P1 · standard §2 · [primary-action] |
| U5 | Built only from kit parts: no ad-hoc cards, bars, button styles or states | high | P7 · [consistency, elevation-consistent] |
| U6 | Nothing is shown twice on the screen | high | P1 · standard §6 |
| U7 | 16 dp rails, spacing on the 4 dp scale, one leading edge per block | medium | P8 · [spacing-scale, whitespace-balance] |
| U8 | Type from the theme's roles, at most three sizes, mono only for technical values | medium | P8 · [font-scale, text-styles-system, weight-hierarchy] |
| U9 | One icon family and style per level; icons sized from the tokens | medium | P7 · [icon-style-consistent] |

**UX flow: how it works**

| # | Check | Priority | Source |
|---|---|---|---|
| X1 | Touch targets are 48×48 dp or more, with 8 dp or more between them | critical | P6 · [touch-target-size, touch-spacing] |
| X2 | Nothing typed or queued is lost on back, dismiss, crash or a lost server; a sheet with unsaved input asks first | critical | P10 · [sheet-dismiss-confirm, form-autosave] |
| X3 | Anything irreversible is confirmed, says exactly what it removes, and sits apart from frequent actions | critical | P6, P10 · [confirmation-dialogs, destructive-emphasis] |
| X4 | Every state is designed: loading, empty, error, offline, working, blocked | high | P3 · [empty-states, error-recovery] |
| X5 | The purpose is clear within a second, and the next step is obvious and in thumb reach | high | P1, P6 · [content-priority] |
| X6 | Back, cancel and undo do what the person expects and keep scroll and input | high | P10 · [back-behavior, state-preservation, undo-support] |
| X7 | Every gesture has a visible alternative, and a modal can always be closed | high | P6 · [gesture-alternative, modal-escape] |
| X8 | Container fits the task: a screen for a place, a sheet for a choice or confirmation, a dialog for short input or a blocking alert | high | P7 · [modal-vs-navigation] |
| X9 | As few taps as possible from where the person starts (tap depth in `ui-ledger/navigation.md`) | medium | P1 |

**Motion: how it moves** (judged on a device or a recording, not the census)

| # | Check | Priority | Source |
|---|---|---|---|
| M1 | With reduced motion or Effects off, every drawing shows its finished frame and nothing loops | critical | P5, P9 · [reduced-motion] |
| M2 | No dropped frames on the emulator (`gfxinfo`), and input is never blocked by an animation | high | P5 · [main-thread-budget, no-blocking-animation, interruptible] |
| M3 | Every movement explains a change: arrival, working or finished | high | P5 · [motion-meaning, excessive-motion] |
| M4 | Durations and curves come from `KitMotion`; at most one ambient loop per screen, only while waiting | medium | P5 · standard §10 · [motion-consistency] |
| M5 | Only paint and transforms are animated, never layout, blur or shadow | medium | P5 · [transform-performance, layout-shift-avoid] |

**Copy: what it says**

| # | Check | Priority | Source |
|---|---|---|---|
| C1 | No secret, key or token is shown, and no link the app did not write opens without the host shown first | critical | P10 · AGENTS.md security invariants |
| C2 | The words match the state on screen, with no contradictions | high | P2, P3 |
| C3 | The person's words: no engine terms, paths, ports or ids above Details (glossary test) | high | P2, P4 |
| C4 | Waits and errors say what happened and what next; a wait of more than 8 s says so and offers a way out | high | P3 · [error-clarity, timeout-feedback] |
| C5 | Buttons are verbs that say what will happen | medium | P2 |
| C6 | Title of four words or fewer, body of two sentences or fewer, sentence case | medium | P2 |

**Principles: the whole**

| # | Check | Priority | Source |
|---|---|---|---|
| P-a | Works at 200 % text: reflows, and nothing is cut to a few letters | critical | P9 · [dynamic-type, truncation-strategy] |
| P-b | Every control has a label, the reading order matches the layout, and a status change is announced once | critical | P9 · [voiceover-sr, aria-labels, contextual-live-badge-updates] |
| P-c | Technical detail is available, folded, and copyable | high | P4 · [progressive-disclosure] |
| P-d | The screen feels like the rest of the app: calm, direct, one language | medium | P7 |

### Where we differ from common guidance

Our standard wins in each of these cases:

- **Busy buttons** [loading-buttons]: the common advice is to disable the
  button and put a spinner in it. We show progress as progress (standard §2,
  §4). A disabled button never stands in for "working", and a disabled button
  always says why it is disabled.
- **Spring curves and staggered lists** [spring-physics, stagger-sequence]:
  we use only `KitMotion`'s named durations and curves, so the app has one
  rhythm.
- **Scale on press** [scale-feedback]: we use the Material ripple. Nothing
  scales on press.
- **16 px minimum body text** [readable-font-size]: we use the theme's roles.
  Supporting lines are smaller by design, and they still pass U1 and P-a.
- **Auto-dismissing toasts** [toast-dismiss]: we use a snackbar only for a
  done-with-undo, and it stays long enough to undo.

### Scoring (1–5 per dimension)

| Score | UI | UX flow | Motion | Copy | Principles |
|---|---|---|---|---|---|
| **5 · Exemplary** | Calm and exact; could be a reference screen for the kit | The next step is obvious; every state designed; nothing wasted | Every movement explains; smooth; reduced motion complete | Short, true, human; nothing to cut | Meets every principle; shows off the product's character |
| **4 · Good** | Kit throughout; one or two craft nits | Clear; one minor extra tap or undesigned edge state | Meaningful; one timing or curve off | Clear; one word or phrase to improve | One minor rule broken, with a reason |
| **3 · Acceptable** | Kit mostly; spacing or type inconsistencies visible | Works, but the person has to think or scroll to act | Some decoration, or a loop outside a wait | Understandable, but long, passive or partly technical | One principle bent (P1–P10) |
| **2 · Poor** | Ad-hoc parts, competing primaries, duplication | Easy to get lost; a state leaves the person stuck | Distracting, janky or ignores reduced motion | Jargon, contradictions or vague buttons | Several principles broken |
| **1 · Broken** | Visibly wrong: clipped, overlapping, error box | Blocks the task or risks losing work | Drops frames badly or hides content | Wrong or misleading | Unsafe: leaks a secret, loses work, surprises |

A screen is **done** when every dimension scores 4 or more, no critical or
high item fails, and it has no blocker or major finding open. Any failed
critical item caps that dimension at 2. Motion is scored only where the screen moves.
Where the census cannot show it, the score waits for a device recording.
