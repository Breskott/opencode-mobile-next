# Folder browser in "Open a project" (2026-09-25)

The owner, on his phone right after setup finished ([before-phone-open-a-project.jpg](before-phone-open-a-project.jpg)):
"Why not browse folders here." The sheet only listed `/root/projects`, a "New project" name field and "Enter a
path".

Slice F of the design pass (`docs/design/motion-and-illustration-2026-09-25.md`, design standard §6 and §10).

## 1. Scope

- `lib/builtin/builtin_folders.dart` (new): `BuiltinRootfsFolders` lists folders of the built-in Ubuntu straight
  from its files on the phone; `BuiltinFolders` adds the fallback through Ubuntu's own projects script.
- `lib/ui/widgets/folder_browser.dart` (new): `FolderBrowserSheet`, the "Open a project" sheet.
- `lib/termux/termux_folders.dart` (new, after the coordinator's change of direction): `TermuxFolders` lists (and
  makes) folders of the OpenCode server this app runs in Termux, with a short read-only script inside Termux's Ubuntu.
- `lib/ui/kit/scenes/folders_open_scene.dart` (new): `KitFoldersOpenScene`, a folder opening, for the empty state.
- `lib/ui/screens/project_folder_actions.dart`: `openFolder` shows the browser for OpenCode inside the app and for the
  Termux server (when Termux can run the app's commands); the path dialog starts at the folder shown. Public API and
  results unchanged (`Future<String?>` of the opened folder).
- Strings: 20 `folderBrowser*` keys in `app_en.arb` and `app_ar.arb`.
- Ledger: page `project-folder-browser` in `docs/design/ui-ledger/parts/e-workspace.json` (the part only;
  `ledger.json` is not regenerated here). `test/design_standard_test.dart` lists the browser with its goldens.

### Feasibility (decided first, before building)

| Server | Can its folders be browsed? | Evidence | Decision |
|---|---|---|---|
| OpenCode inside the app (built-in Ubuntu) | **Yes, without a server.** Ubuntu's root is `<filesDir>/linux/ubuntu` (`BuiltinLinux.kt`: `home = File(context.filesDir, "linux")`, `rootfs = File(home, "ubuntu")`, installed when `linux/ubuntu.ready` exists). `path_provider`'s support directory is that `filesDir` on Android (`PathUtils.getFilesDir`). proot binds only `/dev`, `/proc`, `/sys` (and `/dev/shm`), so `<rootfs>/root/...` is exactly what Ubuntu sees. | `android/.../BuiltinLinux.kt` lines 37–39 and `prootCommand`; a test reads the Kotlin lines so a move breaks the build. | Browse with `dart:io`: works while OpenCode is stopped, no proot run per folder. Links are not followed (an absolute target means a path inside Ubuntu); `..` is refused; `/dev`, `/proc`, `/sys` are left out of `/`. |
| OpenCode in Termux ("This phone · Termux", the owner's own setup) | **Yes, through Termux.** Termux's files are private to Termux, but `TermuxBridge.run` (`runInTermux`: Termux's `RUN_COMMAND` running `bash -s` with the script on stdin) is the app's sanctioned channel for its own Termux features (storage summary, process scan; `createProjectFolderScript` logs into the Ubuntu with `proot-distro login opencode-ubuntu`). My first answer ("no, that is shelling out") was reversed by the coordinator. | `lib/termux/bridge.dart` `run`, `createProjectFolderScript`; `MainActivity.kt` `runInTermux`. | Built: `TermuxFolders`, an inline script through `TermuxBridge.run`; the pinned manager script is untouched. Offered only when the profile is the Termux-managed server (`isManagedPhoneProfile`) and Termux reports installed, service available, protocol supported and permission granted; otherwise the path dialog as before. |
| Remote OpenCode 1 | **No, not outside the project.** `GET /file?path=` resolves `path` inside the instance directory and refuses paths that escape it; `listFiles('/abs')` is joined under the project. Listing another folder means pointing `directory=` at it, which boots an OpenCode instance per folder browsed (watchers, git scan) — the thing `workspace_paths.dart` guards against for home folders. | `lib/api/opencode_api.dart` `listFiles` (sends the current `directory`), `probeProjectFolder` in `connection.dart` (the one deliberate per-folder instance, for a typed path). | Not built. Path dialog as before. |
| Remote OpenCode 2 | **No, same shape.** `GET /api/fs/list?path=<rel>` is relative to `location[directory]` (protocol notes §11). | `docs/opencode2-protocol-notes.md` §11, `lib/api2/client.dart` `fsList`. | Not built. Path dialog as before. |

The sheet says nothing about the other servers: they never see it.

### The Termux script's safety

- **The path is never shell text.** Dart normalises it (absolute, no `..`, no control characters, else refused
  before anything runs), then base64-encodes its UTF-8. Only that base64 (letters, digits, `+ / =`) goes into the
  script, as the single-quoted argument of `proot-distro login opencode-ubuntu -- sh -c '<inner>' -- '<base64>'`.
  Inside Ubuntu the script decodes `$1` into `$path` exactly (a trailing `x` keeps a final newline) and refuses a
  relative path or one with a newline or tab. The inner script has no single quote (asserted and tested), so it sits
  in the outer quotes as is.
- **Read-only.** The listing uses only `[ -L ]`, `[ -d ]`, `[ -e ]`, `[ -r ]`, a glob and `printf`. It walks the path
  one folder at a time and answers `oc-folders-linked` at the first link and `oc-folders-missing` at a gap; children
  that are links, files or hidden (the glob skips dot names) are not printed; `/dev`, `/proc`, `/sys` are left out of
  `/`; names with a newline or tab are skipped (they could not be a workspace anyway).
- **One line per child:** `oc-dir<TAB><g|-><TAB><name>`, after an `oc-folders-ok` line. Dart ignores every other line
  (proot's warnings), refuses a line with a wrong flag or field count, and drops names that are empty, `.`, `..`,
  hidden, or hold `/` or a control character. No `oc-folders-ok` and no known answer is an error, the output under
  Details.
- **Bounded:** `timeout -k 2s 15s` around the login (a 124/137 exit answers `oc-folders-timeout`), and the app gives up
  after 25 s (`FolderListProblem.timedOut`: "It took too long to answer. Try again." with Try again). Skeleton rows
  show while Termux answers.
- **New project** in the browser runs the same kind of script with `mkdir -p -- "$path"`, refusing a link in its
  place; the path first passes `workspaceDirectoryProblem`. Like the existing `TermuxBridge.createProjectFolder`, it
  does not initialise a repository.
- **Checked for real:** `test/termux_folders_test.dart` runs the generated scripts with `bash -s` (as Termux does)
  and a stand-in `proot-distro` that runs what follows its `--`, over a folder tree whose own path and children carry
  single and double quotes, `$(touch PWNED)`, backticks, `;` and `&`, spaces, a newline, an Arabic name, a link out to
  `/etc`, a file, and repositories marked by a folder and by a file. No `PWNED` file appears.

### What the sheet does now

- Starts at `/root/projects`, with the path in mono under the title (left to right in every language) and an "Up
  one folder" row (its supporting line the parent's path) that goes up to `/`.
- The folder list is the content (`KitRow`): a **project** — a git repository (has its own `.git`), a project the
  connected OpenCode already knows (from `listProjects`, marked "OpenCode project"), or any folder straight in
  `/root/projects` — opens with a tap, and its chevron button shows the folders inside it. Any other folder is gone
  into with a tap (`KitChevron`). Hidden folders, files and links are not listed.
- One primary: **Open \<folder\>** for the folder shown. Not offered for the home folder, `/` (workspace_paths.dart)
  or `/root/projects` itself (it holds the projects); a line says why instead. A `/root` with a stray `.git` still
  only browses.
- **New project** (name + tonal Create) makes `<folder shown>/<name>` through Ubuntu (`mkdir -p`, `git init`) and
  opens it; a name already there just opens; a name that would be a home folder is refused.
- **Enter a path** (tertiary) opens the path dialog starting at `<folder shown>/`.
- Loading: `KitSkeletonRows` (only after `KitMotion.quick`, so going into a folder does not flash). Empty:
  `KitStateView` inline with `KitFoldersOpenScene` (plays once, no loop). Error: `KitStateView` inline, attention
  tone, the reason in words, Try again, the filesystem's own message under Details.
- The folders and the actions share the sheet's height and scroll on their own; while the keyboard is up the folders
  step aside (flex only, so the name field keeps its focus).

## 2. Builds

Branch `ds/folder-browser` off `feat/phone-setup-v2` at `cf1d7464`; feature commits `f3ef6f58` (listing) and
`d84c8df8` (sheet). No APK built (no Gradle builds on the shared PC for this slice).

## 3. Devices

None. Widget tests, unit tests over a real temporary directory tree, and golden renders on the workstation with the
pinned Flutter (3.47.1, Shorebird cache `91f8bd75`). Arabic renders use the test font, so Arabic glyphs show as boxes;
the layout and the left-to-right paths are what they show.

## 4. Runs

| # | Check | Expected | Actual |
|---|---|---|---|
| 1 | `test/builtin_folders_test.dart`: list a temporary rootfs | folders sorted, git marks (a `.git` folder and a worktree's `.git` file), no hidden, files or links; `/dev` `/proc` `/sys` left out of `/`; missing projects folder lists empty; links and `..` refused; with a stopped Ubuntu nothing runs; without Ubuntu's files only `/root/projects` through Ubuntu; the Kotlin rootfs lines match | PASS (7) |
| 2 | `test/folder_browser_test.dart` through `ProjectFolderActions.openFolder` | into a folder and up; marks; a project opens with a tap and the path comes back; Open opens the folder shown; New project in the folder shown; keyboard keeps focus; home and `/` never offered; listing error shown and retried; Enter a path starts at the folder shown; 320 dp × 2 text in Arabic with no overflow | PASS (10) |
| 3 | Same file against the old sheet (`cf1d7464`'s `project_folder_actions.dart`) | fails | FAIL as expected: compile error without the override ([failing-first-old-sheet.txt](failing-first-old-sheet.txt)); with a compile shim 9 of 10 fail on behaviour ([failing-first-old-sheet-behaviour.txt](failing-first-old-sheet-behaviour.txt)) |
| 4 | Home-folder guard removed from `_isProject` | "never offered" test fails | FAIL as expected: `Expected: empty, Actual: ['/root']` ([failing-first-home-folder.txt](failing-first-home-folder.txt)); guard restored, PASS |
| 5 | Callers' tests: `test/projects_screen_test.dart`, `test/phone_setup_ready_screen_test.dart` | unchanged behaviour | PASS (39); their setUp now lists through the fake Ubuntu (`BuiltinFolders.throughUbuntu`) because real file access does not run under a widget test's fake clock |
| 6 | `test/design_standard_test.dart`, `test/l10n_coverage_test.dart`, `test/ui_glossary_test.dart`, `test/kit_illustration_test.dart` | pass | PASS |
| 7 | Goldens `test/goldens/folder_browser_golden_test.dart` | 14 renders | PASS |
| 8 | `test/termux_folders_test.dart`: the real scripts under `bash -s` | awkward names listed as data, nothing executed; a folder with quotes in its name listed exactly; newline, `..` and relative paths refused before anything runs; the script alone refuses an encoded newline path; link, missing and `/` answers; a folder with `$(...)` and quotes made, then found; noise and unsafe lines ignored; timeout and no answer mapped; only base64 in the outer script | PASS (9) |
| 9 | Same file with the path embedded raw instead of base64 (mutation) | fails | FAIL as expected, 5 of 9 ([failing-first-termux-path-encoding.txt](failing-first-termux-path-encoding.txt)); restored, PASS |
| 10 | `test/folder_browser_termux_test.dart`, `oc/termux` mocked | the Termux server browses (listing parsed past a proot warning, into and up, a project opens and returns its path, nothing probed on the server); New project made in Termux in the folder shown; a hanging Termux shows skeleton rows, then "It took too long to answer" after 25 s, and Try again lists; Termux not usable → path dialog, no script run; a remote server → path dialog, no script run | PASS (5) |
| 11 | Same file against the sheet before the Termux branch (`7e2816a8`) | fails | FAIL as expected, 3 of 5; the two "no browser" cases pass on both ([failing-first-termux-browser.txt](failing-first-termux-browser.txt)) |

## 5. Evidence

Renders at 412×915 (dark / light):

| State | Dark | Light |
|---|---|---|
| At the projects folder | [dark](folder_browser_projects_dark.png) | [light](folder_browser_projects_light.png) |
| Inside a folder (primary "Open opencode-mobile") | [dark](folder_browser_inside_dark.png) | [light](folder_browser_inside_light.png) |
| Loading | [dark](folder_browser_loading_dark.png) | [light](folder_browser_loading_light.png) |
| Empty (no projects yet, with the drawing) | [dark](folder_browser_empty_dark.png) | [light](folder_browser_empty_light.png) |
| Cannot be shown | [dark](folder_browser_error_dark.png) | [light](folder_browser_error_light.png) |
| 320×640, text ×2, Arabic | [dark](folder_browser_compact_ar_dark.png) | [light](folder_browser_compact_ar_light.png) |
| The drawing, finished frame | [dark](kit_folders_open_dark.png) | [light](kit_folders_open_light.png) |

Before: [before-phone-open-a-project.jpg](before-phone-open-a-project.jpg) (the owner's phone).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test --concurrency=2 test/builtin_folders_test.dart test/folder_browser_test.dart \
  test/termux_folders_test.dart test/folder_browser_termux_test.dart \
  test/projects_screen_test.dart test/phone_setup_ready_screen_test.dart test/design_standard_test.dart
$F test --update-goldens test/goldens/folder_browser_golden_test.dart   # renders; copy them here
```

## 7. NOT proven

- **On a device.** Nothing here ran on a phone or emulator: not that `path_provider`'s support directory is the
  rootfs's `filesDir` on a real install (read from the source of both sides, and guarded by a test on the Kotlin
  lines), not listing speed on a large folder, not the sheet with a real keyboard.
- File ownership inside the rootfs: folders made by proot's fake root are the app's own files, so the app can read
  them; a folder made unreadable inside Ubuntu (`chmod 000`) shows "The app isn't allowed to read it" — not tried.
- Symbolic links to folders are not listed (by design); a project reached only through a link needs Enter a path.
- The "OpenCode project" mark needs the server connected; with it stopped the marks are simply absent.
- The Termux script has not run in a real Termux: `proot-distro login` with `sh -c ... -- arg`, `base64` in
  Termux's Ubuntu image, the round-trip time and the 15 s / 25 s bounds come from the source and the existing
  `createProjectFolderScript`, not a measurement. What Kotlin returns when Termux's own `RUN_COMMAND` timeout kills a
  command is not exercised; the app's 25 s bound covers it.
- No separate Termux render: it is the same sheet (the timeout error has the error render's layout).
- Remote servers: no browsing (see Feasibility); their path dialog is unchanged.
- `docs/design/ui-ledger/ledger.json` and its Markdown are not regenerated (coordinator's merge step).
