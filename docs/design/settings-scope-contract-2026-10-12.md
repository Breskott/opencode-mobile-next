# Settings scope: frozen UI contract — 2026-10-12

Status: implementation contract for approved slices A/B/D. Initial freeze precedes implementation; availability below is the promised boundary, not a claim that code already exists. Source study: [Settings scope](settings-scope-2026-10-12.md). Finish line: shared observable device preferences, explicit target-bound local settings, shared privacy revocation, and per-profile read-state consent. Non-goals: Settings redesign, generic remote configuration writes, cross-server copying, templates, export, Usage widget and project preference inheritance.

## Public domain API

Import `package:opencode_mobile/domain/settings_scope.dart`. These types contain no Flutter, storage or protocol dependencies. IDs are opaque, non-secret identity; UI supplies localized owner names separately. Never put credentials, raw provider configuration or user-entered secret values in these objects.

```dart
enum SettingOwnerKind { device, connection, host, providerAccount, project, chat }
enum SettingAuthority { localPreference, serverConfiguration, hostRuntime, providerAccount }
enum SettingValueState { known, unknown, unsupported, stale }
enum SettingOriginKind { defaultValue, explicitValue, migrated, reported }
enum SettingsFailureReason {
  unsupported, invalidValue, staleTarget, conflict, storageFailed,
  disposed, offline, needsSignIn, managed, outcomeUnknown
}

class SettingsTarget {
  const SettingsTarget.device();
  const SettingsTarget.connection(String profileId);
  const SettingsTarget.host(String hostId);
  const SettingsTarget.providerAccount(String accountId);
  const SettingsTarget.project(String profileId, String projectId);
  const SettingsTarget.chat(String profileId, String sessionId, {String? projectId});
  SettingOwnerKind get kind;
  String get ownerId; // device is 'device'; connection is its profile ID
  String? get profileId;
  String? get projectId;
  String? get sessionId;
  // Structural == and hashCode; non-device IDs must be nonempty.
}

class SettingsRowScope {
  const SettingsRowScope({required String rowId,
    required Set<SettingOwnerKind> owners, required String labelCode});
  String get rowId;
  Set<SettingOwnerKind> get owners;
  String get labelCode; // fixed semantic token, never a localized sentence
}

class EffectiveSetting {
  const EffectiveSetting({required String id, required SettingsTarget target,
    Object? value, SettingValueState state = SettingValueState.known,
    SettingAuthority authority = SettingAuthority.localPreference,
    SettingOriginKind origin = SettingOriginKind.defaultValue,
    int revision = 0, bool writable = false,
    SettingsFailureReason? reason});
  // final public fields with the same names/types as constructor arguments
}

class SettingsEditToken {
  const SettingsEditToken({required EffectiveSetting before,
    required String ownerFingerprint});
  final EffectiveSetting before;
  final String ownerFingerprint; // opaque, excludes credentials
}
class SettingsReceipt {
  const SettingsReceipt({required EffectiveSetting confirmed});
  final EffectiveSetting confirmed; // only after acknowledged local persistence
}
class SettingsFailure implements Exception {
  const SettingsFailure(this.reason);
  final SettingsFailureReason reason; // toString exposes reason only
}

abstract interface class SettingsAccess {
  Future<EffectiveSetting> readSetting(String id, SettingsTarget target);
  Stream<EffectiveSetting> watchSetting(String id, SettingsTarget target);
  Future<SettingsEditToken> beginEdit(String id, SettingsTarget target);
  Future<SettingsReceipt> writeSetting(SettingsEditToken edit, Object? value);
}

abstract final class SettingsScopeCatalog {
  static List<SettingsRowScope> get rows;
  static SettingsRowScope? forRow(String rowId);
}
```

The token is a snapshot for conflict/identity checks, not an authorization credential. Production access verifies a token was issued by that access instance. Switching the main connection does not retarget it. Removing/replacing the profile or changing its transport identity invalidates it. A newer observed settings revision causes `conflict`; the UI rereads before trying again. No network calls happen through this facade in A/B/D. Unsupported scopes remain metadata and return `unsupported`, not fabricated effective values. Watch streams emit an initial value, subsequent local changes, and stale/deleted target states; cancel subscriptions when leaving the page.

## Production facade and fixture

Import `state/settings_access.dart` for `ProfileSettingsAccess(ProfileStore store)`, implementing `SettingsAccess`, plus `void dispose()`. Construction/read/watch never connects, polls or mutates a server. Dispose closes watches and rejects later operations. UI may instantiate one per named page and dispose it, or retain one above Settings. It must pass the target captured when the page opens, not read a mutable current profile when Save is tapped.

Import `domain/settings_scope_fixture.dart` for `MemorySettingsAccess({Iterable<EffectiveSetting> initial = const []})`, implementing the same four methods, with `void publish(EffectiveSetting value)` and `void dispose()`. This deterministic in-memory fixture needs no ProfileStore, plugin channels, server or timers. Public const snapshot/target constructors also let widgets accept fixed scenes. Fixtures preserve target/revision conflicts; they are not production storage.

| Setting ID | Value schema | Target | A/B/D write support |
|---|---|---|---|
| `appearance` | `system`, `light`, `dark` String | device | Yes |
| `themePack` | existing `ThemePackId.name` String | device | Yes |
| `locale` | supported language code String or null for system | device | Yes |
| `reasoningExpanded`, `timestampsVisible` | bool | device | Yes |
| `effects` | Map with `motion`, `activityGlow`, `glowStyle`, `glowColours`, `glowSpeed`; enum values by name; activityGlow bool | device | Yes, full object; celebrations derived from motion, haptics unchanged |
| `shareReadState` | bool | connection | Yes; false is immediate fail-closed revocation, true only after durable acknowledgment |
| `model` | null or Map `{providerId: String, modelId: String}` | connection | Read-only local new-chat preference; no remote default write |
| `agent`, `variant` | String | connection | Read-only local new-chat preference |

`EffectiveSetting.origin` distinguishes saved explicit intent, migrated read consent and shipped fallback. Unknown/unsupported values are not editable. Errors are fixed reasons: unsupported id/target, malformed value, changed/deleted target, newer revision, failed storage, or disposed facade. Reserved network/managed reasons are declared for future adapters but do not imply those adapters exist. Do not interpret a local model snapshot as the model confirmed in a running chat.

## Shared device preferences

Import `state/app_preferences.dart`:

```dart
class AppPreferencesSnapshot {
  const AppPreferencesSnapshot({required AppAppearance appearance,
    required ThemePackId themePack, required Locale? locale,
    required KitEffects effects, required bool reasoningExpanded,
    required bool timestampsVisible});
  // final fields with the same names/types
}
class AppPreferencesStore extends ChangeNotifier {
  factory AppPreferencesStore.forPreferences(SharedPreferences preferences);
  AppPreferencesSnapshot get value;
  int get revision;
  ReadStateConsentStore get readStateConsent;
  int get privacyEpoch; // shared readStateConsent epoch
  Future<void> setAppearance(AppAppearance value);
  Future<void> setThemePack(ThemePackId value);
  Future<void> setLocale(Locale? value);
  Future<void> setEffects(KitEffects value);
  Future<void> setReasoningExpanded(bool value);
  Future<void> setTimestampsVisible(bool value);
}
```

`ProfileStore.appPreferences` returns this shared owner; separate ProfileStore objects over the same SharedPreferences instance obtain the same owner. Every main, secondary and isolated controller subscribes to it. Existing controller locale/appearance/theme/effects ValueNotifiers remain controller-owned mirrors for compatibility with the current app and UI previews; disposing a secondary controller must not dispose shared state. Committed writes serialize and publish after storage acknowledgment. A refused write throws `SettingsFailure(storageFailed)` and cannot become a successful visible save. Existing keys/defaults remain; effects changes preserve other fields, and partial persistence must be recovered or reported without claiming atomic success. Controllers and UI must use these methods, not write SharedPreferences directly.

## Read-state consent and revocation

Import `state/read_state_consent.dart`:

```dart
class ReadStateConsentStore extends ChangeNotifier {
  factory ReadStateConsentStore.forPreferences(SharedPreferences preferences);
  int get epoch;
  bool enabled(String profileId);
  bool saving(String profileId);
  SettingOriginKind origin(String profileId);
  Future<void> migrateExistingProfiles(Iterable<String> profileIds);
  Future<void> setEnabled(String profileId, bool value);
  Future<void> closeProfile(String profileId);
  void reopenProfile(String profileId);
}
```

`enabled` is local consent, not proof the server supports read receipts. Dispatch also checks the actual `SessionReadStateGateway`. Empty, unknown/unmigrated and fresh profiles default off. `ProfileStore.load` migrates the existing stored profile population locally before exposing it; `upsert` must not add a new profile to that old population. Migration captures a durable cohort before copying and commits completion last. Preserve an existing destination value. Legacy global missing means its previous shipped default true for the captured existing population; malformed legacy values fail closed. Unknown capabilities retain the migrated value without any network activity, and use it only through a supported live gateway. New profiles stay off. Do not reapply legacy global consent on later loads.

Use `oc.shareSessionViews.<profileId>` and `oc.shareSessionViewsOrigin.<profileId>`. Migration cohort is a device-level versioned journal; deletion prunes owner references and drains accepted writers before the standard suffix sweep. Legacy `oc.shareSessionViews` is retained for rollback compatibility, never used as a runtime fallback after migration. New code is the sole writer of per-profile keys; old builds are not promised forward privacy compatibility.

Any consent mutation/revocation changes the shared epoch before await. During an accepted mutation its target cannot dispatch sharing; opt-out remains false in memory even when persistence fails. Opt-in is published only after acknowledgment and only if no later revocation superseded it. Every controller captures/checks that epoch after asynchronous local persistence/wake and before sending or applying an acknowledgment. Already transmitted server requests cannot be recalled. Deletion closes the owner to writes and dispatch, drains persistence, clears scoped keys/shared journal references and invalidates stale tokens. A failed deletion keeps the profile available for retry while privacy stays off until explicitly restored.

Controller compatibility: `shareSessionViews`, `savingReadPrivacy`, `readPrivacyRevision` now refer to its named connection and the shared epoch. `Future<void> setShareSessionViews(bool value, {String? expectedProfileId})` captures its current owner before await and rejects a mismatching expected owner. UI should prefer the facade token; the existing Privacy row uses the expected-profile argument and displays that connection's name. No-profile privacy controls are unavailable.

## Row owner and label contract

These are semantic label codes with suggested English, for the slice C builder to localize. Owner names are passed independently through existing safe presentation helpers. Never call a local model preference “Server default”. Show meaningful overrides/shared effects even in the regular-user view. Multi-owner rows are landing pages, not one polymorphic write.

| Row / inner controls | Owners | labelCode / suggested copy |
|---|---|---|
| Servers, add/edit/sign-in/remove/disconnect/Tailscale | device, connection | `connection` — “{server}”; removal: “Remove {server} from this app” |
| This server health/version/capabilities/plugins/AI setup | connection | `serverReported` — “On {server}”; shared config: “Saved on {server}” |
| This phone/start/stop/update/tools/storage/export/terminal/recovery/idle | host | `host` — “{host} on this phone” |
| Agents | host, connection, project | `byOwner` — separate On this phone / Connected agents / AI Team |
| Phone-agent selection/model for new chats | connection | `newChats` — “New chats on {server} in this app” |
| Model, variant, agent, favorites/recent | connection | `newChats` — “New chats on {server} in this app” |
| Chat model/agent/variant and auto-approval | chat | `chat` — “This chat”; connection-wide approval must name its wider effect |
| Providers/account sign-in/credential label/use/remove | connection, providerAccount | `serverAccount` — “Account used on {server}”; remote credentials are server-owned |
| Tools/MCP | connection, project, chat | `nativeConfiguration` — “On {server}” / “{project} on {server}” / “Until this runtime restarts”, according to actual contract |
| Commands/tools/skills/references inspection | connection, project | `serverReported` — “Reported by {server}”; Tools Choose model changes the local new-chat default |
| External agents registry | device | `device` — “On this phone”; remote actions name the selected agent |
| AI Team binding/model/roles/supervision | connection, host, project | `byOwner` — name the engine/project and any host-wide effect |
| Show reasoning; time/tokens/cost; phrase enable; voice; appearance/language/effects | device | `device` — “On this phone” |
| Hidden/learned phrases; reader overrides | connection | `connectionLocal` — “For {server} on this phone” |
| Notifications/quiet hours/Wi-Fi/check-ins/quota master/test | device | `device` — “On this phone”; quiet hours cover all connections |
| Monitor server / source notifications | connection | `connectionLocal` — “Watch {server} on this phone” |
| Stay connected / battery permissions / thermal guard | device, host | `deviceAndHost` — distinguish app connection from host lifetime |
| Permissions and automation / saved grants | connection, project, chat | `byOwner` — device consent vs native project/chat rules, never generic All |
| Privacy read-state sharing | connection | `connectionLocal` — “Share read state with {server}” |
| Privacy local storage/clear queues/drafts | device | `device` — “On this phone · All servers” |
| Usage spending/budgets | connection, project | `measurement` — named server/project, unit and period; budget is local |
| Usage remaining/account allowance | providerAccount, connection | `accountSource` — account and reporting server; freshness/window always visible |
| Quota monitoring / 80% alert | connection, providerAccount | `accountSource` — source enrollment vs account observation, do not imply dedupe |
| Usage widget (future) | device | `device` — “This widget on this phone”; selected sources remain explicit |
| Help/About/guide/demo/licences/tips/shortcuts | device | `device` — no extra preference owner for static information |
| Diagnostics/crash capture/report inclusion | device | `device` — capture consent and one-report consent remain distinct |

`SettingsScopeCatalog.rows` covers every 21 hub + 43 inner-settings search ID from the study, including aliases; aliases reuse ownership, not duplicate preferences. The 17 non-settings destinations do not become settings. The catalog is metadata only: an owner listed there does not grant write support.

## OC1 chat-agent correction

Keep profile default `oc.agent.<profileId>` unchanged when selecting an agent inside an OC1 chat. Persist chat-agent overrides in `oc.sessionAgents.<profileId>` keyed by session ID, capped and swept with the profile; remove on chat deletion. Selection applies only to that chat, survives reconnect/restart, and is used by prompt dispatch. OC2/Paseo retain their existing server-owned session mutation path. This fixes a state defect, not slice E's future project/model inheritance.

## Change discipline

After the initial freeze commit, append a dated **Changes** section for any public signature, schema or behavioral change. No silent contract edits. The implementation handoff records focused checks, remaining C/E/F/H work and exact commit boundaries. No push and no full-suite claim.

## Changes — 2026-10-12: implementation integration

The frozen UI signatures, value schemas, row labels and supported writes remain unchanged. The implementation adds `ReadStateConsentStore.setEnabledIfCurrent(String profileId, bool value, {required bool Function() isCurrent})` for controller/facade integration: it checks the captured owner before writing and before publishing consent. A late identity change returns `staleTarget`, keeps sharing off, and attempts to persist false if true reached storage. Storage refusal is never a successful receipt; as with any refused opt-out, fail-closed memory cannot promise durable change when the platform refuses it. Migration blocks the captured profiles while its writes are pending and retries from the original journal.

For acknowledged provenance, `AppPreferencesStore.hasStoredPreference(String key)` reports snapshot membership and `ProfileStore.confirmedSelectionPreference(String key)` reads only the supported model/explicit-model/agent/variant metadata. These are integration helpers; UI should continue using `EffectiveSetting.origin` and the frozen facade. Profile registry observations are shared by stores using the same SharedPreferences instance, so replacement/deletion invalidates every observer. Legacy controller locale calls retain their established `ArgumentError`/`AppLocaleSaveException` compatibility; the new shared store and facade use the frozen `SettingsFailure` reasons.
