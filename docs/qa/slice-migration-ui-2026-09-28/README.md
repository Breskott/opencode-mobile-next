# slice-migration-ui — moving from Termux to the in-app server — 2026-09-28

The UI for the owner's request (2026-09-28): someone who uses the Termux server
can move to the app's own built-in Ubuntu. It is built on Codex's backend
([contract](../codex-termux-migration-2026-09-28/README.md),
[inventory](../codex-termux-migration-2026-09-28/inventory.md)). This slice
did not edit `lib/domain/termux_migration*`, `lib/builtin/**`, the phone setup
screens, the chat library or `lib/ui/kit/glass/**`.

**States:** implemented and verified by host widget tests. It is not yet
enabled on a device. Nothing was tried on a phone or an emulator.

## Finish line and non-goal

- **Finish line.** A Termux user goes from an entry point to a finished move:
  1. The review shows what moves and what doesn't, with sizes and the space it needs.
  2. The copy runs, showing the real stage for each item, and can be stopped.
  3. If it stops, it can be resumed, also after the app was closed.
  4. The copied files are verified, and the app connects to the in-app server.
  5. The last page is "done", with the next steps.
- **Non-goal.** Deleting anything in Termux. Moving queued prompts. Restoring
  sessions or sign-ins. The backend doesn't offer these.

## Entry points

| Where | What | Keys |
|---|---|---|
| This phone (Termux host) | The first row of the list, shown only when `TermuxMigrationService.eligible` and the in-app Linux is supported. It reads "Move from Termux". It changes to "Resume moving to the in-app server" when a copy was saved but not finished, to "Moving to the in-app server" while a copy runs, and to "Moved from Termux · Remove the Termux server when you're ready" after the move. Showing the row never asks Termux anything. | `this-phone-migrate` |
| Servers | A one-time `KitNotice.offer` under the Termux server's row: "Move your Termux projects into this app? Termux stays as it is." Its action is "Review what moves", which opens the review and starts nothing. Closing it calls `dismissOffer`. It is hidden once a copy has been saved (`shouldOffer`) or finished. | `termux-migration-offer`, `-review`, `-dismiss` |
| Setup v2 | The review page shows `needsBuiltin` as "Set up the in-app server first". The button calls `SetupEngine.run` with the required parts and `opencode: {runtime}` set to the Termux server's generation, then opens setup's own progress screen. That screen closes itself when the job ends, and the page then runs `check()` again. A setup job that is already running is shown, not started twice. Setup and migration never run at the same time. | `migration-needs-builtin`, `migration-set-up` |

## The flow (`lib/ui/screens/termux_migration_screen.dart`)

- **Review**, one list:
  - **Copied and ready to use:** Projects. On by default. The row says "Into a new folder on the in-app server. Nothing there is overwritten."
  - **Saved privately, not turned on:** MCP and agent settings, Conversation history (backup copy: "May contain your sign-ins, and the app doesn't open it. Termux keeps your usable history."), Git settings, Shell settings, and AI Team. All are off by default and marked opt-in.
  - **Every item** shows its measured size and file count, set left to right.
  - **Items that can't be copied:**
    - An item Termux refused says why in plain words, shows "Size unknown" instead of its placeholder zero, and gives its fix.
    - An item over the backend's per-item limit (512 MB with per-file overhead, or 20,000 files) is flagged before starting. Without this, it would only fail after packing.
  - **Not moved:**
    - Sign-ins to AI providers. The providers are named when the app is connected to the Termux server; names only, never keys.
    - SSH keys and saved Git passwords.
    - Tools and caches.
    - Termux itself, which stays as it is and keeps working until you remove it.
  - **Space:** "Needs about X of free space while copying". This uses the contract's published reserve formula, and the real check runs when copying starts.
  - **Primary action:** "Copy to the in-app server", pinned. When nothing is selected, it says "Choose at least one item to copy."
- **Copy:** a `KitChecklist` with one step per item, in the controller's own order, plus "Connect to the in-app server".
  - The working step shows the real stage: Preparing in Termux, Copying to this app, Checking, Importing, Connecting.
  - A notice says "Keep the app open… Android stops it when you leave the app, and it picks up from here when you resume."
  - "Stop copying" and the Back button both ask first (`KitConfirmKind.stop`). They tell the person that what was copied is kept and Termux isn't changed.
- **Leaving the app:** `TermuxMigrationOwner` sits above the routes and watches the app lifecycle.
  - On `hidden`, `paused` or `detached`, it cancels the copy.
  - The page then says: "It stopped because the app left the screen: Android doesn't let it run in the background." Nothing assumes background time.
  - Resume stays disabled until the stopped operation has settled, as the contract requires.
- **After the app was closed:** when the backend has a saved selection, the page shows "The move didn't finish" with the saved items and "Resume copying". Resume is always the person's choice.
- **Done:** "Moved from Termux · Files copied. Your Termux server is still available." Then:
  - "Sign in to your AI providers again", naming the providers when known. It opens Providers on the in-app server.
  - "Your projects: In the folder termux-<job> on the in-app server".
  - "Private copies: … saved inside the in-app Linux, not turned on".
  - "Remove the Termux server when you're ready", which opens Servers. Nothing is removed automatically.
  - The primary action is "Open the in-app server".
  - Under Details are the two folder paths inside the in-app Linux (`/root/projects/termux-<job>`, `/root/.oc-migration-exports/<job>`). No archive paths are shown.
- **Already moved:** the page shows the same next steps from the saved job id. It doesn't contact Termux again and doesn't check the receipts again. Files the person has edited since the move are theirs, so re-checking would only report a false conflict on every visit.
- **Other states:**
  - Termux not answering: "Open Termux" and "Try again".
  - Needs space: how much is needed and how much is free, or that the free space couldn't be read. Actions are "Try again" and "Choose fewer items".
  - Unavailable (the app's private storage couldn't be prepared): "Try again".
- **Failures:** each code maps to the contract's plain words, plus a fix line for `unsupportedEntry`, `tooLarge` and `destinationConflict`, and a way forward:
  - `profileSwitch`: "Try again" and "Open This phone".
  - `invalidSelection`: "Resume copying".
  - `destinationConflict`: "Open the in-app server".
  - All other codes: "Try again", which repeats the last request from where it stopped.
  - Details shows only the fixed code name and the item. Raw exception text, bridge output, paths and credentials never reach the screen (tested).

The layout adapts. It uses the reading width, keeps the primary action pinned
at the bottom within one-hand reach, and ends the action row on wide windows.
Large text and RTL were tested at 360×800 with text scale 2.0 and `ar`, with no
overflow. Arabic copy was dropped per the brief, so English strings show inside
RTL layout.

## Files

- `lib/state/termux_migration_owner.dart`: the one owner above the routes (`TermuxMigrationOwner.instance`).
  - Creates the controller once and runs one operation at a time.
  - Cancels the copy on lifecycle changes.
  - Disposes the controller only after the current operation settles.
  - Stores two keys of its own, both named `oc.<what>.<profileId>`, so the profile deletion sweep removes them (tested):
    - `oc.termuxMigrationDone.<id>`: the job id of the verified move.
    - `oc.termuxMigrationProviders.<id>`: provider names only.
- `lib/ui/screens/termux_migration_screen.dart`: the flow, `openTermuxMigration`, and `setUpBuiltinForMigration`.
- `lib/ui/widgets/termux_migration_entry.dart`: This phone's row, and the Servers offer.
- `lib/ui/screens/this_phone_screen.dart`: adds one row. `lib/ui/screens/servers_screen.dart`: adds the offer under the Termux entry.
- `lib/l10n/app_en.arb`: 98 `migration*` keys, then gen-l10n. The contract's proposed keys and words are used where they fit. Titles were shortened to meet G28 (four words at most).
- Tests: `test/termux_migration_ui_test.dart` and `test/support/termux_migration_fakes.dart`, which run the real `TermuxMigrationController` over fake transport, archive store and journal.
- Captures: `tool/capture/termux_migration_screens_test.dart` and `tool/capture/termux_migration_entry_capture_test.dart`. The second one also runs on the base commit, for the before images.

## Tests

- `test/termux_migration_ui_test.dart`: **29 passed**. It covers:
  - the review defaults, sizes, the refused item as unknown, what doesn't move, the space, and the disabled primary action;
  - the stage shown per item, Stop (and Keep copying), then Resume to done;
  - leaving the app, which cancels with the Android explanation, then Resume;
  - reopening after the app was closed (unfinished), then Resume, then done with its next steps and the done key written;
  - already moved, without asking Termux;
  - `needsBuiltin`, then setup, then the review;
  - the setup v2 hand-off with the real `FakeSetupEngine`: required ids, the runtime parameter, the progress route, then a fresh check;
  - Termux not answering: Open Termux, then Try again;
  - needs space, with free space known and unknown;
  - each of the 11 failure codes: plain words, a way forward, and the code only after Details is opened;
  - raw exception text holding a bearer token, a path, curl output and the profile password, none of which is rendered, even under Details;
  - `profileSwitch`, then Try again;
  - large text with RTL;
  - This phone's row: shown, opens the review, Resume, then Moved;
  - hidden for non-Termux profiles and non-Android platforms;
  - the Servers offer: opens the review, dismissal is remembered and swept, and it is hidden once a job exists;
  - the owner's keys: scoped to the profile and swept with it.
- Gates: `kit_ratchet`, `redaction`, `ui_glossary`, `no_raw_error_text`, `kit/kit_manifest`, `kit/kit_draft_manifest`, `architecture_boundaries` and `l10n_coverage` all pass. The backend's four migration test files also pass: 185 in the combined run.
- `flutter analyze --no-pub` on the whole project: **no issues**.
- Existing tests for the files this slice touched were run: this_phone ×3, termux_running_server, phone_termux_discovery, phone_server_card, servers_scenes, profile_monitor_phone_servers and phone_setup_welcome_entry.
  - 10 of them fail, and the same 10 fail on the base `4c0936d0`, checked in a temporary second worktree:
    - this_phone "first Start asks once";
    - 3 in phone_termux_discovery, the remote-profile recovery tests;
    - 5 dark goldens in servers_scenes;
    - phone_setup_welcome_entry "coming back from phone setup".
  - This slice adds no new failures.
- The full suite was not run, per the brief.

## Images

Rendered with the app's fonts at DPR 1 over the real controller:

- Contact sheets: [every state, dark](contact-states-dark.png), [every state, light](contact-states-light.png), [entry points before/after](contact-entry-before-after.png).
- Each state at the phone size, in dark and light: `after-<state>-412x915-<mode>.png`, for review, progress, stoppedLeaving, needsSpace, needsBuiltin, termuxUnreachable, failed, unfinished and done.
- The wide window, in dark and light: `after-{review,progress,done}-1280x800-<mode>.png`.
- Entry points, before and after, at both sizes and in both modes: `{before,after}-entry-{this-phone,servers}-{412x915,1280x800}-{dark,light}.png`.

## Contract gaps (for Codex; the UI works around none of them silently)

1. **No way to discard a saved job.** Once the journal is written (before packing), the selection can't change, because `invalidSelection` rejects any other one.
   - After `unsupportedEntry`, `tooLarge` or a repeated `sourceChanged` found during packing, the only ways forward are to fix the files in Termux and "Try again", or to delete the profile.
   - Asked of the backend: `discard(sourceProfileId)`. It would remove the journal and the uncommitted caches while keeping committed files, and would let the UI offer "Start over with a different selection".
2. **No read-only "is this job finished?"** `savedSelection` returns the same answer for an unfinished job and a finished one.
   - The UI therefore stores its own `oc.termuxMigrationDone.<id>`, the job id, written once `done` is published. The deletion sweep covers it.
   - If the app dies between the journal's `done` and that write, the page shows "didn't finish". "Resume" then verifies the receipts locally, reaches done, and writes the key.
   - Asked of the backend: `completedJob(id)`.
3. **The `ready` snapshot has no free-space reading for the app.** The review shows only the needed space, using the published formula, and the free figure appears only after `needsSpace`. A `ready.availableBytes` would let the review show "X needed · Y free" up front.
4. **Stop never announces when it has settled.** `busy` goes false in `finally` without `notifyListeners`, so the owner tracks settlement through its own in-flight future. The UI still works, but a notify there would be more robust.
5. **Provider names** can only be known while the app is connected to the Termux server, from `connection.catalog`, names only. Otherwise the done page says "Sign-ins never move from Termux." without names. A source-side inventory of provider ids (no secrets) would fix this.
6. **Queued prompts:** the contract allows a separate explicit offer to call `moveQueuedPrompts` after the switch. It isn't built in this slice; it is next if wanted.

## Still needs a device

An emulator-only proof following the contract's replay recipe:

- a synthetic Termux fixture;
- review sizes checked against `du`;
- interrupting the copy by switching apps (the lifecycle cancel), then Resume;
- the setup v2 hand-off on a phone with no in-app Linux, including whether setup's progress screen returns here;
- TalkBack reading the stage announcements;
- confirming the fake credential never reaches logcat.

The owner's phone was not touched.
