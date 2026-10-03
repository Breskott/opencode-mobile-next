# Capabilities: what each host can do, and how a person gets what they lack

2026-09-26. Answers the owner's question: *"if a user doesn't have this and wants to enable this and this, what is the flow and discoverability and expectations and limitations"*.

Sources: `map/all.json` (the `whenMissing`, `statesMissing` and `proposals` fields of 356 pages), `taxonomy.md`, `owner-verdicts-2026-09-26.json`, `docs/design/phone-setup-v2-2026-09-24.md`, and the code. Every claim cites a file and line. The full data, with evidence for every cell, is in [`capabilities.json`](capabilities.json).

## 1. Capability matrix

Hosts: **In-app** = the built-in Ubuntu on this phone. **Termux** = Termux on this phone. **OC1 PC / OC2 PC** = OpenCode 1 or 2 on a computer. **Codex** = Codex app-server. **Paseo** = the Paseo daemon (Claude Code or Pi), on a computer or on the phone through Termux. **Demo** = the offline demo.

Key: ✓ supported · ◐ partly · ✗ not · — does not apply.

| Capability | In-app | Termux | OC1 PC | OC2 PC | Codex | Paseo | Demo |
|---|---|---|---|---|---|---|---|
| `server.oc1` | ✓ default | ✓ default | ✓ | ◐ run it alongside | ✗ | ✗ | ✗ |
| `server.oc2` | ✓ switch¹ | ✓ switch | ◐ run it alongside | ✓ | ✗ | ✗ | ✗ |
| `server.codex` | ✗ no component | ✗ | ◐ same PC | ◐ same PC | ✓ | ◐ as a Paseo runtime | ✗ |
| `server.paseo` / `claude.local` | **✗ Termux only**² | ✓ | ◐ install daemon | ◐ install daemon | — | ✓ | ✗ |
| `model.auth` | ✓ providers | ✓ | ✓ | ✓ | ◐ Codex account only | ◐ sign in inside the CLI³ | — |
| `team.on` | ✓ component⁴ | ◐ 64-bit + manifest⁵ | ✓ Gas City | ✓ Gas City | ◐ door shown, unproven | ◐ same | ✗ |
| `team.phone` | ✓ port 8472 | ◐ port 8372 | ✗ phone team serves only the phone's server⁶ | ✗ | ✗ | ✗ | ✗ |
| `team.control` (proposed) | ✓ loopback | ✓ | ◐ needs host front | ◐ | ◐ | ◐ | ✗ |
| `mcp.any` | ✓ follows runtime | ✓ | ✓ config + OAuth | ◐ runtime only, no OAuth⁷ | ✗ | ✗ | ✗ |
| `project.open` | ✓ create/browse | ✓ | ✓ path only | ✓ path only | ◐ one fixed dir | ◐ read-only | ✗ |
| `project.git` (proposed) | ✓ Git required | ✓ | ✓ init, worktrees | ◐ no init/create | ✗ | ✗ | ✗ |
| `voice.model`, `perm.mic` | ✓ on the phone, any server; Android only (`platform_capabilities.dart:68`) |||||| ◐ |
| `perm.camera` | ◐ photos | ◐ photos | ◐ photos | ✓ QR + photos | ✗ text only | ✗ text only | — |
| `network.tailscale` | — loopback | — | ✓ | ✓ | ◐ or USB | ✓ | — |
| `quota.collector` (proposed) | ✗ | ✗ | ◐ install it yourself⁸ | ◐ | ✗ | ✗ | ✗ |
| `agent.a2a` (proposed) | ✓ app-side (`lib/a2a`), whatever the server |||||| ◐ |

The three capabilities about the phone itself (`phone.builtin`, `phone.termux` and the proposed `phone.any`) don't depend on which server is open. They exist on Android only (`builtin_linux.dart:140`, `platform_capabilities.dart:59`). The two phone hosts can live side by side on ports 4097 and 4096 (`builtin_linux.dart:124`, `termux/bridge.dart:54`). Nothing moves projects from one to the other.

**Features that exist or disappear with the server** (ServerCapabilities flags; the phone hosts follow whichever runtime they run):

| Feature | OC1 | OC2 | Codex / Paseo |
|---|---|---|---|
| Files, Terminal, Project tab, Review | ✓ | ✓ | ✗ (`codex/gateway.dart:19-23`, `paseo/gateway.dart:23-27`) |
| Providers, MCP, commands, skills (`serverCatalog`) | ✓ | ✓ | ✗ (`codex/gateway.dart:32`) |
| Photos in prompts | ✓ | ✓ | ✗ text only |
| Usage › Spent, staged revert, notes, forms, inbox, dev services | ✗ | ✓ (`gateway_mappers.dart:35,70-71`; `usage_hub_screen.dart:44`) | ✗ |
| Share, worktree create/reset, Git init, cloud environments, remote upgrade | ✓ | ✗ (`gateway_mappers.dart:35-68`) | ✗ |

¹ Both runtimes stay installed side by side (`opencode_ubuntu_setup.dart:54-64`; `phone_server_card.dart:183-196`).
² `claude.sh` runs only through the Termux bridge (`termux/local_agent_runtime.dart:1-6,258-277`).
³ Sign-in happens inside the agent's CLI, never in the app (`app_en.arb:17753`).
⁴ On a phone switched to OpenCode 2, the team's agents still run the OpenCode 1 binary: `acp_command = "exec opencode"` (`builtin_team.dart:207`).
⁵ Needs `supportsAiTeam`: an arm64 or x86_64 phone and a build that carries the manifest (`team_runtime.dart:509-535`).
⁶ `BuiltinTeamSection.appliesTo` and `teamPhoneProfile` apply only to the phone's own server (`builtin_team_section.dart:148-150`, `plugins_screen.dart:49-52`).
⁷ `gateway_mappers.dart:40-43`.
⁸ The collector is "a separately installed, explicitly trusted deployment extension" (`quota/provider_quota_client.dart:1-3`). No screen or guide says how to get it.

## 2. Enable flows

Each flow covers where a person discovers the capability, what to expect, how to get it, its limits, how to undo it, and what the app does today. The JSON has every field for all 21 flows. The ones that matter most:

**Phone setup (`phone.builtin`).**
- *Discover:* the welcome's "On this phone", Servers, Settings, search (`search_index.dart:324`).
- *Expect:* about 4 minutes. About 208 MB to download (Linux 30, essentials 45, Python 25, Node 58, OpenCode 50 MB; `components.dart:33-93`) and about 1.1 GB once installed. It runs as a `specialUse` foreground service, so Android 15's 6-hour limit does not apply (`AndroidManifest.xml:101-116`). A dropped network resumes.
- *Limits, which the screen must say before the button:*
  - 64-bit only. On any other CPU the arm64 Ubuntu is downloaded anyway, and Node exits 64 partway through (`BuiltinLinux.kt:751-760`, `components.dart:210`).
  - Free space is not checked before starting. "No space" is only recognised after a failure (`setup_engine.dart:1035,1067`).
- *Undo:* "Remove from this phone" **deletes every project on the phone** (`app_en.arb:19025`). No single tool can be removed, even though `removeScript` exists for Python and AI Team (`setup_contract.dart:50`, `components.dart:67,114`): nothing ever calls it.
- *Today:* the working path. But the older four-step `builtin-server-setup` screen can still be reached (`main.dart:1636`). And the Terminal's "This phone" source quietly falls back to the server when Linux is missing, without offering setup (`terminal_screen.dart:135-146`).

**Claude Code on this phone, and mixing it with OpenCode (`claude.local`).**
- *Discover:* only the "Claude Code · Optional" row on the Termux page (`termux_setup_screen.dart:2365-2376`), and search on any Android phone (`search_index.dart:979-990`).
- *Expect:*
  - About 60 MB to download, about 1 GB installed, 2 GB free needed (`app_en.arb:17701`).
  - 10–20 minutes under proot.
  - A Claude subscription or API key.
  - The Paseo daemon, Node and one process per conversation, all counted against the phone's 32-process limit together with OpenCode and any team.
- *Undo:* keeps projects and the Claude sign-in unless "forget sign-in" is chosen (`local_agent_runtime.dart:340`, `app_en.arb:17953`).
- ***Today: a dead end.*** On an in-app phone the page says "Finish the On this phone setup first" and offers only Refresh. `onOpenPhoneSetup` is never passed by any caller (`local_agent_onboarding.dart:202,779-800`). Even after setup v2 it can never proceed, because the installer runs only through Termux.
- *Target* (owner: "inline with installation v2 … users who started with OpenCode and now want to mix both"): a `claude` component in Add tools for either phone host. A sign-in row waits for the person. The job ends by saving "This phone · Claude Code" next to "This phone · OpenCode".

**AI Team (`team.on`, `team.phone`, `team.control`).**
- *Discover:* the door on the Work tab, which folds to one quiet row once seen (`team_discover.dart:152-190`); Settings › AI Team; the discovery card.
- *Expect:*
  - About 115 MB on arm64: Gas City 26 MB, Beads 46 MB, Dolt 41 MB (`aiteam_scripts.dart:62-132`).
  - About 2.5 minutes to install, then "Turn on for {project}".
  - The heaviest load a phone can carry. The thermal guard pauses the team at SEVERE, stops it at CRITICAL, and resumes after 2 minutes of cool (`thermal_guard.dart`).
  - A lean tuning keeps it under 32 processes; before tuning it peaked at 37 (`builtin_team.dart:119-160`).
  - Every agent spends model tokens.
- *Limits:*
  - Termux needs a 64-bit phone and a manifest. When those are missing, the Work entry is **hidden silently** (`team_discover.dart:186-190`).
  - A team on a computer without its host front is read-only from the phone.
- *Undo:* the in-app team can only be **stopped**. There is no turn-off and no remove (`builtin_team.dart:639-787`). The Termux team has a Remove sheet.
- *Today:* the Plugins sheet says "Off" twice and offers only "Add manually" (`plugins_screen.dart:502-509`). The owner said "Align with v2".

**OpenCode 2 (`server.oc2`).**
- *Discover:* This phone ⋯ › Switch to OpenCode 2.
- *Expect:* about 50 MB and about 2 minutes. Conversations stay with the profile of the runtime they were made on (`setup_finish.dart:38-47`).
- *Limits:* the feature table above.
- *Today:* features that exist on only one runtime **vanish without a word**. For example, the Spent tab (`usage_hub_screen.dart:44`).

**Model sign-in (`model.auth`).**
- *Today:* discovered only after a reply fails, through the auth error card (`message_view.dart:1993`). The catalog and the model picker never offer to sign in.
- *Target:* the composer's model chip reads "Sign in to a model" before the first send.
- Codex signs in on its account page. Paseo signs in on its host.

**MCP (`mcp.any`).**
- *Today:* only a technical form. It detaches unless the server has `mcpConfigWrites` or `mcpRuntimeAdds` (`mcp_setup_screen.dart:43-70`), and is hidden on Codex and Paseo.
- *Expect:* on a phone host, a local MCP server is one or more extra processes inside the phone's Linux and needs the Node or Python component. On OpenCode 2 an added server is lost when the server restarts.
- *Target, per the owner:* two doors to one list: the technical form, and "Ask the agent" ("I want X installed"). A provider or registry list shows servers as toggles.

**Voice (`voice.model`).**
- *Today:* a working path at the moment of need (`voice_ui.dart:19,843`).
- *Expect:* 104, 160 or 375 MB, gated on 1, 1.5 or 3.4 GB of total RAM (`model_manifest.dart:63-145`, `model_manager.dart:162-168`). Recordings are capped at 30 seconds (`audio.dart:11`); the owner wants that reworked.
- Metered network, full storage and the app being killed mid-download are not named states.

**Tailscale, notifications and battery.**
- Tailscale is offered in the editor ("Not on the same network?"). The app can only hand off to the Tailscale app and cannot check the tunnel (`tailscale_setup_screen.dart:12`).
- Watching a computer in the background uses `dataSync`, which Android 15+ caps at 6 hours per 24 (`app_en.arb:4512,4524`).
- A denied notification permission is not detected.

**Quota collector (`quota.collector`).** The page asks for consent, but the app has no way to get the collector. Either make it a component with a computer guide, or say plainly "needs the quota collector on {server}".

## 3. Target setup model: one installer, a component graph

Setup v2's engine already takes any set of component ids, resumes through check scripts, and gets real progress from its `::oc` protocol. The target adds components and a host choice, and makes everything installable on the phone go through it.

```
linux (in-app) ─┐                              ┌─ python ─────────┐
                ├─ essentials (Git, SSH, CA) ──┤                  ├─ mcp:<local server>
termux ★ ───────┘                              └─ node ─┬─────────┘
                                                        ├─ opencode(runtime=oc1|oc2, version) ─ start ─ signin.model ★ ─ battery ★
                                                        │        └─ aiteam (+ essentials) ─ "turn on for project"
                                                        └─ claude (Paseo + Claude Code) ─ signin.claude ★ ─ second profile
voice:<pack> (app files, no Linux)       ★ = a step that waits on the person (proposed KitActionStep)
```

Components that exist today are marked in `capabilities.json › setupModel.components`: linux, essentials, python, node, opencode, start, aiteam. `claude`, `mcp:*`, the person steps, and Termux as a host are the target. Voice keeps its own downloader but should report through the same progress view and notification.

**Flows:**
- **First setup.** A pre-flight (CPU, free space, RAM) comes before the button. After Ready, "Connect a model" and "Let it keep running" appear as the last rows.
- **Add tools.** This phone ⋯ › Add tools opens the Customize sheet in add mode, with size and time totals. Progress then shows only the new components.
- **Mix both.** Add Claude Code, and a second profile appears on the same phone. The server switcher lists both. A process-budget line warns when OpenCode, a team and Claude Code together approach 32.
- **Switch runtime and update.** Both re-run `opencode` with parameters. They exist today.
- **Switch host.**
  - Termux to in-app: run setup v2; the two coexist.
  - Target: "Bring my projects from Termux" before removing Termux. Nothing migrates projects today.
  - In-app to Termux: Other ways.
- **Remove.**
  - Per component, running `removeScript` and blocked while something depends on it.
  - The whole host, after offering "Keep my projects?" (export) first.
- **Computer side.**
  1. Choose the agent. The editor shows the exact command: `opencode2 pair`, `paseo`, or the Codex token.
  2. Connect, and end with a "ready" moment (missing today).
  3. Optionally set up Tailscale.
  4. Optionally run Gas City on the computer, plus the host front if the phone should control the team.
  5. Optionally add a second agent on the same computer ("They run side by side", `app_en.arb:17969`).

## 4. Discoverability rules

1. **At the moment of need.** Offer a missing capability where its feature would be: the Terminal's phone source, the composer before the first send, the Claude Code result in search, the team door on Work. Settings shows state; it is never the only path.
2. **Once per screen.** Exactly one row or notice per capability on any one screen. This fixes the Plugins sheet's "Off" shown twice.
3. **No dead ends.** Any "finish X first" carries the button that does X.
4. **Nothing vanishes silently.** When the host can't do something, one muted line says which host can ("Files aren't available on Codex — open them on the computer"). Today the Project tab, Files, Terminal, Review, MCP and Providers just disappear on Codex and Paseo (`home_screen.dart:120-132`, `chat_screen.dart:5070`).
5. **Cost before the tap**, taken from the component registry: download size, installed size, time, sign-in or subscription, heat, and "uses part of the phone's background process budget".
6. **Pre-flight before download.** CPU, free space and RAM are checked first. An unsupported phone is told before installing, never after a failure.
7. **One installer UI.** The Termux wizard, the team onboarding steps, the Claude Code panel and `builtin-server-setup` all merge into setup v2's progress view (owner: "unify all installation into v2").
8. **Never nag.** "Not now" folds an offer into one quiet row for that capability and server (the `TeamDiscoverMemory` pattern). Offer again only when the context changes.
9. **Automation first.** Configuration jobs (MCP, providers, settings) offer "Ask the agent" beside the form.
10. **Honest undo.** Before anything is deleted, say what survives: projects, sign-ins.

## Worst dead ends found

1. **Claude Code on an in-app phone** is unreachable. The page offers Refresh only, is reachable from search, and depends on Termux (`local_agent_onboarding.dart:779-800`, `search_index.dart:979-990`).
2. **Removing "This phone" deletes every project**, and no single tool can be removed; `removeScript` is never called.
3. **The in-app AI Team can't be turned off or removed**, only stopped.
4. **No check for CPU or free space before downloading.** An unsupported phone fails partway through.
5. **Codex and Paseo quietly drop about ten areas**, with no line saying why.
6. **Model sign-in** is discovered only after a failed reply.
7. **The quota collector** has no way to be obtained at all.
8. **"No project selected" has no chooser** (`project_hub_screen.dart:301`).
