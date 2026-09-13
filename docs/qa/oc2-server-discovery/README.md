# OpenCode generation and connection discovery

Finish line: saved servers display their known OpenCode generation, an existing OpenCode 2 server has an explicit connection entry, and an Android OpenCode 1 user can find phone setup without changing an existing profile. Non-goals: forcing a protocol, probing on list render, changing or installing a server, runtime setup internals.

Production ownership: `lib/ui/screens/servers_screen.dart`. Runtime setup is a separate slice; this screen navigates to `/termux-setup` with no arguments. New copy uses `oc2Discovery*` ARB keys. Generated localization output is intentionally excluded from the commit; regenerate during integration.

## Findings and implemented behavior

| ID | Priority | Finding and resolution | Behavior evidence |
| --- | --- | --- | --- |
| OC2DISC-01 | P1 | Saved profiles hid generation. Add one quiet metadata line: OpenCode 2 for explicit v2, OpenCode 1 for v1 with cached successful version, neutral OpenCode for legacy default without evidence. Codex stays separate. No extra badge or live-health claim. | Confirmed and unprobed profiles test; saved-list captures. |
| OC2DISC-02 | P1 | No explicit existing-OC2 entry. Add a secondary Connect OpenCode 2 row beside the ordinary Add server path. The shared editor says it detects either generation and retains the actual probe result. | Shortcut saves both real probe outcomes in two tests; first-run and editor captures. |
| OC2DISC-03 | P1 | Editing an endpoint could retain old v2 evidence. A changed normalized URL without a valid probe clears cached version and uses the existing undetected-profile default. A trailing slash alone preserves identity. | Changed and unchanged endpoint tests. |
| OC2DISC-04 | P1 | Retained OC1 and OC2 phone profiles share one managed listener. Tapping either now opens phone setup when both recognized generations are present, rather than directly connecting and rewriting identity. Single managed profiles and remote profiles keep normal connection behavior. | Mixed-local, single-local and mixed-remote route tests; no profile mutation. |
| OC2DISC-05 | P2 | New Connect OpenCode 2 AppBar truncated the final 2 at double text size. Shortened editor title to OpenCode 2 and reduced helper copy. | Final 2× editor capture shows the complete title; all 21 affected cases pass. |

Phone setup remains discoverable as Termux setup, with an explicit OpenCode 1 or 2 subtitle. Its real install/switch actions and the controller mismatch protection are integration dependencies owned by the runtime slice, not proven by this screen's route test.

## Focused verification

Pinned Flutter 3.47.2 / Dart 3.13.2 from Shorebird cache revision `e16cf749ccaa38d7050335ff305def49b1c7c84c`, base revision `881e0d1`.

Manifest, run serially with the coordinator's machine slot:

- `test/oc2_server_discovery_test.dart`
- `test/server_v2_connect_flow_test.dart`
- `test/server_profile_editor_test.dart`
- `test/phone_termux_discovery_test.dart`
- `tool/capture/oc2_server_discovery_test.dart`

Before final copy adjustment: the new behavior file passed all 9 cases. The regression/capture command passed 38 cases and failed one existing Tailscale test because its tap assumed an off-screen row was visible after the added discovery row. The test now scrolls to the row; its exact rerun passed. No production workaround was added. Baseline capture separately passed 12 cases. After the copy adjustment, localization generation and changed-file formatting succeeded, and the 9 behavior cases plus 12 capture cases passed together (21/21). No full-suite, analyzer, native APK, live-server or install claim.

## Visual evidence

Before captures use actual widgets at `881e0d1`; after captures use this slice with synthetic profiles. Three pages (saved list, first run, editor), light/dark and 1×/2× text, each at 390×844 logical pixels, PNG output 780×1688. All 28 files are retained here: 12 baseline, 12 matched after, and 4 extra scrolled first-run options captures. No live probes or server installation occur in the capture harness.

Final after captures include the shortened title and helper copy. Visual inspection of `after-editor-dark-2x.png` confirms the full title and sticky Save & connect action; `after-first-run-options-light-2x.png` confirms both discovery destinations and their complete copy. Saved-list generation metadata stays readable at 2×; existing name/URL ellipsis is inherited. List metadata and discovery rows use existing theme type, spacing and iconography without introducing badges or decoration.
