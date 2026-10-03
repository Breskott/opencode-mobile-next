# Composer edge status (crit: composer rail), 2026-09-29

Owner critique: under the last prompt the live line ("The server has not
answered yet · 40 s  Stop reply") left a noticeable gap above the composer.
Owner direction after four previews: "the edge is the status", option B (a
bending line), no sharp curves, soft hue, calm speed.

## What was built

Kit (`lib/ui/kit/chat/kit_composer.dart`, `kit_turn.dart`, `kit_motion.dart`):

- `KitComposer.rail` (a `KitTurnLive`) and `KitComposer.failure`
  (`KitComposerFailure`: words, Retry, optional Details) and `railNote`.
  While set, the composer's top border eases down into one wide, shallow dip
  (raised cosine, 7 dp deep, caption width + 56 dp, no corner anywhere) that
  cradles the caption: phase words + elapsed, neutral text, and a small red
  Stop square. The whole caption is one tap target (semantics "Stop reply"),
  the caption's text is a live region announcing phase changes only.
  Failure shows the same edge with red words, Retry and Details.
- The dip grows from 0 along the same bell (380 ms ease-in-out; Calm 150 ms,
  half depth; Off/reduced motion instant) and straightens at the end. The
  glass's clip and its rim hairline follow the curve; the hairline is fainter
  in the deepest part so the caption reads over it. No height change.
- A soft light on the outline: wide blurred low-alpha hue, no crisp core or
  head. Thinking: slow breathing neutral hue; writing: follows
  `KitTurnLive.pace` (0..1) with a faint accent tint; stall (server quiet
  20 s+): breathing hue at the dip's edges, no travel; done: fades into the
  border as the dip straightens; failure: one soft red wash. Cross-fades are
  450 ms+. Speed caps live in `KitMotion` (`edgeLightMaxLapsPerSecond` 1/6,
  `edgeLightThinkingLapsPerSecond` 1/10, `edgeLightSpeedEase` 800 ms,
  `edgeLightHueFade` 450 ms). Calm: no travel, slow breathing hue; Off: still.
  The ticker runs only while there is something to show and stops with the
  route (TickerMode) and the backgrounded app. First written word: a light
  haptic tick through `KitHaptics.send` (existing vibration setting).
- `KitTurnLive.pace` (0..1) and `KitTurnLive.wordsFor` / `elapsedText` (shared
  wording; `teamAlsoWorking` still picks "Waiting for the model's first word,
  the team shares the phone"). Sending reads as Thinking on the edge.
- `KitTurn.statusOnComposer`: a running/starting turn draws no starting line
  when the composer's edge already says it. `KitTurnLive` and its line stay
  for pages without a composer.
- The newest turn (`latest`) ends with the kit's standard `space2`, not a
  22 dp section gap: this removes the gap above the composer.

Chat library:

- `chat_screen.dart` `_liveTurn` feeds the composer (`_ChatComposer.live`)
  and no transcript row draws a live line any more; the running turn's row
  passes `statusOnComposer`. `_livePace` derives `pace` from the real stream:
  characters (and 60 per tool step) that arrived since the last change, per
  second, eased, 90 characters/s = full. The kit decays it if events stop.
- `_inAppTeamWorking()` stays wired into `teamAlsoWorking`.

## Skipped and why

- `railNote` ("Sends after this reply") is not fed: the existing queued
  bubble already says it with Retry/Resend/Edit/Discard actions, and showing
  it on the edge too would say it twice. The kit option exists.
- `failure` is not fed from the chat screen: failed sends already have the
  transcript's own "Send again" and the draft-error banner; the kit option is
  ready when the owner wants Retry on the edge.
- Tap targets: the caption is 48 dp tall but half of it lies above the
  composer's bounds, where Flutter does not hit-test, so about 28 dp of it is
  touch-reachable; TalkBack and keyboard are unaffected.

## Evidence (media, not described further)

- `bend-soft.png`: bend growth at 25 % and 50 %, fully grown, thinking,
  writing, stall close-ups (3x) and one full-width shot.
- `bend-soft.mp4`: about 8 s: dip growing in, writing bursts, stall, more
  writing, dip straightening (2x).

## Tests edited (not run; the coordinator gates)

- `test/composer_layout_test.dart`, `test/pending_sends_strip_test.dart`,
  `test/stable_chat_layout_test.dart`: "no Stop in the composer" now checks
  the composer's own Stop circle (`kit-composer-stop`); Stop is on the edge.
- `test/chat_transcript_placement_test.dart`: Stop and status are on the
  composer edge, not under the newest turn.
- `test/composer_desktop_enter_test.dart`: status reads "Thinking…"; Stop
  through its semantics label.
- `test/chat_live_events_test.dart`: Stop tapped by key.
- `test/motion_states_test.dart`: waits the edge's 1.2 s fade before checking
  that nothing is animating.

## Device check

Send a prompt on a slow server: the edge dips with "Thinking · N s ■" and no
line under the prompt; long stall shows "No answer yet" with breathing hue at
the dip; a burst of text brightens the glow (never faster than one lap in 6 s);
Stop by tapping the caption; reply end fades the glow and straightens the dip;
check Calm and Off in Settings › Appearance and TalkBack announcing phases.
