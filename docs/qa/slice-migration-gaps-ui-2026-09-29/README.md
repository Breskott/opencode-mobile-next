# Migration five-gap UI hook-up (2026-09-29)

Finish line: the Termux move's page, This phone row and Servers offer use the
backend APIs from `docs/qa/codex-termux-migration-2026-09-28/README.md`
(five-gap section). Non-goal: device runs, source cleanup, queue moves.

| Gap | Now |
| --- | --- |
| 1 Discard | "Discard saved copy" (tertiary action) on the unfinished, stopped and failed copy. A confirm sheet says what goes and what stays. `TermuxMigrationOwner.discard` stops and waits for a running copy, holds the owner guard, then clears its in-memory request/selection/items; the page then looks again and starts a new review. `alreadyCompleted` opens the moved page (no destructive reset). A failed removal shows a plain notice and can be retried. |
| 2 Completion | `oc.termuxMigrationDone.<id>` and its writes/reads are removed. The page and This phone row ask `completedJob`; an unreadable record is "cannot look" (Try again), never "unfinished". The Servers offer already ends with the backend journal key (`shouldOffer`), which a finished move leaves in place, so it needs no second read. |
| 3 Space | The duplicate reserve formula is removed. The review shows "Needs about X · Y free" (or "Free space unknown") from `reviewSpace`, recalculated locally per tick; too little turns the notice red and disables Copy with the way forward. Start still preflights (space that ran out later shows the existing "More free space is needed" page). |
| 4 Stop | The owner stays busy until `whenSettled`; the stopped page says "Stopping…" and keeps Resume and Discard disabled until then. |
| 5 Providers | `oc.termuxMigrationProviders.<id>` is removed. The done page (fresh or reopened, offline) names providers from `providerNames` (names only, in memory); unknown keeps the generic words. Copy corrected: "{names} appear in your Termux settings. Sign in here to use them." |

Strings: added `migrationReviewSpace(Unknown|Short)`, `migrationDiscard*`,
`migrationStopping`; removed `migrationSpaceNeeded`. English only.

Tests: `test/termux_migration_ui_test.dart` (38 tests, new groups for discard,
backend completion, free space, Stop settlement, provider names) all pass.
Gates run and passing: kit_ratchet, redaction, ui_glossary, no_raw_error_text,
kit_manifest, golden_harness, architecture_boundaries, l10n_coverage;
migration controller, setup-finish and profile-store tests; whole-project
`flutter analyze` clean. New tests were written against the new keys/copy
(absent before), so they cannot pass on the base; behaviour checks were not
run against a reverted build.

Images (phone 412x915 and wide 1280x800, dark and light) come from
`tool/capture/termux_migration_screens_test.dart`; "before" images are in
`docs/qa/slice-migration-ui-2026-09-28/`. Shown: review, reviewShort (space
short, Copy off), stopping, discardConfirm, unfinished, stoppedLeaving, failed,
needsSpace, done (reopened, providers named offline).

Needs a device: discard/stop timing against a real Termux, and real provider
names from an imported config.
