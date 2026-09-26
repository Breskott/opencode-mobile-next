# P0.2 + P0.8: no dead ends before a download (2026-09-26)

## Scope

- **Programme record:** `docs/ux-system/programmes.json`, slices `P0.2` ("Claude
  Code is never a dead end") and `P0.8` ("Pre-flight before any download").
- **Branch:** `fix/p0-setup-dead-ends`, worktree `oc_app-p0-setup`, from
  `feat/phone-setup-v2`.
- **Non-goals kept:** no in-app Claude Code component (P1.6); no
  `DeviceBudget` service (P6); no voice changes.

## P0.2 — Claude Code is never a dead end

**Finish line:** the Claude Code block always offers the button that does the
missing step: phone setup when nothing is installed, "Set up with Termux"
when only the in-app Linux exists, and it never offers Refresh alone.

**What changed**
- `lib/ui/widgets/local_agent_onboarding.dart`: `_needsUbuntu` now reads a new
  `_needsTermuxOnly` flag (probed via an injectable `inAppLinuxProbe`,
  defaulting to `BuiltinLinux().status().installed`) and switches copy and
  the button label between the generic "Open phone setup" and the honest
  "Set up with Termux" / "Claude Code needs Termux for now" pair. The card's
  body and actions moved onto `KitNotice` + `KitAction` (dropped the raw
  `Text`/`OutlinedButton`/`FilledButton` pair it had).
- `lib/ui/screens/local_agent_screen.dart` (the standalone screen reached from
  the Claude Code search result, `search_index.dart:975-992`): now passes
  `onOpenPhoneSetup`, pushing `/termux-setup` — the only place Claude Code
  actually installs today. `termux_setup_screen.dart`'s own
  `LocalAgentOnboardingBlock` still passes no callback: it is the Termux
  wizard itself, so `needsUbuntu` can't be reached there (unchanged, per the
  widget's own doc comment).
- New copy: `localAgentNeedsTermuxBody`, `localAgentSetUpWithTermux` in
  `app_en.arb` and `app_ar.arb`.

**Tests + fail-before-fix evidence**
- `test/local_agent_onboarding_test.dart`, new case "needs_ubuntu with the
  in-app Linux already installed offers Termux, never Refresh alone":
  reverted the copy/label branch to always show the generic strings →
  `flutter test -j 2 --plain-name "in-app Linux already installed"` failed
  (`Expected: exactly one matching candidate ... Found 0 widgets with text
  "Claude Code needs Termux for now..."`). Restored the fix → passes.
- Full file: `flutter test -j 2 test/local_agent_onboarding_test.dart` — 19
  passed (18 existing + 1 new).

## P0.8 — Pre-flight before any download

**Finish line:** phone setup checks the CPU (arm64 or x86_64), free space
against the chosen set's installed size plus margin, and total RAM before
the button. An unsupported phone is told why before anything downloads, and
low space names how much to free and links Storage.

**What changed**
- `lib/builtin/setup/preflight.dart` (new): `checkSetupPreflight(device,
  {downloadBytes})`, checked in order — CPU ABI against the two
  `BuiltinLinux.kt` `imageForDevice()` actually ships a rootfs for
  (`arm64-v8a`, `x86_64`; anything else, e.g. `armeabi-v7a`, has none), total
  RAM against a 2048 MB floor, then free space against
  `requiredSetupFreeBytes` (2x the selection's download size, floored at
  300 MB — the same order of magnitude as `bridge.dart`'s own
  `INSTALL_REQUIRED_MB=2048` against "about 1 GB installed"). An unknown
  reading (empty ABI list, null memory/storage) never blocks.
- Reuses `lib/voice/device.dart`'s `VoiceDeviceInfo` /
  `voiceDevicePlatform.getDeviceInfo()` (the `oc/voice` channel,
  `MainActivity.kt` `voiceDeviceInfo()` at ~779-793) for ABI, RAM and free
  space — no new native method for that part.
- `lib/ui/screens/phone_setup/phone_setup_start_screen.dart`: probes the
  device alongside Termux/in-app on load; screen A's fresh state shows the
  pre-flight headline/body instead of the promise and disables the primary
  button when blocked, with a "Customize" escape hatch kept for low space
  (trimming the selection can clear it) but dropped for ABI/RAM (it can't).
  Low space adds an "Open Storage settings" tertiary action.
- `lib/ui/screens/phone_setup/phone_setup_customize_sheet.dart` (Add tools):
  the same check runs against what the current switches would install; the
  totals line becomes the pre-flight sentence, tinted for attention, and
  Done/Add is disabled — Add starts the download immediately with no further
  confirmation, so this is the real "start button" for that flow.
- `lib/ui/screens/phone_setup/phone_setup_selection.dart`: shared
  `setupPreflightHeadline`/`setupPreflightBody` text helpers.
- **Kotlin (flag for the coordinator's build — not compiled here):**
  `MainActivity.kt` gains one new `builtin_linux` channel method,
  `openStorageSettings` (tries `Settings.ACTION_INTERNAL_STORAGE_SETTINGS`,
  falls back to this app's own App Info on a ROM that hides it), plus the
  matching Dart half `BuiltinLinux.openStorageSettings()` in
  `lib/builtin/builtin_linux.dart`. Both halves added together, minimally;
  no other channel touched.
- `setup_engine.dart`'s existing `_noSpace` regex (recognising "No space" /
  `ENOSPC` after a failed install) is untouched and stays as the backstop
  for a device that changes state mid-install.
- New copy: `phoneSetupPreflightUnsupportedHeadline/Body`,
  `phoneSetupPreflightLowMemoryHeadline/Body`,
  `phoneSetupPreflightLowSpaceHeadline/Body`,
  `phoneSetupPreflightOpenStorage` in `app_en.arb` and `app_ar.arb`.

**Tests + fail-before-fix evidence**
- `test/setup_preflight_test.dart` (new, pure unit tests): thresholds for
  ABI (blocks 32-bit-only, passes `x86_64`, an empty list never blocks),
  memory (blocks under 2048 MB, exact floor passes, null never blocks),
  space (exact byte count to free, exact required space passes, null never
  blocks), and that ABI is checked before memory/space. Fail-before-fix:
  changed `requiredSetupFreeBytes` to return `downloadBytes` unmargined →
  `flutter test -j 2 test/setup_preflight_test.dart` failed 3 tests
  (`Expected: <230000000> Actual: <65000000>` for the low-space byte count,
  plus both `requiredSetupFreeBytes` tests). Restored → 13/13 pass.
- `test/phone_setup_start_screen_test.dart`: new group "P0.8 pre-flight" (4
  cases: 32-bit blocks with the primary disabled and nothing run; low space
  names the MB and shows the Storage action; low memory blocks; a clean
  device keeps the plain promise) and "P0.8 pre-flight in Add tools" (3
  cases against `SetupCustomizeSheet` directly, since
  `showPhoneSetupCustomize` has no override point: 32-bit, low space with
  the Storage action, and a clean device). Also added a
  "small screens and big text" case rendering the 32-bit and low-space
  states at 320 dp / 2.5x (this repo's convention for screen-state
  coverage; there is no `matchesGoldenFile` pixel golden for this screen —
  `test/design_standard_test.dart`'s "each migrated screen has dark and
  light goldens" only checks the existing `setup_start_*`/`setup_customize`
  PNGs exist, and I did not add a new named state there).
  A global `setUp` now mocks the `oc/voice` channel for the whole file
  (`{}` → `VoiceDeviceInfo` with nulls/empty ABI, which never blocks): the
  real `PhoneSetupStartScreen()` default `deviceProbe` reaches this channel
  for the tests that push it via its actual route (`openPhoneSetupStart`),
  and without a mock handler that left a pending 5 s timeout `Timer` past
  teardown, failing 8 previously-green tests the first time this was wired.
  Full file: `flutter test -j 2 test/phone_setup_start_screen_test.dart` —
  49 passed.
- `flutter test -j 2 test/design_standard_test.dart` — 7 passed (no raw
  Material widgets added to either migrated screen file; the new "Open
  Storage settings" control is `KitButton`, the sheet's totals stayed a
  `Text` it already owned).
- `flutter analyze` — clean, both after the P0.2 commit and after the P0.8
  commit (verified independently; the P0.8 arb/generated-l10n additions
  were held back with `git stash` while P0.2 was checked and committed on
  its own, then restored and regenerated for P0.8's commit).

## Kit compliance (owner rule, 2026-09-26)

No new raw `Text`/`Icon`/button/`ListTile`/`Card`/`Container`/`InkWell` was
added. `local_agent_onboarding.dart`'s `_needsUbuntu` moved its existing raw
button pair onto `KitNotice`/`KitAction`. `phone_setup_start_screen.dart`'s
new tertiary action is a `KitAction`; `phone_setup_customize_sheet.dart`'s
new "Open Storage settings" is a `KitButton(role: secondary)`. No kit-gap.

## Devices

None. Everything above is unit/widget tests and static checks; no emulator
or physical phone was used in this worktree.

## Emulator proof: pending coordinator

Both slices' `proof` fields ask for an on-device recording. Suggested
script, in order:

1. **P0.2, Claude Code needs Termux:** on an emulator with the in-app Linux
   already set up (finish "On this phone" once) and Termux never installed,
   open search → "Claude Code" → the block reads "Claude Code needs Termux
   for now…" and offers "Set up with Termux" → tapping it opens
   `TermuxSetupScreen` (`/termux-setup`). Record the search → block → tap →
   wizard sequence.
2. **P0.2, nothing installed:** factory-reset the app's data (or a fresh
   emulator), open search → "Claude Code" → the block reads the "finish
   setup" copy and offers "Open phone setup" → tapping it also opens
   `/termux-setup`.
3. **P0.8, 32-bit:** an x86 (not x86_64) emulator image, or override
   `Build.SUPPORTED_ABIS` via a debug hook, should make screen A show "This
   phone can't run it" with the primary button disabled before any network
   call. (No 32-bit-only emulator image was available in this worktree to
   confirm live; the unit and widget tests above substitute an injected
   `VoiceDeviceInfo`.)
4. **P0.8, low space:** shrink the emulator's userdata partition (e.g. `avd
   config.ini` `disk.dataPartition.size`, or `adb shell` fill the data
   partition with a dummy file under `/data/local/tmp` close to full) so
   `StatFs` on `filesDir` reports under ~330 MB free, then open phone
   setup's screen A: it should read "Not enough free space", name the exact
   MB, disable Set up, and show "Open Storage settings" which opens Android
   Settings (falling back to this app's App Info if the OEM hides the
   direct one). Repeat from "Add tools" for the Customize sheet's Done/Add.
5. Record each with a screenshot into this folder
   (`docs/qa/p0-setup-dead-ends-2026-09-26/`) once run.

## Kotlin flagged for the coordinator's build

`android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/MainActivity.kt`:
one new `when` branch (`"openStorageSettings"`) and one new private method
(`openStorageSettingsIntent`) on the existing `builtin_linux` channel, plus
one new import (`android.content.ActivityNotFoundException`). Not compiled
in this environment (no Gradle/emulator here per the rules); needs a real
`flutter build apk --release` (or a debug run against the pinned
Shorebird engine) to prove it compiles and that the Settings intent
actually resolves on a real device.
