# crit/words, 2026-09-29 (not run; the coordinator gates)

Items done
1. Fork titles: forkSession (v1 and v2) renames the copy to "Copy of <original>" (best effort). Display strips server date stamps anywhere in a title (`isPlaceholderSessionTitle`, `stripIsoStamp` in `lib/domain/session_title_text.dart`, used by `presentedSessionTitleText`).
2. IP-only server names: `plainServerName` ("Computer at 192.168.1.5") applied when saving the default name, when loading saved profiles, and in `serverDisplayName`.
3. Report a problem: Performance table is folded under `KitDetailsFold` (still in the report text).
4. One time helper `lib/domain/relative_age.dart` (Just now / N min ago / Nh ago / Yesterday / Nd ago / short date). `relativeTimeLabel`, work-row status and board cards use it; `teamBoardAge*` strings removed, `e7WorkspaceYesterday` added. Not touched: provider-quota "Last known reading" sentence, Termux storage "Scanned", clock-time formats.
5. Provider state: one sentence "Signed in, but this server can't use it" on the providers tile and the picker row; removed `integrationsSignedInNotLoaded`, `pickerAddKeyNotLoadedHint`. The long picker banners (e7ModelUi*Providers) keep their wording.
6. In-app server: "Run as a Linux service" row hidden (row lives in settings/server_settings_screen.dart; one import added to settings_screen.dart). "Stop the server" is `destructive: true`.
7. Deliberate Stop: `DeliberateServerStop` (`lib/builtin/deliberate_stop.dart`, key `oc.phoneServerStopped.<profileId>`) set on Stop, cleared on any successful start; `AppExitRecovery.runOnce` ignores the server service then, so no banner and no auto-restart. Native side untouched.
8. Reply speed: last in-app timing now persists (`oc.replySpeed.inApp`) and is restored at launch.

Tests edited (strings only): opening_shell, work_last_known, team_home, team_activity, team_agent_screen, picker_signin, revamp/screen_system_2_golden (goldens will need regeneration for "1h ago").

Device check: fork a chat and see "Copy of ..."; list rows read "5 min ago / Yesterday"; Stop server on This phone (red), then force-stop and reopen: no "starting again" banner; send a reply, relaunch, "Reply speed" still shows; Report a problem shows Details fold last.
