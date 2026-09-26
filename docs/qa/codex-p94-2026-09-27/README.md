# P9.4 settings search — domain half (2026-09-27)

Finish line: a shared, typo-tolerant bilingual matcher returns reachable settings
and concrete page/section/row targets, including effects, heat, battery and crash.
Non-goals: UI, KitSearchField, rendered arrival highlights, assistant/P2, network
adapters, settings mutations, query history and persistence.

Base: `64128dba`, existing worktree branch `codex/p94`. Read: AGENTS.md,
STANDARDS sections 2, 3, 13, 15, existing UI search index, destination screens,
localization and KitRedact. Write set: the two new `lib/domain/settings_search*.dart`
files, `test/settings_search_domain_test.dart`, this QA directory and (if needed)
root `COMMIT_MSG.txt`. No UI/single-owner/native files changed. One bounded backend
slice, no independent implementation units or machine-heavy parallel checks.

## Feasibility

Passed for this backend scope: no server API, auth or credential access is needed.
The current rows exist in `settings/personal_settings_screens.dart`,
`keep_running_screen.dart` and `termux_setup_screen.dart`. Existing appearance
navigation supports an effects section; keep-running and Termux do not yet accept
row arrival requests. The backend returns a request for the UI builder to handle.
The existing shared UI index remains the source of legacy navigation/gates; this
addition does not create a second independent list of all settings.

## UI hook-up

Import `domain/settings_search.dart` and `domain/settings_search_catalog.dart`.

- `SettingsSearchDocument`: stable `id`, localized `title`/`parent`, bilingual
  `aliases`, and `SettingsSearchTarget(pageId, sectionId?, rowId?)`.
- `settingsSearchCatalog(l10n, existing: ..., supportsBackgroundService: ...,
  thermalGuardAvailable: ..., managedRecoveryAvailable: ...)` merges the new rows
  before legacy broad aliases, replaces duplicate IDs and keeps their old aliases.
- `SettingsSearchIndex(documents).search(query)` returns ordered documents. Empty
  or punctuation-only queries return an empty list. All words must match; title
  equality, exact tokens/aliases, prefixes, then one-edit typos determine rank.
  Ties retain catalog order. Insertions, deletions, substitutions and adjacent
  swaps are tolerated from four characters. Arabic marks/tatweel/alef variants
  are normalized. Mixed-language queries work.

In the existing `lib/ui/search/search_index.dart` adapter, map the **gated**
`searchIndex(l10n, scope)` into documents. Keep its `SearchEntry` objects by ID for
legacy `open` callbacks. Combine English AND Arabic titles/keywords/parents into
aliases by ID (both `allSearchEntries` locale catalogs can supply static metadata;
only gated IDs become documents). This preserves bilingual aliases even when
English is the display language. Do not index current profile values or secrets.
For legacy targets, map the actual open callback's destination/section rather
than blindly taking `pages.first`: e.g. usage-remaining and quota-monitoring open
`usage` / `remaining` although their ledger coverage lists `provider-quota`.

Pass those documents to `settingsSearchCatalog`, then create one index used by
both Settings' KitSearchField and the command palette. Rebuild when locale,
capabilities, saved profiles or thermal guard availability changes. New defaults
are deliberately required flags:

- Background: `scope.platform.supportsBackgroundService`.
- Heat: whether `thermalGuardSlotProvider` currently holds a guard; also gated on
  background support. Do not show an arrival target for the hidden thermal row.
- Crash restart: Termux support AND a saved profile matching
  `TermuxBridge.managesServerUrl`, mirroring the setup screen's `recoveryProfile`.
  Recheck on selection. If absent, crash still finds app diagnostics.

Dispatch new/overridden IDs by their target; don't reuse an old callback pointing
to a retired door. In particular, battery/keep-alive now lead first to the battery
row instead of the broad Notifications alias, and crash restart goes directly to
Termux options rather than the phone setup chooser. Existing aliases remain
searchable and diagnostics aliases resolve to `app-diagnostics`.

| Result | pageId | sectionId | rowId |
|---|---|---|---|
| Vibration | appearance-settings | effects | effects-vibration |
| Glass | appearance-settings | effects | effects-glass |
| Animations | appearance-settings | effects | effects-motion |
| Celebrations | appearance-settings | effects | effects-celebrations |
| Battery / keep alive | keep-running | — | keep-running-battery |
| Heat | keep-running | — | keep-running-thermal |
| Crash restart | termux-setup | options | managed-recovery-option |
| Crash diagnostics | app-diagnostics | — | — |

For row arrivals, reveal the section (including lazy/folded options), wait until
its row is laid out, scroll it into view, then give it a transient accessible
kit highlight respecting reduced motion. Consume the target once; it must not
repeat on rebuild. `rowId` is a semantic anchor contract, not a GlobalKey lookup
or route string. No widget/navigation implementation is included in this unit.

## Security and storage

No logging, network requests, query retention, settings values or persisted data.
No storage keys, migrations or deletion sweep needed. KitRedact was inspected;
there is no persistence sink requiring it. Any later persisted search history
would be new scope and must use KitRedact and profile deletion handling.

## Verification

Five focused flutter_test cases cover EN/AR acceptance words and row targets,
typos/prefixes/mixed words/empty queries, unavailable targets, preservation of
legacy bilingual aliases and redirected broad doors, and ranking/snapshot behavior.
Existing UI behavior/tests are unchanged; this is a new API, not an enabled UI fix.

- Requested pinned `bin/dart format --language-version=3.10` launcher: blocked by
  read-only `bin/cache/engine.stamp.tmp.19` and `engine.realm`.
- Formatting completed with the **same pinned SDK's**
  `bin/cache/dart-sdk/bin/dart --suppress-analytics format --language-version=3.10`
  on all three changed Dart files. See `format.txt`; package-resolution warnings
  reflect this worktree's missing `.dart_tool/package_config.json`.
- Pinned `bin/flutter test --concurrency=1 test/settings_search_domain_test.dart`:
  blocked before execution by the SDK cache sandbox restriction; see `tests.txt`.
- Pinned `bin/flutter analyze`: same restriction; see `analyze.txt`.
- Direct pinned Dart matcher smoke: see `matcher-smoke.txt`; covers matching only,
  not Flutter/localized catalog compilation and not a substitute for the suite.
- Verifier: run pinned `flutter pub get`, the focused test command above, then
  `flutter analyze`. No full-suite, UI, screenshot, device or release claim.

Implemented: backend API and tests. Enabled: no, awaiting UI adapter/highlights.
Verified: formatting and limited matcher smoke only; Flutter verification blocked.
Committed: implementation and tests in local commit `42a99ffc` on `codex/p94`.
The final smoke output and this QA status update remain uncommitted: the amend
attempt could not create the shared worktree `index.lock` (read-only filesystem).
The requested commit message is preserved in root `COMMIT_MSG.txt`.
Deployed/released: no.
