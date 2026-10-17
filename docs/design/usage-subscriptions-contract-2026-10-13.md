# Usage subscriptions: model and controller contract (slice 1)

Date: 2026-10-13. Branch `feat/usage-rebuild`. Source of truth for the UI builder.
Proposal: "Usage Rebuild" v2 (decisions D1 to D7 accepted; owner change: show the
5-hour and weekly limits together wherever the provider reports both, on every
surface, the widget included).

Files:

- `lib/domain/usage_subscriptions.dart`: types and the pure merge. No Flutter, no I/O.
- `lib/state/usage_subscriptions_controller.dart`: `UsageSubscriptionsController` (ChangeNotifier), alert state, persistence.
- `lib/state/usage_subscription_sources.dart`: production sources (collector, Paseo, Codex account, OpenCode sign-ins).
- `lib/background/usage_widget_snapshot.dart`: the widget feed (`publishSubscriptions`).

The UI imports only the domain file and the controller. It never touches `api/`, `api2/` or the monitors.

## 1. Dart types (`lib/domain/usage_subscriptions.dart`)

```dart
enum UsageConnectionKind { inAppUbuntu, phoneAgents, openCodeServer, paseoServer, codexServer }

class UsageConnection {            // value equality on id
  final String id;                 // saved profile id, or 'phone' (UsageConnection.phoneId)
  final String name;               // the saved name; 'phone' is named by the UI (copy key)
  final UsageConnectionKind kind;
}

enum SignInState { signedIn, expired, notSignedIn }
enum SignInMethod { plan, apiKey, unknown }   // plan = OAuth / account sign-in

class SignedInOn {
  final UsageConnection connection;
  final SignInState state;
  final SignInMethod method;
  final bool readsFromHere;        // true: the numbers on the card came from this connection
  final bool online;               // false: last answer failed or it was unreachable
}

enum UsageWindowKind { fiveHour, weekly, monthly, other }

class UsageWindow {
  final String id;                 // provider's window id, '5h', 'weekly', ...
  final UsageWindowKind kind;
  final String label;              // cleaned provider label, only meaningful when kind == other
  final double usedPercent;        // 0..100
  final double leftPercent;        // 100 - used
  final int? durationSeconds;
  final DateTime? resetsAt;
  bool resetPassed(DateTime now);  // resetsAt <= now
}

enum SubscriptionState {
  ok, nearLimit, exhausted,
  cantReadYet,    // signed in somewhere no reader reaches
  signInExpired,  // the sign-in on the connection being read ran out
  notSignedIn,    // used before, signed in nowhere (or the daemon says "sign in")
  readerBroken,   // reader answered with an error
  offlineStale,   // source connection unreachable; last numbers kept
  noLimits,       // reader works, provider gave no limits
  apiKeyOnly,     // pay-as-you-go key, no plan limits (never a main-list card)
}

enum UsageFix { none, signIn, addKey, setUp, tryAgain }

class UsageSubscription {
  final String key;                // 'codex|<accountRef>' or 'codex|conn:<connectionId>'
  final String providerId;         // 'codex' 'claude' 'glm' 'minimax' 'copilot' ...
  final String displayName;        // cleaned provider name; the UI localizes the known four
  final String? planLabel;         // 'plus', 'pro', 'max' ...; null when unknown
  final String? accountRef;        // opaque hash, never shown
  final List<UsageWindow> windows; // all reported windows, 5h then weekly then others
  final UsageWindow? fiveHour;     // convenience, null when not reported
  final UsageWindow? weekly;
  final DateTime? fetchedAt;       // when the numbers were measured
  final DateTime? checkedAt;       // last attempt (differs from fetchedAt while rate limited)
  final UsageConnection? readFrom; // the reading's source connection
  final List<SignedInOn> signedInOn;
  final SubscriptionState state;
  final UsageFix fix;              // the one button the card offers
  final UsageConnection? fixConnection; // where the fix happens
  final bool resetSinceLastReading;
  final bool showConnectionName;   // another card has the same provider: add the connection name
  final double alertThreshold;     // effective (override or default)
  final bool hasAlertOverride;
  final bool notifyOnReset;
  double? get mostUsedPercent;     // max over windows, null without windows
  double? get leastLeftPercent;
}

class ApiKeyAccount { final String providerId, displayName; final UsageConnection connection; }

class UsageSnapshot {
  final List<UsageSubscription> subscriptions; // the main list, most urgent first
  final List<ApiKeyAccount> apiKeyAccounts;    // "Details" rows for rows 14 and 15
  final List<String> addable;                  // provider ids never used: the "Add a subscription" list
  final List<UsageConnection> connections;     // every saved connection, plus 'phone' when supported
  final DateTime? refreshedAt;
  final bool loaded;                           // false until the first refresh finished
  bool get hasSeveralConnections;              // UI shows server names only when true (rows 28/29)
}
```

`UsageWidgetSettings` (`hiddenKeys`, `showSetupRows`, `windows`: `UsageWidgetWindows.both|fiveHour|weekly`) lives in `lib/background/usage_widget_snapshot.dart`.
The phone host's `UsageConnection.name` is empty: the UI names it with the "This phone" copy key.

Source-side types (UI never sees them): `UsageReading`, `UsageSignIn`, `UsageFailure`, `UsageSourceResult`, `UsageSource`.

### Ordering ("most urgent first")

exhausted, signInExpired, nearLimit, readerBroken, cantReadYet, notSignedIn, offlineStale, ok, noLimits.
Inside `ok` and `nearLimit` the card with the least remaining percent comes first; ties break on provider id then connection name.
The widget and the page use the same list.

## 2. Controller API (`UsageSubscriptionsController`)

```dart
class UsageSubscriptionsController extends ChangeNotifier {
  UsageSnapshot get snapshot;                 // current list; notifies on every change
  UsageSubscription? subscription(String key);
  bool get refreshing;
  Future<void> refresh({bool force = false}); // every source, de-duplicated; never connects or switches the active server
  void setRuntime({required bool foreground, required bool backgroundAllowed});
  void start();                               // schedules 5 min foreground / 15 min background (only when allowed)

  // Alerts (one page, one switch)
  bool get alertsOn;                          // reads oc.notify.quotaAlerts via SharedNotifyRules
  Future<void> setAlertsOn(bool value);       // writes through ConnectionController.updateSharedNotifyRules
  double get defaultThreshold;                // 80
  Future<bool> setDefaultThreshold(double percent);
  Future<bool> setThresholdFor(String key, double? percent); // null clears the override
  bool get notifyOnResetDefault;              // D5, false
  Future<bool> setNotifyOnReset(String key, bool value);
  Future<bool> setNotifyOnResetDefault(bool value);
  List<UsageSubscription> get alertOverrides; // "Different from default" list on the Alerts page

  // Widget settings
  UsageWidgetSettings get widgetSettings;     // {hiddenKeys, showSetupRows (default true), windows: both|fiveHour|weekly}
  Future<void> setWidgetSettings(UsageWidgetSettings value);

  void removeProfile(String profileId);       // deletion cascade: cache, seen records, overrides, widget rows
}
```

Errors: no method throws to the UI. Setters return `false` when the store refused; `refresh` swallows per-source failures and turns them into card states (`readerBroken`, `offlineStale`). No raw error text is ever stored or exposed; technical detail for "Details" is limited to `readFrom`, `fetchedAt`, `checkedAt`, `windows[].id`, `accountRef` presence.

Fix actions the UI performs:

| `fix` | Button | Goes to |
|---|---|---|
| `signIn` | Sign in / Sign in again | the Add-subscription flow on `fixConnection` (OpenCode: provider sign-in; phone: agent sign-in sheet) |
| `addKey` | Add key | the same flow, key step (GLM, MiniMax) |
| `setUp` | Read usage from `<fixConnection.name>` | the "Read usage from" screen |
| `tryAgain` | Try again | `controller.refresh(force: true)` |

Widget deeplink: `usage_target:<action>:<provider>:<connectionId>` with action in `sign_in`, `add_key`, `set_up`. `set_up` maps to `UsageSignInKind.readUsageFrom` in `usageSignInDestination`. Until the screen exists the launch route opens the Usage page.

Reach it with `connection.usageSubscriptions` (`ConnectionController`). It starts on its own only when something is set up to be read (an enrolled collector, an opted-in Paseo server, In-app Ubuntu's reader); otherwise the Usage page calls `refresh()` when it opens. Sources: `QuotaCollectorSource` (In-app reader and consented remote collectors, also the alert bridge), `PaseoUsageSource` (phone host and opted-in Paseo servers), `AgentAccountSource` (the open Codex connection), `OpenCodeSignInSource` (`ServerGateway.providers()` on each saved OpenCode server through a short-lived gateway).

## 3. Combination table (30 rows) to model state

"Model" says what `UsageSnapshot` holds. Tests: `test/usage_subscriptions_test.dart` (merge) and `test/usage_subscriptions_controller_test.dart`.

| # | Situation | Model |
|---|---|---|
| 1 | One connection, nothing signed in | `subscriptions` empty, `addable` = all plan providers, `hasSeveralConnections` false |
| 2 | In-app Ubuntu, Codex signed in | one card, `ok`, `readFrom` In-app |
| 3 | Codex on PC only, no reader | card `cantReadYet`, `fix=setUp`, `fixConnection=PC`, `signedInOn=[PC signedIn, readsFromHere=false]` |
| 4 | Same, PC reader set up | the reader reports a reading with `connectionId=PC`; card `ok`, `readFrom=PC` |
| 5 | PC offline | `offlineStale`, last windows kept, `signedInOn[PC].online=false`; `resetSinceLastReading` true when a reset passed |
| 6 | Same account on PC and In-app | one card; key `codex|<ref>`; freshest reading is `readFrom`; both in `signedInOn` |
| 7 | Two accounts | two cards (different `accountRef`); `showConnectionName` true on both |
| 8 | Ten servers | still one card per key; `signedInOn` lists them; the widget takes the first N |
| 9 | Server removed | `removeProfile` drops its cache and seen records; cards held only by it vanish, shared ones keep the other connections |
| 10 | Termux plus In-app Ubuntu | two connections; same `accountRef` merges (row 6 rules) |
| 11 | Signed in nowhere, used before | `notSignedIn`, `fix=signIn` (`addKey` for glm and minimax) at the connection that held it |
| 12 | Never used | not in `subscriptions`; listed in `addable` |
| 13 | Sign-in expired on the connection being read | `signInExpired`, `fix=signIn`. If another connection has a good reading of the same account it wins and the expired one shows in `signedInOn` with `state=expired` |
| 14 | Codex API key only | `apiKeyAccounts` row; no card |
| 15 | Claude (or any) API key in OpenCode only | same as 14 |
| 16 | Claude Max in Claude Code on the phone | card, `readFrom=phone` (Paseo reading) |
| 17 | Claude Code on a PC with Paseo | card, `readFrom=PC` |
| 18 | Claude Code installed, signed out | `notSignedIn`, `fix=signIn`, `fixConnection` = where the daemon said so |
| 19 | Under the alert level | `ok` |
| 20 | Past the alert level | `nearLimit`, sorted up |
| 21 | Limit reached | `exhausted`, sorted first; any window at 100 |
| 22 | GLM three limits | `windows` holds all three; `fiveHour` and `weekly` set; the card shows those two |
| 23 | Provider gave no limits | `noLimits` |
| 24 | Provider limiting checks | `ok` with the old numbers; `checkedAt` newer than `fetchedAt`; no error state |
| 25 | Reader broken | `readerBroken`, `fix=tryAgain`; old numbers kept |
| 26 | App closed for hours | `refresh()` runs before the first draw (`loaded=false` until done); `resetSinceLastReading` after a passed reset |
| 27 | Paseo reports Copilot, Kimi, Grok, Cursor | cards with their provider ids, same rules |
| 28 | Regular user, one connection | `hasSeveralConnections=false`: UI hides server names, "Signed in on", Details |
| 29 | Advanced user | `hasSeveralConnections=true`; `showConnectionName` where names collide |
| 30 | Arabic, large text | UI only; model strings carry no copy |

## 4. How alerts work (D4, D5)

- One switch: `oc.notify.quotaAlerts` (shared notification rules). No per-plan enrolment: when the switch is on, the controller enrols every readable collector subscription in `ProviderQuotaMonitor` at the effective threshold (default 80) after each refresh, and keeps the monitor's per-source threshold equal to the effective one. The monitor's timer, native delivery and dedupe markers are unchanged.
- Storage: one shared blob `oc.usageAlerts.v1` (not per profile): `{default, notifyOnReset, overrides: {<key>: {threshold?, notifyOnReset?}}, migrated}`. Overrides hold opaque subscription keys, never names. `removeProfile` prunes overrides whose subscription no longer exists anywhere.
- Migration (once, marker `migrated`): every `oc.quotaMonitor.<profileId>` rule whose threshold is not 80 becomes an override for `<provider>|<rule.account>`. Rules stay in place (the monitor needs them).
- Per-connection last readings: `oc.usageLast.<profileId>` (`phone` for the phone host): display numbers only (provider, name, account hash, plan label, windows, fetch time, status). Swept by the profile deletion sweep.
- Widget settings: `oc.usageWidget.v1` (shared): hidden subscription keys, `showSetupRows` (default true, D7), `windows` (`both` default).

## 5. Widget feed

`UsageWidgetSnapshot.publishSubscriptions(snapshot, settings)` writes one document to `oc.widgetUsageSubs`:

```json
{"v":1,"entries":[{"key":"…","provider":"codex","name":"Codex","state":"ok",
 "fetchedAt":123,"windows":[{"seconds":18000,"left":18,"resetsAt":123},{"seconds":604800,"left":59,"resetsAt":123}],
 "action":"","profileId":""}]}
```

- Entries are in page order; each carries both the 5-hour and weekly windows when reported.
- `state` is `ok | near | out | stale | reset | setup | signin | broken`; `action` is `sign_in | add_key | set_up | ""`; `profileId` is `fixConnection.id`.
- Setup rows (`cantReadYet`, `notSignedIn`, `signInExpired`) are included unless `showSetupRows` is off; hidden keys are left out.
- Native prefers this document when present and falls back to the old `oc.widgetUsage.<profileId>` rows otherwise, so nothing breaks before the first publish.

## 6. Copy keys needed (names only, English intent). Do not add to the ARB yet.

usageTitle "Usage"; usageTabPlans "Plans"; usageTabSpending "Spending"; usageEmptyTitle "No subscriptions yet"; usageAddSection "Add a subscription"; usageAddTitle "Add {provider}"; usageAddWhere "Where should {provider} be signed in? The app reads usage from whichever you pick."; usageBest "Best"; usageLeft "{percent}% left"; usageUsed "{percent}% used"; usageWindowFiveHour "5 hours"; usageWindowWeek "Week"; usageWindowMonth "Month"; usageResetsAt "Resets {time}"; usageResetsIn "Resets at {time}, in {duration}"; usageOutUntil "Out until {time}"; usageResetSince "Reset at {time} since the last reading"; usageReadAgo "Read {age} ago"; usageCheckedAgo "Checked {age} ago"; usageOfflineStale "{connection} is offline · read {age} ago"; usageStateCantRead "Can't read yet"; usageCantReadBody "Signed in on {connection}. The app can't read its limits from there yet."; usageReadFrom "Read usage from {connection}"; usageSignInRanOut "{provider} sign-in on {connection} ran out"; usageSignInAgain "Sign in again"; usageSignIn "Sign in"; usageAddKey "Add key"; usageNotSignedIn "Not signed in anywhere"; usageSignInAgentTitle "Sign in to {provider}"; usageReaderBroken "Can't read {provider} right now"; usageTryAgain "Try again"; usageNoLimits "No limits reported for this plan"; usageApiKeyOnly "{provider} API key on {connection} · pay as you go, no plan limits"; usageSignedInOn "Signed in on"; usageThisPhone "This phone"; usageInAppUbuntu "In-app Ubuntu"; usageSameAccount "Same account"; usageDetails "Details"; usageDetailReader "Reader"; usageDetailChecked "Checked"; usageDetailAccount "Account"; usageAlertsTitle "Alerts"; usageAlertsSummary "On · at {percent}% used"; usageAlertsSwitch "Usage alerts"; usageAlertsSwitchHelp "Watches every subscription the app can read"; usageAlertAt "Alert at"; usageAlertAtDefault "Default for every plan"; usageAlertAtPlan "For {provider} only. Other plans use {percent}%."; usageAlertsDifferent "Different from default"; usageNotifyReset "Tell me when a limit resets"; usageNotifyResetBody "{provider} is back: the {window} limit reset."; usageWidgetRow "Home screen widget"; usageWidgetSubs "{count} subscriptions"; usageWidgetSettingsShow "Show these plans"; usageWidgetSettingsWindows "Show 5-hour, weekly or both"; usageWidgetSettingsSetup "Show rows that need setup"; usageUrgentAmber "Past {percent}%"; usageRetryChecking "Checking…".

## 7. Open questions (with recommendation)

1. **Account identity beyond the In-app collector.** Only the collector (and the Codex account, hashed from its email) gives an account hash. A sign-in seen through `ServerGateway.providers()` or a Paseo reading carries none, so those key on the connection and two connections of the same real account stay as two cards (rows 6 and 10 merge only when two readers report the same hash). Recommendation: accept for now; the computer reader (D2) must return the same collector hash so PC and In-app merge.
2. **Plan versus API key.** `ProvidersResponse` lists connected providers but not how they signed in, and `listIntegrations()` reports `credential` for both. The production sign-in source marks `SignInMethod.unknown`, so OpenAI with an API key shows `cantReadYet` (not `apiKeyOnly`) until a reader answers. The model and tests fully support `apiKeyOnly` once a method is known. Recommendation: ask OpenCode for the auth type (`/auth` store type `oauth` vs `api`) in a later slice.
3. **Alerts for non-collector readings.** `ProviderQuotaMonitor` delivery is token-routed per collector rule. Paseo and Codex-account readings are shown and widgeted but do not alert yet. Recommendation: a follow-up slice adds a second delivery path keyed on the subscription key, reusing the same dedupe marker scheme.
4. **Numbers-row widget tap.** The channel still opens Usage. Recommendation: later add `usage_target:open:<provider>:<connection>` to open the subscription page.
5. **"Tell me when it resets" delivery** (D5) is stored (`notifyOnReset`) and exposed, but delivery shares open question 3.
6. **`readerBroken` fix on the widget** is intentionally absent (no `try_again` deeplink); the widget shows "Updated X ago".

## 8. Slice 4: read a computer's plans through OpenCode (decision D2)

Date: 2026-10-13. Closes open questions 2, 3 and 5; narrows question 1.

### What it is

A Codex, GLM or MiniMax plan signed in through OpenCode on a saved computer can now be read. The app runs a one-shot, read-only check on that computer through the OpenCode server it is already authenticated to, reads one line from the terminal, and removes the terminal. Nothing is installed, no port is opened, nothing is written to the computer's disk, nothing keeps running.

- Reader: `tool/quota/read_once.mjs` (self-contained, about 18 KB, passed as ONE `node --input-type=module -e <source>` argument; it ships as a Flutter asset). It reuses the collector's mappers by copy; `tool/quota/read_once.test.mjs` runs both on the same payloads, so drift fails.
- Output: exactly one line, `OCMN_USAGE_V1 <base64 JSON>`, then exit 0 after a 1.5 s linger (so a terminal that has already ended is not removed before the app attaches). JSON: `{v:1, providers:{codex,glm,minimax: ProviderQuotaSnapshot}, auth:{codex,glm,minimax: 'oauth'|'api'|null}}`, or `{v:1, error:'nodeTooOld'|'failed', providers:{}, auth:{...}}`. Never a token, key, email, path or provider error text.
- Sign-in files, in order: `$XDG_DATA_HOME/opencode/auth.json`, `~/.local/share/opencode/auth.json`, macOS `~/Library/Application Support/opencode/auth.json`, Windows `%LOCALAPPDATA%` and `%APPDATA%` `opencode/auth.json`. OpenCode 2 (`@opencode-ai/cli`, checked in the 2.0 binary) uses the same `<xdg data>/opencode/auth.json`; the In-app host's `/root/.oc-opencode2/data/opencode/auth.json` is that rule with `XDG_DATA_HOME` set. Codex only: `$CODEX_HOME/auth.json` or `~/.codex/auth.json`.
- Wire: `ptyCreate` with `command`, `args` and the title "OpenCode Mobile usage check" (`OneShotCommandGateway.createCommandTerminal` on both the OpenCode 1 and OpenCode 2 gateways), the PTY socket for output, `ptyRemove` always. Both gateways leave that title out of `listTerminals`. Checked once against a real OpenCode 1.18.23 with `bash -lc 'echo ...'`: create, connect, output `...\r\n`, remove (404 on a second remove is quiet).
- Source: `ComputerUsageSource` in `lib/state/computer_usage_source.dart`. Applies to saved OpenCode 1 and 2 profiles that are not In-app Ubuntu, only after the person turned it on for that server (`oc.usageComputerReader.<profileId>`, swept with the profile). It never connects or switches the active server (short-lived gateway pair, the same as the monitors).
- Command: `node --input-type=module -e <source>`. If the server refuses it, the terminal ends before output, or no answer comes, it runs once more as `bash -lc 'command -v node ... || exit 127; node --input-type=module -e "$1"' _ <source>` so a login PATH (nvm) is found. 25 s overall; the terminal is removed in every case (socket close and remove are each bounded).
- Cadence: Usage open reads at most once a minute, pull to refresh always reads, the background reads at most once per 15 minutes per computer (`UsageReadContext.background`). It starts on its own at app launch only when some computer is switched on.

### Card states

| Situation | State | Words |
|---|---|---|
| Node missing or older than 20 | `readerBroken` (a `broken` failure for each plan signed in there) | "{server} needs Node.js 20 or later." in the row, Read-from screen and Details ("Last check") |
| Server did not answer | `offlineStale` (`unreached`) | "Can't reach {server} right now." |
| No terminal API (OpenCode too old) | not left switched on | "OpenCode on {server} is too old for this. Update it and try again." |
| Started but never answered | `readerBroken` | "The check on {server} didn't finish. Try again." |
| Codex with an API key | `apiKeyOnly` (open question 2 closed for computers: the reader reports `oauth` or `api`) | |
| MiniMax pay-as-you-go key (`sk-api-`) | `apiKeyOnly` | |

`UsageReaderNotes.problemFor(connectionId)` (controller: `readerProblemFor`) keeps the plain reason for Details; no process or server text is kept.

### Screens

- Read-from, for a computer: the explanation, an expandable "What runs" (command line, where it reads), "Turn on" (runs one check at once and shows the plans found or the plain failure on the same screen), then "Read now" and "Turn off". "Coming soon" is gone.
- Plan page: a row "Reading {server} through OpenCode" with "Turn off", whether or not several connections exist.
- Plan page Connections: this phone is listed for a plan only when that plan's agent is installed on it (`AgentRow.installedOnPhone`); a stopped host says "Not running", never "Offline".

### Account hash (open question 1, narrowed)

The reader's `account.ref` is `HMAC-SHA256("ocmn-usage-ref-v1", accountId)` with the same `accountId` strings as the collector (`codex` account id, `glm:<key>`, `minimax:<key>`). Two computers signed in to the same account therefore merge. The In-app collector still keys its hash with its per-server read token, so a PC and In-app Ubuntu of the same account do NOT merge yet. Making them merge means switching the collector's `ref` to the same fixed key, which changes every existing In-app ref (overrides under `oc.usageAlerts.v1`, monitor rules). Left for a deliberate migration.

### Alerts (open questions 3 and 5)

`SubscriptionAlertDelivery` (`lib/state/usage_subscription_alerts.dart`) is the second delivery path, keyed on the subscription key. After each refresh the controller hands it the snapshot.

- Threshold (D4): every subscription the quota monitor does not already alert for (`UsageAlertCoverage.covers`) alerts when a window reaches its effective level. Marker per subscription, window, duration, reset time and level, stored in the shared `oc.usageAlertSeen.v1` (opaque keys and numbers only; pruned with `removeProfile`). A refused notification does not keep its marker.
- Reset (D5): when the plan's switch is on and a window that was at or past its level is below it with a new reset time (and the high reading was less than 12 h old), one "back" notification is sent, for every plan including collector ones.
- Rules reused: the shared alerts switch, quiet hours, Wi-Fi only, no delivery while the app is open, no alerts on numbers older than 45 minutes, offline or broken readers.
- Delivery: `showCodingAlert(kind: quota | quotaReset, sessionID: 'quota', profileID: <read-from connection>, monitorToken: sha256(subscription key))`. A tap resolves through `UsageSubscriptionsController.ownsAlertToken`, then the Usage page. Native: new fixed-copy kind `quota_reset` ("{provider} is back", provider name validated like `agentName`); this is a native change and needs a new release, not a patch.

### Tests

`test/computer_usage_source_test.dart` (parsing with echo and ANSI, timeout, terminal always removed, Node fallback, each failure, opt-in, cadence, mapping), `test/computer_usage_wire_test.dart` (both gateways on the wire), `test/usage_subscription_alerts_test.dart`, `test/usage_read_from_screen_test.dart`, `test/usage_subscription_screen_test.dart` (phone listing, Turn off), `tool/quota/read_once.test.mjs`.
