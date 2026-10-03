# revamp-screen-usage-1: Revamp usage — Spent and the Codex account (2026-09-27)

## 1. Scope

- Unit: `screen-usage-1` (wave 2b, screen-revamp, tier 1). Finish line: `lib/ui/screens/usage_screen.dart` and `lib/ui/screens/agent_account_screen.dart` have a G1/G16/G7/look count of zero, are built from kit parts in the VL look, and the pages `usage`, `usage-budget-dialog`, `usage-budget-clear-dialog` and `agent-account` are handled by their map proposals, with a missing capability explained in place instead of vanishing. Non-goal: no gateway call, controller field or persistence added (`UsageOverview`, `UsageBudgets`, `AgentAccountController` unchanged); no Arabic (owner decision 2026-09-27).
- Files changed: the two screens; `lib/l10n/app_en.arb` (+ regenerated `app_localizations*.dart`); new `test/revamp/screen_usage_1_test.dart`, `test/revamp/screen_usage_1_golden_test.dart`, `test/revamp/screen_usage_1_support.dart` and 32 goldens `test/revamp/goldens/{usage,agent_account}_*`; this record.
- Pages (map ids): `usage` (proposal `redesign`), `usage-budget-dialog` (`fix`), `usage-budget-clear-dialog` (`fix`), `agent-account` (`fix`).
- Specs followed: STANDARDS.md §1.1, MAP-1, §4 (KIT-1, KIT-11, KIT-20, KIT-25, KIT-33), §5, §6, §15, §16; kit-v2 §9.1; KitScreen.md, KitTopBar, KitRow/KitRowGroup, KitPickerRow, KitProgressRow.md, KitDialog.md, KitConfirmSheet, KitDetailsFold.md, KitSearchField, KitCapabilityExplainer.md; visual language 2026-09-26 (Settings canvas: section labels, surface1 panels of rows, icon tiles, trailing values in text3).
- Contract problems (PROC-20):
  1. **KitSegmented has no stacked form yet** (its own doc: "until KitChoiceList lands, a label that does not fit is cut"). KitChoiceList has merged but KitSegmented was not updated: the four ranges (Today · 30 days · This year · All time) render as "This ye…" at 412 dp. Worked around by making the range a `KitPickerRow` beside Project scope; the unit's `after` list names kit-KitSegmented, so the coordinator may want the stacked form finished and the range turned back into a segmented control.
  2. **`showKitInputDialog` has no `decimal` switch**, and `KitFieldKind.number` is digits only, so a dollar amount like 2.50 cannot be typed with the number kind. The USD budget uses `KitFieldKind.text` (validation unchanged); the token budget uses the number kind. Proposed: an optional `decimal` parameter forwarded to `KitField`.
  3. The map's rationale for `usage-budget-dialog` asks for an "error-coloured" Remove; LOOK-5 (STANDARDS outranks the map) keeps danger for acts that lose data, and a budget can be set again, so Remove is a neutral alternative that is offered only when a budget exists. The `usage-budget-clear-dialog` confirm stays `KitConfirmKind.destructive` (it deletes every saved budget, current and past).
  4. The task's copy line says `app_en.arb` AND `app_ar.arb`; the later owner decision (2026-09-27) drops Arabic, so new copy is in `app_en.arb` only (R15).
  5. "Clean test/goldens/**/failures/ before committing": nothing of this unit's lands there (its goldens live under `test/revamp/goldens/`, and the compare run produced no failures folder).
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - `agent-account` `whenMissing` `server.codex` "hidden … 'scope lost' text" → **explains**: the screen now tells three cases apart instead of one "scope lost" line: the server changed (`agentAccountScopeLostTitle` + "Back to Servers"), not connected yet (`agentAccountNotConnected`), and a server that cannot host a Codex account (`KitCapabilityExplainer.state(capability: 'server.codex')`, which offers "Connect Codex" once coord-main registers the `add-server-codex` flow). Tests "a server that cannot host…", "a changed server says so…", "not connected yet…"; golden `agent_account_unsupported_*`. The entry points that hide the row (Servers menu, Settings Accounts) are other units' files and were not touched.
  - `usage` `whenMissing` `server.oc2` → **explains**: a server without usage statistics shows `KitCapabilityExplainer.state(capability: 'server.oc2')` as the page (offers "Switch to OpenCode 2" once the `server-generation` flow is registered) instead of the red "does not support aggregate usage" line; Refresh is not offered there. Test "a server without usage statistics explains why in place"; golden `usage_unsupported_*`. The hub still hides the Spent tab on such servers (`usage_hub_screen.dart`, owned by screen-usage-2).
  - `agent-account` `statesMissing` "sign-in failed / code expired" → done: `KitNotice.error` "Sign-in did not complete…" with Sign in (pinned primary) starting a fresh code. Test "a failed sign-in says so…"; golden `agent_account_login_failed_*`.
  - `agent-account` `statesMissing` "limit reached" → done: the window's `KitProgressRow` says "Limit reached" at 100 %, and a notice under the limits says "You’ve reached a Codex limit. Resets in 6 h (…)". Test "a window at its limit…"; golden `agent_account_limit_reached_*`.
  - `agent-account` `infoMissing` "relative reset time" → done: "Resets in 6 h" on each window (clock-driven, `package:clock`), the exact date in the limit notice.
  - `agent-account` `actionsMissing` "copy device code" → done: `KitIconButton.copy` "Copy sign-in code" beside the code. Test "sign-in shows the code with Copy…"; golden `agent_account_code_*`.
  - `agent-account` `actionsMissing` "sign out" → **not done**: `AgentAccountSession` has no sign-out call, and the unit's non-goal forbids adding a gateway call. Belongs with slice-P5.4 or a Codex slice.
  - `agent-account` element "Card + raw bars" → `KitRowGroup` rows (state, sign-in method, plan) and `KitProgressRow` per rate window; rationale "KitStateView for sign-in, plain words" → the signed-out, loading, unavailable and disconnected states are `KitStateView`s.
  - `usage` proposal `redesign` (owner verdict Rethink) → kit-only rebuild with the owner's rethink applied where it needs no new behaviour: the total first, then range and scope, budgets as rows, filters folded into the search field, the prose under one Details. The sentence-based summary ("$3.42 in the last 30 days"), filters in a sheet and the Codex account as the Remaining source are **deferred to slice-P5.4**.
  - `usage` `statesMissing` "no activity in range" → done: the empty message sits in the total panel and the zero breakdowns are hidden. Test "an empty range says so…"; golden `usage_empty_*`.
  - `usage` `statesMissing` "budget reached" → done: the budget row reads "3.42 of 2.5 USD · Limit reached" with a full bar, plus the notice "Personal budget reached in this reading." Test "a USD budget is set, shown against spend, reached, and removed"; golden `usage_budget_reached_*`.
  - `usage` `infoMissing` "total above the fold", "budget progress" → done (goldens `usage_loaded_*`, `usage_budget_reached_*`).
  - `usage` `actionsMissing` "export a report" → **not done**: no export path exists in the app for this data, and adding one is new behaviour (deferred to slice-P5.4).
  - `usage-budget-dialog` `statesMissing` "invalid amount" → done: `showKitInputDialog` keeps Save disabled with the reason. Test "an invalid amount keeps Save disabled with the reason"; golden `usage_budget_dialog_*`. `infoMissing` "currency", "effect" → done: the helper says "In US dollars for this range. You’re told when the report reaches it; nothing is stopped." (tokens: "Whole tokens…"). The "$ prefix" is not possible (KitField has no prefix); the title and helper name the currency.
  - `usage-budget-clear-dialog` `actionsMissing` "undo" → **not done**: `UsageBudgets.clearAll` removes current and past budgets and has no restore, so the act stays behind a destructive `showKitConfirm` (DATA-11 confirm branch) with its own verb "Clear budgets". Test "clearing budgets asks first…"; golden `usage_budget_clear_dialog_*`.
- Moved or removed (owner rethink rule 2026-09-27):
  - Usage: the total moved from below the budgets to the top; the four range chips became a "Time range" picker row in one panel with Project scope (contract problem 1); the provider dropdown and the "Clear filters" button were removed — the provider is now the search field's filter (its chip clears it) and the field's own clear button clears the query; five explanatory paragraphs (provider scope, provider totals, filter disclosure, budget rules) moved into one "About these numbers" fold, while the one sentence that these are estimates and not a provider invoice stays visible; Refresh is no longer offered on a server that cannot report usage.
  - Budgets: three text buttons became rows ("Set USD budget · Not set ›"), a set budget became a measured row, and "Clear saved consumption budgets" became the panel's last, destructive row; Remove moved into the dialog only when a budget exists.
  - Codex account: the tinted hero card and badges became a row panel (state + email, "Signed in with", "Plan"); Sign in moved to the pinned bottom primary; the host note, the sign-in note, the usage note and the version detail moved into Details; the hard-coded `auth.openai.com` caption is now the host of the verification address the server sent.
- States per page (STATE-20): `usage`: loaded (golden + tests), loading (screen loading bar; previous result line, test), error with previous result (test), detached (notice), unsupported (golden + test), empty (golden + test), budget reached (golden + test). `usage-budget-dialog`: new (golden), invalid (test), with budget → Remove (test). `usage-budget-clear-dialog`: confirm (golden + test). `agent-account`: signed out (golden), sign-in code (golden + test), cancelled (test), failed (golden + test), signed in (golden ×2 + test), limit reached (golden + test), unsupported (golden + test), scope lost (test), not connected (test); loading, unavailable, disconnected, read failed and uncertain are code paths on kit states, not rendered.
- Deferred states (STATE-21): none beyond the map items marked not done above.

## 2. Builds

- Branch `revamp/screen-usage-1`, base `9007257d` (`feat/phone-setup-v2`), code head: the commit that adds this record.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at the wave checkpoint.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: a rebuild; the map fixes are new states, each with a test | n/a | PASS |
| 2 | `test/revamp/screen_usage_1_test.dart` + `test/revamp/screen_usage_1_golden_test.dart` (compare, no update) | pass | 56 passed (`run-1.txt`) | PASS |
| 3 | `flutter analyze` on the two screens and the three new test files | no issues | No issues found | PASS |
| 4 | Ratchet, design-standard, l10n, glossary, ledger tests | pass | not run (owner decision 2026-09-27: run only the unit's own test files). A script over both screens with `test/kit_ratchet_flutter_widgets.json` minus the §9.1 allowlist finds no framework widget; a grep finds no `.colorScheme`, `.textTheme`, `TextStyle(`, `Theme.of`, numeric `EdgeInsets`/`SizedBox`, `BorderRadius`, `Border.all(`, `showConfirmSheet`, `AlertDialog` or `Positioned(` | NOT RUN |
| 5 | `flutter analyze lib test` (whole tree) | clean | not run (owner decision: analyze on your files) | NOT RUN |

After run 2, one line changed in `usage_screen.dart` (the timezone note left the Details fold because it is already shown under the total); the fold is collapsed in every golden, so no render changed.

## 5. Evidence

- `run-1.txt`: behaviour tests and golden comparison.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | STATE-12 (explain, do not hide) | `screen_usage_1_test.dart` "a server without usage statistics explains why in place", "a server that cannot host a Codex account explains it" | `run-1.txt` |
  | STATE-8 (disabled says why) | "an invalid amount keeps Save disabled with the reason" | `run-1.txt` |
  | DATA-11 (confirm for a loss without undo) | "clearing budgets asks first, in its own words" | `run-1.txt` |
  | STATE-11 (honest stale data) | "a failed refresh keeps the last total and says so" | `run-1.txt` |
  | SEC-1 (external links) | sign-in still opens through `openExternalLink` (golden `agent_account_code_*`; unchanged call) | `run-1.txt` |
  | LAY-4 overflow | "lays out without overflow at Size(…), text 1.0/2.0" (320×640, 412×915, 915×412, 1280×800); "signed in lays out at …, text 2.0" | `run-1.txt` |

- Changed test expectations (TEST-19): none — only new test files were edited (R08). Shared tests this change is expected to break are listed for the integrator (see the build record's `sharedTestsBroken`).
- Goldens added (each opened and looked at): `test/revamp/goldens/usage_{loaded,loaded_1280x800,budget_reached,models,empty,unsupported,range_picker,budget_dialog,budget_clear_dialog}_{dark,light}.png` and `agent_account_{signed_out,code,login_failed,signed_in,signed_in_1280x800,limit_reached,unsupported}_{dark,light}.png` (32 PNGs). The account goldens other than `unsupported` render `AgentAccountPanel` with "Last checked" pinned, because the controller stamps the wall-clock time. Approved render: `docs/design/visual-language-2026-09-26/Settings.png` (nearest canvas; there is no Usage canvas). Matches: sentence-case section labels 8 dp above surface1 panels, icon tiles, text3 trailing values with chevrons, hairlines inset to the words. Differences: no large title (both are pushed pages with the plain title header the map records as their chrome).
- Before and after (EVID-10): `before-usage-loaded.png`, `before-usage-budget-dialog.png`, `before-usage-budget-clear-dialog.png`, `before-agent-account-signed-out.png`, `before-agent-account-signed-in.png` (base census `docs/qa/screen-census/g-servers/`); `after-*.png` with the same names (dark goldens).
- Accessibility: section labels are headers; each figure pair in the metric panels is one merged semantics node; the device code has a spelled-out semantics label and a labelled copy button; every icon-only control is a `KitIconButton` or a top-bar `KitAction` with a label; a disabled refresh or budget row carries its reason; 200 % text checked at the LAY-4 sizes above with no overflow.
- Privacy and security: no credentials, stored formats or notifications changed; the sign-in link still goes through `openExternalLink`; the code is copied through the kit's copy service (never logged); budgets keep their existing per-profile storage.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_usage_1_test.dart test/revamp/screen_usage_1_golden_test.dart
$F analyze lib/ui/screens/usage_screen.dart lib/ui/screens/agent_account_screen.dart test/revamp/screen_usage_1_test.dart test/revamp/screen_usage_1_golden_test.dart test/revamp/screen_usage_1_support.dart
```

## 7. NOT proven

- Not run on a device or emulator (a live OpenCode 2 usage report, a real Codex device-code sign-in).
- The enable actions of both explainers: no handler is registered yet (coord-main), so they render the explains-only form; the offer path is the kit part's own tested behaviour.
- The shared gates (kit ratchet, design standard, l10n coverage, glossary, ledger) and the whole-tree analyze were not run (owner decision 2026-09-27); the integrator regenerates `test/kit_ratchet_baseline.json` and the l10n `_baseline`, and adds both screens to `_migrated` in `test/design_standard_test.dart` (R05, R10).
- Existing shared tests that exercise these screens were not run (see `sharedTestsBroken`).
- No Arabic or right-to-left render (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-usage-1` |
| Enabled | Yes (same entry points: Usage hub "Spent", Servers row menu and search for the Codex account) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
