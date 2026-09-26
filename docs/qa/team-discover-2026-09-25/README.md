# Finding the AI Team, and what it is doing (2026-09-25/26)

## Scope

The owner (a phone user; OpenCode in Termux or inside the app):

- "AI team is impossible to discover bro."
- On Settings › Plugins while turning the team on (build 2054): "why repeat gas city on the plugin page?"
- On the AI Team home (build 2054): "I have no idea to know when is next cycle and whats happening?"
- On a worker's page and its live output: "Wtf", "Taking a year".

Specs: `docs/design/design-standard.md` (§1–§10), `docs/design/aiteam-redesign-2026-09-24.md` (the person's words), `docs/design/motion-and-illustration-2026-09-25.md`, and `docs/design/team-conversation-2026-09-26.md` (a team task is a conversation; Solo · Team).

### What changed

| Where | Before | After |
|---|---|---|
| **Work tab, team off** (`TeamDiscoverEntry`, `lib/ui/widgets/team_discover.dart`) | Nothing. The team was reachable only from Settings › Plugins. | Where the team's section goes (after the person's conversations, never above them): "AI Team", a small drawing (three agents, one holding up a task), "Give a bigger job to a team", "Agents plan it, work on it, check it and merge it. You step in when they ask.", and ✕. Opening it or ✕ folds it to one quiet row, "AI Team · Off · A team of agents for bigger jobs ›", which stays as a door. The fold is one global preference (`oc.teamDiscover.folded`): it is about the person, not a server, so it outlives a deleted server. Absent on a Termux phone whose runtime cannot run a team. |
| **The intro** (`TeamIntroScreen`) | — | A hero drawing (a task card travels from the planner through the worker to the reviewer and lands with a check), "It plans / It works / It checks / It merges", what it needs **on this kind of server**, and one primary that hands over to the existing set-up. Nothing is set up here. |
| **Settings** | Only Plugins › "AI Team · Gas City". | An **AI Team** row at the top of Agent setup. Its line is `teamStateLine`, the same words as the Plugins row: "Turning on…" while this phone installs it, "On · This phone", or "Off · A team of agents for bigger jobs". Off, it opens the intro. On, it opens Plugins. |
| **Plugins, OpenCode inside the app** | The phone card ("AI Team on this phone", turning on) **and** "In this app › AI Team · Off": the same feature twice, in two states. | The phone card **is** the AI Team. A computer's team is one secondary row under it ("A team on a computer · Use Gas City on a computer instead"). Once the phone's team is on, that row is "Technical details" (the sheet, Turn off). |
| **Empty AI Team home** | Board drawing at 88 dp (the inline default), cramped. | 168 dp (`KitStateView(illustrationWidth:)`). |
| **Merged celebration** | Entrance 900 ms, popped in. | `entranceDuration: KitMotion.celebration` (1.4 s) and unfolds in with `KitReveal`. |
| **Motion kit** | `RefreshIndicator`s. | `KitRefresh` on the Work tab and all four team screens; `KitAnimatedRows` for the Work tab's short sections (Needs you, Running, Pinned) and the home's task list. Recent stays a lazy list. |
| **Paused vs asleep** (`lib/ui/widgets/team_now.dart`) | "On this phone · Paused" and "No agents" whenever no agent was live, which is also a normal idle team whose on-demand agents are asleep. | "Paused" only when agents were switched off on purpose (suspended). Asleep reads "2 agents · asleep until there is work". |
| **A waiting task** | "Waiting for a worker", forever. | "Waiting for a worker · the team checks every minute". The interval is the in-app team's own `patrol_interval`, read from `BuiltinTeam.phoneTuning`. Elsewhere it reads "a worker starts at the team's next check": the app cannot know that host's interval, so it names the trigger instead of making up a time. Past two checks (3 min when unknown), or when the host saw no agent start: "Waiting for a worker · 6 min · no worker has started". |
| **The home's Now line** | — | Heads the list (it scrolls with it, so it never takes room from the tasks). One line for the team, in this order: paused (**Resume**); a task stuck ("“…” has waited 6 min and no worker has started", **Start a worker**, or **Why?** opening Technical details when the host takes no controls); working ("a reviewer checks it next"); in review ("it merges when the check passes"); waiting (when a worker starts). Old data's status line still wins (§5, one line). |
| **Agent screen** | Title `demo-app/gastown.furiosa`, "Agent · session ph-yqt", Role `demo-app/gastown.polecat`, many "Not reported" rows. | Title "Worker · furiosa", subtitle "On “<its task>”". Role in plain words. Rows the host does not report are left out. Engine names appear only under Technical details. A worker that is not running while a task waits shows "The worker didn't start" with **Start it** (resume), or **Why?**. |
| **Live output** | "Connecting to the session…" / "Nothing yet", with no end. | An agent that is not running says so at once ("furiosa isn't running, so there is no output"), with the same action. One that runs but is silent after 8 s shows "Starting up · 2 min so far · this can take a few minutes on a phone" (on a phone) or "No output yet · it can take a minute to start". The agent is named by role. |
| **Team state truth** | — | A mapper test pins the rule the coordinator confirmed over adb. The session (`running`, `state`, `active_bead`) is the live truth. The agents list is config and fallback. The test uses the owner's exact agent field set: alone it is stopped, and with its running session on `da-r7d` it is working. `lib/orchestration/**` is not changed. |
| **New conversation: Solo · Team** | — | A small segmented choice above the primary, remembered per server (`oc.newConversationMode.<profileId>`, swept with the profile). It shows where the server can run a team. Team makes the primary "New team task". With the team on, that calls `TeamConversation.start`; otherwise it opens the intro. |
| **Team tasks in the Work tab** | A separate AI Team card. | Open team tasks are rows in **Needs you** / **Running**, with a small team badge on the task mark and "Team · <state line>". They open `TeamConversation.open`. Where the card was, there is one quiet door, "AI Team · On this phone ›", to the team's own page. The `TeamCard` widget remains, but the Work tab no longer uses it. |

### Per kind of server: the one path

| Server | Work tab | Intro says | "Set it up" goes to |
|---|---|---|---|
| **OpenCode inside the app** (built-in Ubuntu) | entry | about 115 MB to download, next to OpenCode on this phone; more battery (several agents); you choose the projects | Settings › Plugins, where the phone card (`BuiltinTeamSection`, not changed here) adds it through the setup engine, turns it on for the project and starts it |
| **OpenCode in Termux**, runtime can run a team | entry | the Termux download (manifest size); keep Termux open while it works | `/termux-setup`, after reopening the phone offer (`PhoneOffer.open`): its "Also run an AI team on this phone" block hid itself once the offer had been skipped or dismissed, which would have made "Set it up" land on nothing |
| **OpenCode in Termux**, runtime cannot (no arm64 manifest) | **no entry** (decision: nothing to offer on this phone) | "This phone can't run the AI Team" (notice) | no primary; **Run it on a computer** opens the host guide |
| **A computer** (any other server, Codex and Paseo included) | entry | runs on <server>; install Gas City there once and the app finds it; as fast as your computer | while the app looks for Gas City on the server's host (`TeamDiscovery`, the one loading bar), **Turn on** if found; else **Set it up** (host guide, then it looks again) and **Enter its address** (`showTeamHostSheet`) |

`TeamConversation` is a **stub** (`lib/ui/screens/team/team_conversation_stub.dart`) with the exact signatures `start(context, team)` and `open(context, team, runId:)`. Until `feat/team-agent-chat` lands, it opens today's start sheet and RunScreen. The coordinator swaps it at merge.

## Builds

- Branch `ds/team-discover`, from `2730891b`. It merged `feat/phone-setup-v2` at `c799e2af` (the design doc), with ARBs merged key by key and l10n regenerated.
- Commits: `a94fc8d1` (discovery), `6b1654a6` (truthful team state), `81fa7fd9` (merge), then the Solo · Team commit.
- No APK, emulator or Gradle build (shared machine).

## Devices

None. Widget tests and golden renders only, with the pinned Shorebird Flutter `91f8bd75…`, at 412 × 915 dark and light.

## Runs

| # | Run | Expected | Actual |
|---|---|---|---|
| 1 | `test/team_discover_test.dart` (20): the entry shows while off, below the work; ✕ folds and stays folded (global key, not swept); opening shows the intro, then it is folded; absent when on; Termux supported / unsupported; intro steps; computer found → Turn on saves the config; not found → guide, looks again, address form; in-app → Plugins with the phone card; Termux → offer reopened, `/termux-setup`; Termux unsupported → notice, host guide; Settings row Off + intro, On; no contradicting rows while turning on (Plugins has no "AI Team · Off", Settings reads "Turning on…"); on → one state; empty home drawing ≥ 160 dp; celebration 1.4 s; Solo · Team remembered and swept, Team → intro; team on → rows with the mark under Running, door, row → RunScreen, Team → start sheet | pass | PASS |
| 2 | `test/team_now_test.dart` (11): asleep is not Paused and the row says so; Paused with Resume (resume sent to each paused agent); fresh wait says "the team checks every minute" and the Now line; on a computer, what starts a worker; stuck says 6 min and no worker, Start a worker sends resume to the sleeping worker; stuck without controls → Why? opens the details; agent titled "Worker · furiosa", no engine names, no "Not reported", "The worker didn't start" + Start it; a working worker has no such notice; output: not running says so at once with the action; running and silent on a phone says "Starting up · …" after 8 s | pass | PASS |
| 3 | Failing first: the same tests with the product wiring at the base | fail | **FAIL**. `failing-first-without-change.txt`: 9 of the discovery tests. `failing-first-team-now.txt`: 9 of the Now tests. `failing-first-solo-team.txt`: both Solo · Team tests. The in-app/Termux/computer intro tests and the Now pure-function test pass there too, because they exercise the new files directly. |
| 4 | Pinning test `team_gascity_mappers_test.dart`: the owner's exact field set | stopped alone, working with its running session | PASS (not failing-first: it pins the current rule the coordinator confirmed) |
| 5 | Affected suites, updated where the design changed: `team_plugin_off` (the Work door is an entry point, `team-discover-*` exempt), `team_home_layout` / `team_home_stable_layout` (the Now line heads the list, and at 320 dp and 2.5× the task row is one scroll below it), `team_card` / `team_cycle` / `team_home` (the wait line; the Work tab lists the team instead of the card), `team_agent_screen` (role title, unreported rows left out), `team_redesign`, `team_phone_onboarding`, `accessibility_guidelines` (48 dp segments) | pass | PASS: see the final-gate row |
| 6 | Final gate on the candidate: `flutter analyze lib test`; 108 files, `-j 2`: every `test/*team*`, workspace, Work tab, settings, search, ledger, design standard and accessibility test, and every golden test | clean / pass | **PASS**: analyze clean; 1618 tests passed, 2 skipped, 0 failed (5 min 2 s), on the working tree committed as the Solo · Team commit |

## Evidence

- Before/after renders (412 × 915, dark and light):
  - Work tab, team off: `before-work-*`, `after-work-*`, `after-work-folded-*`.
  - Work tab, team on: `before-work-team-on-*` (the card), `after-work-team-on-*` (rows and door, Solo · Team).
  - Intro: `after-intro-phone-*`, `after-intro-computer-*`.
  - Settings, Agent setup: `before-settings-*`, `after-settings-*`.
  - Plugins on this phone: `before-plugins-phone-*` (the owner's complaint reproduced), `after-plugins-phone-*`.
  - Empty home: `before-team-home-empty-*`, `after-team-home-empty-*`.
  - Home with the Now line: `before-team-home-now-*`, `after-team-home-now-*`.
  - Agent: `before-agent-*`, `after-agent-*`.
  - Live output: `before-agent-output-*`, `after-agent-output-*`.
  - Merged overview: `after-merged-overview-*`. The finished frame is unchanged; only its timing changed.
- Scene goldens: `test/goldens/team_discover_scene_{teaser,relay}_{dark,light}.png`.
- Screen goldens: `test/goldens/team_discover_*`, `team_intro_*`.
- Ledger: pages `team-intro` and `embedded-team-discover`; elements `settings-ai-team`, `plugins-team-other`, `workspace-new-mode`, `workspace-team-task-row` and `workspace-team-door`. Rebuilt with `build_ledger.py`.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test test/team_discover_test.dart test/team_now_test.dart
$F test test/goldens/team_discover_golden_test.dart test/goldens/team_discover_scenes_golden_test.dart
```

## NOT proven

- **On device.** Nothing here ran on a phone or an emulator. That includes the fold's feel, the intro's drawing in motion, and Termux's `/termux-setup` scrolling to its team block (it sits at the end of that screen; the intro cannot scroll it into view without editing that screen).
- **A turn-on already running in the phone card while the person leaves Plugins.** The card's stage is private to `BuiltinTeamSection` (not this slice's file), so the Settings row can read the install job (`PhoneSetup.engine`) but not the card's turn-on. The fix belongs to its owner: expose the stage (for example a `ValueListenable<BuiltinTeamStage?>` on `BuiltinTeam`), and `teamStateLine` should read it.
- **The next-check time on a computer or in Termux.** The host does not report its patrol interval, so the app says what starts a worker instead of a time. The in-app team's interval comes from its own tuning.
- **"All conversations" listing team tasks** (`global_sessions_screen.dart`, outside this write set). Only the Work tab lists them.
- **The real `TeamConversation`.** A stub stands in until `feat/team-agent-chat` merges.
- **Work tab rows' wait age.** The rows and the card have no team clock to draw an age from, so the age shows on the team home and the task page only. The Work tab says "no worker has started" and the cadence.
