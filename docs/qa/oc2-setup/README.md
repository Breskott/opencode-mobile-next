# OC2 setup checkpoint

Finish line: an existing managed OpenCode 1 phone installation can explicitly try isolated OpenCode 2 and return, with discoverable version labels and preserved old data. Non-goals: automatic chat/provider migration, changing the server pin, public releases, or CI builds.

## User journey

More → Termux setup shows the actual local runtime. Try OpenCode 2 beta explains the server stop and separate chats/provider settings before starting. Project files and project configuration remain shared. The installed-server view has one primary connect/continue action; first-run setup help is collapsed. Return to OpenCode 1 is available after opting into isolated OC2, including recovery after a failed switch. Existing first-run OC2 installations keep their default data and receive no unsafe invented OC1 return.

Servers shows known OpenCode 1/2 identity, clears stale identity after changing an untested address, and offers Connect OpenCode 2 for an already-running server. Selecting between preserved local generation profiles opens the runtime controls; it never silently overwrites a saved profile's generation.

## Implementation and evidence

- [Managed runtime switch](../oc2-managed-switch/README.md): exact-process stop, durable pending/failed operation, isolated XDG/config/database roots, preserved credentials/profiles, explicit connection, compact UI, focused regressions and captures.
- [Server discovery](../oc2-server-discovery/README.md): detected identity and visible connection paths, endpoint identity invalidation, local profile routing, focused regressions and matched captures.
- [Pinned upstream feasibility](upstream-feasibility.md): official published beta18600 host startup and database/authentication proof, plus current upstream differences.
- [Independent switch review](switch-independent-review.md): corrected journal/credential boundaries and exact source-review limits.

Integration source adds the combined generated localization, 3 missing-brace lint corrections, the corrected large-dialog capture, and local checkpoint version 1.0.38+39. No generated SDK files changed. No provider secrets or real phone/server credentials used in notes or tests.

## Verified checkpoint

**APK source: `a6434209d3b5f85053fb868cb45d4f6dcb9b7c05`, version 1.0.38 (39).** Later verification-only commits do not change application source. Built locally with pinned Shorebird Flutter 3.47.2 / Dart 3.13.2 and Temurin JDK 17; no push, CI, tag or public release.

- The [complete recursive serial suite](suite/summary.json) passed all 262 test files in 11 chunks, including nested goldens: 2,800 passing test cases and 6 recorded skips, 518.3 seconds summed across chunks. [Test manifest](suite/test-manifest.json), [source manifest](suite/source-manifest.json), [run definition](suite/run.json) and raw logs in `suite/chunks/` retain the candidate and coverage. Skipped cases are not counted as passes.
- [Final analyzer](analyzer.log) is clean. [Focused copy/capture checks](focused-gates.json) passed. Owner evidence also covers the 106-case [progress repair](../oc2-switch-progress/README.md). No generated SDK code changed.
- [Local release build](local-build.json) succeeded in 115.4 seconds. Both ARM64 and x64 APKs contain valid ELF `libapp.so` and `libflutter.so`, Flutter assets, the expected package/version/ABI, and the same accepted local signing certificate. [Artifact hashes and download](apk-delivery.json); [build log](local-build.log). Portable analyzer/build logs have trailing whitespace removed; original bytes remain in the external verification archive.
- The [actual installed x64 APK identity](native/final-installed-identity.json) matches the final build. Real Android 14/API 34, Termux 0.118.3 and app-managed Ubuntu ran OC2 beta-18600 → OC1 1.18.29 → OC2 beta-18600 through the app's visible controls. Authenticated health worked; unauthenticated requests returned 401. The exact old OC1 session is absent in isolated OC2 (404), and returning to OC1 restores its original title and stored noReply user message. The separate OC2 session survives returning. [History and restart proof](native/runtime-history-proof.json), [artifact-bound installation proof](installed-apk-proof.json).
- Final native progress shows fresh timing/output and “You can leave this screen and return to check progress.” Cold app restart restored the OC2 profile, `/root/projects` and original OC2 session. Android 2× text was reviewed; lower controls remain reachable by scrolling. Font scale was restored afterward. [Current application error-log check](native/delivered-runtime-errors.json) found no fatal exception, unhandled exception or RenderFlex overflow. The owned emulator was stopped after verification.
- [Privacy scan](privacy-check.json) found no exact Mobbin credential, literal bearer header or unreadable input in the scanned notes, changed files and committed blobs. No provider generation was requested. Physical ARM64 hardware and model-backed background-agent completion remain unverified.

The local signer is `1DE5BF08146F269BCD9EB5C2FFC94469CE4617D37806285955F978A62494D60C`, matching the previously accepted local checkpoint. It differs from the stable CI signer and cannot update an installation signed with that certificate. No app was uninstalled or its data removed.

## Final installed Android captures

| State | Evidence |
|---|---|
| OC1 and visible beta entry | [Screenshot](native/delivered-oc1-ready.png) |
| OC2 and visible return action | [Screenshot](native/delivered-oc2-ready.png) |
| Stop/data separation confirmation | [Screenshot](native/delivered-switch-confirmation.png) |
| Fresh switch progress and corrected guidance | [Screenshot](native/delivered-switch-progress.png) |
| Cold restart restores profile/project/session | [Screenshot](native/delivered-cold-restart-ready.png) |
| Actual Android 2× text | [Top](native/delivered-large-text.png), [scrolled controls](native/delivered-large-text-bottom.png) |

These captures are from the final APK source a643420. Matching UI hierarchy XML is saved alongside each PNG. Earlier widget/host evidence is labeled separately in the owner reports.

## Earlier failures and scope limits

Full run `serial-20260909T191245Z-40c882d7` ended after source changed; `serial-20260909T191843Z-b1fdfff2` completed with four stale platform/backend label expectations. Those assertions were corrected and neither run contributes coverage to the final candidate. Earlier source a2525f0 established real initial OC1 → OC2 installation, separate histories, app termination during installation and independent manager completion. It exposed the stale elapsed/log behavior fixed in 41092d0; final a643420 additionally corrects switch-progress guidance.

A Gradle-success package from an earlier candidate lacked `libapp.so` after a build-cache path relocation. It was rejected before installation/delivery. Resetting the owned Flutter cache fixed the path-alias cleanup; final APK validation now checks both native libraries before publication. Full details and superseded logs remain in the external OC2 verification archive.

No runtime pins changed for this slice. [Fresh upstream feature check](upstream-features-20260910.md) distinguishes current documentation and V1 1.18.30 from the tested V1 1.18.29 / V2 beta-18600 pins. Current V2 documentation does not prove every feature exists in the pinned beta.

Remaining follow-ups: provider-backed parent/background-child/final-return execution on real ARM64 hardware; the broader page-polish backlog; repeated loaded-session/incomplete-catalog messaging in Workspace; migration of desktop_drop, flutter_timezone and mobile_scanner away from the Kotlin Gradle plugin before a future Flutter upgrade. These are outside this completed runtime-switch slice and are not claimed as fixed.
