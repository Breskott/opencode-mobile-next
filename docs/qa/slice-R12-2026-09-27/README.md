# slice-R12: AI Team host form, board card, setup output (2026-09-27)

Definition: `docs/ux-system/revamp/leftover-units.json`, id `slice-R12`.
Branch `revamp/slice-R12`, based on `feat/phone-setup-v2` (merged in again at
`52ab78c4` before finishing).

Each R12 item was checked against the code as it is today. P1.7 rebuilt the
phone onboarding, P3.4 made TeamPage the one team page, and the no-raw-errors
sweep had already run.

## Done

| Item | What changed |
| --- | --- |
| Host form: pinned actions | `showTeamHostSheet` pins the form's changing actions through `primaryListenable`/`secondaryListenable`: Test and turn on, then Cancel test while the test runs, then Save the address anyway after no answer. They used to sit in a `KitActionBlock` in the body. The new `TeamHostFormActions` carries them. The form only publishes them from events, never while it is building. A `TeamHostForm` placed outside the sheet (no `actions`) still draws its own block. |
| Host form: wording | "Save without an answer" now reads **Save the address anyway**. A note now appears under the no-answer verdict: "AI Team shows the team as not answering until the computer answers." The original "team card stays off" wording was dropped because the team card no longer exists after P3.4. The raw error fold is now titled **Connection details** instead of Details. |
| Turn-off confirm | The confirm button reads **Turn off AI Team** (new key `teamUiTurnOffConfirm`) instead of the bare "Turn off". This is a deliberate change from the R12 wording "Turn off AI Team for {host}": the sheet title already says "Turn off AI Team for {server}?", and the newer owner rule says an action never repeats a name the title gives. It still follows COPY-8: verb plus thing. `teamUiTurnOff` itself was not changed because the team page menu (owned by P5.2) also uses it. |
| 320 dp / 2.5x layout test | `team_plugins_layout_test.dart` "form" now taps the pinned Test and turn on (it must be hit-testable). The keyboard-Done workaround is gone. |
| Board card receipt | A moving card now uses `KitReceipt(state: sending, sendingLabel: 'Moving to {column}…')` instead of `automatic: true`. The pixels are the same, as the before/after images show. The meaning is now correct: the move is a write still sending, not an automatic-action line. The board still keeps no send time, so the receipt does not escalate on its own. |
| Setup output | The failure-report copy is now `KitLogPanel.headerAction` (key `setup-copy-report`), inside the panel. The loose `KitButton.tertiary` under the panel is gone. |
| Copy | "AI Team" is now capitalised in `teamUiPhoneSuccessTitle`, `teamUiPhoneRemoveTitle` and `teamUiPhoneRemoved`. The four orphaned `teamUiPhoneReoffer*` strings were deleted from en and ar, along with their glossary baseline entry. |

## Already done or obsolete

- **`TeamPhoneReofferCard` (team_phone_section.dart):** obsolete. The re-offer card no longer exists; P1.7 and P3.4 removed it and nothing references `teamUiPhoneReoffer*`. Its now-unused strings were deleted, and the card was not rebuilt.
- **`phone_setup_routes.dart` MaterialPageRoute → KitPageRoute:** not done. That file is under `lib/ui/screens/phone_setup/`, which P5.3 (setup/This phone) owns, and the brief forbids editing phone setup screens. Its three `MaterialPageRoute`s are still there. **Needs P5.3 (or a later slice) to swap them for `KitPageRoute`.**

## Tests

- New: `test/revamp/slice_r12_test.dart` (7 tests, all pass). They cover:
  - pinned submit, then Cancel test, then a dropped late answer;
  - no answer: the pinned Save the address anyway, the note, Connection details, and the raw error kept off the page;
  - a found host closing the sheet;
  - the turn-off confirm label;
  - the moving receipt's `sendingLabel` and non-automatic line;
  - the report inside the panel header, and no extra action without its words.
- New golden: `test/revamp/slice_r12_golden_test.dart` (moving board card; phone and 1280x800, dark and light).
- Updated: `test/team_plugins_layout_test.dart` (pinned tap) and `test/revamp/shared_team_1_test.dart` (wording).
- Goldens regenerated for the changed pages:
  - `team_host_sheet*`
  - `team_turn_off_sheet*`
  - `setup_terminal_states*`
  - `team_phone_remove_sheet*`, whose title changed.
- Run once:
  - `slice_r12_test`, `team_plugins_layout_test`, `shared_team_1_test`, `shared_phone_1_test`, `team_board_test`, `kit_ratchet_test`, `ui_glossary_test`: 113 passed, 6 failed.
  - All 6 failures are **pre-existing**: the same 6 fail on the base `52ab78c4` in a temporary worktree.
    - `team_plugins_layout_test` "editor LTR": a RenderFlex overflow on the Servers screen.
    - `kit_ratchet_test` G17 and G21: other files.
    - `ui_glossary_test` G11 confirm, G11 technical and G28: other keys.
- Pre-existing golden drift was not touched: small dark-theme pixel diffs (around 0.06%) in these goldens were left as they were (not mine):
  - `shared_team_1_golden_test`: board move, priority, add and cancel sheets, the host guide and the cycle How sheet;
  - `shared_phone_1_golden_test`: "On this phone" and "Stop the team?".
- `flutter analyze`: clean.

## Images

The `before-*.png` / `after-*.png` pairs in this folder cover:
- the host sheet: idle, testing, and no answer at phone and 1280x800;
- the turn-off question;
- the setup output;
- the moving board card at phone and 1280x800.

## Still needs a device

- The pinned host-sheet actions with the real keyboard up, at large text, on the phone.
- Copy failure report from a real failed setup. No host passes `copyTooltip` today: `local_agent_onboarding.dart` passes only `onCopy`.
