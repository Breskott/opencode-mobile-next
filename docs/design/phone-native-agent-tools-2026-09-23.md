# Phone-native tools for the agent

Status: ideas for discussion (2026-09-23). Nothing here is built yet unless it says so.

## The shift

The code was written for a terminal-first world, and so far everything flows one
way. The phone shows what the agent did: the image viewer, the terminal view, the
server controls.

The larger opportunity runs the other way: let the agent use the phone. A phone
has things a terminal never had:

- a camera
- a share sheet
- notifications
- a fingerprint reader
- a battery
- installed apps
- a person holding it

## Mechanism

The app runs a small tool server on `127.0.0.1`: a token-protected MCP server.
OpenCode and Claude Code on the phone register it like any other MCP source.

Every call that touches the phone goes through the existing approval sheet. It
stays local-only, which fits the rule that nothing goes over the open internet and
the user reaches the phone only over Tailscale.

## A. The agent uses the phone

1. **Ask for a photo.** "Photograph the whiteboard / the error on the TV." The
   user gets a camera prompt, and the image goes to the agent.
2. **A live preview the agent can see.** Dev services (a command plus a URL)
   exist, but there is no in-app browser yet. Plan:
   - an in-app preview for `localhost:3000`;
   - a `preview_screenshot` tool that returns a screenshot and the page's console
     log, so the agent checks its own UI.

   This is the largest win for web work.
3. **Install what it built.** `install_apk(path)` opens Android's install
   prompt. No more serving the APK on localhost and tapping a link.
4. **Ask from the lock screen.** `notify_user(title, body, actions)` with answer
   buttons, answered from the notification. For long jobs while the user is away.
5. **Remind itself later.** `after(20m, "check CI and report")`: the app wakes
   the conversation on a timer.
6. **Secrets without pasting.** Keys live in the Android Keystore. The agent asks
   for `GITHUB_TOKEN` and the user approves each use with a fingerprint. The key
   never lands in chat or a file.
7. **Fingerprint for dangerous actions.** Force-push, delete and deploy need a
   fingerprint, not just a tap. This is the safe partner to "approve everything".
8. **Battery-aware work.** A tool reports charging, battery level and Wi-Fi. Heavy
   builds wait for the charger, and the app can pause runs below 15%.
9. **Send heavy work to the PC.** "Run this on my PC over Tailscale" sends
   `flutter build` to the computer and returns the result.
10. **Test Android apps on the same phone** (advanced). With wireless debugging
    paired to itself, the agent gets install, logcat, screenshots and taps. The
    setup is fiddly.

## B. Better views of what the agent produces (like the image viewer)

11. **Test results as a list:** pass/fail per test, with "rerun failed" in one
    tap.
12. **Viewers for more file types:**
    - rendered HTML pages
    - CSV/Excel as tables
    - JSON as a tree
    - Mermaid diagrams drawn
    - audio playback
13. **Git at a glance:** a "what changed today" summary, then one-tap commit, push
    and open-PR.

## C. The share sheet, both ways

14. **Share anything in.** Only shared text works today. Add screenshots, files and
    URLs, and let them go into an existing conversation, not only a new one.
15. **Share out.** The agent's files (APK, PDF, report) go to the share sheet.

## First picks

- **Start with:**
  - 2 (preview the agent can see)
  - 4 (lock-screen answers)
  - 3 (install APK)
  - 14 (share anything in)

  All four fit the "away from the PC" moment.
- **Next:** 6 and 7, as one security package.
- **Open question for the owner:** is phone work mostly web apps, Android apps, or
  general coding and ops? The answer decides the order.
