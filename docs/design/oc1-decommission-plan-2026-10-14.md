# Retiring OpenCode 1: plan (2026-10-14)

**Owner request:** "I want to start planning decommissioning opencode 1."

**Status:** proposal; nothing is built yet. The facts below come from a code inventory of `int/ui-batch-2026-10-14` and the npm registry on 2026-10-14.

## Where we stand

- **Upstream does not force a date.**
  - OpenCode 1 (`opencode-ai`) published 1.19.0 on 2026-10-11 and a dev build on 2026-10-13. It is not deprecated.
  - OpenCode 2 (`@opencode/cli`) has been stable since 2.0.0 (2026-09-11); the latest is 2.0.29.
  - Retiring OpenCode 1 is our choice, not a deadline.
- **Most people's own computers still run OpenCode 1** (`opencode serve`). Dropping the OpenCode 1 *client* cuts them off until they upgrade. Dropping the OpenCode 1 *installs* (phone, Termux, BYO bundle) does not.
- **Code size.** About 10k hand-written lines are OpenCode 1 only:
  - `lib/api/`: 8.0k lines; `opencode_api.dart` alone is 1,498, and `product_repository/` is 1.9k.
  - `tool/sdk/`: 7.8k lines.
  - about 42 `ServerFlavor.v1` branches in about 44 files.

  On top of that:
  - the generated SDK `packages/opencode_sdk` (147k lines, 1,886 files);
  - the OpenCode 1 spec in `contracts/`.

  About 60 test files are mostly OpenCode 1, and about 300 touch its client through fakes.
- **Not everything in `lib/api/` is OpenCode 1.**
  - `models.dart` holds shared types that `lib/api2/` and the UI still map onto.
  - `mcp_oauth.dart` is used by `lib/api2/`.
  - `contracts/` also holds the OpenCode 2 and Gas City specs.

## What blocks the switch

| # | Gap | Today on OpenCode 2 | Way forward |
|---|---|---|---|
| B1 | **Chat history** | Switching gives OpenCode 2 its own data folder; old chats stay behind. Nothing in the app migrates them. | The OpenCode 2 server has `GET /api/experimental/migration/v1` (a v1→v2 history import with progress). Wire it into the switch flow, pointed at the OpenCode 1 data. |
| B2 | **AI Team / Gas City** | Gated on `flavor == v1` (`phone_team_setup.dart:95`, `:144`). | Lift the gate and prove a team run on OpenCode 2 on the emulator. |
| B3 | **Undo (revert)** | `revert/stage` and `revert/clear` are mapped; `revert/commit` is never called. | Wire and test commit; it is the top gap in `docs/opencode2-capability-gaps-ux.md`. |
| B4 | **Provider sign-in** (e.g. the ChatGPT device code fixed today) | Not visible in `lib/api2/`; there is a security note about account OAuth over Basic auth. | Verify on 2.0.29, then build or accept. |
| B5 | **The capability table is stale** | `api2ServerCapabilities` was checked against beta-18600, not stable. | Re-probe 2.0.29 before deciding anything below. |

**Lost or changed on OpenCode 2** (decide each: build, wait for upstream, or accept the loss):
- share, archive;
- the session todo list (feeds the new tasks chip);
- message delete;
- text and symbol search, language-server and formatter status, tool inventory;
- managed workspaces, worktree create and reset, session steal, console organizations;
- MCP OAuth, MCP chat tool refresh, MCP config writes;
- shell settings, remote upgrade, client diagnostics, git init;
- provider runtime refresh, configured-provider fallback.

**Gained on OpenCode 2:**
- forms and the inbox;
- runtime MCP add and remove;
- integration credentials;
- plugin inventory;
- web search.

## Phase 0 result (2.0.29 probed live, same day)

Evidence: `docs/qa/oc2-2.0.29-probe-2026-10-14/README.md`.

- **B1 history: solvable.**
  - OpenCode 2 runs the v1→v2 migration itself on every start. It converts the V1 tables in its own `$XDG_DATA_HOME/opencode/opencode.db`; `migration/v1` only reports progress.
  - Proven: OpenCode 2 started on a copy of an OpenCode 1.19.0 database, reported `completed` in seconds, and the chat came across.
  - The switch must copy `opencode.db`, with its `-wal` and `-shm` files, into the OpenCode 2 data folder before OpenCode 2's first start. Today's isolated folder is why chats stay behind.
  - Untested: large histories, and a V1 database added after V2 already marked the migration done.
- **B3 revert commit: available.** `POST /session/{id}/revert/commit` returns 204.
- **B4 provider sign-in: available.** `POST /integration/{id}/connect/oauth` returned a real ChatGPT device code. Poll, complete and cancel all exist.
- **Also available now:**
  - git init (`POST /vcs/init`);
  - worktree create (`{projectID, name}`);
  - shell settings (`GET /config/shell` + `PATCH /experimental/config`; pick only from `acceptable`).

  Flip `gitInit`, `worktreeCreate` and `shellSettings` to true after a widget test each.
- **Still missing on 2.0.29:**
  - the session todo list, share, archive, message delete;
  - text and symbol search (`fs/find` is names only);
  - worktree reset;
  - MCP OAuth and MCP config writes;
  - LSP and formatter status, tool inventory;
  - workspaces, session steal, console organizations;
  - remote upgrade, client diagnostics.

  Provider runtime refresh is only a whole-server `POST /location/reload`.
- **B2 AI Team** was the one blocker without an answer. **Update (same day, evening):** answered and built.
  - **Live proof on 2.0.29:** a real model turn (Z.ai `glm-5.3-flash`, PC scratch server) proved the per-session permission boundary. With read-only rules, a real read runs and a real shell call is refused (`permission.rejected`). With worker rules, the shell runs. Interrupt stops a running turn. An `ask` rule produces a pending request. The role text reaches the model through a session instruction entry. Evidence: `docs/qa/aiteam-oc2-probe-2026-10-14/`.
  - **Code** (merged on this batch): the Rust phone engine has an OpenCode 2 driver beside the unchanged OpenCode 1 one (`engine/phone/src/opencode2.rs`). Team setup accepts an in-app OpenCode 2 server through capabilities, and the app's OpenCode 2 pin moved from 2.0.28 to 2.0.29 (tarball hashes checked against npm). Contract: `docs/design/aiteam-oc2-contract.md`.
  - **Still open:** an emulator team run on OpenCode 2. This is native code, so it ships in a new Shorebird release, not a patch.

## Proposal: two tiers

**Tier 1: stop installing OpenCode 1** (what we control, low risk). Phone, Termux, the BYO bundle and the agent installers all move to OpenCode 2. People keep their OpenCode 1 servers on their own computers, and the app still connects to them.

**Tier 2: stop speaking OpenCode 1** (remove the client). Do this only when upstream announces an end date, or when OpenCode 1 servers are rare among people who use the app.

### Phases

| Phase | What | Release kind | Exit check |
|---|---|---|---|
| **0. Re-probe** | Probe 2.0.29 for every capability flag and fix the table (B5). Sort each lost feature into build / wait / accept. | none | An updated gaps doc that the owner signs off. |
| **1. Close blockers** | B1 history import in the switch flow; B2 AI Team on OpenCode 2; B3 revert commit; B4 provider sign-in. Build the "build" items from phase 0. | Dart, so patchable | Emulator proof per item; the owner's chats survive a switch. |
| **2. Flip defaults** | New in-app installs, Termux setups and agent installers default to OpenCode 2. Rebuild the BYO bundle on OpenCode 2. OpenCode 1 stays selectable as "Older OpenCode". The native default lives in Kotlin (`components.dart:23`, `NativeServerRecipe.kt`, `BuiltinLinux.kt`). | **New Shorebird release** | Fresh setup on the emulator lands on OpenCode 2. |
| **3. Move people over** | A phone or Termux server still on OpenCode 1 shows one quiet line on its own page, "Move to OpenCode 2", with a one-tap switch that imports history (B1). No nag elsewhere. | Patch | The owner's phone is moved. |
| **4. Freeze** | No new feature is gated on v1. The OpenCode 1 install path stays for those who chose it. | — | — |
| **5. Remove the installs** | Delete the OpenCode 1 install branches: in-app, Termux, the gen-UI `openCodeV1` paths, the agent catalog entry. | New release | The Tier 1 finish line. |
| **6. Remove the client** (Tier 2, later) | Delete `lib/api` OpenCode 1 code, its generated SDK and spec, `tool/sdk` and the v1 branches. Move the shared types to `lib/domain`. An OpenCode 1 server then shows "This server runs an older OpenCode; update it to keep using it here." | New release | Upstream end date, or a usage signal. |

## Risks
- **History loss** is the one thing people would not forgive. Phase 3 must not ship before B1 is proven on a real phone with real chats.
- **Old app versions** keep talking OpenCode 1. That's harmless until Tier 2.
- **Profiles saved before flavor detection default to v1** (`profiles/models.dart:238`). Tier 2 needs a probe-on-open, not a blind default.
- **Native changes** (phases 2 and 5) need new releases, which need explicit approval; Dart-only steps can ship as Shorebird patches.

## Decisions for the owner
1. **Scope:**
   - **(A) Tier 1 now, Tier 2 later** (recommended).
   - **(B)** Both now, which cuts off people whose computers still run OpenCode 1.
2. **Is history import (B1) a must before flipping defaults?**
   - **(A) Yes** (recommended).
   - **(B)** No; start fresh, with old chats only on the old server.
3. **After phase 0:** accept, build or wait for each lost feature (a list for you to tick).

### Decided (2026-10-14, evening; the owner delegated: "you decide on my behalf on the open items")
1. **Scope: (A).** Tier 1 now, Tier 2 later.
2. **History import before flipping defaults: (A) yes.** B1 is built and proven on the emulator.
3. **Lost features: build whatever OpenCode 2 can do, and accept the rest until upstream adds it.**
   - **Build:** revert commit, provider sign-in, git init, worktree create and shell settings. These are flipped or wired already.
   - **Accept for now:** todo, share, archive, message delete, text/symbol search, and MCP OAuth/config writes. Each stays hidden behind its capability flag, not removed.

**Order:**
- Phase 2 (flip defaults) does not start until the emulator AI Team run on OpenCode 2 passes. The first run, APK 2315, failed with two P0s, recorded in `docs/qa/aiteam-oc2-emulator-2026-10-14/`. Fixes are in progress.
- Phases 2 and 5 are native changes, so they still need explicit approval before any release.
