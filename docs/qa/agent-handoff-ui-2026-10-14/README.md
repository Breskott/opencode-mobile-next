# Continue with… sheet (2026-10-14)

Built to docs/design/agent-handoff-contract.md. Evidence is real-fonts goldens at
phone size (412x915); no emulator or phone pass has been run yet. Light variants
are in `test/goldens/handoff_sheet_*_light.png`.

| Image | What it shows |
| --- | --- |
| choose.png | Models of this server, and an agent that needs signing in (reason + Sign in) |
| agents.png | Models and a ready agent model |
| model.png | A model of the same server: "Your conversation stays here." + Use this model |
| record.png | New agent chosen: facts, Conversation record, first message, Start and continue |
| preview.png | The record preview unfolded |
| unconfirmed.png | An unconfirmed result: plain words, no second start |

Not captured: the menu entry row and the link lines (no golden exists for them;
the menu key and the line widget are covered by `test/continue_with_sheet_test.dart`).

Tests: `test/continue_with_sheet_test.dart` (12), `test/goldens/continue_with_golden_test.dart` (12),
`test/revamp/slice_p10_1_2_test.dart` (menu list updated).
