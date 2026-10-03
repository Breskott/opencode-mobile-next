# Work tab cleanup: start, loading and layout (2026-09-24)

The owner's screenshots from his phone (`docs/qa/work-tab-cleanup-2026-09-24/before-phone-*.jpg`, Termux server, older APK) show the Work tab while the app starts. He called it "a mess". The code on `feat/phone-setup-v2` builds the same screen (`lib/ui/screens/workspace_screen.dart`, `lib/ui/widgets/other_projects_panel.dart`, `return_brief_card.dart`, `session_inventory_footer.dart`, `termux_phone_tools.dart`, and `saved_server_connection_card.dart` via `main.dart`), so these findings apply to the current branch.

## What is wrong (from the screenshots)

| # | Seen | Why it is wrong |
|---|---|---|
| 1 | The app opens on "Choose a project folder", with Create, Open and "Choose from opened projects" (`before-phone-1`). A second later the project's content appears. | The person has a saved project. The chooser flashes while that project is restored and offers to make a folder they already have. |
| 2 | No header names the current project. Only the server name and "Work" show. The chips show FinanceHub and FinanceHub3, and neither is marked as current (`before-phone-2`, `-3`). | The current project must be clear from the first frame. The header (`_ProjectHeader`) exists but only shows once the project list has loaded (`_hasProjectDetails`). |
| 3 | Three separate progress bars: under the chips, mid-screen, and under "Loading conversations…". | Loading should show in one place. |
| 4 | "No recent conversations in loaded results / Older conversations may still be available below." shows at the same time as "Loading conversations…". "Load more conversations" is greyed out, and "Archived conversations" is also on screen. | Contradictory. While the list loads it should show that it is loading (skeleton rows), and nothing else. |
| 5 | A large "Unreviewed work" card with a paragraph explaining itself ("For this project on this device. Dismissing keeps conversations unread and requests pending."), two buttons and "Dismiss shown items". | Heavy and wordy. It takes a third of the screen for one conversation that is also in the list. |
| 6 | "Last observed state. Reconnect or refresh to check current work and requests." on a normal start. | Noise during an ordinary reconnect. |
| 7 | "Something is still running on this phone — /root/projects/ has used 10 min of CPU with nothing waiting on it", pinned in the main list. | The path is the projects root, which is jargon. It does not say what or how to fix, and it takes permanent space on the main screen. |
| 8 | "In other projects" lists recent conversations from the same projects as the chips right above it. | Duplicate. The other projects are shown twice. |
| 9 | The full-width "New conversation" button covers the "Recent conversations" header and rows. The last row sits under the tab bar ("1h ago · FinanceHub" peeking out). | The list is not padded for the button and the tab bar. |
| 10 | "Connecting to This device (Termux) · Opening your saved project" sat for minutes (`before-phone-4`). | On the phone the server was not answering: 30 s timeouts even on `/global/health`, memory and swap full. The card never says so and offers no way out. |

## The target

Top to bottom, the Work tab is:

1. **Header, from the first frame.**
   - It shows the current project's name, with the server as its subtitle (for example "FinanceHub3 · This device").
   - While the saved project is being restored, use the saved project's name from the store. Never show the folder chooser, a placeholder, or "Choose a project".
   - The chooser (`_WorkspaceFolderChooser`) appears only when the restore has finished and there really is no project.
   - The chevron keeps opening the project sheet.
2. **One loading bar**, 2 px, directly under the header, while anything on the screen is loading for the first time: projects, conversations, reconnecting. No other progress bar anywhere on the Work tab.
3. **At most one status line**, compact (icon, one line, optional action), only when there is something to do, in this priority:
   - The server is not answering or is disconnected (after the grace time below): "OpenCode on this phone isn't answering" with Retry and, for a phone server, Restart. Remote servers get Retry and Details.
   - The stale-data line (item 6) only after reconnecting has failed or has taken more than 8 s. It is never shown during a normal start.
   - The runaway-process line (item 7), in plain words: "OpenCode has been busy for 10 min with nothing to do", with a "See what's running" action.
     - It names the project by its folder name. The server or projects root is "OpenCode", never a path.
     - Its dismissal lasts until the process changes.
4. **"Needs you"** rows, as today (permissions, questions).
5. **Conversations of the current project:**
   - Unreviewed ones carry an "Unreviewed" mark in their row, with Review in the row's actions.
   - The "Unreviewed work" card goes. "Dismiss" stays in the row's overflow menu. Its explanation moves to the menu item's tooltip or confirm text, if it is needed at all.
   - While loading: 3 to 5 skeleton rows, and none of the empty or "load more" texts.
   - The empty state shows only when the load has finished with no conversations.
   - "Load more" shows only when there are more and nothing is loading.
   - "Archived" shows only when there are archived conversations.
6. **Other projects**, one section, after the current project's list. Each recent project appears once, as a row: its name, plus what is going on there (Running, "Needs you", Unreviewed, or the last activity time). Tapping it switches project, and a trailing chevron or secondary tap opens that project's live conversation if there is one.
   - This replaces both the chip strip and "In other projects" (item 8).
   - It shows at most 3 projects, then "All projects".
   - Hidden when there is no other project.
7. **"New conversation"**, still the primary button at the bottom. The scroll view's bottom padding is the button's height, plus the tab bar, plus 16, so no row or header ever sits under either.

## The connecting card (item 10)

- For a saved server with a saved project, do not block on a full-screen card. Open the Work tab straight away with the header (item 1), the one loading bar (item 2), and the cached conversations if the app keeps any; otherwise skeleton rows. The card stays only for a first connection that has no saved project.
- If the server does not answer within 8 s, the status line (item 3) says so. The app keeps retrying in the background.
  - For the phone's own server (Termux or in-app), offer Restart. It is the existing restart path, with a confirm that says a running agent turn will stop.
  - The line never claims the phone is out of memory unless the app actually knows that.
- If the card is kept anywhere, it needs the same 8 s behaviour: say it isn't answering, and offer Retry, Restart (phone server) and "Choose another server".

## Rules

- Keep the modules. Each section is its own widget, fed by the controller, and nothing is special-cased for one server kind in shared code.
- Reuse existing strings where they fit. New strings go in `lib/l10n/app_en.arb` and Arabic (`app_ar.arb`), following `test/l10n_coverage_test.dart` and `test/ui_glossary_test.dart` ("conversation", never "chat" or "session").
- Accessibility: one live region for the status line. The loading bar has a label, and skeleton rows are excluded from semantics.
- At text scale 2.0 and a 320 dp width, nothing overflows.

## Proof (the owner's rule: modular, tested, documented)

- Widget tests for each state:
  - restoring with a saved project (no chooser, header shows the saved name);
  - loading (one bar, skeletons, no empty text);
  - loaded and empty;
  - unreviewed row;
  - other projects rows (no duplicate);
  - the runaway line wording;
  - server not answering after 8 s (fake clock);
  - bottom padding (the last row can scroll clear of the button and tab bar).
- At least one test must fail on the old code for each of items 1, 3, 4, 8, 9 and 10.
- Before and after screenshots rendered by widget tests at 412×915, in the phone's dark theme, with real fonts loaded, in `docs/qa/work-tab-cleanup-2026-09-24/`, for the states above.
- `docs/qa/work-tab-cleanup-2026-09-24/README.md` in the `docs/qa/README.md` format. Include a NOT proven list: on-device viewing happens in the integrated emulator run.
