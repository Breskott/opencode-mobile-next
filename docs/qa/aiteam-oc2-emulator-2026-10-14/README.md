# AI Team on OpenCode 2, emulator proof (APK 2315), 2026-10-14

Tester: Claude, emulator-5554 only (Pixel, 1080x2400). APK build 2315 installed with `-r` over the existing state. Wall time about 65 min (20:28 to 21:08). No model key was needed or used; the free model (Cat Jam Free) answered. No app code was touched.

**Result: BLOCKED at step 3. AI Team cannot be turned on while the phone server is OpenCode 2 (2.0.29). The safety check passes, then OpenCode 2 will not start again in protected mode. Steps 4 and 5 were not reachable.**

| Step | Result | Time | Image |
|---|---|---|---|
| 0. Start state | App opened on OpenCode 1 (1.19.0), Connected | | s01.png |
| 0b. "Switch to OpenCode 2" | First attempt FAILED at "Start OpenCode" (Details: `A component update could not be restored. Run setup again.`). "Continue setup" then worked. Steps 1 to 4 took about 45 s | 20:29 to 20:30 | s06.png, s08.png |
| 1. This phone OpenCode 2 2.0.29 Connected | PASS (after the retry above) | | server sheet text: "Connected · OpenCode 2.0.29 · Running" |
| 2. Plain chat "Say hello" | PASS. Answer "Hello! How can I help you today?" about 5 s after send (free model; first words 1.2 s in Reply speed) | 20:34 | s12.png |
| 3. Turn on AI Team | FAIL, reproduced 2 times. Door: Settings has no AI Team row; found through search "AI Team" > "In Agents". Flow: "Stop OpenCode briefly?" > Stop and continue > reply wait 0 s, stop 6 to 10 s, safety check passes in 5 to 6 s, then "Start OpenCode again, protected" fails: headline "The server didn't return", Details "OpenCode did not answer after it was started again. refused". "Start again" fails the same way | 20:43 to 20:45; 21:05 to 21:07 | s26.png, s27.png, s44.png |
| 3b. Restart afterwards | plain Restart and "Start the server" also fail until the app is force-stopped and reopened; then "Start and connect" works and OC2 is Connected again | | s36.png, s41.png |
| 4. Small task (README line) | NOT RUN, blocked by step 3 | | |
| 5. Needs-you answer | NOT RUN | | |

## Bugs

**P0-1 Turn-on of AI Team on OpenCode 2 ends with OpenCode 2 not running.** Steps: This phone on OC2 2.0.29, Settings search "AI Team", Turn on AI Team on this phone, Stop and continue. Expected: protected restart, team ready. Actual: step 4 fails ("refused"), OpenCode stays stopped. Server details (This phone > Details): `The phone server could not start (... IllegalStateException: A component update could not be restored. Run setup again ...; cause IllegalStateException: ownershipUnknown)`. The same exception text appeared on the very first OC2 switch (step 0b), so a component ownership record is in an unknown state on this emulator and the start path refuses to run. Screenshots s26, s27, s36.

**P0-2 "Add tools" (Python + AI Team) on an OpenCode 2 phone silently reinstalls OpenCode 1.** I ran Add tools > AI Team while OC2 2.0.29 was active (about 20:35 to 20:41): the progress list said "Step 4 of 6 OpenCode Done 1.19.0" and the phone ended up as OpenCode 1 1.19.0, Python missing from the Installed line. I had to "Switch to OpenCode 2" again (about 30 s) to get back. Screenshots: s17.png (OpenCode 1 1.19.0 after Add tools), s19.png (back on OC2). Expected: components are added without changing the OpenCode flavor.

**P1 After a failed turn-on the Installed line loses Python and AI Team.** Before: "Linux base, Git and SSH, Python, Node.js, OpenCode and AI Team". After the failed turn-on: "Linux base, Git and SSH, Node.js and OpenCode". The AI Team page still says "Installed on this phone", then later "AI Team is off. It needs a quick safety check".

**P1 Recovery is not offered.** The banner "OpenCode on this phone isn't answering" Restart and the "Start the server" button both fail with no way forward; only a force-stop of the app then "Start and connect" recovers. The failure copy says "Start again" which cannot work. The Details text is a raw exception (`ownershipUnknown`, obfuscated stack frames), against the no-raw-errors rule.

**P2 Discoverability.** Settings has no AI Team row on this build (AI group shows Model, Providers, Usage, Tools, Agents); the page is only reachable by search ("In Agents") or the Agents page.

**P2 First OC2 switch failed once** with the same restore text; the retry succeeded (see P0-1; likely the same cause).

**P2 Two profiles** "In-app Ubuntu · OpenCode 1 (Not connected)" and "· OpenCode 2" both exist after switching, listed under Settings.

## Not tested
Model GLM (no key was needed to reach the block), plan, lanes, findings, merge, needs-you, Inbox. Timebox used on the block and recovery attempts; no logcat evidence of a SIGSYS or crash (no sandbox death seen), the failure is in the app's component ownership check.

`ui.sh` is the dump/tap/screenshot helper (copied from the oc2-switch-keeps-chats record, regex made tolerant).

## Follow-up diagnosis and local fixes

See [root-cause.md](root-cause.md) for the exact APK mapping, allowlisted syscall
evidence, fixes, JVM results and Flutter rerun list. Restart on the unchanged
APK 2315 was reproduced during diagnosis:
[diagnosis-2315-restart.png](diagnosis-2315-restart.png). Its tracked peer lookup
returned `ENOENT`. This was initially interpreted as exit; the APK 2316
follow-up below proves that a live hidden daemon produces the same result.
Add tools also omitted the current runtime parameter and fell back to OC1.

The local source corrections and ownership-recovery actions require a rebuilt
APK. **This record still does not qualify AI Team execution on the fixed APK**;
steps 4 and 5 above remain outstanding. No app data was cleared or uninstalled
during the follow-up.

## APK 2316 protected-start follow-up

[Root cause 2](root-cause-2.md) corrects the earlier exit inference: Android
hid the still-live engine process from its parent. It records the authenticated
identity fix and the separate shared-starter bug behind the banner action.
Fixed-APK qualification remains pending.

## APK 2317 planner follow-up

[Run 3](run3-2317.md) confirms protected turn-on works. [Root cause 3](root-cause-3.md)
records why planning then failed: the blank planner role inherited Cat Jam Free,
which returned provider-auth HTTP 403, while chat used the app's Z.ai selection.
An explicit Z.ai planner role and retry completed one phase/one task on APK 2317.
The plan remains unapproved; worker/checker models still need configuration.
The follow-up source change preserves a safe model recovery reason and requires
new native binaries for device qualification. It also specifies the missing
Team model UI contract.

## APK 2318 checker follow-up

[Run 4](run4-2318.md) proves one project completed plan → worker → checker →
dev merge on OC2. [Root cause 4](root-cause-4.md) explains the second project's
interruption: the checker succeeded, but its prose followed by unfenced JSON
failed the engine's strict parser. The OC2-only compatibility fix retains
strict verdict/commit validation. The record defines `resumeTask` to inspect
the original completed checker without another model call and explains why
current presentation hides that action. The emulator checkpoint was left
unchanged for rebuilt-APK recovery verification.
