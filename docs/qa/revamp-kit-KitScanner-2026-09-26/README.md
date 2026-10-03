# revamp-kit-KitScanner: Build KitScanner (2026-09-26)

Second round. The first round (2026-09-26) stopped because kit-KitSince had not been merged yet (`dependency-check.txt`). KitSince is now on `feat/phone-setup-v2`, and this round builds the part and moves the pairing scanner's camera preview onto it.

## 1. Scope

- **Unit:** `kit-KitScanner` (wave 1, tier 1b, kit part).
- **Finish line:** `KitScanner` is built to its frozen API, with the states starting, slow, scanning, rejected and paused, its behaviour tests and its gallery. `pairing_scanner_screen.dart` shows its scanning state through `KitScanner`.
- **Non-goals:**
  - No new scanner behaviour (P9.9).
  - No permission, recovery or parsing logic in the part.
  - No `kit.dart` export. The integrator adds it (R06).
- **Files changed:**
  - `lib/ui/kit/kit_scanner.dart` (new).
  - `lib/ui/screens/pairing_scanner_screen.dart`.
  - `lib/l10n/app_en.arb`, plus the `gen-l10n` output (`app_localizations*.dart`).
  - `test/kit/kit_scanner_test.dart` (new).
  - `test/goldens/kit/kit_scanner_golden_test.dart` and 13 PNGs (new).
- **Pages (map ids):**
  - `pairing-scanner`: the element `pairing-scanner-camera` moves into the kit.
  - The recovery states and the top bar were already on `KitStateView`, `KitScreen` and `KitTopBar` (screen-servers-2).
- **Specs followed:**
  - `docs/ux-system/kit-api/KitScanner.md` (frozen).
  - kit-v2 §5, §9.2 and §8.2.
  - Rules KIT-1, KIT-3, KIT-9, KIT-12, STATE-5, STATE-9, LOOK-4, LOOK-5, LOOK-6, LAY-3, LAY-9, A11Y-1, A11Y-3, SEC-2, SEC-5 and MOT-11.
  - Owner decisions of 2026-09-27: Arabic is dropped; galleries only at 412×915 and 1280×800; speed over test breadth.
- **Contract problems (PROC-20):**
  1. **Gallery names.**
     - Spec: the Galleries section names shots `kit_scanner_<state>` with the states starting, slow, scanning, rejected and paused.
     - Gate: the kit manifest (G4, `test/kit/kit_manifest_test.dart`) requires the KIT-12 `States:` line to use only {loading, empty, error, disabled, working, answered}. It also requires 412×915 goldens whose names start with `kit_scanner_<that state>`. The spec's own KIT-12 line ("loading (starting, slow), error (…), paused") does not parse.
     - What I did: the doc line reads `States: loading, error.`, and a following sentence names the sub-states.
     - Resulting shots:
       - starting → `kit_scanner_loading`;
       - slow → `kit_scanner_loading_slow`;
       - rejected → `kit_scanner_error`;
       - scanning and paused keep their names.
     - Proposed text: the Galleries section should use these names.
     - Blocks: nothing.
  2. **The rejected line's tone.**
     - Spec: "neutral tone, `AppIconography.error` glyph in `text1`".
     - Problem: `KitNotice` (v1) paints the neutral tone's glyph in `text2`, and has no colour parameter.
     - What I did: used `tone: AppStatusTone.failure` with the error glyph. That tone's tint is `text1`, never `danger` or `attention` (LOOK-4, LOOK-5), so the painted colours are exactly what the spec asks for. Test 8 scans the pixels to check it.
     - Proposed text: "the failure tone of KitNotice (`text1` glyph)".
  3. **Gallery host.** `KitScanner` paints only its frame. KitPageRoute is opaque, and with no host the text would render over black. The gallery therefore shows the part inside `KitScreen` and `KitTopBar`, as the real screen does.
  4. **The spec's "No edits to `pairing_scanner_screen.dart`".** The unit task (later, coordinator) explicitly asks for the swap, so the later instruction wins (R15).
- **New kit parts (KIT-3):** none beyond this unit's own `KitScanner`, `KitScannerCamera` and `KitScannerFailure`.
- **Map items (EVID-11):** `pairing-scanner#pairing-scanner-camera` → done: `test/kit/kit_scanner_test.dart` "pairing scanner screen …" and the `kit_scanner_*` goldens.
- **What I moved or removed (owner rule: rethink, not restyle):**
  - The screen's own `_handled` latch, `MobileScannerController`, `_onDetect` and its `dispose` moved into the kit part (KitScanner.md "Handled once").
  - The screen's second "Opening the camera…" fallback inside `_preview` is gone. The part has its own starting state.
  - The rejected line's glyph changed from `warning` to `error`, in `text1` (LOOK-4: amber and warning mean "needs you").
  - No stray actions were found on the page. "Paste it instead" names what it does and stays the one way out (`onSlow`, and on the recovery states).
- **States per page (STATE-20):**
  - Part:
    - loading (starting, slow): tests 5 and 8, goldens `kit_scanner_loading*`;
    - scanning: tests 1 and 8, goldens `kit_scanner_scanning*`;
    - error (rejected): tests 2 and 3, golden `kit_scanner_error*`;
    - paused: test 6, golden `kit_scanner_paused*`;
    - failure (reported to the host): test 4.
  - `pairing-scanner` scanning state: test "scanning is KitScanner under the kept keys…".
  - `pairing-scanner` camera failure: test "a camera that will not open…".
- **Deferred states (STATE-21):** none.

## 2. Builds

- Branch `revamp/kit-KitScanner`, base `646990ad` (`feat/phone-setup-v2`), code head `57e1e58c`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof (a real camera) is coordinator work (R19, R20).

## 4. Runs

All with the pinned Flutter, through `tool/qa/machine_lock.sh`, one file at a time.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_scanner_test.dart` (9 contracts + 2 screen tests) | passes | 11 passed | PASS |
| 2 | `test/goldens/kit/kit_scanner_golden_test.dart` (13 shots, G5 in both themes) | passes | 13 passed | PASS |
| 3 | `test/kit/kit_manifest_test.dart`, KitScanner lines | only integrator rows left | `exported` and `docRow` (the `kit.dart` row, R06) | PASS (expected) |
| 4 | `flutter analyze` on the 4 changed Dart files | no issues | no issues | PASS |
| 5 | `gen-l10n` | generates | generated; the ar class falls back to English for the 4 new keys | PASS |

## 5. Evidence

- **Rule evidence (PROC-31)**, all tests in `test/kit/kit_scanner_test.dart`:

  | Rule | Test |
  |---|---|
  | "Handled once" | "1. accepts once" |
  | A11Y-3 | "2. rejects, keeps scanning, and announces a message once" |
  | SEC-2 | "3. never keeps the value" (the rendered tree, the semantics tree and `debugPrint` during `debugDumpApp`) |
  | STATE-9 (honest failure) | "4. a camera that fails…" |
  | STATE-5 | "5. slow…" (7 s: nothing; 8 s: the words and the action; three actions assert) |
  | Lifecycle | "6. pauses in the background…" |
  | LAY-3 | "7. a short window…" |
  | LOOK-4, LOOK-5, LOOK-6 | "8. colours" (a pixel scan of starting, slow, scanning and rejected, dark and light) |
  | G6, G8 | "9. no overflow… settles after one pump" (320, 412 and 915×412 at text 1.0, 1.3 and 2.0) |

- **Changed test expectations (TEST-19):** none. No existing test was edited.
- **Goldens added.** Each was opened and looked at:
  - 412×915, dark and light: `kit_scanner_loading`, `kit_scanner_loading_slow`, `kit_scanner_scanning`, `kit_scanner_error` and `kit_scanner_paused`;
  - `kit_scanner_scanning_1280x800` in dark and light;
  - `kit_scanner_error_text2_dark`.

  That is 13 PNGs, about 300 KB.
- **Before and after:** there is no before render. The census never rendered the scanning state, which needs a camera. After: `after-kit-scanner-scanning.png`, `after-kit-scanner-rejected.png` and `after-kit-scanner-slow.png`.
- **Accessibility:**
  - The preview is one image node, "Camera view", with the instruction as its hint.
  - The rejected line is a live region. Setting the same words again keeps the same node, so they are not announced twice.
  - The starting and slow line is one live region around the progress bar.
  - The `onSlow` actions are tertiary `KitButton`s.
  - At 2.0 text the text block scrolls instead of shrinking the window below 160 dp.
  - G5 (tap targets, labels, contrast and reading order) passed on every shot in both themes.
- **Privacy and security:**
  - The decoded value goes from the camera stream to `onCode` only. It is never kept in state, rendered, put into semantics or logged (test 3).
  - The camera stops on accept (before the host pops), on inactive, hidden or paused, and on dispose.
  - `KitScannerFailure.deviceMessage` comes from the camera's start error only.
- **Migration:** n/a. No stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_scanner_test.dart
$F test -j 1 test/goldens/kit/kit_scanner_golden_test.dart
$F analyze lib/ui/kit/kit_scanner.dart lib/ui/screens/pairing_scanner_screen.dart test/kit/kit_scanner_test.dart test/goldens/kit/kit_scanner_golden_test.dart
```

## 7. NOT proven

- The part has not run on a device or emulator. `_MobileScannerCamera` (the real mobile_scanner adapter: start, stop, dispose, the `codes` mapping and the preview) is not exercised by any test. Every test uses the fake camera.
- That the part disposes a camera it created itself is not tested. The fake can only be passed in, so only "a passed camera is stopped, not disposed" is proven.
- Screen-reader announcements are proven only through the semantics flags and node identity, not with TalkBack.
- Shared gates were not run (owner decision 2026-09-27): the ratchet, design-standard, l10n coverage, the census and the full suite. The pairing screen now builds only kit parts and `ValueKey`s, so its G16 counts should drop, but the ratchet was not run. `kit_manifest_test` still fails on the `kit.dart` export and doc row, which the integrator adds.
- The UI ledger's `pairing-scanner-detect` effect text (`docs/design/ui-ledger/parts/g-servers.json:1249`) still says `MobileScanner.onDetect -> _onDetect`. It is outside this unit's write set and left for the integrator.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitScanner` |
| Enabled | Yes, on the pairing scanner screen (Android, once camera permission is granted) | `lib/ui/screens/pairing_scanner_screen.dart` |
| Verified | Tests and goldens only; no device | this record |
| Committed | Yes | `57e1e58c` + this record |
| Deployed | No | |
| Released | No | |
