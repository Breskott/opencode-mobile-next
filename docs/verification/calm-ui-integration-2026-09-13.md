# Progressive disclosure integration, 2026-09-13

Finish line: frequent navigation and connection actions stay visible while project, session, tool and code details open on demand; storage cleanup cannot remove projects, team data or shared scratch. Non-goals: Gas City feature development, custom Termux forks, whole-phone storage scanning or any real-device cleanup.

Integrated from e39d7f0 into fix/calm-ui-integration-20260913. The original dirty dev checkout remains untouched. Version 1.0.43+48 distinguishes the new candidate from the previously delivered 1.0.42+47 APK. This record is not a publication claim.

## Focused verification

- Storage: 29 tests pass, including modern/legacy/rootfs-free layouts, protected and forged paths, ownership/symlink refusals, partial removal accounting, stale reports, failed process discovery, interrupted locks, confirmation and large-text LTR/RTL.
- Running-server discovery and profile editor: 30 tests pass after cancellable discovery and explicit absent-Termux editor mocks; six disposal cases cover capabilities/status/probe with missing and late replies.
- Chat follow-up: 145 discovery/editor/chat tests pass together after adjusting old control-location expectations. Earlier expanded chat checks passed 217 tests with three opt-in skips, with five failures subsequently fixed by that follow-up.
- Workspace/shell/reader checks: initial 177 pass and three failures; the corrected projects, project-health and Markdown/reader files pass all 60 cases. Remaining workspace, brief, feature-gating, accessibility, home and library tests passed in the initial run.
- Files: 35 product/capture cases pass, with recovery cases passed separately. Source-order menu test taps target actual menu items.
- Rendered evidence: real-font workspace and project details at 390dp/1x and 320dp/2x/2.5x; chat idle/draft and large-text keyboard; Files list/search/changes; More/settings; storage inventory/confirmation and detected-server entry. Data is synthetic, not live-device storage. The workspace capture now scales the entire navigator so modal sheets inherit the tested scale.
- Analyzer was clean before the final storage process/lock and discovery cancellation corrections; final candidate analysis and recursive full suite remain pending.

## Review findings addressed

Cleanup uses exact Gradle/npm content caches only, checks canonical paths and ownership, refuses unknown process activity, and invalidates reports before mutation. Every cleanup needs confirmation. Reports measure Termux home/prefix, not the entire phone, and removed apparent bytes do not claim equal filesystem free-space gains. Existing layouts remain a bounded supported scope; no multi-device scan-performance claim is made.

Discovery remains read-only until Connect is tapped, revalidates the observation, retains saved remote profiles, and opens credentials when needed. View disposal cancels deadlines and HTTP requests; native replies cannot start a subsequent stage after disposal.

Capture harness correction: the optional running-server PNG encoder initially hung under the widget fake clock. Encoding now runs in runAsync; both real-font captures pass. No product timeout or device failure was involved.

Artifacts: docs/qa/calm-workspace-2026-09-13, calm-chat-2026-09-13, calm-files/after, calm-storage-2026-09-13, calm-termux-2026-09-13 and settings-discovery/calm-*.png. Native upgrade validation and new signed artifacts are still required before release.
