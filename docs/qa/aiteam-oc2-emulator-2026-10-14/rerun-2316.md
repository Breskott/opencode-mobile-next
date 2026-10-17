# AI Team on OpenCode 2, emulator re-run (APK 2316), 2026-10-15

Tester: Claude, emulator-5554 only. APK build 2316 installed with `-r` over the existing state (no data cleared). No key was needed (free model Cat Jam Free answered). No app code touched, nothing committed.

**Result: STILL BLOCKED at step 3.** The ownership race fix removed the `ownershipUnknown` text, and the new recovery copy and "Open app settings" button work, but turning on AI Team on OpenCode 2 still ends with OpenCode not running. Steps 4 and 5 not reachable.

| Step | Result | Time | Image |
|---|---|---|---|
| 0. Install 2316, open | Opens on "OpenCode inside the app is stopped" (expected after update). "Start and connect" worked first try, about 25 s, no "component update could not be restored" error (the first-run P0 on the switch did not recur) | 01:35 | r2-01.png, r2-02.png |
| 1. This phone OC2 2.0.29 Connected | PASS. Server sheet: "In-app Ubuntu - OpenCode 2, Connected, OpenCode 2.0.29, Running" | | r2-03.png |
| 2. Plain chat "Say hello" | PASS. Answer "Hello! (wave) How can I help you today?" within about 15 s | 01:37 | r2-05.png (empty new chat), r2-06.png |
| 3. Turn on AI Team | FAIL, reproduced 2 times (01:38:44, 01:42:38). Path: Settings > Agents > AI Team > "Turn on AI Team on this phone" > "Stop OpenCode briefly?" > Stop and continue. Steps 1-3 Done (0 s, 9 s then 3 s, 5 s). Step 4 "Start OpenCode again, protected" FAILED. Headline "The server didn't return", body "The server on this phone couldn't restart safely. In app settings, tap Force stop, then reopen the app; your conversations stay." Button "Open app settings". Details text: "OpenCode did not answer after it was started again." plus code `componentRecovery` | | r2-10.png, r2-11.png, r2-12.png |
| 3b. Recovery path | "Open app settings" opens the correct package (OpenCode Mobile, r2-13.png). After Force stop and reopen, app shows OC2 stopped; "Start and connect" reconnects OC2 (Connected). So recovery is real and keeps chats. But retry of turn-on fails identically | | r2-13.png, r2-14.png, r2-15.png, r2-16.png |
| 4. Small task | NOT RUN | | |
| 5. Needs-you | NOT RUN | | |

## Findings

**P0 (unchanged outcome, changed cause) Turn-on of AI Team on OC2 still leaves OpenCode not running.** Failure is now classified `componentRecovery`, not `ownershipUnknown`/"refused", so the confirmed-exit race fix did change the failure, and the Details no longer show a raw stack. Cause of the start failure after the safety check is not visible from the UI or logcat (only OCTRACE `linux.bindServerRecovery`/`serverRecoveryReceipts` polling lines). Needs native-side investigation: why the protected start after a passing safety check is treated as component recovery.

**P1 Copy mismatch.** The failure tells the user to Force stop, but the cause in Details is "did not answer after it was started again". Force stop does not cure it (the second turn-on failed the same way after Force stop). The copy promises a fix that does not work for this cause.

**P1 Banner stays.** "OpenCode on this phone isn't answering / Restart" banner remains across Settings pages after the failure (still showing on Appearance).

**Not re-verified:** Add tools on OC2 keeping OC2 (P0-2), Installed line losing Python/AI Team, Settings discoverability (Settings still has no AI Team row; reached via Agents page), two profiles (Settings still lists "OpenCode 1 Not connected" and "OpenCode 2").

## UI notes (one screenshot each)

- **Chat header (r2-06.png):** title "Greeting" now sits on the first line and the project/server chip "my-app - In-app Ubuntu - OpenCode 2 v" sits below, indented a little right of the title and the back arrow, so the two lines do not align. The context-usage ring (seen in the old s12) is gone from the header. Nothing broken, but the chip is slightly offset and the title is tight to the status bar.
- **Live background (r2-05.png, r2-06.png):** very faint drifting glow, visible but low contrast. In r2-06 there is a hard horizontal edge at the top of the "Asks first / model" row where the glow stops and a flat dark strip begins, so the background looks cut off above the composer.
- **Appearance (r2-17.png):** Display card (Light or dark, Text size) looks fine. The Effects card shows a large green icon in an otherwise empty card with the Motion row cut off below; the Look setting "Aurora drift" (present in the accessibility tree) is not visible as a normal row in the screenshot, so the Look picker looks missing or unrendered at this scroll position.

## State left

Emulator app: OpenCode 2 stopped/"isn't answering" after the last failed turn-on (recover with Force stop, reopen, Start and connect). Physical phone untouched.
