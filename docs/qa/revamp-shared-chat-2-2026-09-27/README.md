# revamp-shared-chat-2: Revamp chat, the form sheet (2026-09-27)

## 1. Scope

- Unit: `shared-chat-2` (wave 2a, tier 1, revamp). Finish line: an OpenCode 2 form opens in the kit sheet frame built only from kit parts, and what the person typed survives swipe, back, close, Finish later and reopening until it is sent or dismissed. Non-goal: changing how the chat library opens forms (`lib/ui/screens/chat/form_flow.dart` is chat-owned) or the KitSheet frame itself.
- Files changed: `lib/ui/widgets/form_renderer.dart`, `lib/l10n/app_en.arb` (8 new `formRenderer*` keys, English only per the 2026-09-27 owner decision), `test/form_renderer_test.dart`, new `test/goldens/chat_form_sheet_golden_test.dart` and its 14 `test/goldens/chat_form_*.png` goldens.
- Pages (map ids): `form-sheet`, `form-sheet-date-picker`, `form-sheet-dismiss-confirm-sheet`.
- Specs followed: STANDARDS.md §1, §15, §16, §18 (G1, G16, G2, G7, G17, G21, G48); kit-v2 §9 (allowlist); visual-language §6 (sheet frame from KitSheet).
- Contract problems (PROC-20): KitSheet (kit-KitSheet-v2) keeps its header and pinned action block outside the scroll view, so at `AppTheme.maxTextScale` (2.5) on a 360x740 phone a long title plus the action block overflow (372 px in `test/text_scale_overflow_test.dart` "the form renderer lays out at 2.5x"). The KitSheet doc promises pinned actions only up to 200 %. Proposed: KitSheet lets the header scroll with the body (or unpins the actions) when header + actions exceed the available height. Blocks: that one shared test; every KitSheet page has the same exposure.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - form-sheet: actionsMissing "save answers and come back" → done: Finish later + draft carry, `test/form_renderer_test.dart` "draft carry: Finish later and close keep the answers", "draft carry: answers survive a swipe down and reopen".
  - form-sheet: statesMissing "send failed" → done: `form-error-banner` with Try again, `test/form_renderer_test.dart` "send failure shows the error notice with Try again"; golden `chat_form_sendfailed_{light,dark}.png`.
  - form-sheet: statesMissing "form withdrawn by the agent while open" → done through `RequestRoutes` (the presenting request retires the sheet and the nested confirm, passed to `showKitSheet`/`showKitConfirm`); no new test in this unit (existing chat request-route tests own the invalidation path).
  - form-sheet: statesMissing "unsaved answers on back (only Dismiss confirms)" → done: back/swipe/close keep the answers silently instead of losing them; only Dismiss (which throws the answers away) confirms. Tests as for draft carry above.
  - form-sheet-date-picker, form-sheet-dismiss-confirm-sheet: no items (proposal keep).
- States per page (STATE-20): form-sheet: content height → golden `chat_form_sheet_*`; full height / wide end sheet → `chat_form_full_*`; busy → `loading` bar + Dismiss disabled with a spoken reason (code only, no test: deferred); send failed → `chat_form_sendfailed_*`; validation error → "validation blocks submit and shows inline errors". form-sheet-date-picker: date → `chat_form_datepicker_*`; time (date-time) → code path `_pickDate`, no golden. form-sheet-dismiss-confirm-sheet: confirm → `chat_form_dismiss_*`.
- Deferred states (STATE-21): date-time time picker golden → needs a second picker pump, no owner; busy (sending) test → needs a held submit future, no owner.

## 2. Builds

- Branch `revamp/shared-chat-2-r2` (the name `revamp/shared-chat-2` is held by a stale worktree `wf_9cdf1571-206-1` with an uncommitted-parent WIP commit `6cd15b4c`; this branch carries that WIP forward onto the current base), base `2cec35ca` (feat/phone-setup-v2), code head `716aec35`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/form_renderer_test.dart` | passes | 32 passed | PASS |
| 2 | `test/goldens/chat_form_sheet_golden_test.dart` (after `--update-goldens`, each image opened) | passes | 14 passed | PASS |
| 3 | `KIT_RATCHET_WRITE=1 test/kit_ratchet_test.dart`, baseline read then restored | `form_renderer.dart` absent from every gate (0) | absent from G1, G15, G16, G2, G7, G15x, G17, G21, G48 | PASS |
| 4 | `test/accessibility_guidelines_test.dart --plain-name "form renderer"` | passes | passed | PASS |
| 5 | `test/text_scale_overflow_test.dart --plain-name "form renderer"` | passes | RenderFlex overflow 372 px (KitSheet header + pinned actions at 2.5x, see Contract problems) | FAIL |
| 6 | `flutter analyze` on the changed files and `form_flow.dart` | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | P7.1 draft carry | `test/form_renderer_test.dart` "draft carry: answers survive a swipe down and reopen" | run 1 |
  | P7.1 draft carry | `test/form_renderer_test.dart` "draft carry: Finish later and close keep the answers" | run 1 |
  | showKitConfirm | `test/form_renderer_test.dart` "dismiss asks in place, cancels, and forgets the answers" | run 1 |
  | G1/G16/G7/G17/G21/G48 = 0 | `test/kit_ratchet_test.dart` write mode | run 3 |

- Changed test expectations (TEST-19): `test/form_renderer_test.dart` now finds the kit parts (KitSheet actions `form-submit`, `form-cancel`, `form-later`, KitNotice `form-error-banner`, `form-dismiss-confirm`) instead of the Material widgets; behaviour asserted is unchanged plus draft carry.
- Goldens changed (each opened and looked at): all new, phone 412x915 and 1280x800, light and dark:
  - `chat_form_sheet_*`: content-height sheet, radio rows, date row, switch row; approved render `docs/design/visual-language-2026-09-26/Confirm.png` (sheet frame): same handle, title/subtitle, full-width primary + tonal secondary; difference: the form adds a text-only Finish later under the buttons.
  - `chat_form_full_*`: full-height sheet on phone, end side sheet at 1280x800 with actions in one row.
  - `chat_form_sendfailed_*`, `chat_form_dismiss_*`, `chat_form_datepicker_*`: as named; dismiss matches `Confirm.png` (icon tile, destructive primary, Cancel).
- Before and after: `before-form-sheet--sheet.png`, `before-form-sheet--full-screen.png`, `before-form-sheet-dismiss-confirm-sheet.png`, `before-form-sheet-date-picker.png` (from base census `docs/qa/screen-census/d-chat-sheets/`); `after-form-sheet--sheet.png`, `after-form-sheet--full-screen.png`, `after-form-sheet--send-failed.png`, `after-form-sheet-dismiss-confirm-sheet.png`, `after-form-sheet-date-picker.png`.
- Accessibility: choice rows merge semantics and speak checked / mutually exclusive state; inline errors are live regions; the dismiss-while-sending button carries a spoken disabled reason; targets come from KitRow/KitButton (48 dp). 250 % text fails in the kit sheet frame (run 5).
- Privacy and security: external form links still go through `openExternalLink` with the host shown; multiline answers are saved as a `KitDraft` under `oc.draft.form.<formId>.<fieldKey>.<profileId>` only when a `profileId` is passed (the draft sweep finds the `oc.<what>.<profileId>` name), cleared on send and dismiss.
- Migration: n/a: no stored format changed (new draft keys use the existing KitDraft format).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/form_renderer_test.dart test/goldens/chat_form_sheet_golden_test.dart
$F test -j 1 test/accessibility_guidelines_test.dart test/text_scale_overflow_test.dart --plain-name "form renderer"
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart   # then: git checkout test/kit_ratchet_baseline.json
$F analyze lib/ui/widgets/form_renderer.dart test/form_renderer_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Draft carry across an app restart: only multiline answers persist, and only when the caller passes `profileId`; `lib/ui/screens/chat/form_flow.dart` (chat-owned) does not pass it yet, so today answers survive swipe/back/reopen in memory but not a restart.
- The full suite, the whole-tree analyzer and the design-standard / l10n coverage tests were not run (owner decision 2026-09-27: own tests only).
- 250 % text in the sheet frame (run 5 fails, kit contract).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/shared-chat-2-r2` |
| Enabled | Yes (OpenCode 2 servers; forms are hidden where `ServerCapabilities` has no forms) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `716aec35` |
| Deployed | No | |
| Released | No | |
