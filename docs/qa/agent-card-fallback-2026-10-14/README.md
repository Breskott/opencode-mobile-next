# Agent card fallback (2026-10-14)

Owner's phone (OpenCode 1 1.19.0, gen-UI 1.19.0): a finished `oc-ui_show` call
showed as an expanded tool step with the raw input rows (V, Id, Title) and the
tool's reply for the model under "Technical details". No card.

Images: `before-owner-phone.jpg` (owner's screenshot), `after.png` (the same
call with no card drawn: one folded line, "Showed a card", nothing opens).

## Root cause
The payload is valid (v:1, id, title, body, ask all parse; fixture
`test/fixtures/genui/runtime_opencode1_tool.json` has the same shape). The card
was withheld by the gate in `GenUiStateController.cardForPart`: it returned
null unless the scope was `available` (source registered ready, transport
current) AND the session's authoritative view had already cached the part. When
either was not true yet (qualification pending or lapsed, transport suspended,
view not yet refreshed) a completed card call fell through to the ordinary tool
row. Not provable from the phone (logcat silenced); this is the only path in
the code that yields a tool row for a valid completed card call.

## Fixes
1. `cardForPart` now falls back to parsing the finished call itself. The card
   draws; its state stays `unknown` (no ask is answerable, "can't confirm yet"
   note) until the authoritative view confirms it. Unfinished calls stay rows.
2. When a card call still shows as a step, it is one folded line ("Showed a
   card · title", "Couldn't show this card · title") with no body: no input
   rows, no model-facing reply, no details.

## Tests (fail without the fix)
- `test/gen_ui_state_test.dart` "a finished card call reads as a read-only card while unconfirmed"
- `test/tool_card_test.dart` "a completed/error card call with no card is one quiet line"
