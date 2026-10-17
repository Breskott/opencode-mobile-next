# Provider sign-in with a device code (OpenAI headless), 2026-10-14

Branch `fix/oauth-device-code`. Emulator `emulator-5554` only, release APK build 2301
against a real OpenCode 1.19.0 (`npx`-style install in a scratch dir, own XDG dirs,
port 4160, added in the app as `http://10.0.2.2:4160`). The PC's global `opencode`
is broken (postinstall not run), so 1.19.0 was installed with npm into a scratch folder.

## Root causes
1. OpenCode saves an "auto" sign-in (OpenAI headless, Copilot) only while a client holds
   `POST /provider/{id}/oauth/callback` open. The app only made that call when the person
   opened the row and tapped Finish, so approving in the browser alone saved nothing.
2. OpenCode 1's gateway had no sign-in recovery, so its sign-in lived only in the screen and
   was marked "source changed" when the app reconnected after the browser. The row then said
   "Sign-in waiting" for ever.
3. Nothing ended an attempt whose server memory was gone (restart) or whose code expired.

## What the person sees
1. Tap OpenAI, ChatGPT Pro/Plus (headless): the sheet shows the code large and monospaced
   with Copy (`02-sheet-code-and-copy.png`).
2. Open browser copies the code too and says "Code copied" (`03`, Android's own clipboard chip
   shows the code). The app starts holding the callback open.
3. Back in the app the row says "Waiting for approval in the browser" (`05`); its sheet has
   the code with Copy and "Open browser again" (`06`).
4. Approve: the provider is connected with no tap, "OpenAI is connected" (needs a real OpenAI
   account: NOT done here, see below).
5. If the server forgot the attempt or the code ran out: the row says "Sign-in ended" and the
   sheet offers "Start again" (`07`, `08`, `09`), which authorizes again for a new code.

## Evidence
- `04-callback-in-flight-ss.txt`: the server holds 3 app connections after Open browser (2
  before), with no Finish tap: the extra one is the callback check.
- `07`: the server was killed by its exact PID and started again; its pending attempt was gone,
  so the app's callback ended and the row shows "Sign-in ended" (not "waiting").

## Not verified here
- Approving with a real OpenAI account (the owner does that): the complete path is covered by
  `test/provider_device_code_signin_test.dart` with a fake gateway only.
- OpenCode 2: its status read answers at once, so the same wait polls it every 3 s; covered by
  the shared screen code and tests, not run against a live OpenCode 2.
