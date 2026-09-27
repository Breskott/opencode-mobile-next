# revamp-kit-KitCapabilityExplainer: the capability registry and its explainers (2026-09-27)

## 1. Scope

- Unit: `kit-KitCapabilityExplainer` (wave 1, tier 5, kit-part; cut v2 C20, replaces slice-P7.3). Finish line: one registry maps every capabilities.json capability to why it is missing, which hosts can and its enable flow, and `.row` / `.state` / `.offer` say so in place, offering the flow only when the app registered a handler. Non-goal: registering the 21 handlers, building any enable flow, adopting on screens, persisting "Not now" (coord-main and wave-2 units).
- Files changed:
  - `lib/ui/kit/kit_capability_explainer.dart` (new part: `KitCapabilityExplainer`, `KitCapabilities`, `KitCapability`, `KitHost`, `KitEnableRequest`, `KitEnableFlowHandler`, `KitEnableFlows`);
  - `lib/l10n/app_en.arb` (+123 keys) and the regenerated `lib/l10n/app_localizations*.dart`;
  - `test/kit/kit_capability_explainer_test.dart`, `test/goldens/kit/kit_capability_explainer_golden_test.dart` and 14 PNGs.
- Pages (map ids): none (a kit part; adoption is wave 2 per C37).
- Specs followed: `docs/ux-system/kit-api/KitCapabilityExplainer.md`; STANDARDS.md STATE-8, STATE-12, STATE-13, AUTO-18, AUTO-20, KIT-12, KIT-37, COPY-8, COPY-11, COPY-12, COPY-30, TEST-9, TEST-20; kit-v2 §2.2, §2.5; `docs/ux-system/capabilities.json` (`matrix`, `enableFlows`, `rules`).
- Contract problems (PROC-20):
  1. **Joiner grammar.** The spec gives `kitCapNotOnHost` as "{feature} isn't available on {host}", but its own example is "Files aren't available on Codex". Built as an ICU plural on a `count` placeholder (1 = singular title, 2 = plural title), with a private set of plural titles in the part. The API is unchanged. Proposed text: note the plural form in the spec's Copy paragraph.
  2. **Extra joiner keys.** The spec lists three joiners. A host list and a server name also need words, so the part adds `kitCapAnd` "{first} and {last}", `kitCapComma` "{first}, {next}", `kitCapWhyElsewhere` "{notHere}. {worksOn}.", `kitCapServerOnHost` "{server} ({host})" and `kitHostOpenCode` "computers with OpenCode" (used when both OpenCode generations can). It also uses `kitCapWorksOn` = "Works on {hosts}" rather than "Works {hosts}", because the host words are nouns ("this phone", "Codex"). None of this blocks anything.
  3. **Arabic.** The spec says copy goes in the kit ARB and has RTL and Arabic galleries. The owner decision of 2026-09-27 wins: the copy is only in `app_en.arb`, and there are no Arabic, RTL or text-2.0 shots. Galleries were rendered only at 412x915 and 1280x800.
- New kit parts (KIT-3): `KitCapabilityExplainer` (this unit's own; not exported from `kit.dart`, R06: integrator).
- Map items (EVID-11): n/a (no pages).
- States per page (STATE-20): n/a. The part's declared states are explains, offers-enable, prerequisite, offer, folded and working. Each has a test, and all but prerequisite and working also have a golden.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitCapabilityExplainer`, base `8dc27c66`, code head `80ef98b6`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new code | n/a | PASS |
| 2 | `test/kit/kit_capability_explainer_test.dart` | passes | 41 passed | PASS |
| 3 | `test/goldens/kit/kit_capability_explainer_golden_test.dart --update-goldens`, then each PNG opened | 14 shots, G5 checks pass in both themes | 14 passed; images looked at | PASS |
| 4 | `flutter analyze` on the part, both tests and `lib/l10n` | no issues | No issues found | PASS |
| 5 | Ratchet, design-standard, l10n, glossary, ledger, manifest tests | pass | not run (owner decision 2026-09-27: own test files only) | n/a |

## 5. Evidence

- Rule evidence (PROC-31), all in `test/kit/kit_capability_explainer_test.dart`:

  | Rule | Test (`--plain-name`) |
  |---|---|
  | Registry parity (spec test 1) | "every enable flow has an entry with a flow id; 21, distinct"; "every matrix capability has equal supported and partly sets" |
  | 21 enable flows (C20 acceptance) | group "the 21 enable flows": 21 tests, each taps the row's enable action and checks the `KitEnableRequest` |
  | STATE-8 / spec test 2 | "canEnable follows registerFlow; unregisteredFlows shrinks"; "without a handler, .row and .state only explain" |
  | Spec test 3, STATE-7 | "tapping enable calls the handler once, with the request"; "while the handler runs the action is working, …"; "a throwing handler does not crash; the explainer stays" |
  | STATE-12, COPY-11, COPY-30 (spec test 4) | "names the host and the hosts that can, without engine words" |
  | AUTO-20 (spec test 9) | "no kitCap/kitHost copy mentions the setup assistant (AUTO-20)" |
  | AUTO-18 (spec test 5) | "\"Not now\" calls onNotNow once; folded renders the quiet row"; "the offer runs the flow; without a handler it explains" |
  | STATE-13 (spec test 6) | "a prerequisite with no flow asserts (STATE-13)"; "a prerequisite with no handler asserts (STATE-13)"; "a prerequisite with a handler shows its button" |
  | Unknown id (spec test 7) | "an unknown capability id asserts in debug" |
  | G14x (spec test 8) | "Tab reaches the enable action and Enter runs it"; ".offer puts \"Not now\" after the enable action in Tab order" |
  | G8 (spec test 10) | "reduced motion: the fold settles after one pump" |

- Changed test expectations (TEST-19): none.
- Goldens added (each opened and looked at). They are all new, so there is no before render (EVID-10), and there is no approved VL canvas render for this part (EVID-12).

  | Golden | Shows |
  |---|---|
  | `test/goldens/kit/kit_capability_explainer_row_explains_{dark,light}.png` | "Files and Terminal": a dimmed row, "… aren't available on laptop (Codex). Works on this phone and computers with OpenCode." |
  | `…_row_enable_{dark,light}.png` | "Voice typing": the dimmed row with the trailing "Download voice model" |
  | `…_state_explains_{dark,light}.png` | "Review changes" on Paseo: the inline missing state with no action |
  | `…_state_enable_{dark,light}.png` | "Voice typing": the cost line "About 160 MB · about 2 min · …" above the primary "Download voice model" |
  | `…_offer_{dark,light}.png` | The AI Team offer sentence with "Turn on AI Team" and the "Not now" close |
  | `…_offer_folded_{dark,light}.png` | The quiet row "AI Team / AI Team is off on this server." with "Turn on AI Team" |
  | `…_default_1280x800_{dark,light}.png` | The row-enable variant, centred in the 720 dp gallery column |

- Accessibility:
  - The row's semantics come from `KitRow.unavailable`: disabled, with the reason as the hint and the enable action as its own button.
  - The offer's "Not now" is a `KitIconButton` whose tooltip is "Not now", and it follows the enable action in Tab order (tested).
  - The G5 gallery checks (labels, targets, contrast, reading order) passed for every shot in both themes.
  - 200 % text was not rendered, because the owner dropped the text-2.0 shots.
- Privacy and security: n/a. No credentials, stored data, links or notifications. Handler exceptions go to `FlutterError.reportError` with the flow and capability ids only.
- Migration: n/a (no stored format).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_capability_explainer_test.dart
$F test -j 1 test/goldens/kit/kit_capability_explainer_golden_test.dart
$F analyze lib/ui/kit/kit_capability_explainer.dart test/kit/kit_capability_explainer_test.dart test/goldens/kit/kit_capability_explainer_golden_test.dart
```

## 7. NOT proven

- The part was not run on a device or an emulator.
- No handler is registered in the app yet (coord-main), so no real enable flow was exercised.
- The shared gates were not run (owner decision 2026-09-27): ratchet, design-standard, l10n coverage, glossary, ledger and `test/kit/kit_manifest_test.dart`. The part is not exported from `kit.dart` yet, so the manifest test may flag it until the integrator adds the export.
- The following were not rendered: Arabic, RTL, text 2.0, and the sizes 360x800, 915x412, 800x1280 and 1600x1000.
- The "one offer per screen" rule (capabilities.json rule 2) is for the reviewer or G37 to check, because the part cannot see the whole screen.
- None of the new ARB keys have Arabic entries. `app_localizations_ar.dart` falls back to the English copy.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitCapabilityExplainer` |
| Enabled | No: no screen uses it yet, and no handlers are registered (coord-main, wave 2) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `80ef98b6` |
| Deployed | No | |
| Released | No | |
