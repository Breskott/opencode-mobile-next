# revamp-shared-usage-1: Revamp usage (2 files) (2026-09-27)

## 1. Scope

- Unit: `shared-usage-1` (wave 2a, screen-revamp). Finish line: `provider_logo.dart` and `quota_monitor_section.dart` construct only kit parts and allowlisted widgets (G1, G16, G7 and look patterns at 0) with unchanged behaviour. Non-goal: moving the callers of `ProviderLogo`, `BrandTile` or `QuotaMonitorSection` (other units own `pickers.dart`, `integration_tiles.dart`, `integrations_screen.dart`, `provider_quota_screen.dart`).
- Files changed: `lib/ui/widgets/provider_logo.dart`, `lib/ui/widgets/quota_monitor_section.dart`, `lib/l10n/app_en.arb` (+ generated), `test/provider_logo_test.dart`, `test/revamp/shared_usage_1_test.dart`, `test/revamp/goldens/*.png`.
- Pages (map ids): none (the unit's `pages` list is empty).
- Specs followed: STANDARDS.md KIT-1, KIT-43, LOOK-12, STATE-8, G1; kit-v2 §9.1; KitImage.md "Replaces" (ProviderLogo → KitAvatar, BrandTile → KitSurface).
- Contract problems (PROC-20): the task text names the record `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 adds the date. This record follows EVID-1.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a (no pages).
- States: quota section — empty (golden `usage_quota_monitor_empty_*`), source with a state notice (golden `usage_quota_monitor_source_*`), saving (threshold row and Disable disabled with "Saving…"), save failed (in-place error notice). Provider logo — image, loading/failed (initials), OpenCode glyph (`test/provider_logo_test.dart`).
- Deferred states (STATE-21): a source with a fresh reading (window rows) has no golden: it needs a collector read, which the fixture avoids so no network is touched (TEST-11). Owner: no owner.

## 2. Builds

- Branch `revamp/shared-usage-1`, base `64128dba`, code head `b60cf854`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/provider_logo_test.dart` | passes | 9 passed | PASS |
| 2 | `test/revamp/shared_usage_1_test.dart` (behaviour + gallery, `--update-goldens`) | passes | 12 passed (Disable test re-run after adding `runAsync` for the alert dismissal) | PASS |
| 3 | `flutter analyze` on the two files, their callers and the owned tests | no issues | 1 unnecessary import in the test, removed | PASS |
| 4 | Pattern grep on the two files (G1/G16/G2/G17/G21 constructors and look patterns) | none | none | PASS |

Not run (owner decision 2026-09-27, speed): `usage_hub_screen_test.dart`, `library_integrations_test.dart`, `integration_auth_recovery_test.dart`, `provider_quota_screen_test.dart`, `model_picker_test.dart`, the ratchet and design-standard suites.

## 5. Evidence

- Changed test expectations (TEST-19): `provider_logo_test.dart` — image width 20 → cover fit + high filter + 30 dp tile (KitImage.md); monogram "GR" → "G" (KitAvatar initials, one grapheme per word); `BrandTile.size` → laid-out size 18; prompt glyph `Text('❯')` in primary → terminal icon in the avatar (KitAvatar never colours identity, STATE-9).
- Goldens (new, each opened and looked at): `test/revamp/goldens/usage_quota_monitor_{source,empty}[_1280x800]_{light,dark}.png`.
- Before and after: no before render (no page id); `after-usage-quota-monitor-source.png`, `after-usage-quota-monitor-empty.png`.
- Accessibility: the gallery runs the G5 checks (targets, labels, contrast) in both themes; the logo stays decorative; disabled Refresh/Disable show their reason as text.
- Privacy and security: no new network use; the favicon URL stays app-authored and reaches the kit as an `ImageProvider`. Tests use a mismatched source hash so the monitor never reads.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/provider_logo_test.dart test/revamp/shared_usage_1_test.dart
$F analyze lib/ui/widgets/provider_logo.dart lib/ui/widgets/quota_monitor_section.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared suites listed in §4 were not run; the ratchet baseline was not regenerated (integrator, R05).
- The reading-window rows are not rendered in a golden.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/shared-usage-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `b60cf854` |
| Deployed | No | |
| Released | No | |
