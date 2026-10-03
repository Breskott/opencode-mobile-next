# Design and UX critique, build 2065 (updated from 2064)

## Status against 2064 (read this first)

IMPROVED in 2065: Light theme no longer crashes (light screens now exist: `J10-16-light-work`, `J10-18-light-chat`, `J10-19-light-picker`, `J9-03-clear-storage`; contrast passes); AI Team install and Voice download work with honest per-step progress (`J7-19-setup-again`, `J8-09-voice-end`); Work empty state has an illustration and says which project it opened (`J2-05-work-home`); the header seam is gone; the model picker banner is readable and the list ends with "Add an API key for Anthropic/Google" and "Connect a provider" rows (`J3-03b-picker-bottom`); provider rows say "Signed in, but this server can't use it . Add an API key" (`J5-providers-01`); the dead "Manage accounts" entry was removed; errors show "The agent stopped because of an error. Send again / Error details" with a copyable sheet (`J3-13-error-details`); picker search works with the keyboard up (`J3-05-search-keyboard`).

STILL OPEN: first Send tap ignored; failed installs show raw Dart text and a no-op "Continue setup" (`J7-12-details`); AI Team page stays "Off" after an install that worked (`J7-18-aiteam-page`); Glass effects is still a user toggle and Appearance still has 7 controls (`J5-appearance-01`); Plugins page; three homes for background running; two search entry points; raw ISO fork titles; mixed time formats; green Cancel; interrupted-turn silence; code blocks clip; demo gutters.

NEW in 2065: two wordings for one provider state; "Run as a Linux service" shown for the in-app server; "Reply speed" row vanishes after relaunch; banner "they're starting again" after a deliberate Stop (`J6-13`); first-attempt install failures cured by a force-stop.

Light contrast (sampled): Work subtitle 6.9:1, picker description 6.3:1, composer placeholder 5.8:1, inactive nav 7.6:1, white on green button 5.1:1: all pass AA. Light matches Dark structurally; the glow background becomes a pale mint wash (`J10-16-light-work`) while sub-pages are flat white (`J10-19-light-picker`).

Top-10 status: 1 AI Team install: fixed on retry, first attempt fails; 2 "unreachable" error: replaced, failure path leaks raw text; 3 glass/Light: crash fixed, toggle remains; 4 picker + Send: picker fixed, Send not; 5 provider truth: fixed; 6 Plugins/Notifications merge: open; 7 raw text: open; 8 flat background: open; 9 interrupted work: open; 10 a11y floor: open.

---

The 2064 critique follows unchanged; the block above supersedes it where they conflict.

# Design and UX critique, build 2064

Basis: the walk in `README.md` (emulator 1080x2400 at 2.625 px/dp, Dark theme only; Light crashed the emulator). Numbers are from uiautomator bounds or pixel sampling of the screenshots named. Blunt by request.

Verdicts: 1 IA needs work . 2 Cognitive load needs work . 3 Visual design needs work . 4 Theme/design-system needs work (Appearance good, language drift) . 5 Consistency needs work . 6 Flows broken (AI Team, Add tools) . 7 Accessibility needs work . Spacing needs work . Usability needs work.

## 1. Information architecture (needs work)
Problems
1. The same destination is offered from 3 to 4 places. "On this phone": welcome, Add server, Setup guide, Settings > This phone. "Connect by address": welcome > On my computer, "Other ways", Add server. Background running: 4 places (README P2). Search: header magnifier (Command launcher) and Settings search field (`J2-06`, `J4-03`).
2. Pages that should not exist or should merge: **Plugins** (one row, a copy of Settings > AI Team, 80% empty, `J5-plugins`); **Available on this server** (a capability report titled like a menu); **What runs by itself** (a mix of one notification prompt, "Always allowed actions", and a link to Notifications, `J5-runs-itself`); **AI setup** (read-only page saying "Changes are made on the server for now", `J5-ai-setup`); Settings > Model / Providers / Tools also live inside "AI setup" and "This server".
3. Depth is right for chat (max 2 taps to any menu item) but wrong for Settings: 20+ top-level rows in 5 groups, then 2-3 levels (Tools > MCP > Add > catalogue > list).
4. A new user can tell where to go on the welcome (3 clear options) but not in Add server, which lists 6 ways plus "Or connect another way" plus "External agents" (`J1-02`). Codex and Claude/Pi-through-Paseo appear before "this phone" for someone with no computer.
5. Naming drift breaks wayfinding: "Saved servers" opens "OpenCode"; "Providers and accounts" opens "Providers"; "Servers" sheet vs "Manage servers" vs "This server".
Recommend: delete Plugins (fold AI Team into Tools or Agent group); merge Notifications, Keep running and What runs by itself into one page "Notifications and background"; remove the Settings search field (keep the header launcher) or the reverse; make "This phone" the first Add-server choice when no server exists; drop "Available on this server" into About > Details.

## 2. Cognitive load per screen (needs work)
- Model picker: banner, search, filter, refresh, 3 tabs, provider list, thinking chip, agent chip, CTA. About 3 rows fit (`J3-03`). Primary action ("Use for this conversation") is far down. Rows expand to 6 lines with price jargon ("$4.00 per million tokens read").
- Conversation details: three token numbers and "Estimated input makeup" (`J3-23`). Nobody can act on them.
- Providers: 9 connected rows each ending "Stored credential: default" wrapping to a second line, then ~100 flat alphabetical "Not connected" rows (`J5-providers-01/02`).
- Report a problem: a developer Performance table under a user form (`J5-report`).
- Command launcher: 13+ entries in one sheet with an icon tile plus X (`J4-03`).
Good: empty Work, Inbox and terminal states; the demo; the Add-tools sheet wording; Stop-server confirm; `J9-03` (says what is deleted and what stays, with sizes).
Jargon to plain words: "Reload providers", "Estimated input makeup", "Tools: bash", "invalid: Do not use", "OpenCode 1 / Switch to OpenCode 2", "quota collector", "loopback".

## 3. Visual design (needs work)
1. Hierarchy is generally clear: large page title, grouped cards, one green primary. Type scale is consistent (Geist-like).
2. Background: Work/Inbox/Project/Settings sit on a green and blue radial glow (`J2-05`, `J4-01`, `J4-05-files`) while sub-pages are flat graphite (`J5-plugins`). Two backgrounds in one app.
3. A visible rectangular seam sits behind the server pill and search at the top of every tab (darker band, ~200 px wide edge to edge, `J2-05`, `J10-08`). It looks like a rendering bug.
4. The glass dock works, but scrolled content shows through the strip above the Settings search field and the last row runs under the dock (`J5-settings-bottom`).
5. Density: Settings rows are ~64 dp tall for one-liners; pages such as Plugins, Files, Cloud environments float 3 rows in a 2400 px screen (`J5-plugins`, `J4-05-files`). Demo completion leaves ~250 px of void (`J1-16`).
6. Icons: mixed styles. Line icons in rows, filled tiles on sheets, a different "Work" icon in the launcher vs the dock, an avatar with a stray x badge on "OG" (`J5-providers-01`).
7. States: loading is good on setup (per-step spinner), poor elsewhere (model reload spins then returns the same banner; Add tools shows nothing). Errors: honest and plain on connection loss, but "Could not finish ... unreachable" is a dead end.
Recommend: one flat graphite background everywhere (remove glow); fix the header seam; add bottom fade above the dock; unify icon tile usage; drop the double icon-tile + X on sheets.

## 4. Theme and design-system complexity (needs work)
Appearance has 7 controls on one page (`J5-appearance-01`): Light or dark (System/Light/Dark), Language (3 options), Glass effects, Animations (Full/Calm/Off), Celebrations, Vibration. Assessment:
- Keep: theme (3), language.
- Merge: Animations (3 levels) + Celebrations into one "Motion: Full / Calm / Off". Fold Vibration into Notifications or drop; nobody chooses haptic ticks on a phone.
- Remove: **Glass effects** as a user setting. It is the one option that crashes the emulator with Light (P0-1), and the visual-language doc restricts glass to the floating nav anyway. Ship it fixed, not optional.
Where the design language breaks (per `docs/design/visual-language-2026-09-26.md`):
- "One accent": green is the primary button, links ("Sign in to a provider", "Cancel", "Notify me"), toggles, active nav, progress, diff added lines, Connected dots, "Copy link". Cancel and primary are the same green, so Cancel looks as important as the action (`J5-apikey-01`).
- "Flat content, glass only on the nav": the message box/composer is glass too (the Appearance text says so), the top bar pill is glass-styled, and the glow background is not flat.
- "Red = destroy/stop": correct on Disconnect, Delete everything, Stop setup; wrong on **Stop the server** (grey, `J6-09`) and the chat Stop button (white).
- "Amber = needs you": correct on the demo permission card and MCP "Authentication required" (`J1-15`, `J5-mcp`). Not seen misused.
Colour/type consistency across screens is good in Dark; Light is unverifiable (crash).

## 5. Consistency (needs work)
- Time formats: "2h ago", "3d ago", "2026-09-19", "2:05 AM", "Just now", ISO in titles (`J2-08`, `J3-20`, `J3-31`).
- Project names: "oc_app" on Work, "Code/oc_app" in search, path in Switch project; two projects both named "proj" and two "oc_app" (`J4-07`).
- Segmented controls come in 3 styles: Appearance pill with checkmark, Commands tabs with taller pill, Terminal location toggle (`J5-appearance-01`, `J5-commands-tools`, `J4-05-terminal`).
- Status lines: "Connected . 1.18.32 . Stopped" and "Reconnecting..." and "isn't answering" can appear together (`J6-12`).
- Sheets: some have icon tile + title + X, some only title + X; cards inside sheets are inset ~20 dp vs 16 dp on pages.
- Row patterns: Go-to menu rows without subtitles vs Do rows with; flat rows with dividers (Files) vs card rows (Settings) vs bare rows (Work list).
- Wording: "conversation" vs "session" (raw "New session - ..."), "Add server" step counts, "Connect" vs "Sign in".

## 6. Flows (broken)
1. **AI Team**: tap, sheet, Add, back to Off. No progress, no error (P1-1). The alternate path shows an error that cannot be acted on (P1-2). Highest-priority fix.
2. **Add tools** generally: nothing installs; Voice cancel/stop untestable.
3. First message: first Send tap only closes the keyboard (P1-5).
4. Model picker search invisible with keyboard (P1-3).
5. Provider sign-in: shows Connected while the picker says it failed; "Manage accounts" disabled; banner button loops (P1-4).
6. Interrupted reply: silent (no "stopped by connection loss, send again"); stale Thinking animation while offline.
7. Compact context: no confirm, no progress, unexplained summary bubble.
8. Stopped phone server: three conflicting status lines, plus a nag sheet on every start; the stopped-after-relaunch page is good.
9. After connecting a server the user is dropped into an empty New conversation with the keyboard open, not Work.

## 7. Accessibility (needs work)
Touch targets (uiautomator, dp; sizes for partly scrolled rows under-report):
- Send/Mic circle in composer: 40x40 dp (measured from `J3-16`, 88 px displayed = 105 px = 40 dp). Under 48.
- Copy/More icons under replies: 48 dp wide, height reported 29-30 dp when partly visible; the row gap suggests 48 but was not confirmed.
- Code-block copy and wrap icons: 48x30 dp (`J3-35`). Under 48 in height.
- Model picker tabs (All/Favorites/Recent): reported 123x21 dp with the keyboard open; tab text at the visible size otherwise ~48 dp.
- Terminal Page up/Page down 47x48 dp (fine); "Try the demo" link on Setup guide 411x23 dp (under 48).
- Dock items: ~93x46 dp each (borderline).
Labels: most controls have content-desc. Gaps: text fields expose empty text in the tree (26 composer/search fields listed as "347x48dp" or "379x50dp" unlabelled clickable), so TalkBack relies on the hint. Icon buttons for Filter, Refresh, Copy and Wrap are labelled.
Reading order: page titles come first in the dump; the sticky bottom action (Save & connect, Add, Set up AI Team) is last, which is correct. In Add server the progress ("Step 1 of 4") is read before the title.
Contrast (Dark, sampled): secondary text (163,165,171) on (20,21,24) = 7.4:1; (140,143,150) tips and composer placeholder on (20,21,24)/(29,30,33) = 5.6:1 and 5.1:1; green links on card = 10.3:1. All pass AA. Light not testable. Toggles off use grey knob on grey track (low contrast for the state, colour is the only signal besides knob side).
Colour as the only signal: MCP status (amber/grey icon plus text: ok), Connected dot (text also says Connected: ok), toggle on/off (colour + knob position). Diff uses signs. Mostly OK.
Font scale: 1.3 fine (subtitles ellipsise, `J10-12`). 2.0: no overlap or horizontal scroll, pill and title wrap, search circle and mic do not scale, code blocks show ~14 characters per line clipped without scroll cue (`J10-09`, `J10-10`, `J10-11`).
Motion: with all animator scales at 0 nothing stuck or invisible (`J10-13`). The app has its own Calm/Off animation setting but I did not verify it changes anything.
Landscape: Work gets a side rail (good); chat leaves ~1 message of transcript and a full-width composer (`J10-07`, `J10-08`).

## Spacing (needs work; measured)
- Side gutter: page text starts at 43 px = 16.4 dp on phone: correct (Work, Settings, chat). Cards start at 16 dp. Sheets inset content ~20 dp and inner cards ~20 dp (`J3-01`, `J2-11`). Demo permission card sits at ~8 dp and "Reset demo" ends ~8 dp from the edge (`J1-14`, `J1-15`). Diff wrap FAB hugs the right edge (`J1-17`).
- Vertical rhythm: section heading to card ~20 dp; card to next group ~22 dp (Settings `J5-settings-bottom`); single-line row height ~64 dp, two-line rows 80 dp, three-line 88 dp: consistent inside lists.
- Around floating nav and composer: nav bottom edge ~7 dp above the gesture bar; New conversation button sits 9 dp above the dock and glued to the last list row (row text clipped under it, `J10-08`, `J10-12`). Composer bottom sits ~7 dp above the gesture bar; keyboard open leaves a 30% strip for content (`J3-32`).
- Crowded: Add server error text is 8 dp above its button (`J1-04`); "Accumulated cost" label touches its value (`J3-23`); dock labels touch the dock border at 2.0x font (`J10-11`).
- Too much air: Plugins, Files, Cloud environments, demo completion, Setup step 4 "Connected" page (60% empty, `J2-03`).
Screens where the rhythm breaks: demo, sheets vs pages, Files (dividers run to the edge with no right gutter, `J4-05-files`), Work bottom, Details, Add server errors.

## Usability per journey (taps counted from launch or from the stated start)
- J1 welcome to finished demo: 4 taps (Just show me, Send, Allow once, optional Review changes). New user succeeds unaided. Guess moments: "They run side by side" intro, "opencode2 pair" vs the pinned `opencode` binary. No dead ends; Back and Leave demo always present.
- J2 connect a host by address: 6 taps plus typing (On my computer, OpenCode, Enter address instead, field, Save & connect, Open). Would a new user succeed? Probably, but "Enter the address instead" is hidden under Scan/Paste and needs a guess. Surprise: lands in a New conversation, not Work.
- J3 first reply: New conversation (1) > chooser Solo (1, only after the first time) > type > Send (2 taps, first ineffective). Waiting 40-120 s on the free model with only "Thinking..." (no time hint). Stop is one tap; resend one tap. Missing: Undo for Compact, confirm for Compact, interrupted-turn message.
- J4 Inbox/Project: 1 tap per tab; Back consistent. Inbox "done" row opens only Dismiss.
- J5: median 2 taps to any page, 4 to MCP catalogue. Missing Back? None. Loops: Reload providers banner. Needless confirm: none seen. Missing confirm: MCP catalogue toggles.
- J6 setup on phone: 3 taps then ~5 minutes wait with a live per-step log (good) and notification promise. Relaunch resilience good. A new user would succeed.
- J7/J8: cannot succeed. 3 taps to nothing (AI Team), or 4 taps to an error (Add tools).
- J9: Android's page offers only Clear storage/Clear cache; a careful user cannot find the safer app page from there on this build.
- J10: connection loss handled with plain words and auto recovery; nothing needs the user.

## Top 10 changes, ranked
1. Make AI Team install work or fail loudly: show progress and a plain reason on the AI Team page; surface the same error as the This phone path; never return silently to Off.
2. Fix "OpenCode is unreachable" on Add tools (all items) and stop calling the server Running/Connected while the installer cannot reach it; add Details plus a retry that can work.
3. Remove the Glass-effects option and fix the Light-theme crash; test Light on the emulator GPU path before any release.
4. Fix the model-picker search-with-keyboard layout and the first-tap Send.
5. Make provider status truthful: one source for "Connected"; if sign-ins failed to load say "Signed in, but the server could not load it", with a working action; enable or explain "Manage accounts".
6. Delete Plugins; merge Notifications + Keep running + What runs by itself into one page; delete the duplicate Settings search field; drop "Available on this server" into About.
7. Kill raw text: no ISO "New session" titles, no raw IP as a server name, no model reasoning in the compact card, no "prompt.turn 144307ms" in Report a problem; one time format ("2h ago" / "Yesterday" / "12 Sep").
8. One flat graphite background, remove the header seam and the green glow; keep green for one primary action and turn Cancel/links neutral; make Stop-server red.
9. Handle interrupted work: when the connection drops mid-reply, replace the Thinking animation with "Connection lost, this reply stopped. Send again" and disable Stop; confirm Compact.
10. Accessibility floor: 48 dp minimum for Send/Mic, code-block icons and the Setup-guide demo link; give text fields visible labels in the tree; make code blocks scroll or wrap by default (14 characters at 2.0x is unusable); cap landscape chat header height.
