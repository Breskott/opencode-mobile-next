# revamp-kit-KitComposer: KitComposer (2026-09-27)

## 1. Scope

- Unit: `kit-KitComposer` (wave 1, tier 3, kit part). Finish line: `KitComposer` exists at `lib/ui/kit/chat/kit_composer.dart` with the frozen API of `docs/ux-system/kit-api/KitComposer.md`, behaviour tests and a gallery. Non-goal: migrating `lib/ui/screens/chat/composer.dart` or `voice_conversation.dart` (chat-3, chat-5), and editing `lib/ui/kit/kit.dart`.
- Files changed: `lib/ui/kit/chat/kit_composer.dart` (new), `test/kit/kit_composer_test.dart` (new), `test/goldens/kit/kit_composer_golden_test.dart` (new) and its PNGs, `lib/l10n/app_en.arb` (33 new `kitComposer*` / `kitVoice*` keys) and the generated `lib/l10n/app_localizations*.dart`.
- Pages (map ids): `chat#embedded-composer`, `embedded-composer#embedded-composer-field`, `#embedded-composer-send`, `#embedded-composer-stop`, `#embedded-composer-activity`, `embedded-voice-conversation-controls#embedded-voice-conversation-controls` (the part only; the screens move in chat-3 and chat-5).
- Specs followed: KitComposer.md (frozen API), STANDARDS Appendix B9 (Stop and Send side by side, 8 dp apart; Stop a `text1` circle), LOOK-5, LOOK-20, LOOK-29, LOOK-30, STATE-7, STATE-8, DATA-1, DATA-11(c), MOT-11, LAY-9; visual language §5 and §6.
- Owner decisions applied (2026-09-27): no Arabic ARB entries (app_en.arb only; Arabic falls back to English), no RTL galleries or RTL tests; galleries at 412x915 and 1280x800 only, light and dark.
- Contract problems (PROC-20):
  - Esc "closes the suggestions if they are open", but the API has no callback to tell the host. The composer hides the suggestions itself until the text changes or the host hands a new `suggestions` widget. Proposed text: add `onDismissSuggestions` (optional) in a later additive change if the host needs to know.
  - No copy for Stop's own in-flight tap (`stopping`). Stop shows a spinner and is disabled with the existing `kitWorking` ("Working") as its reason. Proposed: `kitComposerStopping` "Stopping".
  - Tokens: the spec gives the voice phase words KitText `secondary` (14). At 14 dp, "Listening…" failed G5's measured text contrast (1.80: the checker samples a 1/DPR downscale, where thin short words read as grey), so the phase words use `body` (16), the role of the field they replace. Proposed text: "`body` (field, voice phase words)".
  - The field's own node is held at 48 dp tall (G5 androidTapTarget failed at the one-line 24 dp height); the text sits at the top of that line.
  - The `KitSwap`/`KitGlass` names are as specified; `KitLayout.composerMaxShare`, `KitTokens.composerActionSize` and `composerStopSquare` were already on the base.
- New kit parts (KIT-3): none (KitComposer is this unit's part).
- Map items (EVID-11):
  - statesMissing "offline: Send label does not say it will queue" → done: `test/kit/kit_composer_test.dart` "offline: Send says it queues and still sends"; golden `kit_composer_offline_*`.
  - statesMissing (voice) "mic denied inside the mode" → done: "micDenied: the reason and the fix"; golden `kit_composer_voice_mic_denied_*`.
  - Owner Fix "one trailing control …, plain Steer/Queue words" → done: the "trailing control (the table)" group and the "delivery" group.
  - Owner Rethink (voice) "a composer mode: big mic in the send slot, listen→send→speak loop without the sheet, plain 'Read replies aloud'" → part half done: the "voice" group; the host loop is deferred to chat-5.
- States (KIT-12): idle empty, idle with text, sending, busy empty, busy with text (with and without the delivery choice), busy cannot send yet, offline, read-only, focused, and every `KitVoicePhase` → the tests named in §5; the gallery covers the states the spec lists.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitComposer`, base `024e97b0`, code head `0b6c298c`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_composer_test.dart` | passes | see `run-tests.txt` | PASS (42 passed) |
| 2 | `test/goldens/kit/kit_composer_golden_test.dart --update-goldens`, then each PNG opened | renders, G5 accessibility checks pass | see `run-goldens.txt` | PASS (30 rendered; the two voice_listening shots failed G5 first, fixed, then all voice shots re-rendered) |
| 3 | `dart analyze` on the three new Dart files | no issues | no issues | PASS |

Per the owner decision of 2026-09-27 (speed), no other suites were run: ratchet, design-standard, l10n coverage and the manifest tests were not run by this unit.

## 5. Evidence

- `run-tests.txt`, `run-goldens.txt`: the tail of each run.
- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_composer_test.dart` + `--plain-name`) or golden |
  |---|---|
  | B9, LAY-9 | "Stop and Send: 48 dp each, at least 8 dp apart" |
  | LOOK-5 | "Stop is a text1 circle with a ground square; no danger" |
  | STATE-7 | "sending: this tap only says Sending" |
  | STATE-8 | "busy, text, cannot send: Stop and the reason" |
  | DATA-1 | "the composer never changes the text" |
  | MOT-11 | "a Send tap sends once and ticks once", "Vibration off: no haptic" |
  | LOOK-29 | "glass: a dimmed KitGlass, solid under remove animations"; golden `kit_composer_glass_off_*` |
  | A11Y-3 | "voice … its words, in a live region" (one per phase) |
  | P9.5 | "200 % text at 320 dp: no overflow; Stop and Send 8 dp apart"; golden `kit_composer_busy_text_text2_*` |

- Changed test expectations (TEST-19): none.
- Goldens: all new, `test/goldens/kit/kit_composer_*` (13 states at 412x915, the default at 1280x800, busy_text at text 2.0; light and dark = 30 PNGs). The gallery harness renders with remove animations on, so the glass is solid in every shot (KitGlass's own rule).
- Before and after: no before render; the part is new (`chat#embedded-composer` census PNGs show today's `_ChatComposer`).
- Accessibility: every control is labelled by the table's words (tooltip = label); targets are 48 dp; the field's accessible name is `fieldLabel` ("Message"); voice phase words are a live region; the level meter and elapsed time are excluded from semantics; 200 % text checked at 320 dp and 412 dp.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed. The composer never stores the draft.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_composer_test.dart
$F test -j 1 test/goldens/kit/kit_composer_golden_test.dart
dart analyze lib/ui/kit/chat/kit_composer.dart test/kit/kit_composer_test.dart test/goldens/kit/kit_composer_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator; the liquid and frosted glass looks are not rendered (the gallery is solid).
- No screen uses the part yet (chat-3, chat-4, chat-5 migrate).
- Repository-wide gates (ratchet, design standard, l10n coverage, kit manifest, full analyze) were not run by this unit (owner decision 2026-09-27).
- Focus-ring visibility on each control is KitTappable's and KitIconButton's (their tests), not re-tested here; the Tab test checks only the first step (field → "+").

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitComposer` |
| Enabled | No: no screen uses it yet (chat-3) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | `revamp/kit-KitComposer` |
| Deployed | No | |
| Released | No | |
