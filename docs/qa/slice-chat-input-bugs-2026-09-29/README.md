# Chat input bugs (build 2064 journey J3) plus model-picker sign-in shortcuts

Evidence for slice `revamp/slice-chat-input-bugs`. Tests are widget tests at 412x915; nothing here was run on a device.

## 1. Model picker search hid its results under the keyboard (P1-3)
Cause: the sheet is a fixed-height frame that shrinks by the keyboard inset. The header, notices, search row and collections took the top of a short scrolling body, and the pinned Thinking/Agent footer plus the Apply button took the bottom. The results started below the fold. Nothing scrolled them into view.
Fix (`lib/ui/widgets/pickers.dart`): while the keyboard is up (a) the search row is scrolled to the top of the body on keyboard change and on every query change, and (b) the Thinking/Agent footer waits until the keyboard closes.
Test: `test/picker_search_keyboard_test.dart` (fails before, passes after).
Images: `picker-search-before.png`, `picker-search-after.png` (the empty band at the bottom is where the keyboard sits).

## 2. First Send press only hid the keyboard (P1-5)
Cause: Flutter's default "tap outside the text field" action unfocuses the field on pointer-down for mouse, stylus and unknown pointer kinds, on every platform (touch only on web). Send was outside the field, so the press dropped focus, the keyboard hid, the composer slid down, and the release landed on nothing. The second press worked because the keyboard was already gone. It reproduces with a mouse-kind press; a plain touch press in a widget test does not lose focus, so a finger on a real phone may not hit it.
Fix (`lib/ui/kit/chat/kit_composer.dart`): the whole composer pill is a `TextFieldTapRegion`, so its own controls count as inside the field.
Test: `test/chat_input_bugs_test.dart`, "the first mouse press on Send keeps the field focused and sends once" (fails before, passes after; the touch twin passed before too).

## 3. Touch targets
Send, Mic and Stop already had 48 dp hit areas in the kit (a 40 dp circle inside a 48 dp `SizedBox`), and the code-block Copy and Wrap buttons are 48x48. The 40x30 and 48x30 readings in the critique are the visible circle or a clipped, partly scrolled node in uiautomator. No size change was needed. `test/chat_input_bugs_test.dart` now pins 48 dp for Send, Mic, Copy and Wrap.

## 4. Sign-in shortcuts in the model picker (from the stopped `revamp/slice-picker-signin`)
Its work was sound and is brought in as it was: a "Connect a provider" row ending the list, per-provider "Add an API key for X" / "Sign in to X" rows, a free-model-only note with "Add an API key" and "Connect a provider", and a return to the picker with the new provider's models. Tests: `test/picker_signin_test.dart`. Images: `picker_signin_phone_dark.png`, `picker_signin_wide_light.png`; the changed model-sheet goldens in `test/revamp/goldens/` were regenerated and looked at.

## Checks
Analyze of the whole project is clean. New tests, `model_picker_test`, `kit_composer_test`, `kit_ratchet_test`, `composer_layout_test`, `composer_desktop_enter_test`, `provider_reload_running_reply_test`, `slice_p3_3_model_sheet_test` and the kit composer golden pass. `shared_chat_1_golden_test` "continue on phone" (4 cases) fails the same way on the base commit and is untouched.
Still needs a device: the first-Send fix with a real finger and a mouse, and the search with a real keyboard.
