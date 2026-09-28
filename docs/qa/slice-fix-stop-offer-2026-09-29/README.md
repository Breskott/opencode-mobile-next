# slice-fix-stop-offer (2026-09-29)

Branch revamp/slice-fix-stop-offer, from docs/qa/emulator-qa-claude-2026-09-28 (F3, F16).

## What changed
- F3 (lib/state/connection.dart, `session.error`): a Stop (v1 `MessageAbortedError`,
  v2 `aborted`, via `sessionErrorIsStop`) on the connected server no longer files a
  failed run, no longer settles attention as an error, sets no error alert or
  `lastError`. Inbox never says "Failed" and "needs you" does not count it. A real
  failure behaves as before.
- F16: "Notify you when the agent needs you?" moved from above the composer into the
  chat page's status slot (below every real status line, above the free-model note).
  Not now = the dismiss X (tooltip "Not now"); Notify me is the action. The claim,
  answer and failure flow lives in `lib/state/first_reply_notify_offer.dart`
  (`FirstReplyNotifyOffer`); `first_reply_notify_card.dart` and its test are deleted.
  A refusal shows plain words in the same slot. The reply and its actions do not move.

## Tests
- test/slice_fix_stop_offer_test.dart (fails without the fix: Stop shows Failed).
- test/chat_notify_offer_test.dart (reply does not move; Not now remembered; Notify me;
  refusal; streaming reply does not ask), test/first_reply_notify_offer_test.dart,
  test/consent_in_flow_test.dart, chat_free_model_note_test.dart.
- Gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text, kit_manifest,
  golden_harness, architecture_boundaries, l10n_coverage, design_standard; whole-project
  `flutter analyze` clean. Goldens refreshed: chat_notify_light/dark (looked at).

## Images
before/after at 412 (dark) and 1280 (light): `chat_notify_offer_{before,after}_*.png`
(before: the row sits above the composer and pushes the reply up; after: in the status slot).

## Needs a device
Android notification permission prompt on Notify me.
