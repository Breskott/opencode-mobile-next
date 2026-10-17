# Phrase chips - 2026-10-12

Feature: one row of the person's own common short phrases above the message
box, chosen for the moment and learned on the phone from what they send.
Branch `feat/phrase-chips` (local, unpushed).

## Evidence kind

Widget-test renders of the real `ChatScreen` at 390x844 (real fonts, light
theme), **not** emulator or device screenshots. No release APK was built and
no emulator was used for this slice, so nothing here proves the row on a real
phone, with the on-screen keyboard, or against a live server. Run on a device
before shipping.

## Images

- `stopped-partway.png` - the last turn was stopped by the person. Learned
  phrases for this moment ("Run the tests", "Commit it") lead; the starter
  "Continue" fills the room left.
- `working.png` - the agent is busy. "Run the tests" was learned for this
  moment; the starter "What's the update?" follows it. The composer shows Stop.

## How they were made

```bash
OC_PHRASE_CAPTURE_DIR=$PWD/docs/qa/phrase-chips-2026-10-12 \
OC_TEST_SLOTS=2 tool/qa/machine_lock.sh test timeout 590 \
  ~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter \
  test --concurrency=2 test/phrase_chips_chat_test.dart
```

The capture tests are skipped unless `OC_PHRASE_CAPTURE_DIR` is set.

## Tests

- `test/phrase_chips_test.dart` - normalization, what is recorded, secret
  rejection, two-send threshold, per-moment ranking, recency decay, starters,
  hide / show hidden, bounds (50 phrases, 100 hidden), persistence, the
  profile deletion sweep and a late write after deletion.
- `test/phrase_moment_test.dart` - moment derivation.
- `test/phrase_chips_chat_test.dart` - the row per moment, hidden while
  typing, tap sends, long-press Edit / Hide, no second Continue, the switch,
  learning from a real send, Arabic.
- `test/phrase_chips_settings_test.dart` - the Settings switch and "Show
  hidden phrases", launcher search, Arabic.

Proof the tests bite: with these seven changes made together, nine tests
failed (then reverted): transcript-Continue exclusion removed, typing
condition removed, `_learnPhrase` call removed, long-press removed from the
kit row, `PhraseChipStore.closeProfile` removed from the deletion sweep,
`working` mapped to `idle`, secret check removed.
