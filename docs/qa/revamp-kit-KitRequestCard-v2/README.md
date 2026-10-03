# revamp-kit-KitRequestCard-v2: KitRequestCard v2 (2026-09-27)

## 1. Scope

- Unit: `kit-KitRequestCard-v2` (wave 1, tier 4, kit-change). Finish line: `KitRequestCard.ask` answers every agent request (permission, question, form, choice, gate, reply) in place through the five phases, and the pre-v2 constructor keeps compiling with the v2 frame. Non-goal: no screen adoption, no details sheet, no `change` variant (P2 deferred, C50).
- Files changed: `lib/ui/kit/kit_request_card.dart`; `lib/l10n/app_en.arb` (+10 `kitRequest*` keys, English only per the owner decision of 2026-09-27) and the regenerated `lib/l10n/app_localizations*.dart`; new `test/kit/kit_request_card_test.dart`, `test/goldens/kit/kit_request_card_golden_test.dart` and its 28 PNGs; this record.
- Pages (map ids): embedded-permission-attention-card, embedded-question-attention-card (served; adoption is chat-5's).
- Specs followed: `docs/ux-system/kit-api/KitRequestCard.md` (frozen API); kit-v2 §2.1, §3, §4.5, §4.8, §4.9, §8.2; visual language §1, §4, §5 (LOOK-4, LOOK-6, LOOK-20, LOOK-21, LOOK-24); STATE-5, STATE-8, STATE-10; A11Y-3, A11Y-8; LAY-9, LAY-13; MOT-5, MOT-11; G9, G37.
- Contract problems (PROC-20):
  1. **The spec's "Arabic" shortcut test.** It says "under an Arabic layout, physical A still allows". flutter_test's key simulator has no key code for an Arabic logical key (it fails an assertion: `keyCode != null`). The test sends the physical A key with a different logical key (Q, as an AZERTY keyboard types). That shows the same thing: the physical key decides. Arabic is dropped for this wave anyway.
  2. **The collapsed row as "one line".** A title and a receipt with Undo ("Allowed once · Undo") do not fit on one line at 412 dp. The row shows the title on its first line and the receipt under it, in one row of at least `rowHeight`, with no card, border or attention colour. See `kit_request_card_answered_*.png`.
  3. **The Details line.** It does not show when the one primary already opens the sheet (`KitRequestInSheet`, `KitRequestChooseMany`), because that would be a second control for the same place. The spec does not say either way.
  4. **G5 textContrast false failures.** The gate samples each text node at 1x. A lone short `text2` word ("Sending…", the collapsed title) comes out below 4.5 from its anti-aliasing alone, although `text2` measures 5:1 and more on every pack. This is the same finding as kit_receipt's gallery and docs/qa/revamp-kit-KitStatusMark-v2-2026-09-27. The gallery reads those four states (sending, answered, answered-elsewhere, expired) as one merged node, as kit_receipt's gallery does. The part itself is unchanged. It needs a fix in the gate (sample at the view's DPR), which belongs to the integrator.
  5. **The spec's copy list for the caption.** It lists `kitRequestAge` "waiting {age}" but no key for "{who} on {server}" or for the spoken age. The card reuses KitNeedsYou's `kitNeedsYouWhoOnServer` and `kitNeedsYouWaitingSpoken`, so the two surfaces say the same words (COPY-18).
- New kit parts (KIT-3): none.
- Map items (EVID-11): embedded-permission-attention-card / embedded-question-attention-card: the card itself is done (test + goldens); adoption is deferred to chat-5.
- States per part (STATE-20): each state has a golden and a test:
  - waiting per kind: `permission|question|form|choice|gate|reply_waiting` and the "every kind waiting" tests;
  - waiting-refused, disabled, sending, sending-escalated, answered (Undo), answered-elsewhere and expired: goldens of the same name and the "phases" tests.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitRequestCard-v2-r2`, base `8ce9389b` (`feat/phone-setup-v2`). The name has the `-r2` suffix because `revamp/kit-KitRequestCard-v2` already exists, checked out by another worktree (`wf_1d49ead2-79b-5`, no commits of its own). A worktree-isolated agent cannot move it.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_request_card_test.dart` | passes | 48 passed | PASS |
| 2 | `test/goldens/kit/kit_request_card_golden_test.dart` (28 shots, G5 in both themes) | passes | 28 passed | PASS |
| 3 | `flutter analyze` on the part, its tests, its gallery and its callers (attention_card, team_needs_you, kit_foundation gallery, kit_overflow_scenes) | no issues | no issues | PASS |
| 4 | Ratchet, design-standard, l10n and chat_states_standard tests | — | not run (owner decision 2026-09-27: own tests only) | NOT RUN |

Output: `run-tests.txt`.

## 5. Evidence

- **Rule evidence (PROC-31)**, all in `test/kit/kit_request_card_test.dart`:

  | Rule | Test (`--plain-name`) |
  |---|---|
  | P4.1a Allow once / Reject in place, G9, MOT-11 | "Allow once / Reject in place; one tap, once; one haptic", "no haptic with Vibration off" |
  | P4.1a an option sends with Undo | "a tap sends once; sending shows the receipt on the chosen row; …" |
  | P4.1a Something else opens a KitField with a draft (DATA-1) | "Something else opens a KitField whose draft survives and is sent by Send" |
  | STATE-8 | "disabled: the reason shows under the answers", "reply: Send is disabled with its reason while empty" |
  | STATE-5 / STATE-10 | "sending: …Not confirmed yet with Try again at 8 s" |
  | LOOK-4 | "answered collapses to a row with no attention colour" |
  | A11Y-3 (announced once) | "announcements: appear, sending, answered — three; the same state again — none" |
  | §8.2 shortcuts | group "shortcuts (§8.2)" |
  | LAY-9 48 dp | "48 dp targets; the decide buttons are 8 dp apart" |
  | 200 % cap | "2.0 text on 360x740: …", "no overflow at … dp, 2.0 text" |
  | G37 | group "asserts (G37)" |
  | KIT-43 / LOOK-6 | group "legacy constructor (KIT-43)" |
  | G8 | "reduced motion: every phase settles after one pump (G8)" |

- **The test font.** It draws every glyph 1 em wide, so the side-by-side test uses short verbs ("Run" / "Skip"). With the real face, "Run once" / "Don't run" sit side by side at 412 dp (`kit_request_card_permission_waiting_*.png`).
- **Changed test expectations (TEST-19):** none. No shared test was edited.
- **Goldens (new, each opened and looked at):** `test/goldens/kit/kit_request_card_<state>_<dark|light>.png` for the 13 states at 412x915, plus `kit_request_card_permission_waiting_1280x800_<dark|light>.png`.
  - Compared with the approved render `docs/design/visual-language-2026-09-26/Chat.png`: the permission card has the amber surface, line and ring, the tile, the caption, a mono inset and "Don't run" / "Run once" side by side. The one difference is the tertiary Details line under the buttons.
- **The pre-v2 look changed, as the spec says:**
  - a null or non-attention tone now paints a plain `surface1` card with a hairline and a `surface3` tile, with no accent tint (LOOK-6);
  - the tile is `requestTileSize`/`requestTileRadius`, the summary radius is `codeRadius`, and the width cap is `KitLayout.readingWidth`.

  Integrator-owned goldens that draw the pre-v2 card will drift: kit_foundation's request-card shots, and the chat and team census renders that show attention cards. They were not rendered here (owner decision: do not regenerate other units' goldens).
- **Accessibility:**
  - the card is one container labelled "{title}, {reason}, {who on server}, waiting N minutes, {detail}, {ifIgnored}";
  - the announcement is a live region with constant words, so it is read once;
  - the summary is its own node with the untruncated value, left to right;
  - the tile is excluded;
  - the receipt carries phase changes;
  - the expired words are a live region;
  - targets are 48 dp or more;
  - the v2 card is one Tab stop with a focus ring of `focusRingWidth`, and the pre-v2 card keeps today's traversal.
- **Privacy and security:** n/a. No credentials or links. The drafts use `oc.draft.request.<id>.<profileId>` through `KitDraft`, which the card never clears.
- **Migration:** n/a. No stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_request_card_test.dart test/goldens/kit/kit_request_card_golden_test.dart
$F analyze lib/ui/kit/kit_request_card.dart test/kit/kit_request_card_test.dart test/goldens/kit/kit_request_card_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The shared gates were not run in this unit (owner decision, 2026-09-27): kit_ratchet, design_standard, l10n_coverage, kit_manifest and `test/chat_states_standard_test.dart`.
  - The ratchet counts for this file should drop: G15x `numeric maxWidth:` 1→0, and G21 4 kinds → 0.
  - `chat_states_standard_test` should hold: the key `kit-request-card` stays, and the card is its 16 dp padding plus a hairline.
- **The shortcut hints ("A", "D") on the decide buttons.** They come from `KitButton.shortcut`, which draws only on a fine pointer from expanded. No gallery shot is on a desktop platform.
- **The digit shortcuts in the choice rows' semantic hints.** Not done: `KitChoice` has no hint field (a KitChoiceList change).
- **"Announced once per request" across a dispose and remount** (a card scrolled out of the list and back). Not guarded: it is a live region with constant words, so a remount reads it again.
- **The escalated sending receipt.** Try again shows only when the host passes `receipt.onRetry`.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitRequestCard-v2-r2` |
| Enabled | No: no screen adopts `.ask` yet (chat-5, shared-shell-1, screen-team-1) | |
| Verified | Own tests and gallery only | `run-tests.txt` |
| Committed | Yes | local branch |
| Deployed / Released | No | |
