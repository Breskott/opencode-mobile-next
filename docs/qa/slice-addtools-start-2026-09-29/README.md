# Add tools: "Start OpenCode" fails after the app has run a while (P1) - 2026-09-29

## Root causes
1. **Widget ref captured by an app-wide closure.** `_RootState._attachPhoneSetup`
   (`lib/main.dart`) gave the app-wide setup engine (`PhoneSetup`, a static) a
   finisher that called `ref.read(bootstrapProvider)` on the shell widget's own
   `ConsumerState` ref, at the moment the last step ("Start OpenCode") ran. The
   shell (`_Root`) is replaced as soon as the person opens a conversation, so
   any Add tools job started later hit "Bad state: Using ref when a widget is
   unmounted" and failed at the start step. It worked after a force-stop only
   because the shell had not been replaced yet. Fix: read the store once in
   `initState`-time code and let the closures capture the object, not the ref.
2. **"Continue setup" did nothing** was the same bug: Continue re-ran the same
   job, the same stale closure ran the finisher, and it failed the same way
   at once. With (1) fixed it resumes and ends done (test below).
3. **Stale state.** This phone and Settings > AI Team each read the phone once
   when they opened, and neither noticed a setup job ending; the AI Team intro
   also always priced a 125 MB download and offered "Set up", even for a phone
   that already had the programs. Now `setupToolsChanged` (bumped by the engine
   when any job ends, however it ends; not a listener, so it does not keep the
   engine polling) makes both pages read the phone again, and the AI Team page
   reads the same check (`installedOptional`) as This phone and Add tools:
   installed-not-on shows "Installed on this phone" with "Turn on AI Team on this
   phone" and no download or cost; not installed keeps the download and
   "Set up AI Team on this phone"; on shows the team.
4. **Raw text:** the failed start row's body was already plain ("Stopped during:
   Starting OpenCode. What went wrong is under Details."); the Dart text is
   only in Details and goes through `KitRedact` (unchanged, still true).

## Tests (fail first)
- `test/builtin/setup_finisher_lifetime_test.dart`: finisher after the shell was replaced (failed with the exact "Using ref" StateError; passes).
- `test/builtin/tools_agree_after_setup_test.dart`: This phone and Settings > AI Team re-read when a job ends (both failed before).
- `test/team_discover_test.dart` "installed but not on": intro shows no download and Turn on (failed before).
- `test/builtin/add_tools_run_test.dart`: Continue after a broken start step ends done with the adding list kept (passes without the fix at engine level; the failure it guards was the finisher closure, covered above); job end signal fires once.
- Gates: kit_ratchet, redaction, ui_glossary, no_raw_error_text, golden_harness, l10n_coverage, architecture_boundaries pass; `flutter analyze` clean.
- `test/goldens/team_discover_golden_test.dart` "work · AI Team off · light" fails identically on the base commit (0.05% pixels), not from this change.

## Device proof (emulator-5554 only, Pixel_6, release build 2066, dark theme)
Fresh install, set up OpenCode on this phone (built with this branch minus the
final one-string title shortening), opened a conversation (replaces the shell),
used Settings and Work for about 3 minutes, then:
- `01`-`03` Settings AI Team Off; This phone; Add tools sheet.
- `04` "Adding AI Team" and `05` finished on the FIRST attempt (Installed now lists AI Team without reopening the page).
- `06` BEFORE the intro fix (same build, first): AI Team page still says "About 125 MB to download / Set up" though installed. `07` after: "Installed on this phone", "Turn on AI Team on this phone", no download.
- `08` AI Team is running on this phone (turn on took about 6 minutes); `09` Settings row "On - This phone".
- `10`/`11` Voice typing added on the first attempt: "Start OpenCode" step done, ends "Installed: ... AI Team and Voice typing".
Only my emulator was touched; emulator PID killed via its own script.
