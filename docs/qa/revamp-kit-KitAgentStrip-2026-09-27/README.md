# revamp-kit-KitAgentStrip: KitAgentStrip (2026-09-27)

## 1. Scope

- Unit: `kit-KitAgentStrip` (wave 1, tier 3, kit part). Finish line: the kit has `KitAgentStrip`, `KitAgent` and `KitAgentTint` to their frozen API, and `agent_color.dart` forwards to `KitAgentTint` with zero `Colors` literals. Non-goal: migrating `_TeamFamilyStrip` in `team_conversation_view.dart` (chat-4) or any other screen; exporting from `kit.dart` (integrator, R06).
- Files changed: `lib/ui/kit/chat/kit_agent_strip.dart` (new), `lib/ui/widgets/agent_color.dart` (forwarding layer), `lib/l10n/app_en.arb` (+3 keys) and the generated `lib/l10n/app_localizations*.dart`, `test/kit/kit_agent_strip_test.dart`, `test/goldens/kit/kit_agent_strip_golden_test.dart` and its PNGs, this record.
- Pages (map ids): `team-conversation#team-conversation-family` (element only; the page migrates in chat-4).
- Specs followed: `docs/ux-system/kit-api/KitAgentStrip.md` (frozen API); STATE-9, LOOK-4, LOOK-6, LOOK-24, COPY-13, A11Y-8, KIT-3; kit-v2 §8.2 (adaptive: compact/medium scroll, expanded/large wrap).
- Contract problems (PROC-20):
  - Galleries: the spec's list (360x800, 915x412, 800x1280, 1600x1000, text 2.0 and Arabic RTL; ~26 PNGs) is replaced by the owner decision 2026-09-27 (Arabic dropped; 412x915 and 1280x800 only, light and dark). The gallery is 6 states x 2 sizes x 2 themes = 24 PNGs. Kit copy is `app_en.arb` only (the spec says en + ar).
  - `kitAgentLabel` "{name}, {role}, {state}" with "the role part dropped when null": one ARB key cannot drop a free-text placeholder, so the key is an ICU `select` on a `hasRole` placeholder (`yes`/other). The generated method is `kitAgentLabel(hasRole, name, role, state)`; the key name and English text are as specified.
  - The fine-pointer horizontal scrollbar waits for `KitScrollbar` (kit-KitScrollbar has not merged; the spec says "once it merges"). No local substitute was built (R13).
  - `KitTappable` has no hint parameter; the "Open {name}'s conversation" hint is a `Semantics(hint:)` around the tappable, which merges into the same button node (test 4 asserts the merged node).
- New kit parts (KIT-3): `KitAgentStrip`, `KitAgent`, `KitAgentTint` (the unit's own part; planned).
- Map items (EVID-11): team-conversation-family → done in the kit: `test/kit/kit_agent_strip_test.dart` + gallery; adoption deferred to chat-4.
- States (STATE-20): mixed, needs you, paused, all done, lead only, overflowing → goldens `kit_agent_strip_<state>`; all working → overflow golden (most chips working) and test 6; empty → test 1.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitAgentStrip`, base `024e97b0`, code head: see `git log`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new part | n/a | n/a |
| 2 | `test/kit/kit_agent_strip_test.dart` | passes | 10 passed | PASS |
| 3 | `test/goldens/kit/kit_agent_strip_golden_test.dart --update-goldens`, then looked at | renders, G5 passes | 24 passed; overflow (412, 1280), needs_you and paused opened and checked | PASS |
| 4 | `flutter analyze` on the changed files and the three `agent_color` callers | no issues | no issues | PASS |

Owner decision 2026-09-27 (speed): no other suites were run (ratchet, design-standard, l10n coverage and other goldens are the integrator's).

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden |
  |---|---|
  | STATE-9 | `test/kit/kit_agent_strip_test.dart` "semantics: group, chip words, hint, not live, 48 dp" |
  | LOOK-24 | "each state shows its mark; needsYou is KitNeedsYou.mark" |
  | LOOK-4/LOOK-6, G17 | "KitAgentTint is text2; the wrappers return the same neutral" |
  | COPY-17 | "paused with done asserts; paused working reads Paused" |
  | A11Y-8, G6 | "200% text at 320 dp: no overflow, LTR and RTL" |
  | §8.2 adaptive | "compact scrolls sideways inside the strip; expanded wraps" |
  | Keyboard | "onOpen fires on tap, Enter and Space; …", "desktop: Tab walks tappable chips into view; …" |
  | MOT-7 | "reduced motion: a state change settles after one pump" |

- Changed test expectations (TEST-19): none (no shared test edited).
- Goldens: 24 new `test/goldens/kit/kit_agent_strip_*` PNGs, each opened and looked at.
- Accessibility: group label "Agents on this task"; chip label "{name}, {role}, {state}"; tappable chips are buttons with the hint; lead is not a button or Tab stop; chips ≥ 48 dp; names isolated with `KitBidi.auto`.
- Privacy and security: n/a: no credentials, stored data, links or notifications.
- Migration: n/a: no stored format. Visual: every agent colour (sub-agent chip in `tool_card.dart`, `pickers.dart`, `command_launcher.dart`) is now `text2`; goldens that show a coloured agent may change (integrator-owned, not regenerated here).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_agent_strip_test.dart test/goldens/kit/kit_agent_strip_golden_test.dart
$F analyze lib/ui/kit/chat/kit_agent_strip.dart lib/ui/widgets/agent_color.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Fine-pointer scrollbar (waits for KitScrollbar).
- Arabic/RTL galleries (dropped by the owner); RTL is covered only by the 200 % text no-overflow test.
- Ratchet/design-standard/l10n-coverage gates and other units' goldens were not run (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitAgentStrip` |
| Enabled | No: no screen uses it until chat-4 | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
