# revamp-kit-KitMessage: KitMessage, the words of a transcript (2026-09-27)

## 1. Scope

- Unit: `kit-KitMessage` (wave 1, tier 5, kit part). Finish line: `KitMessage.prompt/.reply/.thought/.notice/.marker` exist in `lib/ui/kit/chat/kit_message.dart` exactly as frozen in `docs/ux-system/kit-api/KitMessage.md`, with behaviour tests and a gallery. Non-goal: migrating `message_view.dart` / `team_conversation_view.dart` (chat-1, chat-4), the turn footer (KitTurn), `kit.dart` exports.
- Files changed: `lib/ui/kit/chat/kit_message.dart` (new), `test/kit/kit_message_test.dart` (new), `test/goldens/kit/kit_message_golden_test.dart` (new) and 24 goldens `test/goldens/kit/kit_message_*.png`, `lib/l10n/app_en.arb` (7 new `kitMessage*` keys), this record.
- Pages (map ids): `embedded-message-view#embedded-message-view-prompt`, `team-conversation#team-conversation-prompt`, `embedded-message-view#embedded-message-view-reasoning-toggle`, `active-context-message#active-context-message-parts`, `embedded-message-view-v2-rows` (all served by this part; the screens adopt it in chat-1 / chat-4).
- Specs followed: STANDARDS.md STATE-16, KIT-41, LOOK-26, LOOK-5, KIT-28, A11Y-5, COPY-2, KIT-32, MOT-5, MOT-11; kit-v2 §9.2, §8.2; visual-language §5 (Transcript: prompt is a 20/20/6/20 `surface2` bubble, reply is plain prose).
- Contract problems (PROC-20): none blocking. Notes: (a) the frozen block declares `final KitMessageKind kind` without saying how it is set; each named constructor sets it in its initializer list. (b) "never narrower than its content needs up to that" has no kit primitive: `KitMarkdown` stretches and its tables use `LayoutBuilder` (no intrinsics), so plain prose is measured with a `TextPainter` in the body role; a prompt with block Markdown (heading, list, quote, table, code) or attachments takes the full 85 % share.
- New kit parts (KIT-3): `KitMessage` (the unit's own part). No other part created.
- Map items (EVID-11): prompt bubble → test 1, golden `kit_message_prompt`; reasoning toggle → test 5, goldens `kit_message_thought_*`; active-context parts / OC2 notice rows → test 6, goldens `kit_message_notice*`; marker → test 7, golden `kit_message_marker`.
- States per part (STATE-20): prompt plain / attachments / time → tests 1, 3, goldens `prompt`, `prompt_attachments`; reply → test 4, golden `reply`; thought working / folded / open → test 5, goldens `thought_folded`, `thought_open`; notice quiet / failed / with action / open → test 6, goldens `notice`, `notice_failed`; marker still / working → test 7, golden `marker`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitMessage`, base `4c871866` (feat/phone-setup-v2), code head: see `git log -1`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new part | n/a | n/a |
| 2 | `test/kit/kit_message_test.dart` (`-j 1`, pinned Flutter 3.47.1) | passes | 22 passed | PASS |
| 3 | `test/goldens/kit/kit_message_golden_test.dart --update-goldens` (dark, then light) | renders, G5 passes | 24 passed; every image opened | PASS |
| 4 | `dart analyze` on the three new Dart files | no issues | No issues found | PASS |
| 5 | Ratchet, design-standard, l10n, manifest tests | owner decision 2026-09-27: not run by the unit | not run | n/a |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | LOOK-26 / VL §5 | `test/kit/kit_message_test.dart` "sits at the end edge, surface2, 20/20/6/20" (ltr, rtl) | step 2 |
  | STATE-16 | "no control row; long-press opens the menu; custom actions" | step 2 |
  | KIT-28 / A11Y-5 | same, plus "right-click opens the same items", "10. desktop" | step 2 |
  | LOOK-5 | "failed: \"Failed,\" first, and no danger colour" | step 2 |
  | MOT-5 | "8. no size animation; reduced motion settles in one pump" | step 2 |
  | A11Y (48 dp, expanded, no live region) | "9. semantics" (includes `androidTapTargetGuideline`) | step 2 |
  | G6 | "11. 200 % text at 320 dp: no overflow" (ltr, rtl) | step 2 |

- Changed test expectations (TEST-19): none (new files only).
- Goldens (all new, each opened and looked at): `kit_message_{prompt,prompt_attachments,reply,thought_folded,thought_open,notice,notice_failed,marker}_{dark,light}.png` at 412x915; `kit_message_default[_1280x800][_text2]_{dark,light}.png`. Compared with `docs/design/visual-language-2026-09-26/Chat.png`: end-aligned `surface2` bubble with the small bottom-end corner, reply as unframed prose with inline code, same order; differences: the canvas has no time caption (the part shows one only when the host passes `time`).
- Accessibility: prompt is one container "You said, {text}, {attachment names}" with the menu as custom actions and "Show actions" long-press hint; folds are buttons with `expanded`; failed notice starts with "Failed,"; no live regions; 48 dp fold rows and bubble (with a menu); 200 % text checked at 320 dp.
- Privacy and security: n/a: no credentials, stored data, links or notifications. `KitMenuItem.copy` goes through `KitCopy` (redacts).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_message_test.dart
$F test -j 1 test/goldens/kit/kit_message_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Arabic / RTL galleries (dropped by the owner decision of 2026-09-27); RTL is covered only by behaviour tests 1 and 11.
- The shared gates (ratchet, design-standard, l10n coverage, kit manifest, G8x motion discovery) were not run; `kit.dart` does not export the part yet (integrator, R06).
- The hug width is measured on the raw Markdown source; inline marks (bold, code chips) can make the rendered line a few dp wider or narrower than measured, which only moves a wrap point.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitMessage` |
| Enabled | No: no screen uses it until chat-1 / chat-4 | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
