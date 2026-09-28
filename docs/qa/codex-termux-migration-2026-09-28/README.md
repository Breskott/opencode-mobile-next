# Termux → built-in Ubuntu backend — 2026-09-28

**Implemented backend; UI handoff pending.** Feasible for managed Ubuntu projects
and confidential exports. A complete session/credential/AI Team runtime restore
is not established and is not offered. No owner-phone access, native changes,
UI edits, source deletion, or automatic sign-in occurred.

Finish line: inventory → bounded private transfer → verified staged import →
create/select built-in profile while retaining Termux. Non-goals: source cleanup,
restoring active sessions, activating imported commands, UI implementation.
Source base: `7954e980` on `codex/arm64` (merged phone-setup-v2).

## Feasibility and supported selection

The [detailed inventory](inventory.md) links the exact pinned upstream code.
Both managed hosts use OC1 **1.18.32** / OC2 **2.0.10**. Same pins are necessary
but insufficient to prove live SQLite/WAL portability; this transfer does not
execute source binaries to discover an actual installed version. Inventory
version fields are explicitly **unknown**, never substituted with pins. No
session import is enabled regardless of version. Termux OC2 may have default
or isolated XDG roots; built-in OC2 always uses `.oc-opencode2`. Both possible
source trees are preserved separately in the export, never merged or activated.

| Item | Implemented decision | Reason / destination |
| --- | --- | --- |
| Managed `/root/projects` repositories | Migrate, explicit selection | New `<filesDir>/projects/termux-<job>`; proot exposes `/root/projects/termux-<job>`. Never overwrite existing projects. |
| OpenCode config and MCP config | Offer private export | Includes `.config/opencode` and `.oc-opencode2/config`; paths, commands and embedded credentials require review before activation. |
| OpenCode data/sessions | Offer raw private export only | Both pins use SQLite/WAL; OC2 DB includes credentials. A live file copy is not a consistent backup or a supported cross-version import. Keep Termux for usable history; supported per-session CLI exports remain a manual option. |
| Provider auth (`auth.json`, OC2 credential table) | Require re-sign-in | Never activate copied credentials. They may be contained in a deliberately selected confidential data export; all exported files are 0600. |
| Global Git config | Offer private export | Helpers/paths/include files can be host-specific and values can contain secrets. Project `.git/config` remains part of its private repository. |
| Git credential stores / SSH private keys | Skip | Re-authenticate or separately provision keys. This backend does not implement the inventory's possible separate SSH-export offer. |
| Shell dotfiles | Optional private export | `.bashrc`, `.bash_profile`, `.profile`, `.zshrc`; never execute. Histories skipped. |
| AI Team state | Offer private export | Known managed Ubuntu/Termux state roots; no runtime activation or autonomous work resume. Toolchains are reinstalled through setup. |
| Caches/toolchains/manager secrets | Skip standalone migration | Source server identity/password/PID are not the destination server's identity. A selected project/export tree is copied as a unit; no claim of filtering every nested log/cache/secret. |

Only the managed `opencode-ubuntu` roots are supported, including old/new
proot-distro layouts. Arbitrary native-Termux installations need manual export.
Projects with links, devices/sockets, external `.git` worktree/submodule pointers,
unrepresentable USTAR names, or oversized trees are refused. Unsupported export
categories do not block supported projects: each inventory row has a typed
`problem`, whose zero size/count placeholders mean **unknown**, not empty.
Do not run migration during active project writes; tar detects some concurrent
changes but the project copy is not a transactional repository snapshot.
Local repository origins pointing outside the imported tree need review.

## Transfer, bounds, recovery and privacy

`RUN_COMMAND` executes fixed-source inventory and packing inside Termux. Archives
stay in `~/.oc/migration/<job>` with private modes. No shared-storage archive and
no binary payload through a bridge callback. The app binds `127.0.0.1:0`; a fresh
secure bearer authorizes 1 MiB PUT chunks. Payloads never enter logs, errors,
notifications, diagnostics, or preferences. Bridge callbacks contain only fixed
statuses, counts, bytes and hashes. HTTP content and bearer are never echoed.

Limits: **512 MiB archive / 20,000 entries per item**, strict uncompressed USTAR,
90-second source-command deadline (110-second bridge bound), 30-second curl bound,
40-second receive bound, and a **15-minute foreground attempt budget** checked at
phase/chunk boundaries. A current pack can take up to its own deadline to stop.
This is not a persistent foreground service and assumes no Android background
lifetime. UI must cancel on backgrounding; later Resume is explicit.

Preflight requires the built-in ready marker, reachable Termux, supported selected
items and known space on both filesystems. Before packing, reserve conservatively
`3 * Σ(logicalBytes + entries * 4096 + 10240) + 64 MiB` against **both** free-space
readings, because source archive, app archive and extracted files can share a
partition. Packing repeats its own space/size checks. No free-space reading is
an enduring reservation; later storage failures remain possible and typed.

A source job lock prevents overlapping pack retries. Immutable archive size/SHA
are journaled before copying. Chunk bytes are flushed before atomically advancing
the private offset sidecar; restart truncates uncommitted tail bytes and rotates
the bearer. Whole-archive SHA is checked before extraction. The importer rejects
traversal, links, hardlinks, special entries, duplicates and bad headers, writes
only private staging, verifies per-file hashes, then atomically renames the whole
item with its receipt. A crash after rename is recognized on resume. Modified
imported files cause `destinationConflict`, never overwrite.

Projects use 0700 directories, 0600 files (0700 for executable project files).
Non-project items remain inactive at:
`<filesDir>/linux/ubuntu/root/.oc-migration-exports/<job>/<item>`.
The hidden receipt includes file paths/hashes, never content, and is private.
Do not include these exports or receipts in automatic diagnostic attachments.
Completed app transfer caches are removed; committed projects/exports remain.
Termux originals and private transfer archives remain; source cleanup is a
separate explicit operation outside this job.

Journal: `oc.termuxMigration.<sourceProfileId>`; offer dismissal:
`oc.termuxMigrationOffer.<sourceProfileId>`. Existing profile deletion sweeps both.
Production checks `ConnectionController.isProfileReadable` before/after journal
writes and throughout work, preventing deletion races from recreating keys.
On next service creation, orphaned app transfer caches are removed; uncertain
journal ownership preserves caches. Imported projects/exports are retained app
files, not session state, and are not deleted merely by removing a server row.

## Exact UI hook-up contract (Claude owns UI)

Import only `package:opencode_mobile/domain/termux_migration_service.dart` for
this flow. It exports models/controller; UI must not invoke Termux scripts,
filesystem paths or profile mutations itself.

```dart
final migration = await TermuxMigrationService.create(
  connection: connection,
  builtinProfileName: l10n.phoneSetupProfileName, // existing localized key
);
// Keep one owner above routes. Render migration.snapshot via Listenable.
await migration.check();
await migration.start(
  sourceProfileId: termuxProfile.id,
  selected: {TermuxMigrationItem.projects}, // explicit reviewed selection
);
// After restart: savedSelection(id) gives prior selection; null means no job.
await migration.resume(termuxProfile.id);
// Cancel immediately; await the outstanding start/resume future before Resume.
await migration.cancel();
// Dispose only after cancellation/current operation settles.
migration.dispose();
```

`busy` stays true until
in-flight work settles, even when snapshot phase already reads `cancelled`.
No simultaneous second migration is admitted. Saved selection is immutable;
a different selection for that source returns `invalidSelection`. Completed
retries verify receipts locally without contacting Termux or reconnecting.
This v1 flow is a one-time migration, not ongoing two-way synchronization.

Entry points:

- **This phone, managed Termux user:** show “Move from Termux”; offer Resume if
  `savedSelection(profile.id)` exists. `TermuxMigrationService.eligible(profile)`
  determines eligibility. Show per-item size and migrate/export distinction.
- **One-time Termux server-row offer:** pure `shouldOffer(store, profile.id)`;
  call `dismissOffer` on dismissal. Do not run inventory merely because a row
  becomes visible. User opens the review flow first.
- **Setup v2:** `needsBuiltin` hands off to the existing built-in setup engine,
  host `SetupHostKind.builtin`; install Linux, essentials, Node and OpenCode of
  the source profile's runtime through the normal registry. Await setup finish,
  then `check()` and explicitly start/resume migration. Do not introduce a new
  installer or run setup and migration concurrently.

After import, the adapter reuses/creates the built-in profile with the source
flavor, starts it using the existing bounded health-check path, connects and
checks connection success. Only a verified imported **project location** follows;
workspace/session IDs do not. Source profile, pins, drafts, session models and
queued prompts remain unchanged. A failed switch retains imported files and both
profiles; it restores the prior Termux selection when this operation still owns
the selection. It does not override a simultaneous user server selection.
Rollback is selecting the retained Termux profile; no source restore is needed.

After successful connection, a separate explicit offer may call the existing
`ConnectionController.moveQueuedPrompts(sourceProfileID:, promptIDs:, sessionID:)`.
Use `sessionID: null` to create a new destination conversation, or an explicitly
chosen verified destination session. The existing API serializes queue writes,
rejects uncertain sends/source-local attachments, redacts moved content and
returns undo information. Never copy queue preference blobs or reuse source
session IDs. Do not auto-submit queued prompts as part of migration.

UI lifecycle: cancel when leaving foreground; keep listener ownership above the
sheet/page; disable duplicate start/resume and profile removal while busy; await
cancellation before navigation disposal. No raw exception, archive path or
bridge output belongs in a Details fold. Use kit components and normal localized
semantics/progress announcements. Only fixed codes and measured counts reach UI.

## States and copy keys to add

Names below are proposed English/Arabic ARB keys for Claude; no localization or
UI files were edited. Use localized byte formatting and `unknown` for refused
inventory rows, not their placeholder zero. No ETA or success inference from a
phase transition. `done` alone means import verification and profile connection
completed; it does not mean provider sign-in succeeded.

| Phase | Proposed key | Plain words |
| --- | --- | --- |
| checking | migrationChecking | Checking Termux and phone storage… |
| ready | migrationReview | Choose what to copy from Termux |
| needsSpace | migrationNeedsSpace | More free space is needed before copying. |
| needsBuiltin | migrationNeedsBuiltin | Set up the in-app server first. |
| termuxUnreachable | migrationTermuxUnavailable | Open Termux, then try again. |
| packing | migrationPacking | Preparing your files in Termux… |
| copying | migrationCopying | Copying files to this app… |
| unpacking | migrationUnpacking | Importing your files… |
| verifying | migrationVerifying | Checking the copied files… |
| switching | migrationSwitching | Connecting to the in-app server… |
| done | migrationDone | Files copied. Your Termux server is still available. |
| cancelled | migrationCancelled | Copy stopped. You can resume later. |
| failed | use code table | No raw error interpolation. |

| Failure code | Proposed key | Plain words |
| --- | --- | --- |
| unavailable | migrationTermuxUnavailable | Open Termux, then try again. |
| sourceChanged | migrationSourceChanged | Files changed during copying. Try again when Termux is idle. |
| sourceBusy | migrationSourceBusy | Termux is finishing the previous step. Try again shortly. |
| unsupportedEntry | migrationUnsupportedFiles | This item contains files that cannot be copied safely. |
| tooLarge | migrationTooLarge | This item exceeds the migration size or file limit. |
| invalidArchive / checksumMismatch | migrationVerificationFailed | The copy could not be verified. Your Termux files are unchanged. |
| destinationConflict | migrationDestinationChanged | Imported files changed. They will not be overwritten. |
| storage | migrationStorageFailed | The copy could not be saved. Check phone storage and try again. |
| timedOut | migrationTimedOut | This step took too long. Keep the app open and resume. |
| invalidSelection | migrationSelectionChanged | Use the saved migration selection to resume. |
| profileSwitch | migrationConnectionFailed | Files are copied, but the in-app server could not connect. |
| cancelled | migrationCancelled | Copy stopped. You can resume later. |

Additional copy: `migrationMoveFromTermux`, `migrationResume`, `migrationCancel`,
`migrationPrivateExport`, `migrationSessionsExportOnly`, `migrationSignInAgain`,
`migrationTermuxKept`, `migrationSizeUnknown`, and the six item labels.
Review must explain that config/MCP/shell/AI Team exports are inactive, session
exports may contain provider credentials and are not verified backups, sign-in
is required again, and Termux remains intact. Do not label this “move everything”.

## Verification and emulator replay

Backend/test commit: `aeb3ef67`. Final shared-lock test command covered all four
migration files plus `kit_ratchet`, `redaction`, `ui_glossary`,
`no_raw_error_text`, and `architecture_boundaries`: **127 passed, 16 seconds**.
The affected transport file was repeated after its final source-root/mode
adjustment: **11 passed**, including real Bash/tar/curl fixture execution.
Whole-project `flutter analyze --no-pub`: **no issues, 8.9 seconds**. Pinned
Shorebird Flutter 3.47.1, Dart formatting, whitespace and documentation-link
checks passed. [Verification and source hashes](verification.json). No full product suite
or real-device migration is claimed. Emulator proof was deferred to preserve the
requested budget; host tests exercise the real generated Bash/tar/curl stream as
well as fake bridge/filesystem failure paths.

For a later emulator-only proof: follow
[the boot recipe](../emulator-boot-2026-09-27/README.md); every adb invocation must
select `-s emulator-5554`. Use a separate preview app and synthetic Termux managed
Ubuntu fixture, including a repository, config with a fake credential, and a
SQLite/WAL fixture. Configure the normal RUN_COMMAND permission. Review sizes,
run projects+exports, interrupt during copy, relaunch/resume, verify checksums and
0600/0700 modes, confirm the fake credential never reaches logcat/diagnostics,
then verify built-in connection and the retained Termux profile. Test cancellation
and a corrupt archive without deleting source data. Remove only created preview
fixtures and shut down the owned emulator. Never substitute the owner's phone.
