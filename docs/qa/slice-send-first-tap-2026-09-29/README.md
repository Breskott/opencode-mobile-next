# First Send tap (P1, journeys 2064/2065 J3): not reproducible with a real touch

Result: no code change. One touch tap on Send sends with the keyboard up. I could not find a touch path that loses the first tap.

## Device proof (emulator-5554 only, Pixel_6, Android 14, build 2065)
- Host: pinned OpenCode 1.18.32 x64-baseline (sha256 verified) on 127.0.0.1:4123, adb reverse; the app was already connected.
- Method: tap the field (keyboard up), `input text proofN`, screenshot, ONE `adb shell input tap` (a touch) on Send, screenshot. 5 of 5 sent on the first tap (`tap1-before.png` .. `tap5-after.png`, all in `contact.png`: before on the left, after on the right).
- Extra runs: a fresh conversation (first message), a 150 ms press held with `input swipe`, and Send tapped after the keyboard was hidden with Back (focus kept): each sent on the first tap.
- Build 2066 was not rebuilt: `lib/` is unchanged since the 2065 build (only docs and a test were added), so the 2065 APK is the same code.

## Why the reported symptom is unlikely to be the app
- Flutter's default tap-outside action never drops focus for a touch on Android (the earlier mouse-kind fix covers mouse and stylus). Nothing in the chat page, kit screen or composer unfocuses on pointer-down (`onTapOutside`, `FocusScope.unfocus`, and drag-dismiss are absent from that path).
- Send's `onTap` is not gated on focus. KitTappable fires on tap-up.
- Even if the keyboard collapsed between press and release, a Flutter tap follows the pointer routed at press time, so the release still sends. New test proves it.
- In the 2065 walk, `J3-09-typed` already shows the keyboard hidden before the tap, and `J3-10` is identical to it: the tap coordinates were most likely taken from the keyboard-up layout and landed on empty space after the composer moved down. A walk that types with `adb input text` and taps too soon (before the keyboard finishes rising) misses the same way; I hit that myself once (`rep1` stayed in the field).

## Tests
`test/chat_input_bugs_test.dart`: new "a touch tap on Send still sends when the keyboard collapses between press and release" (passes; it cannot fail first because the app has no such bug). With `kit_ratchet_test`: 43 pass.

## Still needs
The owner's phone with a real Gboard, if it still happens: note the state just before the tap (keyboard up or hidden) and the text length.
