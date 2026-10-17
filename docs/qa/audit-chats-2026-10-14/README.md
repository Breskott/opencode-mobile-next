# Audit slice: chats (2026-10-14)

| ID | Verdict | Reason | Commit |
|---|---|---|---|
| P1-2 | REAL | Panes measured the window, not the body beside the 296 dp sidebar; a non-hosting `twoPane` got 248 dp (840) or 264 dp (1200) of detail. Now the detail needs 360 dp after the sidebar, the list (unless the sidebar holds it) and the side pane, else one column. Phone unchanged. Test: 840 and 1200 with a sidebar that holds no list. | 78089a51f |
| P1-3 | FALSE | No "Done" tag exists; `_row` always passes the age, beside Needs you / Working / Failed. Already covered by `chats_home_test` ("3d ago"). | none |
| P1-5 | REAL | Quiet lines, leftover and agent notices moved from the fixed header into the feed's scroll; title and chips stay fixed. First section keeps a zero gap, so every existing golden is pixel-identical (`after-notice-in-feed.png` is the leftover-process notice, which is a KitStatusContribution drawn by the kit status-line slot above the title by design, same as before; the scrolling quiet lines are the ones the new test covers). Test fails without the fix. | 7998eb760 + follow-up |
| P2-1 | SKIP | The tapped row already shows "Opening..." and the bar runs. Cancelling or switching mid-open would mean aborting a connection switch (and a late route push); needs an owner decision and a change in `connection.dart`. | none |
| P2-2 | REAL | Tapping the Project tab again now leaves Files for the hub (browser keeps its folder). Files-in-tab is deliberate (keeps state) and already has a header Back. Test fails without the fix. | 7998eb760 + follow-up |
| P2-5 | FALSE | Top controls are in `KitTopBar.shell`, not floating; only the dock is positioned in `kit_nav.dart`. | none |
| P2-8 | FALSE | The Settings hub has no server row with Retry; that probe lives in `server_settings_screen.dart` (not a navigation row). | none |
| P3-2 | REAL | No `BackdropFilter` remains in `lib/`; `BackdropGroup` removed, "glass" comments in `kit_nav.dart` and `home_screen.dart` updated. | 78089a51f |
| P3-4 | SKIP | Global search leads to All conversations. An inline field would add a row level on Chats. Recommendation: if wanted, let the top-bar Search filter the feed through the existing `KitScreen.search` slot at 8 or more chats, an owner call since it changes what that button means. | none |
