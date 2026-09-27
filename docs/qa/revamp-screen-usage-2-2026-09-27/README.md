# revamp-screen-usage-2: Revamp usage (2 files) (2026-09-27)

## 1. Scope

- Unit: `screen-usage-2` (wave 2b, screen-revamp, tier 1). Finish line: both
  files in the write set have a G16 count of zero (and G1, G7, G17, G21 zero),
  each page is handled by its map proposal, the look is VL. Non-goal: no
  gateway call, controller field or persistence is added; the provider-quota
  redesign (slice-P5.4) and the enrol merge (slice-P3.11a) are not built here.
- Files changed: `lib/ui/screens/provider_quota_screen.dart`,
  `lib/ui/screens/usage_hub_screen.dart`, `lib/l10n/app_en.arb` (+5 keys) and
  the generated `lib/l10n/app_localizations*.dart`, new tests
  `test/revamp/screen_usage_2_test.dart`,
  `test/revamp/screen_usage_2_golden_test.dart`,
  `test/revamp/screen_usage_2_support.dart`, 16 goldens under
  `test/revamp/goldens/` (`quota_*`, `usage_hub_remaining_*`), this record.
- Pages (map ids): provider-quota (`redesign`), provider-quota-enroll-dialog
  (`merge-into:provider-quota`), provider-quota-clear-dialog (`fix`),
  usage-hub (`fix`).
- Specs followed: STANDARDS.md MAP-1, KIT-1, KIT-2, KIT-16, KIT-20, KIT-24,
  KIT-25, KIT-26, KIT-27, KIT-32, KIT-33, KIT-36, LOOK-1, LOOK-2, LOOK-4,
  LOOK-12, LAY-7, LAY-8, DATA-11; kit-v2 §9.1 allowlist; visual-language §5
  (rows in surface1 panels, sheets), §6 (no glass on these pages).
- Contract problems (PROC-20):
  1. G17 `attention roles` (`test/kit_ratchet_test.dart`, pattern
     `\.(?:attention|…)\b`) also matches the data field
     `QuotaBudget.attention` (`lib/state/provider_quota_budgets.dart`), a
     boolean, not a colour role. Evidence: the first rebuild counted
     `attention roles: 2` for `rule.attention` / `rule?.attention`. Worked
     around by reading the field through a record pattern
     (`QuotaBudget(attention: final on)`), with a comment. Proposed: scope the
     pattern to `ThemeRoles`/`roles.` receivers. Blocks: nothing.
  2. The task text asks for `docs/qa/revamp-<unit id>/README.md`; EVID-1 asks
     for `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/README.md`. This record follows
     EVID-1 (the rulebook) like screen-usage-1 did.
  3. R04 / §1.1 "Copy" ask for `app_ar.arb` too; the later owner decision
     2026-09-27 drops Arabic. New keys are in `app_en.arb` only (the Arabic
     generated file falls back to English), per the later decision.
- New kit parts (KIT-3): none.
- Moved or removed items (owner rule 2026-09-27, rethink):
  - "Stop using this collector" and "Clear saved provider thresholds" were bare
    text buttons at the end of the reading; they now sit in one "Collector
    server" panel with the collector's origin they act on (rows `quota-stop`,
    `quota-clear`, the clear row destructive, last).
  - "Enable quota monitoring" moved from above the notices to under the
    account's name it monitors (`quota-enable-monitoring`).
  - The collector route (a technical value) left the setup text for one
    `KitDetailsFold` at the end, with the source disclosure note (KIT-33).
  - The page-level Refresh text button under a failure became the failure
    notice's own Retry (`KitNotice.error(retry:)`).
  - The monitoring save failure was a SnackBar; it is now a notice under the
    Enable button (G1).
  - The window "Card" with a separate used line: the bar now fills with what is
    used (so the part's near-limit words follow consumption) and the words say
    what is left; the separate "x % used" line was dropped as a duplicate.
- Map items (EVID-11):
  - provider-quota (proposal `redesign`: kit-only rebuild of today's layout;
    new structure deferred to slice-P5.4):
    - statesMissing "reset time passed" → kept: the reset row's supporting
      line (`quotaResetPassed`); no new test.
    - statesMissing "Android stopped background reads" → deferred to
      slice-P5.4 (the paused words live in `QuotaMonitorSection`, outside the
      write set).
    - actionsMissing "set the collector up for me" → deferred to slice-P5.4.
    - actionsMissing "open the setup guide in the browser" → deferred to
      slice-P5.4.
    - infoMissing "one line per provider" → deferred to slice-P5.4.
    - couldBeAutomatic chips "show the providers the server uses" → deferred
      to slice-P5.4.
    - couldBeAutomatic window "alert automatically at a default threshold" →
      deferred to slice-P5.4 ("Alert me at 80 %" on by default).
    - couldBeAutomatic setup "an agent installs the collector" → deferred to
      slice-P5.4 (non-goal there: no collector packaging; otherwise no owner).
    - kitGap KitChipRow → done with `KitSegmented` (test "changing provider
      asks for consent again"); kitGap KitProgressRow → done (test "reads only
      after consent…", golden `quota_loaded_*`).
  - provider-quota-enroll-dialog (proposal `merge-into:provider-quota`):
    kit-only with the least change: `showKitSheet` with the threshold as a
    `KitSegmented` in place (test "monitoring is enabled from a sheet…",
    golden `quota_enroll_sheet_*`); marked
    `// revamp: merge-into:provider-quota (slice-P3.11a)`. couldBeAutomatic "a
    switch with a sensible default replaces the dialog" → deferred to
    slice-P3.11a / slice-P5.4.
  - provider-quota-clear-dialog (proposal `fix`): kitGap KitConfirmSheet →
    done, destructive kind (test "a threshold saved from its picker is cleared
    only after the destructive confirmation", golden `quota_clear_confirm_*`).
    actionsMissing "undo" → not done: restoring needs every saved rule across
    accounts, which `ProviderQuotaBudgets` keeps private; adding that is a
    controller change (STATE-21 non-goal). DATA-11 is met by the
    confirmation. Deferred to slice-P5.4 (no explicit owner in
    work-units.json). infoMissing "count" → same reason, same deferral.
  - usage-hub (proposal `fix`):
    - kitGap raw TabBar → done with `KitTabSwitcher.tabs` (test "two sections
      under one bar…", goldens `usage_hub_remaining_*`).
    - actionsMissing "pull to refresh (KitRefresh)" → done: Spent already had
      it (screen-usage-1); Remaining wraps a consented reading in `KitRefresh`.
      The gesture itself is not tested here.
    - statesMissing "skeleton totals while loading", "no usage yet",
      "offline: last result with its time" → belong to `usage_screen.dart`
      (screen-usage-1, merged); not in this write set.
    - statesMissing "provider does not report quota" → done: an unreported
      window says "Not reported" in its panel (test "reads only after consent…"),
      a snapshot without windows shows its status notice.
    - "one name" → the bar says "Usage", the Settings row's word.
- States per page (STATE-20):
  - provider-quota: setup (golden `quota_setup_*`), consent needed (test
    "reads only after consent…"), loading (KitScreen bar, `quotaLoading`
    line), loaded (golden `quota_loaded_*`, `quota_window_*`), unsupported
    provider (test "changing provider…"), failure (`KitNotice.error`, code
    only), stale (`KitProgressRow.asOf` + notice, code only), detached
    (`KitNotice`, code only).
  - usage-hub: two tabs (test + golden), one section (test "one section
    left"), opened at Remaining (test), none (KitStateView, code only).
- Deferred states (STATE-21): none beyond the map items above.

## 2. Builds

- Branch `revamp/screen-usage-2`, base `7011dc46` (feat/phone-setup-v2), code
  head `4253a39e`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b
checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first run | n/a: no bug fix; a rebuild | n/a | PASS |
| 2 | `test/revamp/screen_usage_2_test.dart` | passes | 7 passed | PASS |
| 3 | `test/revamp/screen_usage_2_golden_test.dart --update-goldens`, then every image opened | renders, no exceptions | 16 passed, images looked at | PASS |
| 4 | `test/kit_ratchet_test.dart` with `KIT_RATCHET_WRITE=1` (baseline then restored with `git checkout`) | no G1/G16/G7/G17/G21 entry for the two files | none left | PASS |
| 5 | `flutter analyze` on the two screens and the three new test files | no issues | no issues | PASS |
| 6 | Design-standard, l10n, glossary, ledger, other suites | not run (owner decision 2026-09-27: only the unit's own test files) | not run | n/a |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-2 (no AlertDialog/SnackBar) | `test/revamp/screen_usage_2_test.dart` "monitoring is enabled from a sheet" | run 2 |
  | KIT-26 (no CheckboxListTile/Card) | same file "reads only after consent" | run 2 |
  | KIT-36 (one bar in the hub) | same file "two sections under one bar" | run 2 |
  | DATA-11 (confirm before clearing) | same file "a threshold saved from its picker is cleared only after the destructive confirmation" | run 2 |

- Changed test expectations (TEST-19): none edited; shared tests broken by the
  rebuild are listed for the integrator (below).
- Goldens (new, each opened and looked at): `quota_setup`, `quota_loaded`,
  `quota_window`, `quota_loaded_1280x800`, `quota_enroll_sheet`,
  `quota_clear_confirm`, `usage_hub_remaining`, `usage_hub_remaining_1280x800`,
  each `_dark` and `_light`. Approved renders (EVID-12): the rows follow
  `docs/design/visual-language-2026-09-26/Settings.png` (panel of rows with
  icon tiles, sentence-case labels) — differences: long supporting copy on the
  attention switch is cut at two lines ("…device noti…"); the confirm follows
  `Confirm.png` — differences: none beyond the copy.
- Before and after (EVID-10): `before-provider-quota--setup.png`,
  `before-provider-quota--loaded.png`, `before-provider-quota-enroll-dialog.png`,
  `before-provider-quota-clear-dialog.png`, `before-usage-hub--loaded.png`
  (census PNGs from base `7011dc46`); `after-provider-quota--setup.png`,
  `after-provider-quota--loaded.png`, `after-provider-quota-enroll-dialog.png`,
  `after-provider-quota-clear-dialog.png`, `after-usage-hub--remaining.png`.
- Accessibility: the provider choice is a `KitSegmented` named "Provider"; the
  consent is a labelled `KitSwitchRow` that says why it is disabled; the
  refresh icon is a `KitIconButton` with its tooltip; each window's bar has
  the part's spoken value; tabs are a keyboard strip. 200 % text not checked
  in this unit.
- Privacy and security: no credentials, links or notifications changed. The
  collector origin is shown isolated left to right; the route stays in
  Details. No provider tokens or account refs are rendered (the fixture's
  account ref never appears).
- Migration: n/a: no stored format changed.
- Shared tests this change breaks (for the integrator, TEST-19):
  `test/provider_quota_screen_test.dart` (finds ChoiceChip, Checkbox,
  CheckboxListTile, FilledButton, TextButton, AlertDialog, DropdownButton,
  SwitchListTile, LinearProgressIndicator, AppBar, the visible route path),
  `test/usage_hub_screen_test.dart` (finds AppBar, TabBar),
  `tool/capture/quota_monitor_test.dart` (TextButton "Enable quota
  monitoring", AlertDialog). `test/design_standard_test.dart` `_migrated`
  should gain both files; the ratchet and l10n baselines only dropped.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_usage_2_test.dart
$F test -j 1 test/revamp/screen_usage_2_golden_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart  # inspect, then: git checkout test/kit_ratchet_baseline.json
$F analyze lib/ui/screens/provider_quota_screen.dart lib/ui/screens/usage_hub_screen.dart test/revamp/screen_usage_2_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The full suite, the design-standard, l10n, glossary and ledger tests were
  not run (owner decision 2026-09-27).
- Pull to refresh on Remaining, the failure, stale and detached states and
  the no-section state are code only (no test or golden).
- 200 % text and keyboard traversal on the rebuilt pages were not checked.
- A live collector was not read; all readings are synthetic fixtures.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-usage-2` |
| Enabled | Yes (no flag) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `4253a39e` |
| Deployed | No | |
| Released | No | |
