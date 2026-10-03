# AI Team engine UI - 2026-09-30

Finish line: on this phone's in-app OpenCode 1 profile, one tap on "Turn on AI Team on this phone" takes the team from off to ready through real steps, and every work action follows what the engine can do now.
Non-goal: engine internals (Codex owns them); the demo is unchanged and never gated.

## What was built
- `lib/state/phone_team_setup.dart`: the flow controller (reply wait, stop question, engine start/proof, protected server start, probe until `canExecute`, attach). Uses the existing controls only: `BuiltinLinux.stopServer` + `DeliberateServerStop`, `LocalTerminalSessions.remove`, `BuiltinServerStarter.start`, `phoneProjectEngine.start/probe/attach`. New file; no edit to connection.dart or the engine adapter.
- `lib/ui/screens/team/team_phone_setup_screen.dart`: the kit step page (KitChecklist + KitStateView), elapsed per step, tick, plain failure + Details + Start again.
- Entries: AI Team empty state (in-app profile), Team settings row, the off page of a phone team, the gate line on every work screen.
- Work strip row (`phone_team_setup_strip.dart`): after an app update a team that was on is re-proved once per app run; progress shows in the Work strip; a stop is asked, never done silently.
- `team_execution_gate.dart`: New project, Quick task, Approve and start, resume/restart, merge, verify/recheck/fix, move, Promote are not drawn while the matching `OrchestrationCapabilities` flag is off; one line with the fix replaces them. Demo controllers are never bound, so never gated.

## Checks
- `test/phone_team_setup_test.dart` (16): flow states and gating. Also the existing team/project test files, kit ratchet, golden harness (see commit message).
- Goldens `test/goldens/team/kit_teamphonesetup_*` (phone dark, wide light). Contact sheets: `contact-sheet-phone-dark.png`, `contact-sheet-wide-light.png` (looked at).

## Not done / needs the phone
- Live device run of the whole flow (no device proof claimed).
- Start failure reasons are not typed (see requests to backend in the hand-off).
