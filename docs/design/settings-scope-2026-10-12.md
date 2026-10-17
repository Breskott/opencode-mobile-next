# Settings ownership and scope — 2026-10-12

**Status: research and proposed contract, not implemented or runtime-qualified.** Source baseline: `5ebe8a496b60158d5bf0c737fdec1442657d5398`. The earlier [IA audit](settings-ia-audit-2026-10-12.md) describes `a07fe4ed9`; current source wins where they differ. No tests, builds, app runs, server calls, commits or source edits were performed. Only this document was created. `HANDOFF.md` is absent at this checkout's root. Existing untracked `h.sh` and `o.txt` were left alone.

**Finish line:** define the owner, target, persistence, inheritance and visible effect of every Settings entry, with a contract and migration plan a state builder and a later UI builder can implement independently. **Non-goal:** implement the redesigned Settings UI, enable unsupported capabilities, provision hosts, or change anybody's configuration.

The owner's answer: **personal presentation choices should work across connections automatically; settings belonging to a server, project, account or host should stay with that named owner.** A person should see “On this phone”, “New chats on Laptop”, or “Everyone using Laptop”, never have to understand the word *scope*. Connecting a second server must not copy credentials, permissions, model choices or operating-system behavior to it. Offer an explicit, reviewable copy operation for advanced use, not invisible synchronization of servers.

## 1. Inventory and verified current behavior

Source references below use repository-relative `file:line` locations at the baseline above. Read-only work was divided into UI/storage inventory, state/runtime ownership, and official external research; the state pass inspected all 51 `connection/*.dart` parts for ownership and persistence, alongside the controller, stores, monitors, background and domain contracts. A page, status, destructive action or search alias is recorded as such; it is not invented as a persisted preference. “Correct” means an appropriate ownership boundary by source inspection, not that runtime behavior passed tests. The supplied IA audit and the owner's listed standard dimensions are the standard context; no separately supplied draft standard text is being silently amended.

### 1.1 Findings that change the design

- The Settings **Model** picker writes `oc.model.<profileId>`, `oc.modelExplicit.<profileId>` and `oc.variant.<profileId>` on this phone; it does not edit the server's configured default. Calling this “Server default” after an explicit choice is misleading (`lib/state/connection/models.dart:432`; `lib/state/profiles.dart:62`).
- OC1 chat model overrides are local per-profile/session records; OC2/Paseo session selection is server-owned through `SessionSelectionGateway`. OC1's chat agent setter falls back to the profile agent setter. Model, agent and variant must not be presented as one uniformly scoped operation (`lib/state/connection/models.dart:277`, `:372`, `:394`).
- The default shell is genuinely **server-global** in OC1: global config read, update and read-back. It sits next to phone-global transcript switches today (`lib/api/product_repository/ops_dev.dart:182`, `:210`; `lib/ui/search/search_index/hub_rows.dart:193`).
- MCP has three distinct meanings already: runtime-location activation, persisted project configuration and persisted global configuration. OC1 handles all three; a runtime-only addition is not a saved configuration (`lib/api/product_repository/ops_catalog.dart:316`).
- Read-state sharing is a phone-global preference behind a current-server capability gate. Phrase suggestions combine a phone-global enable switch with profile-owned learned/hidden data. Both need clearer owner copy before any storage migration (`lib/state/connection.dart:434`; `lib/state/connection/read_state.dart:91`; `lib/ui/screens/settings/phrase_chips_row.dart:18`).
- Several connections can have independent state. That does **not** authorize background watching of every saved connection. Monitor support and explicit monitoring consent are separate (`lib/state/profile_monitor.dart:153`, `:517`).
- The implemented home-screen widget is a **recent-sessions widget**, not the proposed multi-source Usage widget. Its single `oc.widgetSessions` snapshot records an owning profile and at most four sessions, and deletion explicitly clears it (`lib/background/widget_snapshot.dart:29`, `:59`, `:111`). Searches of `lib/` and Android source found no Usage widget or `PaseoUsageMonitor` implementation. FactsBook remains a future requirement in this design, not a verified current feature.

### 1.2 Coverage ledger: hub and search

The current index contains **81 entries: 21 hub rows, 43 inner-settings entries and 17 navigation destinations**. Thus the “~60 search-only entries” include destinations and aliases, not 60 additional preferences. Assembly is `lib/ui/search/search_index.dart:412`. `H` below means `lib/ui/search/search_index/hub_rows.dart`; `I` means `lib/ui/search/search_index/inside_pages.dart`; `P` means `lib/ui/search/search_index/places.dart`. All settings behind these doors are expanded in §1.3–1.5. A duplicate door shares its destination's storage and owner.

| Hub entry / ID | Entry evidence | Current scope and truth owner | Assessment / expanded inventory |
|---|---|---|---|
| This server / `settings-category-server` | H:9 | Selected controller profile; local connection record plus remote facts | Ambiguous “this”; use named owner; §1.3. |
| Saved servers / `settings-saved-servers` | H:23 | Device profile registry and secure sign-ins | Correct; profile is not necessarily unique server. |
| In-app Ubuntu / `settings-this-phone` | H:40 | Host runtime on this phone | Single-host naming hides Termux alternative; §1.5. |
| Agents / `settings-agents` | H:54 | Phone-host agents | Say “On this phone”; not selected remote server. |
| Model / `settings-model-and-mode` | H:83 | Local per-profile preference | Misleading server-default label; §1.3. |
| Providers and accounts / `settings-providers` | H:96 | Server-owned credentials, or host account session | Same row changes destination based on capability; name target and account kind. |
| Tools / `settings-tools` | H:119 | Server/project/runtime tools plus local external agents | Mixed owner; sections must disclose it. |
| AI Team / `settings-ai-team` | H:138 | Local connection binding, engine/project configuration, host settings | Not one app-wide toggle. |
| Show reasoning / `settings-show-reasoning` | H:196 | Device preference | Correct intended scope; cross-controller cache risk below. |
| Show timestamps and usage / `settings-show-timestamps` | H:208 | Device preference | Same; rename to time/tokens/cost. |
| Default shell / `default-shell-settings-entry` | H:221 | OC1 server-global config | Wrong implication beside personal toggles; §1.3. |
| Phrase suggestions / `settings-phrase-chips` | H:239 | Global enable, profile-owned learned corpus | Mixed scope not explained. |
| Voice / `settings-voice` | H:249 | Device pack/language/files | Correct device resource. |
| Notifications and background / `settings-category-background` | H:262 | Device delivery, profile monitoring, host/OS controls | Split into named concerns; §1.4–1.5. |
| Appearance / `settings-category-appearance` | H:291 | Device preferences | Correct. |
| Privacy and data / `settings-category-privacy` | H:303 | Device consent plus local data across profiles | Global read sharing/current-target presentation is ambiguous. |
| Usage / `settings-category-usage` | H:317 | Server/project consumption, provider-account quota, local policies | Aggregation page, not one setting owner. |
| Setup guide / `settings-setup-guide` | H:331 | Static help/demo navigation | No stored setting. |
| Report a problem / `library-report-bug` | H:343 | Device diagnostic records/actions | No server configuration; redact included facts. |
| Available on this server / `settings-server-capabilities` | H:359 | Read-only connected target capability snapshot | Must name target; no global scope. |
| About / `settings-about-notices` | H:374 | App build/assets/help and tip-reset action | Device/app ownership. |

Every inner-settings search entry, including aliases:

| Entry IDs | File:line | Ownership/control mapping |
|---|---|---|
| `settings-on-this-phone` | H:69 | Host setup action; §1.5. |
| `settings-automation` | H:157 | Profile automation policy; §1.3. |
| `saved-permissions-entry` | H:181 | Server project grants; §1.3. |
| `settings-keep-running` | H:274 | Device/host controls; §1.5. |
| `settings-tailscale` | H:388 | Device Tailscale handoff / local connection setup; no server config setting. |
| `settings-models` | H:399 | Same model picker/local profile preference. |
| `settings-accounts` | H:417 | Host agent account API. |
| `settings-mcp` | H:432 | Target runtime/project/global MCP operation. |
| `settings-commands-tools` | H:453 | Server catalog/inventory. |
| `settings-server-plugins` | H:472 | Server plugin inventory. |
| `settings-external-agents` | H:491 | Local external-agent registry and secure bearer. |
| `settings-privacy-data-use` | H:514 | Static privacy policy. |
| `settings-try-demo` | H:529 | Demo navigation; no real server preference. |
| `library-keyboard-shortcuts` | H:540 | Static help. |
| `settings-show-tips-again` | H:552 | Device nudge history reset. |
| `settings-voice-notices` | H:568 | Bundled voice licences; no setting. |
| `inside-server-disconnect`, `inside-server-ai-setup` | I:10, I:35 | Local connection disconnect; read-only remote config inspection. |
| `inside-notifications-what`, `inside-notifications-quiet` | I:63, I:83 | Device event delivery and quiet hours. |
| `inside-notifications-background`, `inside-notifications-servers` | I:104, I:124 | Device connection service; per-profile monitor enrollment. |
| `inside-appearance-mode`, `inside-appearance-language`, `inside-appearance-theme` | I:150, I:169, I:188 | Global display/language/theme. |
| `inside-appearance-motion`, `inside-appearance-glow` | I:207, I:208 | Global effects; definitions `lib/domain/settings_search_catalog.dart:28`. |
| `inside-keep-running-battery`, `inside-keep-running-thermal` | I:211, I:217 | OS app permission and device thermal guard; definitions `lib/domain/settings_search_catalog.dart:39`. |
| `inside-usage-spent`, `inside-usage-budgets` | I:222, I:239 | Target consumption view and local scoped budget. |
| `inside-usage-remaining`, `inside-usage-quota-monitoring` | I:256, I:276 | Account observations and source monitoring. |
| `inside-capabilities-commands`, `inside-capabilities-tools` | I:296, I:313 | Server/project catalog; primarily inspection/navigation. |
| `inside-capabilities-skills`, `inside-capabilities-references` | I:330, I:346 | Server/project inventory; supported edits retain native target/lifetime. |
| `inside-phone-running-now`, `inside-phone-storage` | I:362, I:373 | Host processes/files, not active laptop. |
| `inside-phone-crash-recovery` | I:383 | Host recovery control; definition `lib/domain/settings_search_catalog.dart:66`. |
| `inside-phone-claude-code`, `inside-phone-claude-code-unavailable` | I:389, I:409 | Mutually exclusive supported/unavailable doors to phone agent. |
| `settings-add-server` | I:420 | New local profile/secure sign-in, not a remote config preference. |

The other 17 entries are accounted for rather than mislabeled as preferences: `library-import-session` (H:501, writes a session to the explicitly targeted capable server); `tab-chats`, `tab-files`, `tab-settings` (P:8, P:18, P:29, navigation only); `project-files`, `project-changes`, `project-terminal`, `project-health`, `project-worktrees`, `project-services`, `project-workspaces`, `project-search` (P:39, P:52, P:63, P:74, P:85, P:98, P:109, P:120, current named project operations); `all-conversations`, `archived-conversations` (P:132, P:149, target server views); `ai-team-agents`, `ai-team-project-demo`, `ai-team` (P:167, P:193, P:205, team roles/setup below or simulated demo).

### 1.3 Connection, model, tools, team and permission controls

`S` in storage cells means SharedPreferences on this installation, `K` means secure storage, `R` means remote API/host authority. “No preference” distinguishes a read/action from persistent user intent.

| Controls, including inner-page fields | Storage today and evidence | Effective owner/scope and verdict |
|---|---|---|
| Saved server name, address, username, backend/flavor, project/engine binding; active connection | S `oc.profiles`, `oc.activeProfile`; `lib/state/profiles.dart:51`; serialization `lib/state/profiles/models.dart:246` | Device's connection records. Correct; backend/version is observed/cached information, not blanket capability authority. |
| Change server sign-in; socket token; AI Team engine sign-in | K `pw.<id>`, `oc.codexToken.<id>`, `oc.teamEngineAuth.<id>`; `lib/state/profiles.dart:58`; page `lib/ui/screens/settings/server_settings_screen.dart:401` | Device credential binding to one target, distinct from provider account credentials. Correct; do not export. |
| Private HTTP confirmation | S `oc.cleartextOk.<profileId>`; `lib/state/profiles.dart:54` | Consent for a confirmed origin on a connection. Never inherit/copy as general preference. |
| Default/last/recent project; show other server's chats | S `oc.location.<id>`, `oc.recentLocations.<id>` (`lib/state/profiles.dart:70`), `oc.defaultProject.<id>` (`lib/state/interaction_defaults.dart:301`), `oc.lastProject.<id>` (`lib/state/connection/chat_feed.dart:8`), `oc.chatListShown.<id>` (`lib/state/connection/side_connections.dart:33`) | Connection-local navigation/launch defaults, not project configuration. Correct boundary; keep separate from Settings editor context. |
| Model for new chats, thinking variant, agent | S `oc.model.<id>`, `oc.modelExplicit.<id>`, `oc.variant.<id>`, `oc.agent.<id>`; `lib/state/profiles.dart:62`; `lib/state/connection/models.dart:432` | Local connection default. Current catalog fallback: explicit valid model → location config → provider default → first catalog (`lib/state/connection/catalog.dart:650`). Label/implicit fallback needs revision. |
| Favorite/recent models | S `oc.modelLibrary.<id>`; `lib/state/profiles.dart:69`, `:845`; `lib/state/connection/models.dart:473` | Local connection catalog preference; sensible availability boundary. |
| Chat model and variant | S `oc.sessionModels.<id>` for OC1; R session selection through `SessionSelectionGateway` for OC2/Paseo; `lib/state/connection/models.dart:83`, `:383` | Same-looking picker has different truth owner. Show chat owner and confirmed selection. |
| Chat agent/mode | `lib/state/connection/models.dart:372`; OC1 falls back to profile-wide `selectAgent`; agent runtimes use supported session semantics | **Wrong to promise chat-only uniformly.** Add OC1 chat-agent state or accurately name wider effect; never translate mode/agent as interchangeable. |
| Providers: key, sign-in method, connect, disconnect, reload | R OC1 integration credential plus legacy auth writes/reload (`lib/api/product_repository/ops_integrations.dart:204`, `:232`); R OC2 (`lib/api2/gateway_operations/ops_integrations.dart:123`) | Server credential/config owner with location context. Environment-provided OC2 credentials cannot be removed by this API (`:138`). “Disconnect” must say what source remains. |
| Provider credential: Use this account, rename label, remove stored credential | R location-bound OC2 credential PATCH/activate/DELETE; `lib/api2/gateway_operations/ops_integrations.dart:77`; UI `lib/ui/screens/library/credential_sheet.dart:175`, `:229`, `:369` | Server-owned stored credential and activation, not a phone-global account choice. Rename changes a credential label, not verified provider account identity. |
| Codex account sign-in/cancel/refresh, usage/limits | R `AgentAccountGateway.openAccountSession()`; `lib/ui/screens/agent_account_screen.dart:62`, `:92`, `:233`, `:375`, `:541` | Host/runtime account identity; usage read-only. Not a global phone provider account selector. |
| MCP name, command/URL, environment, headers, timeout, target; add/connect/disconnect/auth/remove | R OC1 runtimeLocation/project/global (`lib/api/product_repository/ops_catalog.dart:317`); R OC2 runtime location (`lib/api2/gateway_operations/ops_catalog.dart:150`, `:173`) | **Persistence differs:** OC2 add survives only current runtime; OC1 can persist project/global. Activation, authentication, runtime removal and config deletion need different words. Secret fields never enter generic exports. |
| Commands, tools, skills, references | R target catalog/inventory; doors I:296–346; Tools schemas/details `lib/ui/screens/tools_screen.dart:338`; References details/copy or chat mention `lib/ui/screens/library/references_screen.dart:167` | Current Settings pages are inspection/preview, not generic config editors. Backend config methods such as `lib/api/sv3_tool_configuration.dart:98` do not prove an exposed setting. No generic app-wide tools boolean. |
| Tools: Choose model; tool search | Shared picker changes `controller.selectedModel`, then reloads inventory; `lib/ui/screens/tools_screen.dart:117`; transient search `:54`, `:166` | **Choose model changes the local connection default**, not just a temporary inventory filter. Make the side effect explicit or introduce a true view-only filter. |
| Skills: Rendered / Raw; Run agent now | Transient sheet display/`resume` choice; `lib/ui/screens/library/skill_activation.dart:172`, `:108`, `:221` | Rendered/Raw is not expertise mode. Settings-origin skill view is preview/copy; Run agent now exists only with a supplied chat target and affects that chat. |
| External agent name/address/protocol; bearer; remove | S `oc.externalAgents`, task state `oc.a2aTasks.<agentId>`; K `oc.a2aBearer.<agentId>`; `lib/state/external_agents.dart:14`, `:100`, `:129`, `:224` | Local registry with independent agent identity/deletion. Not swept merely by deleting a server profile; explicit ownership needed. |
| AI Team enable/host/address/engine binding/upkeep | S profile orchestration JSON, K engine auth; `lib/state/profiles/models.dart:79`, `:246`, `:287`; page `lib/ui/screens/team/team_settings_screen.dart:415` | Mixed connection-to-engine binding and host operations. Team controller integrated per profile (`lib/state/connection/team.dart:99`); do not call current Team just planned. |
| Team model | Host `BuiltinTeam().applyModel` then S `oc.teamModel.<id>`; `lib/ui/screens/team/team_settings_screen.dart:133`, `:161`; `lib/state/team_model.dart:24` | Host model effect plus local receipt. A profile key does not make the host effect isolated to that profile/project. |
| Team role name/purpose/instructions/model, task-role assignment | S `oc.teamRoles.<id>`, `oc.teamTaskRoles.<id>`; `lib/state/team_roles.dart:42`, `:238`; dispatch `:493` | Local profile roles sent to engine tasks; in-app role model changes host model, remote team's host chooses model. **Protocol/host semantic difference.** |
| Supervision level for new team tasks, automation permissions | S `oc.automation.<id>`; `lib/state/automation_policy.dart:22`, `:43`; UI `lib/ui/screens/automation_settings_screen.dart:69`, `:279` | Device's authorization for connection; not policy for all clients of that engine. Never auto-copy. |
| Your answers: notification/battery/autostart prompts; offer declined Always allow again | S `oc.inFlowConsent.<id>`, `oc.permissionConsent.<id>`; `lib/state/in_flow_consent.dart:57`; `lib/state/repeated_permission_consent.dart:66`; UI `lib/ui/screens/automation_settings_screen.dart:480` | Per-profile prompt bookkeeping sometimes describing device-wide OS permissions. Distinguish remembered answer from current OS grant. |
| Chat auto-approval and connection-wide approve-everything choice | S `oc.autoApprove.<profileId>`; session entries plus reserved `*` connection entry; `lib/state/connection.dart:343`; `lib/state/session_auto_approval.dart:113`, `:128` | Device policy applied to requests on the selected connection/chat, separate from remote standing grants. Wider `*` choice must be explicit and must not be copied to other connections. |
| Always allowed actions: list and revoke | R current-project grants filtered by project ID; `lib/api/product_repository/ops_session.dart:75`; `lib/ui/screens/saved_permissions_screen.dart:164` | Server/project authority. Paseo can honor persistent grants without an app-readable list; never imply an empty list means none. |
| Default shell / automatic / explicit shell | R OC1 `globalConfigGet/Update` and read-back; `lib/api/product_repository/ops_dev.dart:182`, `:210`; UI `lib/ui/screens/settings/default_shell_row.dart:55`, `:104` | Server-global truth, shared by clients; options enumerated with location. OC2/Paseo UI support false today. |
| Health/version, recheck agents, plugin inventory, AI setup review | R read-only; `lib/ui/screens/settings/server_settings_screen.dart:364`, `:467`, `:557`; `lib/ui/screens/settings/server_plugins_section.dart:125` | Named server facts, not editable preference. Setup Apply/Undo unavailable; do not promise generic config editor. |
| Run as Linux service; server update/restart | R host mutation; `lib/ui/screens/settings/server_settings_screen.dart:487` | Affects shared running service, not just mobile connection. Name host and impact. |
| Disconnect / Remove server | Local controller lifecycle / full deletion; `lib/ui/screens/settings/server_settings_screen.dart:569`; `lib/state/connection/deletion.dart:9` | Removes connection/local data, not remote server, provider account or host installation. Correct distinction must remain visible. |

### 1.4 Personal, privacy, notification and Usage controls

| Controls | Storage today and evidence | Effective scope/owner and verdict |
|---|---|---|
| Show reasoning; show timestamps/tokens/cost | S `oc.transcript.reasoningExpanded`, `oc.transcript.timestampsVisible`; `lib/state/profiles.dart:78`; UI `lib/ui/screens/settings_screen.dart:411` | Device-global intent. Separate controllers may retain stale cached values; see §1.6. |
| Phrase suggestions enable | S `oc.phraseChips.enabled`; `lib/state/phrase_chips.dart:96` | Device-global display preference, correct. |
| Hide / Show hidden phrases | S `oc.phraseChips.<id>` learned/hidden corpus; `lib/state/phrase_chips.dart:136`; UI `lib/ui/screens/settings/phrase_chips_row.dart:18` | Profile-specific data/action behind global-looking row. Name target, keep corpora separate. |
| Voice pack, language, download/remove | S `voice.selected_pack`, `voice.language`; app support `voice_models` files; `lib/voice/model_manager.dart:60`, `:103`, `:202` | Device-wide resource/settings, correct. Download/removal are file actions, not server changes. |
| Light/dark/system; theme | S `oc.appearance`, `oc.themePack`; `lib/state/profiles.dart:80`; UI `lib/ui/screens/settings/personal_settings_screens.dart:95`, `:167` | Correct device preference. |
| Language/system default | S `oc.appLocale`; `lib/state/app_locale.dart:11`, `:32`; UI `lib/ui/screens/settings/personal_settings_screens.dart:125` | Correct device preference; independent of server. |
| Motion Full/Calm/Off and linked celebrations | S `oc.effectsMotion`, `oc.effectsCelebrations`; `lib/state/profiles.dart:83`; UI `lib/ui/screens/settings/personal_settings_screens.dart:400` | Device preference; reduced-motion constraint at `:434` wins in rendering. |
| Glow enabled/style/one or two colors/speed | S `oc.effectsActivityGlow`, `oc.effectsGlowStyle`, `oc.effectsGlowColours`, `oc.effectsGlowSpeed`; `lib/state/profiles.dart:85`; UI `lib/ui/screens/settings/personal_settings_screens.dart:449` | Correct device preference; subordinate controls shown when enabled. |
| Reader source-first/code wrapping (linked Files destination) | S `oc.readerPreferences.<id>`; `lib/state/reader_preferences.dart:6`, `:41` | Today profile-local presentation. Candidate for device default with retained connection overrides; do not flatten existing differences. |
| Sync read state | S global `oc.shareSessionViews`; `lib/state/connection.dart:434`; send gate `lib/state/connection/read_state.dart:248`; UI `lib/ui/screens/settings/personal_settings_screens.dart:621` | **Ambiguous and privacy-sensitive:** global preference shown conditionally for current server; cross-controller cache risk. Recommend explicit connection consent plus shared revocation mechanism. |
| Storage used; clear queued prompts; clear drafts | S shared queue/draft data, actions across profiles; UI `lib/ui/screens/settings/personal_settings_screens.dart:713`, `:747`; cascade `lib/state/connection/deletion.dart:23` | All-profile local data, not just selected server. Name “on this phone” and affected count in confirmation. Storage row is measurement. |
| Privacy policy | Static document; `lib/ui/screens/settings/personal_settings_screens.dart:800` | No stored preference. |
| Finished runs | S `oc.notify.finishedRuns`; `lib/state/notification_preferences.dart:159`, `:188`; UI `lib/ui/screens/settings/notifications_settings_screen.dart:200` | Global preference, comment describes connected-server completions; other-server monitoring uses separate rules. Clarify coverage. |
| Approvals/questions/forms | S `oc.notify.requests`; `lib/state/notification_preferences.dart:160`, `:193`; UI `lib/ui/screens/settings/notifications_settings_screen.dart:211` | Device-wide event delivery default, correct. |
| Check in on long runs; duration | S `oc.notify.checkInAfterMinutes`; `lib/state/notification_preferences.dart:157`; UI `lib/ui/screens/settings/notifications_settings_screen.dart:222` | Shared schedule, not remote server execution policy. |
| Quota threshold notifications | S `oc.notify.quotaAlerts`; `lib/state/notification_preferences.dart:158`; UI `lib/ui/screens/settings/notifications_settings_screen.dart:256` | Global delivery master, distinct from individual source threshold. |
| Quiet hours enabled/start/end | S `oc.notify.quietStart`, `oc.notify.quietEnd`; `lib/state/notification_preferences.dart:154`, `:176`; UI `lib/ui/screens/settings/notifications_settings_screen.dart:284` | Device-local wall clock; null disables; global overlay wins over legacy profile schedule (`notification_preferences.dart:60`). Correct. |
| Wi-Fi only | S `oc.notify.wifiOnly`; `lib/state/notification_preferences.dart:156`; UI `lib/ui/screens/settings/notifications_settings_screen.dart:416` | Shared network policy although shown near per-server controls. Loopback exemption uses no network (`lib/state/profile_monitor.dart:498`). |
| Monitor this server; notify when attention is needed | S `oc.notifyRules.<id>` plus automation consent; `lib/state/profile_monitor.dart:193`, `:491`; UI `lib/ui/screens/settings/notifications_settings_screen.dart:398`, `:434` | Per-connection enrollment/notification intent on this phone; not shared server config. Correct with explicit consent. |
| Send a test notification | Device action, no preference; `lib/ui/screens/settings/notifications_settings_screen.dart:268` | Correct device target. |
| Usage range, all/current project, provider/model filters | Transient view/controller state; `lib/state/usage_overview.dart:51`, `:135`; UI `lib/ui/screens/usage_screen.dart:423`, `:764` | Query against target server/project. Changing view does not change server or provider billing. |
| USD/token consumption budgets: set/remove/clear | S `oc.consumptionBudgets.<id>`, indexed by source hash/project/range/start/timezone/unit; `lib/state/usage_budgets.dart:55`, `:107`; UI `lib/ui/screens/usage_screen.dart:490` | Local comparison budget for this measurement; not enforced spend limit or provider quota. Old `oc.budgets.<id>` is retired (`lib/state/profiles.dart:199`). |
| Remaining quota provider/source selection, trust collector, read now | Screen-visit consent in memory, invalidated by provider/location/identity change; `lib/state/provider_quota_overview.dart:10`, `:136`; UI `lib/ui/screens/provider_quota_screen.dart:530`, `:659` | Provider owns allowance; selected host credential collector supplies observation. One-time read consent is not durable monitor enrollment or verified shared account identity. |
| Quota monitoring enrollment, stop, threshold | S `oc.quotaMonitor.<id>` with per-provider/source entries; `lib/state/provider_quota_monitor.dart:171`, `:317`; UI `lib/ui/screens/provider_quota_screen.dart:301`, `:573`, `:895` | Per-source local monitoring. No verified cross-profile account dedupe; alert markers per source (`provider_quota_monitor.dart:725`). |
| Account-answer “Alert me at 80%” | S `oc.quotaAnswers.<id>` default-on; `lib/state/quota_answer_preferences.dart:7`, `:22`; UI `lib/ui/screens/provider_quota_screen.dart:202`, `:1077` | Separate local preference, not same as monitor threshold/master. Preserve distinction pending consolidation. |
| About version/copy version/signer/licences/components/voice notices/check updates | Local artifact/assets or update action; `lib/ui/screens/about_screen.dart:102`, `:180`, `:235`, `:297` | App-level information/actions; no per-server preference. |
| Show tips again; keyboard shortcuts | S reset `oc.nudges.shown` and related discovery history (`lib/state/nudges.dart:92`, `:221`); UI `lib/ui/screens/about_screen.dart:95`, `:282` | Device discovery preference or static help. |
| Diagnostics/crash reports/exit history/performance trace/report problem | Device diagnostic store/actions, door H:343 | Local diagnostic evidence; selecting a server does not make its raw config safe to include. No server setting. |
| Keep crash reports | App-private `crash-diagnostics-consent`, records `crash-diagnostics.json`, pending/native crash files; `lib/diagnostics/crash_diagnostics.dart:53`, `:200`, `:558`; UI `lib/ui/screens/crash_reports_section.dart:201` | Persisted device-wide opt-in, distinct from submitting a report; disabling erases evidence (`crash_diagnostics.dart:210`). No automatic sync or profile inheritance. |
| Include diagnostics in report | Transient form checkbox; `lib/ui/screens/app_diagnostics_screen.dart:459` | One outgoing report's consent, distinct from capture/storage consent. Changing server does not authorize including its secrets. |
| Performance Copy report / Clear timings | In-memory current-run diagnostic actions; `lib/ui/screens/perf_trace_section.dart:8`, `:47` | Device diagnostic view, not a persistent trace-capture setting or server operation. |

### 1.5 Host and background controls

| Control/action | Storage/authority and evidence | Scope judgment |
|---|---|---|
| Stay connected in background | S `oc.keepLiveInBackground`; `lib/background/live_background.dart:223`, `:269` | Device app-service intent. Does not guarantee remote or local server lifetime. |
| Battery optimization / autostart permission | Android OS permission/settings reached from `lib/ui/screens/settings/notifications_settings_screen.dart:327` and keep-running door H:274 | Device/app OS truth, not a per-server permission. Profile answer records are only prompt history. |
| Termux wake lock | Host request while loopback non-built-in OC and app background choice enabled; `lib/state/connection/connect.dart:155` | Termux host effect; not equivalent to built-in service policy. |
| Pause when hot | S global `oc.thermalGuard` default true, per-team/profile hold `oc.thermalPause.<id>`; `lib/builtin/thermal_guard.dart:263`, `:305` | Device thermal guard over local work; remote servers unaffected. |
| Crash recovery | Termux owner/alias-mirrored S `oc.managedServerRecovery.<id>` (`lib/termux/managed_server_recovery.dart:35`, `:60`); built-in S `oc.builtinRecovery.<id>` plus native state (`lib/builtin/builtin_server_recovery.dart:96`) | Host-runtime policy despite profile-shaped key. Shared aliases must not conflict or delete owner prematurely. |
| Built-in idle policy (state/native contract; not a confirmed independent hub row) | Native `setPhoneServerIdlePolicy(enabled, idleMinutes)`, no profile argument; `lib/builtin/builtin_linux.dart:585` | Built-in host policy. Do not invent per-server idle controls from it. |
| Start/stop; update/reinstall; switch OC1/OC2; retry/return after failed switch | Host process/files/setup transaction; `lib/state/phone_host.dart:80`, `:132`; UI `lib/ui/screens/this_phone_screen.dart:843`, `:1082`, `:1095` | Named installed runtime; affects its clients. Current page selects active host or prefers saved built-in (`:49`), not proof of exclusivity. |
| Add tools / install or remove optional tool / agent sign-in terminal | Installed host component files and agent's own credential authority; UI `lib/ui/screens/this_phone_screen.dart:1115`, `:1213`; phone-agent ownership `lib/state/profiles/phone_agent_owner.dart:3` | Host/agent action; no cross-host copying. Phone agent owner aliases outlive one protocol profile. |
| Phone chat agent choice / model for new agent chats | S `oc.chatAgent.<ownerProfileId>` and `oc.agentModel.<ownerProfileId>` map agent ID → model ID; `lib/state/connection/phone_agents.dart:335`, `:369`, `:1412` | Local preference for the resolved phone-agent owner, which can be the in-app side connection while Termux is primary (`:173`). Not a provider-wide or daemon-wide model config write. |
| Running now / stop a run / storage / export projects / terminal | Host process/files actions; I:362, I:373; UI `lib/ui/screens/this_phone_screen.dart:1134`, `:1147`, `:1189` | Phone host, not current laptop. Export is project data, not settings backup. |
| Termux Storage: Scan / Cancel scan / Clean build caches | Host file actions through `~/.oc/tools.sh`; `lib/termux/storage.dart:2`, `:64`, `:440`; UI `lib/ui/screens/termux_storage_screen.dart:151`, `:186` | No preference; only build caches eligible for cleanup. A selected laptop must not redirect the host action. |
| Remove OpenCode / optional tools | Host removal and dependent-component checks; UI `lib/ui/screens/this_phone_screen.dart:1201`, `:1217` | Different from Remove profile. Explicit host/data retention preview required. |
| Reply-speed diagnostics | Read-only host performance details; `lib/ui/screens/this_phone_screen.dart:1341` | No persisted preference. |
| Termux migration | Verified project transfer; private config/sessions/git/shell/team files are export-only categories; `lib/domain/termux_migration.dart:35`; profile mapping `lib/builtin/migration/migration_profile.dart:8`, `:94` | Does not currently clone settings/credentials; source profiles/pins/drafts/queue preserved. |
| BYO host adoption/settings foundations | Build flag `OC_BYO_HOST` default false (`lib/domain/byo_host.dart:8`); S metadata and K `oc.byoHostSecrets.<id>` (`lib/state/byo_host_store.dart:11`, `:112`) | Backend foundation, not an ordinary enabled Settings feature; needs provision/authorization contracts. |

### 1.6 Cross-protocol matrix and risks requiring builder attention

| Concern | OC1 | OC2 | Paseo | Design consequence |
|---|---|---|---|---|
| New-chat model chosen at hub | Local per-profile default | Local preference; authoritative session initialization must be confirmed | Agent/runtime-dependent selection | Never label this a universal server config write. |
| Chat model | Local profile/session map | Server session selection | Server/agent session selection | Same UI may have different persistence; origin must be truthful. |
| Chat agent | Profile-wide fallback today | Session-owned selection where supported | Runtime modes/capabilities, not general agent switching | Fix or expose OC1 wider effect; do not fake equivalence. |
| Shell config | Global server write | `shellSettings: false` | `shellSettings: false` | Hide write in unsupported target, retain explanatory task route. |
| MCP add | Runtime/project/global | Runtime location only | No add/config-write capability | Never promise persistence or fan-out equivalence. |
| Provider sign-in/config | Server integration/legacy auth | Server integration, env credential limits | No integration credential API | A shared provider logo is not shared credential authority. |
| Saved permissions | Project grant list/revoke | Capability/adapter-dependent | Persistent grants may exist; list capability false | “Can't list” is not “none allowed”. |
| General AI setup Apply/Undo | Disabled | Disabled | No equivalent advertised contract | Proposed bulk infrastructure must not enable this accidentally. |

Matrix evidence: `lib/api2/gateway_mappers.dart:17`, `:44`, `:65`, `:79`; `lib/api2/gateway.dart:52`; `lib/paseo/gateway/capabilities.dart:24`, `:30`, `:40`, `:59`; API/control references in §1.3. Treat capability snapshots as target/version-specific: the disconnected OpenCode fallback can be `allV1` (`lib/state/connection/status.dart:226`), which is not permission to mutate an offline cached OC2 target.

**Cross-controller propagation risk, source-level only:** secondary controllers share a store but snapshot app preferences independently (`lib/state/connection.dart:499`, `:596`); setters update one controller (`lib/state/connection/settings.dart:50`), and secondary chat transcripts read their own controller (`lib/ui/screens/chat/chat_transcript.dart:416`). Global read-state consent also has a per-controller cache and privacy revision (`lib/state/connection.dart:434`; `lib/state/connection/read_state.dart:91`, `:248`). A toggle may therefore leave another live controller using old state. Introduce one observable device-preference owner and broadcast/drain privacy revocation before claiming “applies everywhere”. This was not reproduced by running the app.

**Verified concurrent-host and future-feature corrections:** built-in Linux explicitly uses a separate port to coexist with Termux (`lib/builtin/builtin_linux.dart:550`). Side OC controllers show phone servers by default and remote servers by opt-in (`lib/state/connection/side_connections.dart:3`, `:58`, `:112`); they do not write the main active pointer (`lib/state/connection.dart:377`). Monitor consent is separate. AI Team is integrated; BYO foundations are gated; no FactsBook/PaseoUsageMonitor/Usage-widget implementation was found in the inspected source. This scope proposal must not be read as enabling those future features.

## 2. The smallest useful scope model

Do not build an eight-position global scope selector. Use **four editable places**, with explicit ownership behind them:

| Place people see | Internal target | Truth and examples | Inheritance |
|---|---|---|---|
| **This app** | device installation; future optional person preferences | Appearance, language, transcript display, voice packs, notification delivery/quiet hours, local privacy and widget instances | Built-in defaults → optional synced personal preferences → explicit device preference; OS accessibility/permission constraints remain authoritative. |
| **A connection** | stable profile ID; separately, its remote configuration authority | Local model preference, monitoring choice, read-state consent; remote providers/MCP/shell are explicitly labeled as changes on the server | Local preferences may inherit app defaults where the setting declares it. Remote config is read from its own authority, never treated as a local override record. |
| **A project** | `(connection authority, canonical project/workspace identity)` | Team engine binding; supported project model preferences, tool configuration, project permissions | Only settings that explicitly support project overrides participate. A same-named path on two hosts is not the same project. |
| **A chat** | `(profile ID, session ID)` plus authoritative session owner | Model/variant/mode for this chat, session permissions, read state | Use the runtime's session contract; do not recompute a running chat's choice from changing new-chat defaults. |

Two resource owners are necessary but are **not additional inheritance levels**:

- **Host runtime**: one concrete installed environment, e.g. “In-app Linux on this phone” or “Termux on this phone”. Owns processes, installed tools, filesystem, keep-running support and update/remove operations. Multiple connection profiles can point to one host. A profile ID, port number, `localhost`, or “phone” is not sufficient host identity.
- **Provider account**: an authenticated billing/quota principal and entitlement pool, possibly reached through multiple servers. Owns quota truth. A connection owns its credential binding to that account; the app owns its alert preferences. One account does not imply one credential, one subscription window or permission to move a credential.

**Person** is a future transport/identity layer for an allowlist of personal preferences, not a new server policy authority. **Managed policy** is a constraint/default source, not a UI mode or target. Do not add separate “agent”, “connector”, “workspace folder”, “phone server”, “organization” or “template” scopes unless they identify a genuinely independent configuration authority. An agent may supply an authority or session capability; an organization may supply policy. Neither automatically creates another cascade.

### 2.1 Resolution is setting-specific, not one universal chain

Every setting definition declares its valid targets and resolver. Return both the value and its source.

1. **Personal display:** shipped default → synced personal preference (future, opt-in) → explicit device override. Respect system reduced-motion and platform limits; a remote project cannot change the app language.
2. **New-chat model preference:** runtime's effective default → optional personal preferred model → local connection override → supported project override → explicit choice for the new chat. Resolve IDs against that target's fresh catalog and authentication. The personal preferred model is a preference for new chats, not a server configuration write. Existing migrated connection choices remain explicit overrides.
3. **Existing chat:** authoritative persisted chat selection, or OC1's profile-owned chat record under its actual adapter contract. New-chat defaults stop at creation. A missing/stale authoritative choice is “Checking model…”, not a guessed fallback. Do not silently switch provider or cost tier when a preference is unavailable: use the runtime default only if the user chose “Use this server's default”; otherwise show “Not available on Laptop — Choose a model”.
4. **Server configuration:** the server's native resolution rules determine global/project/runtime effects. Show confirmed origin where available. OC2 config inspection returns a list of sources and deliberately does not guess the effective merge (`lib/api2/setup_config_adapter.dart:9`, `:74`). An app preference can influence a request only where the protocol supports it; it cannot override a server rule merely by being more specific.
5. **Notifications:** app event defaults → optional connection event overrides, then mandatory delivery gates: explicit monitoring consent, platform permission, app master delivery, global quiet hours, and per-account/source freshness. A per-server “On” cannot bypass quiet hours. Quiet hours silence delivery, not jobs or server execution.
6. **Permissions:** server/organization restrictions form a ceiling. A project or chat can narrow authority; widening requires the runtime's explicit supported consent flow. Never apply ordinary last-write-wins inheritance to approvals, standing grants or autonomous work.

Absent, explicitly set, inherited, unsupported, unknown, stale, managed and pending are different states. `null` must not simultaneously mean “inherit”, “clear on server”, “unknown” and “not supported”. Reset means **Use default** for a local preference; **Remove override** only where the server offers that exact operation. Show which default will take over.

## 3. Writes that span connections

| Strategy | Benefit | Failure mode | Decision |
|---|---|---|---|
| Per-server writes only | Smallest, truthful ownership, no hidden propagation | Repetitive setup | Default for server-owned settings. |
| App preference continually pushed to every server | Superficially convenient | Fights other clients, expands credentials/permissions, changes later-added servers, cannot map runtime semantics safely | Reject. Personal model preference may be resolved at chat creation without rewriting servers. |
| Explicit **Copy to other servers…** | Useful for deliberate bulk setup | Partial success and ambiguous retries | Add later for an allowlist with preview and individual receipts. Never an ordinary toggle side effect. |
| Named templates | Repeatable onboarding and future servers | Drift and false expectation of ongoing enforcement | Add after bulk semantics; templates are versioned proposals with placeholders, never live policy bindings by default. |

“Apply everywhere” must be split into two meanings: **Use for new chats in this app** (personal preference, subject to target compatibility and overrides) and **Copy this setting to selected servers** (independent remote writes). Do not label both “All”. Copying now does not include future servers. A new connection may offer “Use template…”, with a fresh preview; declining leaves its server untouched.

### 3.1 Copy transaction and receipts

1. Capture an immutable target set and exact setting operation; exclude the source; resolve duplicate profiles to a proven common configuration authority so the same server is not written twice. If identity cannot be proven, warn of a possible duplicate and require selecting only one route, not guessing from URL or display name.
2. Read each target's capability/version, current field and write authority. Preview “Laptop: model A → B”; “VPS: offline — not changed”; “Pi: unavailable”; “Team server: shared with other clients”. Capability support, role permission, provenance and conditional-write support are distinct.
3. Validate semantic portability, not identical strings: exact provider/model IDs, shell existence, MCP runtime/project/global lifetime, project identity and required sign-in. Never copy credential material, tokens, authorization headers, executable hooks or standing permission grants through this operation. A provider/template item can say “Sign in on VPS”.
4. Apply a bounded number of independent operations, with an operation ID and target-bound lease. Use compare-and-set/ETag/version when the contract provides it. Otherwise re-read before a narrow patch and after it; explicitly expose “Concurrent edits cannot be protected on this server”. Read-back detects a mismatch but does not make a nonconditional API atomic. Refuse bulk changes whose safe merge/delete semantics are unproven.
5. Report per-target outcomes: `appliedConfirmed`, `acceptedUnverified`, `alreadyMatched`, `offlineSkipped`, `unsupported`, `needsSignIn`, `conflict`, `failed`, `outcomeUnknown`, `cancelledBeforeSend`. Example: “2 of 4 servers updated · VPS offline · Pi doesn't support this”. Never reduce this to a green “Saved”. A timeout after send is outcome-unknown; reconcile before retrying, especially for additions.
6. Default offline behavior is **skip**, with “Try skipped servers…” after fresh preview. Do not enqueue a delayed permission/configuration mutation under today's ordinary prompt queue. An optional durable pending proposal may remember intent, without credentials, but requires revalidation and user review when the target returns; reconnect alone does not execute it.
7. Keep successes on partial failure. Never automatically roll back a shared server: another client may have edited it since the copy. Offer revert only against a fresh conditional revision and only for adapters with proven exact restoration. Both setup adapters currently refuse general Apply/Undo (`lib/api/setup_config_adapter.dart:84`; `lib/api2/setup_config_adapter.dart:99`).

## 4. “Current server” is navigation context, not global authority

The mixed Work/Chats list has no single configuration owner. Define these separately: **default destination for a new chat**, **connection owning the open chat**, **connection being edited**, and **connections being monitored**. None changes the others implicitly.

- Settings root has no selected server mode. Entering a named connection page captures its stable ID and optional project ID. Opening another chat must not retarget an open Settings page, dialog or save.
- From a chat, “Settings for Laptop” opens that chat's owner. “Model for this chat” changes only that chat under the supported session contract. A separate “Use for new chats on Laptop” action makes broader intent explicit.
- From the root AI Model/Providers/Tools shortcuts: one eligible connection opens directly with its name visible; multiple connections show a compact named list with values. Do not automatically pick whichever server last produced an event or whichever one happens to be online. A recent destination may be highlighted, not silently committed.
- From a project, show “Project settings · repo · Laptop”. A project choice affects future chats in that project unless the runtime explicitly applies it to existing sessions; label that effect. Moving a chat/project to another connection revalidates choices; it does not carry permissions or credentials.
- Search results retain target context through navigation and save. Current `SettingsSearchTarget` has only page/section/row (`lib/domain/settings_search.dart:3`): extend the navigation request with typed owner IDs, without placing server values or credentials into the static search document (`:15`). A global “Shell” query asks which server if ambiguous.

## 5. UX recommendation

### 5.1 Compare the alternatives

| Option | Regular user | Advanced user | Verdict |
|---|---|---|---|
| (a) Scope switcher above all Settings | Every page appears to change owner, even language and voice; hidden mode persists after navigation | Fast switching but unsafe mixed global/remote pages | Reject as the root model. A target picker is appropriate inside a server-owned task. |
| (b) App-wide groups plus named connection pages | Familiar general settings and named entities; one connection needs no extra picker | Stable target, deep links, parallel panes and explicit comparison | **Choose this as the primary structure.** |
| (c) Inline “Applies to: All / Laptop” and badges | “All” is unclear: all chats, all clients, all servers, future servers? | Helpful for local inherited defaults if words are precise | Use selectively as “New chats on Laptop”, “This chat”, “Use app default”; never generic All on remote settings. |
| (d) User / Remote / Workspace tabs | Requires learning precedence and knowing the active workspace | Excellent provenance and technical inspection | Use the provenance idea in Details; do not copy desktop tabs into the mobile hub. |

### 5.2 Exact five-group hub

Keep the IA audit's five groups and search launcher. These are task shortcuts into canonical pages, not duplicate stores or additional scope modes.

| Group | Exact rows and sample values | Target behavior |
|---|---|---|
| **Connections** | **Servers** — “2 connected · 3 saved”; **This phone** — “Running” / “Stopped” / “Set up” | Servers lists every saved connection, not just active one. This phone opens installed host choices when both exist. |
| **AI** | **Model** — one: “Sonnet · Laptop”, many: “By server”; **Providers** — “By server”; **Usage** — “2 sources”; **Tools** — “By server”; **Agents** | Model opens new-chat preferences; Providers/Tools go to the named server's canonical section. Agents separates On this phone, Connected agents and AI Team; each operation retains its owner. |
| **Chat** | **Show reasoning**; **Show time, tokens and cost**; **Phrase suggestions**; **Shell for commands** — “Laptop” / “By server”; **Voice typing**; **Permissions and automation** | First two switches and voice affect this installation. Phrase enable is personal, learned data remains connection-owned. Shell/permissions use named destinations, not root-level server edits. |
| **This app** | **Notifications**; **Background**; **Appearance**; **Language**; **Privacy and data** | Phone defaults here; named server/host sections are links into the same canonical editors. Read-state sharing becomes connection consent under Privacy, not a misleading global switch. |
| **Help and about** | **Setup guide**; **Report a problem**; **About** | App-wide; contextual diagnostics explicitly name any included server/host. |

**Servers › Laptop** has sections, not one long flat list: Connection (**Status and version**, **Sign-in**, **Name and address**, **What this server supports**); In this app (**Model for new chats**, **Notifications**, **Watch this server**, **Share read state**); On Laptop (**Providers**, **Tools**, **Shell for commands**, **Permissions**, **AI setup**, **Plugins**, **Updates**); bottom named actions **Disconnect from Laptop**, **Remove Laptop from this app**. **Projects** links to project settings when supported. Technical service installation and address fields stay under Details. Permission and setup entries expose only the contracts supported by the target.

At the top of a local-default page: “For new chats on Laptop in this app”. On a remote-config page: “Saved on Laptop. Other clients may use this setting.” On project pages: “repo on Laptop”. On host controls: “Runs in Termux on this phone”. Avoid repeating owner subtitles on every row where the page header already fixes the owner; repeat it in confirmation sheets, search results and bulk previews that can be seen independently.

The hub remains stable while other servers disconnect. An unavailable targeted setting shows “Not supported on Pi” on its page, with one reason and next action. Do not use the active server's capabilities to hide a phone setting or another server's configuration. Hide platform-impossible operations, not supported entities that happen to be offline.

### 5.3 Effective-value disclosure

Default state: **Model — Sonnet**, supporting “Using app preference”. Override: **Model — Opus**, supporting “Different for Laptop”, action **Use app preference**. Server source: “Set on Laptop”; known managed source: “Set by your organization”. Unknown provenance: “Reported by Laptop”; never claim an administrator changed it without evidence. A regular user must see the plain-language difference even if somebody else created it; Details adds setting ID, owner ID, source chain, observed time and revision, all sanitized.

### 5.4 Phone, tablet and Arabic

Phone uses ordinary push navigation and a short target list only when necessary. Tablet uses the same canonical routes: groups/connections in the leading pane, a named owner and settings in the detail pane. Changing selection with unsaved remote edits offers **Keep editing** / **Discard changes**; no automatic save to the next owner. Preserve selection by ID through refresh and reorder.

Arabic mirrors layout, directional spacing, pane ordering and back affordances; use start/end alignment. Keep user server names intact; isolate URLs, paths, model IDs and versions as LTR technical spans. Localize complete phrases such as “New chats on {server}”; do not concatenate a translated “on” with punctuation. Scope/override state must be text and accessibility semantics, not color or a small badge alone. Screen readers announce owner, effective value and origin before the edit action. Support text scaling without truncating the only owner label.

### 5.5 Usage and its proposed home-screen widget

Usage is an aggregate view, not a new owner. **Spending**, **Left this period**, **Widget** remain together. Every source row carries owner, measured window, units, last refresh and availability. Different quota percentages are never added into a total. Costs combine only with compatible currency/window and nonoverlapping measurement coverage.

Widget configuration belongs to a **widget instance on this phone**: **Sources**, **What to show**, **Refresh**, **Preview**, **Add to home screen**. Offer “All selected accounts” only after identity/coverage dedupe; list included accounts, not “current server”. Widget taps include the exact account/source/profile target. Removing a selected source shows “Source removed” until the user replaces it; no fallback to another account. Offline data is visibly stale. A widget must not start a server, grant monitoring consent, upload secrets or acquire new background privileges simply because it was placed. Show available update behavior, not a guaranteed refresh interval Android cannot honor. All of this is proposed; existing session-widget support is not evidence of a Usage widget.

## 6. Nuances and edge cases

| Case | Required behavior |
|---|---|
| Termux and built-in Linux installed | Represent two distinct host resources, each with its own status and controls. “Preferred for new phone chats” is one routing preference, not proof only one can run. Detect actual endpoint/process conflicts; never infer ownership from loopback alone. Show both existing environments before migration/removal. |
| Moving Termux → built-in | Treat as a host/data transfer plus optional connection replacement, not global settings synchronization. Preserve source until verified completion; map projects explicitly. Copy safe local preferences once to new profile IDs without overwriting explicit target values. Rebind secure sign-ins only through the supported migration contract; re-consent host permissions and automation. Show source/destination and remaining source data. |
| OC1 ↔ OC2 on a host | Host may remain the same while protocol, storage and profile/session identity change. Reprobe capabilities and invalidate incompatible catalogs/settings plans. A local OC1 session preference does not prove a corresponding OC2 server session selection. Preserve unknown data for recovery instead of guessing a mapping. |
| Same provider account on two servers | Keep two credential bindings, one verified account/entitlement identity when available, and multiple observations. Dedupe only with provider-qualified stable opaque account and pool/window IDs or an explicit user-confirmed link. Never dedupe by display name, API-key string, provider name or matching percentages. Unknown identity stays “Account not identified”; do not publish a combined total. |
| Quota alerts and dedupe | Deduplicate an alert event by `(person/device, account or unlinked source, entitlement pool, window, threshold crossing)`, retaining contributing source IDs. A source outage cannot reset a crossing and ping again. Pick a fresh authoritative observation; do not add two readings of the same pool. Subscription quota and usage costs remain separate metrics. |
| Notifications | One app delivery policy/quiet schedule; explicit per-connection monitoring and optional event overrides. User-selected timezone behavior defaults to current phone local time, with DST-aware intervals. Quiet hours do not stop servers or delay approval execution automatically. Unsupported notifications remain explanatory, not a working-looking switch. |
| Keep running | Distinguish “Keep this app connected” from “Keep the in-app server running” and Termux's OS settings. Opening Laptop Settings must not change Termux battery exemption. OS permissions/thermal limits are device facts; desired host policies are per host; actual status reports constraints separately. |
| Remove profile | Delete local profile preferences, secrets, pending settings proposals and references in shared blobs through the controller cascade. Drain writers first. Do not remove shared host installations, shared account data or remote server config just because one route was removed. Retain resources still referenced by another profile, with explicit reference ownership. |
| Export/import | Versioned allowlisted personal preferences and optional named templates; exclude passwords, tokens, key material, grants, consent, history, learned phrases, URLs/paths by default and raw server config. Preview mappings to existing targets; never trust incoming profile IDs as identity. Import is local proposals; remote application is separate. Reject malformed/unknown/security-sensitive fields rather than execute them. |
| Shared/team server | Refresh on entry/resume and after mutations; show observed age and server revision if supplied. External changes update a clean form; dirty forms become conflict state. No automatic periodic push of the phone's cached value. Never promise exclusive ownership on a shared server. |
| Credentials | Bind sign-in to exact target/owner and keep secrets in secure storage or the owning host/server's approved credential store. Static search, diagnostics, logs, receipts, exports, widget snapshots and raw views must never echo credentials. Provider response redaction happens before persistence or rendering. |
| Version/capability change | Capability snapshot has an identity/version epoch. Cancel unsubmitted plans on change; reconcile submitted outcomes before retries. Re-read setting support at apply time. Preserve unavailable local preferences as inactive with a reason; do not quietly convert them into broader defaults. |
| Ten or more servers | Searchable connection list, favorites/recents as navigation only, duplicate-name disambiguation, status summaries without opening every socket, bounded refresh and bulk concurrency. “Copy to selected…” uses a stable visible selection count; recently added servers do not join a pending batch. |
| Same server through two routes | Profiles remain separate transport/credential choices until remote identity proves shared authority. Show “Same server via another connection” when verified. Do not let aliasing produce double writes, double spend or double notifications. |
| Connection switched during edit | The editor keeps captured owner, project and capability epoch. Save either targets that owner or refuses as stale. A successful save on a previous owner may be recorded there; it must never update the new page's value. |

## 7. Future use cases without another settings hierarchy

| Future case | Placement and constraints |
|---|---|
| BYO VPS | A host with one or more connection profiles; host lifecycle/SSH identity are distinct from OpenCode config. Provisioning/adoption and SSH trust remain explicit flows. No scope change implies infrastructure creation. |
| FactsBook personal memory | A personal data authority hosted on a chosen device; connection controls specify endpoint/auth, host controls where it runs, project/chat controls whether a memory source may be consulted. “Use memory” is consent, not a generic all-servers inherited preference. Memory content never goes into settings sync/export. Moving its host is a separate data migration. |
| AI Team | Project-owned engine binding and runtime-owned team policy. Connection page exposes availability/discovery; project page chooses team/engine and autonomy; chat knows its project. Never turn on a team for every project by toggling an app-wide boolean. |
| Cross-device preferences | Opt-in person identity; sync allowlisted language/theme/transcript and optional model intent. Device overrides support different accessibility, voice storage and widget needs. Do not sync host operation, notification OS grant, provider credentials, automation consent or remote config. Resolve concurrent preference edits with per-key revisions and visible local overrides. |
| Multiple people | Start with one app installation per OS user; do not claim current account isolation. Future in-app person switching partitions profiles, caches, widgets, secrets and sync under a person ID and re-evaluates background work. A provider account is not an app person. Switching people must not leave the previous person's foreground widget or watcher exposed. |
| Enterprise defaults | Typed managed recommendations can be overridden; enforced constraints cannot. Explain who manages them and disable incompatible writes at the state boundary. The server enforces its own authorization regardless of what the mobile UI says. |
| Project overrides | Canonical project identity within a remote authority, separate from a local “last visited path”. Model preference can be local-only or native server-owned; show which. Workspace folder scopes are deferred until a supported runtime distinguishes multiple independent folder policies in one workspace. |
| ACP/Paseo/other agents | Adapter declares per-setting targets, lifetime, discovery and mutation support. A daemon with chat model changes but no provider-config API exposes exactly that. Do not translate permission modes, MCP files or CLI flags between products by name. |

## 8. External research

Research used web search and official product documentation/announcements, accessed 2026-10-12. The “use here” and “do not copy” columns are design inferences. Historical announcements establish a pattern, not today's account limits or platform parity. No competitor source establishes atomic multi-server settings writes; the receipts/conflict contract in §3 is our design response to independent authorities.

| Product | Documented behavior and direct source | Use here | Do not copy |
|---|---|---|---|
| VS Code settings | Ordinary precedence includes User → Remote → Workspace → Workspace Folder; language-specific settings add another dimension, policies override other values, and some settings cannot be workspace settings. [Settings](https://code.visualstudio.com/docs/configure/settings) | Per-setting allowed targets, effective source, reset, policy constraints. | Whole desktop tab hierarchy; “most specific always wins”; equating remote client preference with shared server configuration. |
| VS Code profiles | **Apply Setting to all Profiles** is continuing shared behavior: changes from one profile affect the others; it can be disabled. Profiles support export. [Profiles](https://code.visualstudio.com/docs/configure/profiles) | Distinguish live personal inheritance from a one-time copy operation. | Treating customization profiles as independent servers, or using this as justification for hidden remote writes. |
| VS Code Settings Sync | Sync selects categories, excludes machine/machine-overridable settings by default, handles conflicts and provides versions/backups. [Settings Sync](https://code.visualstudio.com/docs/configure/settings-sync) | Allowlisted person sync, device exclusions and recoverable conflicts. | Syncing credentials, runtime paths or server config with theme/language. |
| JetBrains | IDE-global, project and module settings are distinct; project markers identify project settings; new-project defaults are separate from existing projects. [Configure the IDE](https://www.jetbrains.com/help/idea/configuring-project-and-ide-settings.html) Personal settings sync is separate from VCS-shared project settings. [Backup and Sync](https://www.jetbrains.com/help/idea/sharing-your-ide-settings.html) | Mark project origin; distinguish future defaults/templates from existing-project changes. | A module/folder level without a real supported OpenCode use case. |
| Slack | Notification defaults have channel/DM exceptions and mobile choices; badge inclusion can select workspaces. [Configure notifications](https://slack.com/help/articles/201355156-Configure-your-Slack-notifications) Personal schedules can override workspace/organization default schedules. [Pause notifications](https://slack.com/help/articles/214908388-Pause-your-Slack-notifications) | Source-specific delivery preferences plus device delivery; recommended policy differs from enforced restrictions. | Per-workspace complexity for basic composer/display habits; treating a personal schedule as shared server configuration. |
| Discord | Server mute/notification choices have channel/category overrides. [Notification Settings](https://support.discord.com/hc/en-us/articles/215253258-Notifications-Settings-101) Device notification settings provide app-wide mobile control. [Mobile notifications](https://support.discord.com/hc/en-us/articles/218892547--Mobile-Notifications-Settings-101) | Global quiet/delivery gate with visible per-connection exceptions. | Assuming a “server notification setting” changes settings for everyone on that server. |
| Gmail Android | Settings offers **General settings** or a named account: general changes apply to all accounts in this app, account changes only to the selected account. Examples include general swipe behavior and account notifications/sync/signature. [Gmail settings](https://support.google.com/mail/answer/6562?co=GENIE.Platform%3DAndroid&hl=en-EN) | Strongest regular-user pattern: This app plus named connections. | Hiding the distinction between local account behavior and changes to a shared remote service inside the account page. |
| Outlook mobile | Specific email accounts have notification choices separate from device notification settings for Outlook. [Optimize Outlook mobile](https://support.microsoft.com/en-us/outlook/optimize-the-outlook-mobile-app-for-your-ios-or-android-phone) | Aggregation and per-account/connection controls coexist with app-wide delivery. | No support here for an “all accounts” remote configuration write; no complete signature-scope contract was established in this research. |
| Telegram | Official account announcements describe notifications continuing from several signed-in accounts, including recipient-account identity in notifications. [Multiple accounts](https://telegram.org/blog/autoplay?setln=en), [Android accounts](https://telegram.org/blog/themes-accounts?setln=en) | A viewed connection is not the only live source; notifications need origin. | Historical account limits as current facts; a whole-app account switcher as a hidden Settings mutation target. |
| Home Assistant companion | Android multi-server support includes individual server settings and mixing servers in widgets/notifications/shortcuts/tiles. [Multi-server announcement](https://www.home-assistant.io/blog/2023/03/30/android-20233/) Sensor docs distinguish per-server sending/privacy and common sensor settings. [Sensors](https://companion.home-assistant.io/docs/core/sensors/) | Closest architectural match: one phone, concurrent independent servers, shared device capabilities, explicit per-server sharing; widgets retain source IDs. | One selected server retargeting every background/widget operation; claiming every setting behaves identically on all platforms. |
| Termius | Host groups inherit parameters per field, explicit host/subgroup overrides win; tags filter hosts. [Groups and tags](https://docs.termius.com/organize-and-connect-to-hosts/groups-and-tags) Vaults distinguish personal/team access; hosts can have several protocols. [Core concepts](https://docs.termius.com/getting-started/what-is-termius) | Advanced templates, searchable groups, distinct host versus endpoint identity. | Inherited client connection parameters as a precedent for automatically enforcing arbitrary remote service config. Defer vault/group hierarchy until needed. |
| Tailscale | Fast switching allows one active account/tailnet for the client, separate from the admin-console account. [Fast user switching](https://tailscale.com/kb/1225/fast-user-switching) CLI preference changes in that mode target the connected tailnet. [CLI](https://tailscale.com/kb/1080/cli) | Explicit operation target; viewing account and runtime connectivity are separate concepts. | Its single-active runtime assumption: OpenCode's phone and laptop may both be live. This is a useful counterexample, not the model to follow. |
| GitHub Mobile | Docs support signed-in accounts across GitHub.com, GHE.com and Enterprise Server with explicit switching. [GitHub Mobile](https://docs.github.com/en/get-started/using-github/github-mobile) The multi-account announcement describes separate data/unread counts and notifications per account. [Multi-account announcement](https://github.blog/changelog/2023-08-15-log-in-with-multiple-github-accounts-on-github-mobile/) | Target-bound deep links and source identity, with principal distinct from server endpoint. | Mutating the currently viewed account when a notification belonged to another; assuming hosted and enterprise server capabilities match. |
| Chrome profiles | Desktop profiles separate settings/history/passwords; deleting one removes its local data, and local profile switching is not a security boundary. [Desktop profiles](https://support.google.com/chrome/answer/2364824?co=GENIE.Platform%3DDesktop&hl=en) Android has one Chrome profile per Android user. [Android profiles](https://support.google.com/chrome/answer/2364824?co=GENIE.Platform%3DAndroid&hl=en-GA) | A person/principal boundary differs from a connection; local deletion differs from deleting remote accounts. | Claiming labels/colors or a server selector provide multi-person security isolation. |
| Android users | Users have separate account/app/settings spaces, while some device settings remain shared; account and user are distinct. [Android users](https://support.google.com/android/answer/2865483?hl=en) | Use OS-user isolation for shared-device people until full app principal partitioning exists. | Claiming all hardware/device settings are private to one user or that adding a connection creates a new person boundary. |

The strongest combination is **Gmail's navigation**, **Home Assistant's concurrent target ownership**, **VS Code's provenance and permitted overrides**, and **Termius's optional advanced repetition tools**. Discord/Slack clarify delivery overrides; Tailscale explains why “current” is safe only when the runtime really has one active target. These patterns support progressive disclosure, not a universal scope switcher.

## 9. Migration and implementation contract

### 9.1 State/domain contract before UI

These names and shapes are **proposed**, not existing APIs. Domain types must not import Flutter widgets or protocol clients. UI uses the domain/controller facade. Keep `ConnectionController` and all its parts one editor's unit.

```dart
enum SettingOwnerKind { device, connection, host, providerAccount, project, chat }
enum SettingAuthority { localPreference, remoteConfig, hostRuntime, managedPolicy }
enum ValueState { known, unknown, stale, unsupported, pending }

// Immutable, non-secret IDs; project/chat require a parent connection owner.
SettingTarget(kind, ownerId, profileId?, projectId?, sessionId?)
SettingDefinition(id, valueType, allowedTargets, authority,
                  resolverId, sensitivity, syncAllowed, exportAllowed)
SettingSupport(readable, writable, removable, lifetime,
               conditionalWrite, reasonCode, capabilityEpoch)
SettingOrigin(authority, target, sourceLabelCode, revision?, observedAt?)
EffectiveSetting(id, target, value?, state, origin, inheritedFrom?,
                 explicitOverride, constraints, support)
SettingEdit.set(id, target, typedValue)
SettingEdit.inherit(id, target) // not a null-valued remote patch
SettingPlan(id, edits, immutableTargets, beforeRevisions,
            capabilityEpochs, preview, expiresAt)
SettingReceipt(planId, target, status, confirmedValue?, revision?,
               observedAt?, reasonCode)

abstract interface class SettingsCoordinator {
  Future<EffectiveSetting> readSetting(String id, SettingTarget target);
  Stream<EffectiveSetting> watchSetting(String id, SettingTarget target);
  Future<SettingPlan> planSettingChanges(List<SettingEdit> edits);
  Future<List<SettingReceipt>> applySettingPlan(String planId);
  Future<SettingReceipt> reconcileSettingOutcome(String planId,
                                                SettingTarget target);
  Future<void> discardSettingPlan(String planId);
  Future<SettingsExport> exportPreferences(SettingsExportSelection selection);
  Future<SettingsImportPreview> previewImport(SettingsExport document);
}
```

Adapters additionally expose `describeSettingSupport(target, id)`, `readSettingSnapshot(target, id)` and `writeSettingChange(target, change, expectedRevision)` through an optional domain settings gateway. Do not route an arbitrary JSON document into `/config`; start with typed, allowlisted fields. `RemoteSettingSnapshot` can carry unknown provenance. A gateway's boolean capabilities enable discovery; per-setting support describes writable scope/lifetime. `SettingsCoordinator` pins the exact gateway lease and owner epoch instead of borrowing a mutable current-controller API at send time.

Separate services: a single observable `AppPreferencesStore` owns device preferences for every main/secondary controller; `PreferenceResolver.resolve(definition, context, sources)` is pure; `SettingsTargetResolver` binds profile/project/host identity; `SettingsWriteCoordinator` handles plans/receipts; `AccountObservationResolver` groups proven quota identity without granting credential access; existing persisted keys remain authoritative until migrated. A privacy revocation increments a shared epoch, invalidates every affected controller and cancels/drains not-yet-sent sharing work before confirming the change; an already-transmitted read receipt cannot be recalled. `DefaultChoice`/`DefaultReason` already provide a useful vocabulary for explicit/default/last-used decisions (`lib/state/interaction_defaults.dart:10`, `:28`, `:58`); extend that instead of building a second contradictory inference engine.

Errors are typed fixed reasons (`offline`, `unsupported`, `needsSignIn`, `staleTarget`, `conflict`, `managed`, `invalidValue`, `storageFailed`, `outcomeUnknown`); technical text is sanitized separately. Never log raw values generically. Persistence must distinguish a refused SharedPreferences save from success and notify only after confirmed persistence (or visibly pending optimistic state with rollback).

### 9.2 Keys and one-time copy rules

Prefer an ownership registry over renaming correct keys for cosmetic consistency. Keep current global appearance/locale/effects/transcript keys and current per-profile model keys initially. New profile-owned records use `oc.settingsOverrides.<profileId>`, `oc.projectSettings.<profileId>`, `oc.settingsPending.<profileId>` with versioned internal maps; project/session IDs are fields inside the profile-owned record. This preserves the required `oc.<what>.<profileId>` sweep. No server ID is derived from a name, URL or port.

New device records may use `oc.settingsDevice.v1` and `oc.usageWidgets.v1`; shared host/account registries use `oc.settingsHosts.v1` and `oc.settingsAccounts.v1`, with explicit profile-reference cleanup in `deleteProfileAndLocalData`. These shared keys intentionally need explicit deletion handling; a suffix sweep cannot discover ownership hidden in JSON. Host/account records must use opaque IDs in values, not accidentally match a profile ID as a key segment. Widget instance/source and pending-plan references must be covered too. Secrets stay in their existing secure slots until an independently reviewed secure-storage migration; never copy them into these maps.

| Existing value | Migration rule | Default after migration |
|---|---|---|
| App language/theme/effects/transcript | Keep key and value; expose correct device owner | Existing defaults unchanged. |
| Reader preferences per profile | Keep existing values as explicit connection overrides if a device-wide reader default is introduced; never pick the active profile as everyone's default | New device default uses shipped behavior until explicitly chosen. |
| Explicit per-profile model/agent/variant | Preserve as explicit connection override, including explicit marker | New personal preferred model starts unset; do not infer a global preference from the active or most recent profile. |
| Cached/implicit model choice | Preserve as observation, not newly granted explicit intent | Use runtime default if no explicit preference; revalidate catalog. |
| OC1 session model map | Keep profile/session identity and local authority | Do not copy into OC2/Paseo session config; migration never writes remote state. |
| Global `oc.shareSessionViews` | Initialize missing per-profile `oc.shareSessionViews.<profileId>` for existing supported profiles to the previous value; record migrated origin. Preserve any existing target value | New profiles default off and offer consent. If capability is unknown, retain a non-executing migration value pending capability check, not a network action. Global legacy key retained only for bounded rollback compatibility. |
| Global notification preferences | Keep confirmed shared policy; do not rerun legacy merge from a different active profile | New per-connection event overrides inherit; monitoring/automation consent is never synthesized. |
| Per-profile monitor/quota rules | Preserve enabled/threshold/source and existing consent independently | Do not merge differing quotas or turn on polling for a new connection/account. |
| Global phrase switch and per-profile learned data | Preserve both; label the distinct behavior | No cross-profile content merge; future personal phrase sync requires a separate consent design. |
| Termux → built-in profile preference copy | Copy only allowlisted explicit local preferences to absent target fields after confirmed identity mapping; record source revision and migration ID | Target's own values win; no host permissions, grants, provider secrets, account identity or cached session IDs copied implicitly. |
| Host preference previously keyed by runtime | Map to a host only when ownership is proven; retain ambiguous record without applying it | Ask at relevant host action; never duplicate “auto-start” across both installations. |
| Quota/account observations | Start unlinked; attach account/pool identity only from proven metadata or explicit link | Existing source behavior preserved; no fabricated combined total. |

Migration is idempotent, staged and resumable: validate old data; write only missing destinations; verify persistence/read-back; commit a per-migration marker last. A crash cannot leave a marker saying work completed before all writes did. Keep legacy data for a documented rollback window, with one canonical new writer; do not promise old/new clients can safely dual-write indefinitely. Reject unsafe/corrupt values, record a non-secret reason and preserve recoverable source data. Do not overwrite explicit target choices on rerun. A schema migration must never send a server request or grant new automatic behavior.

### 9.3 Independently shippable slices

| Slice / ownership | Read/write set and dependency | Acceptance and later focused checks (not run here) |
|---|---|---|
| A. Metadata and provenance | New domain definitions + read-only facade over existing stores; reads Settings index/capabilities. No shared controller edits by another worker | Every inventory entry maps to an owner, authority and support reason; pure resolver cases prove absent/explicit/unknown distinctions. |
| B. Shared preferences, target-pinned state and deletion | One owner edits `ConnectionController` library and ProfileStore; adds shared observable `AppPreferencesStore`; depends on A | Main and secondary controllers observe display changes immediately; global privacy revocation reaches every controller before success; connection change during load/save never retargets; scoped/shared data deletes without resurrection; refused persistence returns failure. |
| C. UI labels and canonical routes | One UI owner edits Settings/search/kit composition/localization; depends on A and B contracts | One/two/many connections, search deep links and shared-server notices use captured target. No storage migration required merely to fix “Server default” copy. No invented advanced mode. |
| D. Read-state consent migration | State owner, per-profile key migration + Privacy UI; depends on B | Old on/off preserved only for existing profiles; fresh profiles off; unknown capability cannot transmit; retry/crash/explicit-target cases covered. |
| E. Model inheritance and project defaults | State resolver + adapter session contract, then model UI; depends on A/B | OC1/OC2/Paseo choose only supported targets; explicit chat selection remains stable when defaults change; unavailable preference prompts rather than guesses. |
| F. Host/account identity and Usage sources | Host ownership service and quota identity resolver, no controller co-edit; depends on A/B | Two hosts distinguished; alias profiles deduped only on proof; quota windows/units never summed incorrectly; no extra watcher consent. |
| G. Usage widget | Dart/native halves owned together, widget-instance store and UI; depends on F | Multiple sources, stale/offline state, target-safe tap and deletion; native lifecycle/platform checks required before claiming usable widget. |
| H. Copy/templates/export | Coordinator and per-setting adapters, then advanced UI; depends on B/F and proven remote APIs | Partial failure, duplicate aliases, timeout unknown, conflict, absent CAS, unsupported lifetime, offline skip and later-added server exclusion. Export/import contains no secrets/consents and never executes remote writes. |

Parallel ownership after contracts freeze: A metadata, C UI composition against immutable fixtures, and F research/identity pure types can progress independently. B and E must serialize shared-controller edits. Native/Dart widget halves have one owner. A shipping slice must include its usable UI and deletion behavior; an unexposed backend contract is groundwork. Proposed checks are requirements for builders, not claims of tests executed in this research.

The eventual integration suite must additionally cover secure-storage channel mocks, all new per-profile key deletion, shared host/account reference retention, drained pending writes, import validation, server version epoch changes, Arabic/large-text/screen-reader owner announcements, and 10+ server navigation without eager socket fan-out. Follow pinned tooling and machine-lock rules at implementation time; do not substitute this document for local test or device evidence.

## 10. Rules to add to the Settings Standard

| ID | Imperative rule | Why |
|---|---|---|
| SC1 | Give every setting a declared owner, authority, allowed targets and persistence contract. | A label or storage location alone cannot explain who is affected. |
| SC2 | Say “On this phone”, “New chats on {server}”, “This chat”, or “Saved on {server}”; keep “scope” out of ordinary UI. | Users need consequences, not architecture vocabulary. |
| SC3 | Keep app preferences independent of the selected or most recently active server. | Several servers can be live at once. |
| SC4 | Pin every editor, search destination and save to stable owner IDs and a capability epoch. | Navigation and reconnect must never redirect a mutation. |
| SC5 | Distinguish a personal default from a shared server configuration value. | Changing one's preference must not silently affect other clients. |
| SC6 | Show the effective value and a plain-language origin; expose any meaningful override even in the simple view. | Users can encounter differences they did not create. |
| SC7 | Declare inheritance per setting; show what “Use default” will restore. | There is no safe universal scope hierarchy. |
| SC8 | Treat permissions, credentials and automation consent as explicit authority, never generic inheritable preferences. | More specific must not mean more powerful. |
| SC9 | Keep global quiet hours and platform restrictions authoritative over per-server notification choices. | A server override must not bypass a person's delivery limits. |
| SC10 | Ask for a target only when more than one valid target exists; always name the target before a remote write. | Reduce decisions without hiding consequences. |
| SC11 | Keep Settings' top-level groups stable; explain target-specific unavailability on the target page. | Another server's connection state must not rearrange app settings. |
| SC12 | Make multi-server copying explicit, previewed, bounded and receipted per target. | Partial success is normal, not an exceptional corner case. |
| SC13 | Skip offline remote writes by default and revalidate before every retry. | Old intent may be unsafe by the time a server returns. |
| SC14 | Never apply a template or old batch automatically to a later-added connection. | New targets need new intent. |
| SC15 | Identify hosts independently from profiles and accounts independently from observations. | Aliases and shared resources otherwise cause double actions and false totals. |
| SC16 | Preserve source, unit, window and freshness in Usage and widgets. | Aggregation must not manufacture precision or duplicate quota. |
| SC17 | Store profile-owned preferences as `oc.<what>.<profileId>` and register shared-blob cleanup. | Removing a connection must remove its local data without deleting another owner's data. |
| SC18 | Redact before display, persistence, export or diagnostics; never echo credentials in technical views. | Advanced presentation is not permission to disclose secrets. |
| SC19 | Revalidate actual capabilities and authorization on apply, including after version changes. | A familiar protocol label does not prove a callable operation. |
| SC20 | Disclose technical controls progressively through task-specific Details and named actions, not a global expertise switch. | People vary in expertise by task; safety and origin stay visible to everyone. |
| SC21 | Keep existing chats stable when a new-chat default changes. | A preference edit must not silently change ongoing work. |
| SC22 | Mirror navigation for RTL and announce owner/value/origin accessibly. | Target identity must survive layout direction, text scaling and assistive technology. |
| SC23 | Migrate locally and idempotently; never infer consent or write remote configuration during migration. | Upgrading the app must preserve intent. |
| SC24 | Report implemented, enabled, verified, committed and released states separately. | A proposed contract or stored toggle is not an operational feature. |

## 11. Regular and advanced users

No persisted expertise/advanced-mode setting was found in the Settings, state, search or localization paths inspected. Existing disclosure is task-specific, notably Details folds; existing `InteractionDefaults` already distinguishes explicit choice, only option, server default and unresolved choice. Build on those. Do not add a global “Advanced mode” that hides owner warnings or makes saved differences invisible.

| Situation | What a regular user sees | What the app infers / asks | Advanced path |
|---|---|---|---|
| No connections | Normal app preferences; Servers — “Add a server”; This phone — “Set up” | Never invent a server target. | Import a safe preferences file or connection template, then review. |
| Exactly one connection | Model opens directly with “New chats on Laptop”; Providers names Laptop; appearance works everywhere in this app | Infer the sole eligible target, but show shared-server effect before saving server config. | Details shows provenance; “For this project” appears only with a real project and support. |
| Second connection added | Same five groups; server-owned shortcuts show two named rows with current values; one brief message: “App preferences work on both. Each server keeps its own setup.” | Do not reset/copy existing values or turn on monitoring. Offer “Use the same model for new chats” as an optional personal preference, only after compatibility check. | Compare values, explicit connection/project overrides, later copy/template actions. |
| Phone host and laptop both live | Servers names both; This phone controls the host; Model choices name destination; notifications identify the source | Infer a new chat's destination from an explicit project/chat context. Otherwise use a visibly labeled last destination or ask once; never infer from which server is busiest. | Multiple host details, connection status and independently selected monitoring. |
| Shared server has a different model/rule | “Set on Laptop” / “Different for this project”; explain effective behavior in one line | Do not claim who changed it unless provenance exists. Offer “Use default” only when that operation is real. | Compare observed sources/revisions; resolve a conflict; inspect sanitized settings. |
| Many servers | Search/favorites and a count, not 10 rows on the root hub | Remember navigation separately from preference authority. | Visible “Copy to other servers…”, “Templates”, “Export preferences”, per-target receipts. |

**Progressive disclosure:** collapse the target picker when there is one eligible target; reveal a list when there are several. Always show a remote write's named owner, privacy/authority effect, managed restriction, conflict or override; none requires opting into technical controls. Details contains IDs, path/source metadata and revision, not the only explanation of a setting's effect. The optional technical/raw view is a read-only allowlisted, redacted projection, never a raw credential response or arbitrary JSON write editor. Per-project controls appear when a project context and supported operation exist, not merely after ten servers are added. Bulk/export actions are task-specific secondary rows on a page with something portable to copy.

**What may be inferred:** sole eligible target, known project owner, system language/reduced motion, a supported runtime default, previously explicit new-chat destination. **What must be asked:** granting automatic monitoring, moving credentials/data, linking unverified quota identities, changing shared configuration, broadening permission, selecting among ambiguous destinations, and applying copied settings to additional targets. Do not ask again for an unchanged operation already explicitly approved; invalidate approval only when its target, value or authority effect changes.

## Recommendation and owner decisions

Adopt app-wide preferences plus named connection pages, with project/chat overrides only where their contracts exist. Keep server configuration, host lifecycle and provider account facts as separate authorities behind those pages; use simple consequence labels and always-visible differences. Correct today's misleading model, read-state, phrase and background scope copy first, then add target-pinned contracts and narrowly scoped migrations. Offer a personal new-chat preference to make ordinary use consistent, while reserving remote copying/templates for explicit, capability-checked actions with per-target receipts. This handles one phone server, a phone plus laptop, and many heterogeneous agents without making the root Settings screen a global server mode.

Decisions for the owner (recommended option in bold):

1. Root navigation: **app groups plus per-connection pages**, retaining the five IA groups and topic shortcuts; no global server scope switcher.
2. Hub Model wording: **“Model for new chats” on the page**, with a named connection or optional personal preference; never call a local explicit preference “Server default”.
3. Consistency across servers: **personal preferred model for new chats, initially unset**, resolved against each target; preserve existing per-server choices as overrides.
4. Read-state sharing: **per-connection opt-in**, with one-time preservation for existing profiles; new profiles off.
5. Two phone environments: **show both installed hosts, one preferred new-chat destination**, and expose only operational concurrency actually supported by runtime evidence.
6. Notification policy: **one global quiet schedule and event defaults, per-connection monitoring consent and optional event overrides**; no quiet-hour bypass initially.
7. Bulk changes: **defer until typed adapters and receipts exist**; use “Copy to other servers…” with offline skip; exclude credentials and grants.
8. Templates and future servers: **explicit application at onboarding, never automatic enforcement**.
9. Usage account linking: **verified identity or explicit user link; otherwise separate unknown sources**, without a fabricated grand total.
10. Expertise controls: **task-specific progressive disclosure**, no global advanced switch; overrides and shared effects remain visible to everyone.
11. Sync/export: **allowlisted personal preferences first**, no credentials, consent, host control, memory content or raw server configuration.
12. Delivery order: **shared preference propagation/privacy revocation, labels/target contracts and read-state ownership before Usage widget or bulk tooling**; retain existing capability gates until separately verified.
