# Daily-flow repair acceptance

Baseline: local checkpoint724a8bd. Maintainer reported duplicate Chat Stop controls, missing background/task handoffs, hidden Termux and project changes after restart.

Finish line: one correctly scoped foreground Stop; discoverable supported background work with server-owned automatic child-result delivery into the parent; direct Android Termux access; selected project survives restart and incomplete catalogs. Non-goal: another visual-system redesign, a new remote execution service, or claiming exhaustive polish.

The previous page captures and passing source tests did not establish these daily flows. This batch requires behavior regressions plus integrated Android interaction evidence where available. UI state must remain truthful: idle is not completed, a204 is only an acknowledged background request, and an incomplete project catalog is not proof of deletion.

## Ownership

- Chat plus its part library/task widgets: `fix/chat-task-controls`.
- Project selection/controller/preferences: `fix/project-restart-state`.
- Android Termux entry journey: `fix/phone-termux-discovery`.
- Native OpenCode 2 subagent contract/cards: `fix/v2-subagent-contract`.
- Integration and final local build/device checks: `fix/daily-flow-integration`.

All checks are local and serialized. No CI. Each worker's focused evidence lives in its adjacent QA directory; final integration results will be appended here. Synthetic fixtures do not call providers and must be labelled as fixtures.

## Gate plan

1. Red→green project restore regression; selection-save failure, profile switch/deletion and controller isolation checks.
2. Chat checks for one Stop, pending abort, eligibility/no-op backgrounding, persistent child tasks, scoped navigation and live canonical-history refresh after server inbox delivery.
3. Android-only Termux discovery with a saved remote profile; unsupported/missing/install/permission states remain truthful.
4. Integrate branches, run affected cross-feature checks and analyzer once; build locally with the disclosed local signer.
5. Inspect the actual installed candidate using synthetic data: running Chat, Tasks, child/parent navigation, More→Termux and force-stop/relaunch with an incomplete project catalog. Do not publish fixture endpoints or raw diagnostic logs in the phone gallery.

## Automatic background agents

OpenCode 2 exposes `subagent({agent,description,prompt,background:true})`. The server launches the linked child and later delivers its final result into the parent via synthetic inbox delivery. The app renders canonical server history; it must not fabricate parent messages. The existing Background endpoint promotes currently blocking work and cannot create a child from arbitrary text. A manual result-to-draft feature was withdrawn after the maintainer clarified this requirement.

The exact versioned source review and client event path are recorded in [async-agent-contract.md](async-agent-contract.md). Live phone-server/provider execution remains a separate gate; synthetic tests only prove client behavior.

## Integration corrections

All four repair branches are integrated locally. Integrated analysis identified two missing braces in project deletion guards and a mounted-check recognition issue after chat rescoping; these were corrected without weakening the guards. The first recursive test candidate (`865b4ce`) stopped in chunk 5 on the localization coverage guard: the new ToolCard launch status bypassed AppLocalizations. The summary, accessibility label and expanded result now use the new `workStartedInBackground` key. The focused localization/card checks pass (21 cases). The earlier partial suite is retained as failed evidence; it is not counted as the final candidate gate.

## Final local verification and delivery

Candidate `002ebef3138d7364abe36fad154e192880afe23c` (production source unchanged from `95375e8` after a test-only Workspace presentation correction):

- Pinned Flutter 3.47.2: dependency resolution, final analyzer (no issues, 8.2s), format and diff checks pass. Full recursive Flutter suite: 259 files in 11 serial chunks, 2,751 passed and 6 pre-existing optional capture skips, 524.2s. [Summary](serial-summary.json), [complete manifest](serial-test-manifest.json), [gate record](verification.json). No earlier failed run is included in this pass.
- Local ARM64 and x86-64 release build succeeded in 155.8s with JDK 17 / API 37. No CI or cloud signing job. Both APKs retain the accepted local certificate 1DE5BF08146F269BCD9EB5C2FFC94469CE4617D37806285955F978A62494D60C. The ARM64 file is 70,941,047 bytes; SHA-256 b6cde96ecabe3d7e4e2636b16e9fffeae6745a2477046c1dbc265da88025bc35. [APK delivery](apk-delivery.json).
- Installed x86-64 APK on the owned Android 14 / API 34 AVD; installed base.apk hash exactly matches the built artifact. Native screenshots below use 1080×2400, 420 dpi, actual app, synthetic provider-free v1 server; 1.0x and 1.5x system text. No Flutter/AndroidRuntime error entries observed during the scoped walkthrough. [Device proof](device-verification.json).
- Native actions: single foreground Stop; background promotion reaches the exact parent endpoint; idle child stays available; child/parent round trip preserves an unsent draft; keyboard leaves controls reachable; direct More→Termux reaches missing-install state without changing the server; select B → catalog contains only A plus B lookup 503 → force-stop/relaunch retains B path/session. [Post-restart request scope](restart-request-scope.json). More bottom actions remain scroll-reachable at 1.5x text. No prompt was sent and no provider was called.
- Four native-v2 ToolCard captures rerun after localization, all pass. [Current v2 captures](../v2-subagent-contract/README.md).

### Native evidence

- [One Stop and persistent Tasks](native/repair-chat-running.png)
- [Idle tasks stay accessible](native/repair-tasks-idle.png)
- [Child task with parent return](native/repair-child-chat.png)
- [Parent draft preserved](native/repair-parent-draft-restored.png)
- [Composer above the keyboard](native/repair-chat-keyboard.png)
- [Direct Android Termux entry](native/repair-more.png)
- [Truthful Termux install state](native/repair-termux.png)
- [Project retained after force-stop](native/repair-project-b-restored.png)
- [Bottom actions at 1.5x text](native/repair-more-large-bottom.png)

### Remaining evidence and polish

- P1 verification: a real phone/server OpenCode 2 parent → background child→automatic final return is still unverified. Source and wire contracts support it; canonical live-refresh regressions pass. Synthetic Android walkthroughs do not establish real provider execution or server restart recovery.
- P2 UI: server synthetic completion currently uses an expandable notice; a future result card can use validated child metadata to avoid exposing the XML wrapper in its collapsed preview.
- P2 copy: Termux setup still exposes technical musl/environment wording before the install steps; simplify that explanation in a focused copy pass.
- Physical-device frame timing and TalkBack are not proven by the software-rendered emulator. This is a verified repair checkpoint, not a claim of exhaustive polish or a public release.

Privacy verification: [scan report](privacy-check.json) found no exact Mobbin credential values or literal bearer headers across the audit, APK/gallery assets, changed/untracked files in all repair worktrees, and the inspected committed history. No provider credentials were used in the native fixture.
