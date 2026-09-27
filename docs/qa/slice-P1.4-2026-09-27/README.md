# slice-P1.4: Per-component remove (2026-09-27)

Branch `revamp/slice-P1.4`, base `4c81a913` (feat/phone-setup-v2 after P1.7).
Built on the Codex backend in [codex-p07-p14](../codex-p07-p14-2026-09-27/README.md)
(`ComponentRemovalService`, `BuiltinTeam.turnOff/remove`). This slice owned
`lib/builtin/setup/**` and This phone (P1.2 and P1.7 are merged).

**Finish line.** This phone lists each optional tool setup installed with its
own "Remove <tool>", on both hosts. Each one names what it deletes, asks
first, and its question says what goes, what stays and the space measured
now. A tool that something else still uses is named with what uses it and
cannot be removed. The in-app AI Team can be turned off (for good, until it is
turned on again) and removed.

**Non-goal.** No project move between hosts. Required parts (Linux, Git and
SSH, Node.js, OpenCode) are not removable on their own; they go only with
"Remove OpenCode".

## What changed, per page

**This phone** (`lib/ui/screens/this_phone_screen.dart`)
- Destructive rows at the end of the list, before "Remove OpenCode":
  "Remove Python", "Remove AI Team", "Remove Voice typing" (whichever is
  installed on this host). The line under each says what it deletes, for
  example "Deletes pip and venv. Python and your projects stay."
- A tool another installed tool depends on is shown off, with "Needed by
  <tools>" as its line and its disabled reason. The service refuses it too.
- The question: "Remove Python from this phone?". The body says the space
  measured now ("About {size} comes back. You can add it again from Add
  tools."). The measurement waits at most 3 s, and a slow or failed reading
  leaves the figure out. It is followed by what goes and what stays:
  - Python: "pip and venv are deleted, with the packages only they used".
    "Python itself and your projects stay".
  - AI Team: its programs, tasks and settings are deleted, and team work not
    yet brought into your projects is lost (the phone-side origins go).
    Your project files and their git history stay.
  - Voice typing: typing by voice stops until you add it again.
- Removal runs inside the question. A failure keeps the question open with
  the kit's notice and Try again, and shows no script or native text. The
  list is read again afterwards either way, because a failed removal may
  have removed part.
- While a tool is being removed, Update, Switch, Add tools and Remove
  OpenCode are off with "Wait for the current step to finish".
- After AI Team is removed, the team's config leaves every saved profile of
  that host that points at it. For the in-app host that uses
  `forgetBuiltinTeam`. For Termux it follows the same steps as the Termux
  team section.
- In Termux, AI Team removal runs `aiteam.sh remove` (it stops the
  supervisor) and then the component's own `AiTeamScripts.removeScript` in
  the same Ubuntu. Both hosts end in the same state, and the presence probe
  confirms it.
- **P9.4 follow-up.** The page's rows are one Column inside the ListView, so
  all of them are laid out at once. "Restart after a crash" is now built
  even at 320×200 and 3× text. The test for this fails on the base.

**Remove OpenCode question** (`phone_server_card.dart`, P0.7 extras ported
from `revamp/slice-P0.7`)
- There are two lines under the body. What goes: "Conversations and
  settings inside OpenCode are deleted". What stays: "Your projects (50.0 MB)
  stay and come back when you set up again". The body no longer repeats the
  projects.
- "Delete everything" adds the line "Project files not saved anywhere else
  are lost for good".
- Both removals run inside their question. A failed uninstall keeps the
  question open with Try again, the saved "This phone" entry stays until
  removal worked, and no alert shows the native text.
- Kit (`kit_confirm_sheet.dart`, one line): a destructive `alternative` now
  draws in danger. Before, "Delete everything" was drawn in the accent
  green, as if it were the safe path.

**AI Team on this phone, in Plugins** (`builtin_team_section.dart`)
- "Stop AI Team" is replaced by "Turn off AI Team". The old stop was
  temporary: app resume restarted the team. Turn off asks first ("The team
  stops and stays off until you turn it on again", and its tasks and
  settings and your projects stay). It then calls `BuiltinTeam.turnOff`
  (durable marker, then stop) and clears the in-app profile's team config.
  The section then offers "Turn on AI Team for <project>".
- A failed turn-off shows plain words. The redacted bridge text is only
  under Details.

**Setup backend** (`lib/builtin/setup/`)
- `SetupComponent.sizeScript` (new, optional): prints kilobytes. Python's
  dry-runs `apt-get --auto-remove remove` and sums the installed sizes. AI
  Team's runs `du -sk` on its folders.
- `ComponentRemovalService`:
  - `freedBytes(id)`: an app-side component reports its own size; zero or a
    failure means no figure.
  - `removeTeam` hook for hosts that do not use the in-app `BuiltinTeam`.
  - `termuxTeamRemover(...)`.
  - AI Team is `unsupported` when neither a team nor a remover is given.

**Copy.** English only (`app_en.arb`), then gen-l10n.
- Removed: `aiteamComponentStop`, from both ARBs.
- Changed: `removeFromPhoneKeepBody` and `removeFromPhoneKeepBodyUnmeasured`.

## Tests

New:
- `test/this_phone_component_removal_test.dart` (8):
  - rows appear per tool, and required parts have none;
  - Remove Python asks, names the lost and kept items and the size, then
    removes it and the row leaves;
  - a failure keeps the question open, Try again works, and no script text
    reaches the page;
  - "Needed by" blocks a tool;
  - Remove AI Team calls the team's removal and clears the in-app profile's
    config;
  - Termux uses its own team remover;
  - Remove OpenCode shows its lost and kept lines, a failure keeps the
    question open, and Try again removes;
  - non-lazy layout at 320×200 and 3× text. This test was run on the base,
    where it fails.
- `test/setup_component_removal_test.dart` (+6): `freedBytes` parsing; size
  scripts parse as POSIX shell; the host team remover is used; no remover
  means unsupported; the Termux remover's order; a Termux failure stops
  before any file is deleted and gives no manager text.
- `test/builtin_team_section_test.dart` (+1): Turn off asks, says what
  stays, turns the team off and clears the config, and Turn on comes back.
- Gallery `test/goldens/this_phone_remove_tools_golden_test.dart` (11
  images).

Changed: `test/phone_server_card_test.dart` has the new body and lines.
`phone_this_phone_remove_confirm_{dark,light}.png` were regenerated and
checked (the lines were added and "Delete everything" is now in danger).

Passing: the new files above; `phone_server_card_test`;
`revamp/shared_phone_1_test`; `setup_voice_component_test`;
`builtin_team_removal_test`; `setup_scripts_test`; `team_discover_test`;
`failed_job_report_ui_test`; the kit confirm and sheet tests. `flutter
analyze` is clean.

Failing on base `4c81a913` too, compared in a temporary second worktree.
None of these failures is new:
- `this_phone_screen_test`: "Update is not offered…".
- `revamp/screen_phone_1_golden_test`: 19 setup, storage and this-phone
  goldens. The two remove-question goldens were regenerated here.
- `builtin_team_section_test`: "turn-on waits for the store…". Codex's
  `prepare` now reads the off marker first.
- `team_phone_onboarding_test`: the 2 layout cases at 320dp.
- `kit_ratchet_test`: G17 and G21.
- `revamp/team_phone_v2_golden_test`: 4 cases.
- `kit/kit_request_sheet_test`: case 15.

The size scripts were also run on a host shell. AI Team's printed 0 (no
folders). Python's printed 38117 KB.

## Images

| | Before (base) | After |
|---|---|---|
| This phone, end of list, phone | `before-this-phone-end.png` | `after-this-phone-end.png` |
| This phone, end of list, 1280×800 | `before-this-phone-end-1280x800.png` | `after-this-phone-end-1280x800.png` |
| Remove Python question | none | `after-remove-python.png`, `after-remove-python-1280x800.png` |
| Remove AI Team question | none | `after-remove-aiteam.png` |
| A tool another needs | none | `after-remove-needed-by.png` |
| Remove OpenCode question | `before-remove-opencode-question.png` | `after-remove-opencode-question.png` |

The full gallery, in dark and light, is `test/goldens/this_phone_remove_*.png`.

## Still needs a device (the unit's proof)

Check these on the emulator with a release APK from the merged branch:
- Storage before and after removing Python and removing AI Team. The freed
  size said in the question should roughly match.
- The Python size dry run under proot within 3 s. Otherwise the question
  opens with no figure.
- The Termux AI Team removal end to end (`aiteam.sh remove`, then the
  component script), including that the presence probe finds nothing left.
- Turn off AI Team, then leave and come back to the app: the team stays off.
- A remove that fails on a device, for the Try again path.

Not touched: Kotlin, `lib/state/connection.dart`, chat files.

## State

Implemented: yes. Enabled: yes, on This phone (both hosts) and in Plugins ›
AI Team (in-app). Verified: widget and unit tests and goldens only.
Committed: yes (this branch). Deployed or released: no.
