# slice-P5.4 Quota as answers — UI half (2026-09-27)

Finish line: Usage shows Spent · Remaining as sentences ("About 40% left this
week · resets Tue"). On a Codex host the Codex account is Remaining's source,
the last known value keeps its age offline, "Alert me at 80% used" is on by
default, and a missing collector says "Needs the quota collector on {server}"
with how to get it. Non-goal: no collector packaging, no background monitor
changes. Builds on Codex's state half ([codex-p54](../codex-p54-2026-09-27/README.md)).

## What changed, per page

**provider-quota (Usage → Remaining)** — `lib/ui/screens/provider_quota_screen.dart`

- *Codex host* (`capabilities.agentAccount` and an `AgentAccountGateway`): the
  page is the account's answer, read through a dedicated
  `QuotaAnswersController.codex` session (never the sign-in page's). No
  collector, consent step or provider choice. Rows: "About 40% left in this
  5-hour window · resets at 3:00 PM", bar filled with what is used and
  labelled "60% used". Label: "From your Codex account on {server}".
  - Offline / refresh failed: the last reading stays, rows carry `asOf`, and a
    notice gives its age ("Last known reading, from 40 min ago"); resume
    re-says the age. Reconnect opens a fresh session and reads again (refetch,
    no replay). A changed profile/location/gateway or unreadable profile
    forgets the answer and disposes the controller before anything else.
  - "Alert me at 80% used" switch, default on, bound to
    `QuotaAnswerPreferences` (`oc.quotaAnswers.<profileId>`, covered by the
    deletion sweep); save failure is said under the switch. A fresh reading
    at ≥80% used shows an attention notice on the page (foreground only).
  - Signed out: one row "Sign in to Codex on {server}" opens the Codex
    account page. API-key sign-in, invalid answer, no windows, read failure:
    fixed localized words, never exception text.
  - Monitored sources on other servers stay listed when there are any.
- *Collector servers*: the per-window panels became one panel of the same
  sentence rows (window title only when a window is not reported). The P3.11a
  "Alert me about {provider} on {server}" row is kept; its starting threshold
  is now 80% (was 90%) so both paths alert at the same point.
  - Setup title and the missing-route failure now say "Needs the quota
    collector on {server}", each with an in-place "How to get it" row
    (KitExpandRow; the page's single KitDetailsFold stays for technical
    values) listing the operator steps from tool/quota/README.md. The app
    installs nothing.
  - Leftover: the collector origin shows once — its KitTechnicalValue left
    Details (the Collector server row shows it).

**usage (Usage → Spent)** — `lib/ui/screens/usage_screen.dart`

- The total's label is the answer: "Spent in the last 30 days" / "Spent
  today" / "Spent this year" / "Spent in total" when the server covered the
  range asked for (`SpentPeriod.matchesRequestedRange`), otherwise the days it
  actually covered: "Spent · Sep 2 – 6". The dates show once (in the label,
  or beside the project when the range matched). Dates come from the
  returned half-open interval (end = last included instant). The query's
  timezone is the device's own (UsageOverview reads it from the device), so
  local time is the display timezone.

Copy: 34 new English strings; deleted what this made unused
(`quotaSetupTitle`, `quotaSetupGuide`, `quotaCollectorMissing`,
`quotaResetPassed`, `quotaDays`, `quotaHours`, `quotaSeconds`,
`usageReportedCost`) from en/ar and the glossary baseline; `quotaSetupDescription`
reworded (its Arabic entry dropped). gen-l10n regenerated.

Deviation from a leftover note: the window row's valueLabel is "{used}% used",
not "{used}% used · {left}% left" — "left" is already the row's title
sentence, so the pair would show the same number twice.

## Tests

New (all pass, 13): `test/revamp/slice_p54_quota_answers_test.dart` —
sentences + attribution without collector; alert default on and persisted;
attention at ≥80% only; offline age and its update on resume; reconnect on a
fresh session; signed-out row opens the account page; API-key sign-in;
collector setup names the server with how-to steps; missing route; collector
rows + 80% start + origin shown once; Spent matched vs "Sep 2 – 6".

Goldens: new `test/revamp/slice_p54_golden_test.dart` (14 images); regenerated
`screen_usage_2_golden_test.dart` (all) and the `usage *` cases of
`screen_usage_1_golden_test.dart`.

Pre-existing files run once, compared with the base commit (29a5b520) in a
temporary worktree: no new failures. Pre-existing failures on base that remain:
`provider_quota_screen_test.dart` (all ~27 legacy cases; only compile fixes
applied), `usage_hub_screen_test.dart` (4), `usage_statistics_test.dart` (2),
`kit_ratchet_test.dart` G17/G21, agent-account goldens in screen_usage_1, and
`ui_glossary_test.dart` (3 groups, none mention quota/usage keys).
`kit_ratchet_test.dart` G16 passes. `flutter analyze lib test`: clean.

## Images

before/after (phone dark unless named): `before-quota_setup_dark.png` →
`after-quota_setup_dark.png`; `before-quota_loaded_*` → `after-quota_loaded_*`;
`before-quota_window_dark.png` → `after-quota_window_dark.png`;
`before-usage_loaded_*` → `after-usage_loaded_*`. New states:
`after-codex_answer_dark.png`, `after-codex_answer_1280x800_light.png`,
`after-codex_alert_dark.png`, `after-codex_offline_light.png`,
`after-collector_missing_dark.png`, `after-spent_partial_dark.png`,
`after-spent_partial_1280x800_light.png`.

## Still needs a device

- Emulator against OC2 with the collector absent and with fixtures present
  (programme proof), and a Codex host with a ChatGPT sign-in.
- The attention is foreground only; routing it to device notifications is the
  notification router's (not wired here). Background monitoring stays the
  opt-in P3.11a row.
- Offline values survive disconnect within the page, not app restart (by the
  controller's design).
