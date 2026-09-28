# slice-clear-storage-guard (2026-09-28)

**Why:** The owner used Android Settings › Apps › OpenCode Mobile › Clear storage. That deleted the in-app Ubuntu, its OpenCode data, and every project in `<filesDir>/projects` (mounted at `/root/projects`). Nothing warned them first.

**Finish line:** Android's storage button opens our page before anything is deleted. The page says what clearing deletes and what stays. It offers:

- Export projects first
- Clear the app's cache only
- Delete everything, which needs a confirm that names the counts

This phone can also export projects at any time.

**Non-goal:**

- Restoring from an export. The zip is a normal archive, and the in-app terminal can unpack it.
- Choosing projects one by one. One zip holds all of them.

## How it behaves

- **Manifest.** `<application android:manageSpaceActivity=".ManageSpaceActivity">`. Settings then shows **Manage space** in place of **Clear storage**, and the button opens `ManageSpaceActivity`.
  - `ManageSpaceActivity` is a `FlutterActivity` with its own engine. It runs the `manageSpaceMain` entrypoint (`@pragma('vm:entry-point')` in `lib/main.dart`, so it survives AOT tree shaking), not the whole app.
  - It works while the app is not running. It does not connect to a server, start the in-app server, or read secure storage.
  - It is exported with no intent filter, so Settings can start it on every OEM. It reads no extras, and nothing happens without the person's tap.
- **Page: "Clear this app's storage"** (`lib/ui/screens/manage_space_screen.dart`, kit parts only):
  1. A notice at the top says that clearing deletes everything the app keeps, that this cannot be undone, and to export first.
  2. **Export projects first**, with a line like "2 projects, 3.0 MB, as one zip file where you choose". Below it, the switch **Include sign-ins and conversations**, which says "Private: anyone with the file can use your accounts".
  3. **Clear the app's cache only**, with a line like "Frees 5.0 MB. Projects, servers and settings stay". It never removes the running server's `proot-tmp`.
  4. **Delete everything**, in red.
  5. **Clearing deletes**: the in-app server (Ubuntu, OpenCode, its sign-ins and conversations) with its size, each project with its size, and saved servers and settings with the count.
  6. **Stays**: Termux and the projects in it, your computers and their servers, and anything you pushed to git.
- **Delete everything** opens a destructive confirm. Its lost items name the counts: "2 projects (3.0 MB)" and "2 saved servers and all settings". Its kept item is Termux, computers and git. Only **Delete everything** in that sheet calls `ActivityManager.clearApplicationUserData()`. If Android refuses, the sheet stays open with Try again.
- **Export**:
  1. The system "Save to" picker (SAF `ACTION_CREATE_DOCUMENT`, `application/zip`) opens with the name `opencode-projects-YYYY-MM-DD.zip`. A private export is named `opencode-projects-private-…`.
  2. Dart plans the files in an isolate. The native side streams them into a `ZipOutputStream` on a worker thread.
  3. Progress shows as "1.0 MB of 3.0 MB", with **Stop the export** under it.
  4. It runs only while the page is open. There is no service and no background lifetime. Closing the page or pressing Stop cancels the export and deletes the partial file. A new export can be started at any time.
  5. When it finishes, the page says "Projects exported: 3.0 MB in 42 files" and "1 file with sign-ins or keys was left out".
  6. Failures are shown in plain words: the place is full, it cannot write there, or a project file could not be read. Try again is offered, and the technical class name goes only under Details.
- **Export rules** (`lib/builtin/project_export.dart`, following the Termux migration exporter's rules):
  - Links and special files are never followed or copied. The native side re-checks each source with `lstat` and confines it to `filesDir`.
  - A plain export leaves out:
    - `auth.json`, `.git-credentials`, `.netrc`, `.npmrc`, `.pypirc`, and `id_*` keys
    - `.env*` files, except the example, sample, template and dist ones
    - `*.pem`, `*.key`, `*.p12`, `*.jks` and similar key files
    - the `.ssh`, `.gnupg`, `.aws` and `.docker` folders
    - a `.git/config` whose remote URL has a password or token in it
  - A private export adds those files. It also adds OpenCode's sign-ins, settings and conversations (`.local/share/opencode`, `.config/opencode`, and the OpenCode 2 `config` and `data`), without `bin` and `log`.
- **This phone** (in-app host): one new row, **Export projects** ("Save them as a zip file, to keep or move"), directly under Storage. It opens a small page with the same export rows and the project list with sizes. Nothing else on This phone changed.

## Images

**Before:** This phone had no way to back up projects. Android's Clear storage deleted everything without a warning.

| | |
|---|---|
| This phone before (light) | `before-this-phone-light.png` |
| This phone before, list end (dark) | `before-this-phone-end-dark.png` |
| This phone before, wide (dark) | `before-this-phone-1280x800-dark.png` |

**After:**

| | |
|---|---|
| This phone with Export projects (light) | `after-this-phone-light.png` |
| This phone, list end (dark) | `after-this-phone-end-dark.png` |
| This phone, wide (dark) | `after-this-phone-1280x800-dark.png` |
| Manage space page, phone (dark / light) | `after-manage-space-dark.png`, `after-manage-space-light.png` |
| Manage space page, whole list | `after-manage-space-412x1500-dark.png` |
| Manage space page, wide 1280x800 (dark / light) | `after-manage-space-1280x800-dark.png`, `after-manage-space-1280x800-light.png` |
| Delete everything question (light / dark) | `after-delete-question-light.png`, `after-delete-question-dark.png` |
| Export in progress | `after-exporting-dark.png` |
| Export finished | `after-exported-dark.png` |
| Export failed (destination full) | `after-export-failed-light.png` |
| This phone › Export projects page | `after-this-phone-export-page-dark.png` |

## Tests

New tests:

- `test/manage_space/project_export_test.dart` (8, unit tests on real temporary files):
  - A plain export has no credentials.
  - A private export adds them and OpenCode data, but no logs.
  - Links are never followed.
  - Per-project sizes, file counts and private-file counts are right, and so is the server size.
  - An empty app gives an empty result.
  - Legacy `/root/projects` is included.
  - The plan file frames its entries correctly.
  - The file name says private.
  - The policy table is checked.
- `test/manage_space/manage_space_screen_test.dart` (10 widget tests with a fake native side):
  - Counts and sizes.
  - Export success, including the credentials-left-out note.
  - Private opt-in.
  - Progress, then Stop.
  - Export failure in words, then Try again succeeds.
  - Backing out of the picker changes nothing.
  - Cache only.
  - The delete confirm names the counts. Cancel deletes nothing. Only confirming calls `clearAllData`.
  - With no projects, there is no export row.
  - This phone's export page.
- `test/manage_space/manage_space_manifest_test.dart` (3):
  - `manageSpaceActivity` is declared on `<application>` and the activity exists.
  - The entrypoint name matches `@pragma('vm:entry-point') manageSpaceMain`.
  - Both halves of `oc/project_export` agree on the channel name and its methods.
- `test/goldens/manage_space_golden_test.dart` (12 goldens).

Existing tests:

- `test/kit_ratchet_test.dart` passes. The new UI uses kit parts only.
- `test/this_phone_screen_test.dart`: "the server log waits folded under Details, last" missed its tap once the list grew by a row. The test now brings Details clear of the end padding (`ensureVisible`) before tapping. This is a test-only fix.
- `this_phone_component_removal_test.dart` and `this_phone_plain_failures_test.dart` pass.
- These goldens were regenerated because This phone gained a row: `test/goldens/this_phone_remove_*`, and in `test/revamp/goldens/`, `phone_this_phone_running*` and `phone_this_phone_details_log*`.

Checks:

- `flutter analyze` on the whole project is clean.
- `tool/qa/machine_lock.sh build -- flutter build apk --release` built `app-release.apk` (89.8 MB), signed with the local release key (SHA-256 `1DE5BF08…D60C`).
  - `aapt2` on the merged manifest shows `manageSpaceActivity=".ManageSpaceActivity"` and the activity.
  - `libapp.so` contains `manageSpaceMain`.
- Arabic copy was dropped per the brief. English is in `app_en.arb`, and `gen-l10n` was run.

## Still needs a device

- Settings › Apps › OpenCode Mobile › Storage shows **Manage space** and opens the page, both while the app is running and after a force stop.
- The SAF picker works with Downloads and with a cloud provider such as Drive, where writes go through a pipe.
- An export larger than 4 GB (ZIP64) is written by `ZipOutputStream`.
- **Delete everything** ends the app and leaves it as new.
- An export is cancelled when the page is closed mid-way, and the partial file is deleted.
