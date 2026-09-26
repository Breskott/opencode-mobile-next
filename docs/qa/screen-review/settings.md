# Screen review: Settings and more (`j1-settings-more`)

35 pages, all rendered (37 images). The per-page verdicts, scores and fixes are in [`settings.json`](settings.json).
**Verdicts:** 2 keep · 27 fix · 6 rethink. The rethinks are `settings`, `notifications-settings`, `team-plugin-sheet`, `plugins-mapping-dialog`, `appearance-picker-sheet` and `model-picker-sheet-agent-dialog`.
Motion is not scored: every page here is a still, and the only motion is sheet and dialog entrances, which need a device recording.

## The five most important problems

1. **The Settings hub shows the same things twice, in engine words** (`settings`).
   - About 30 rows sit in five groups. Model is there twice ("Model and mode" and "Models & agents", same icon). So are Privacy ("Privacy and local data" and "Privacy and data use") and the licence notices. The AI Team appears twice too: its own row, and the Plugins row's "AI Team · Gas City".
   - The supporting lines say "durable OpenCode permissions", "sherpa-onnx, ONNX Runtime" and "Gas City", and there is a bare "MCP" row.
   - Fix: merge the duplicates and write the lines in plain words. That cuts the hub to about 18 rows.
2. **Notifications reads like a disclaimer, not a control panel** (`notifications-settings`).
   - It has four row styles.
   - "Keep live" is named in two explanations, but no control on the page has that name.
   - The copy is written as a spec: "At most one notification is attempted per observed interval", "no remaining runtime is promised".
   - The Android 6-hour warning is cut off mid-word ("says s…").
   - This is the page that decides whether a person trusts a delegated agent to reach them.
3. **The model picker contradicts itself and piles up containers** (`model-picker-sheet`, `-agent-dialog`, `-options-dialog`, `-unloaded-providers-dialog`).
   - A banner says context details are unavailable, while every row shows "200K context".
   - "Mode", "Thinking mode" and "Agent: build" are three names for two settings.
   - Choosing an agent takes a sheet, then a dialog, then a dropdown, and the same dropdown sits in a second dialog.
   - The providers dialog says "Reload to pick up the sign-in" and offers only "Done".
4. **The legal documents render broken** (`about`, `about-open-source-tab`, `about-privacy-tab`).
   - The Markdown keeps its hard wraps, so paragraphs break mid-sentence, and literal backticks show ("`LICENSES/`").
   - The title is cut to "About and open source not…".
   - The identity blocks repeat on both tabs, and "Report a bug" appears twice.
   - The Privacy text uses "Gas City supervisor", "idempotency key" and "100.64.0.0/10".
5. **Destructive actions are unconfirmed or sit beside the main action** (`app-diagnostics`, `legacy-drafts-review-sheet`).
   - On Diagnostics, the Performance "Clear" is green and acts at once, while the error "Clear" is red and confirms. Same word, two behaviours.
   - In Older drafts, "Delete saved copy" is an accent-coloured outlined button right beside "Insert into draft", in a right-aligned cluster built from raw buttons.

Close behind: the AI Team plugin sheet (`team-plugin-sheet`) says "Off" twice under "AI Team · Gas City" and offers only "Add manually". The owner rejected that engine name in regressions 5 and 18.

## Recurring patterns

- **Raw Material parts on the screens this pass has not reached yet.** The unmigrated screens are Notifications, Usage, Web sources, Server capabilities, the About app summary, the Language row, the Default shell sheet, Older drafts and the model picker dialogs. They use ListTile, SwitchListTile, Card, raw buttons, AlertDialog and raw showModalBottomSheet, which gives two leading edges (16/56 dp vs the kit's 20/60 dp) and misaligned chevrons within one screen.
- **Four confirmation styles.** Most confirmations use the kit confirm sheet. The exceptions:
  - Revoke access is an AlertDialog with right-aligned buttons.
  - Older drafts stacks a confirm sheet on top of another sheet.
  - Performance Clear does not confirm at all.
- **Row words disagree with the sheet they open.** "Clear drafts" opens "Delete drafts?". The guide says "Paste pairing code", but the Add server button is "Paste code". "Keep live" is named in text but not on any control. "Usage" is also titled "Usage and cost".
- **Disabled buttons stand in for status.** Examples: "Current appearance" in both appearance sheets, and Send and Copy on empty Diagnostics.
- **Engine and storage words in supporting lines:**
  - "grants" and "(all matching resources)"
  - "process memory"
  - "Project scope"
  - "Compact" and "Worktrees"
  - "no recorded server"
  - "plugin-command links"
- **Sheets for choices that could be inline.** Light or dark (three options), Transcript display (two switches) and Default shell (one option in the sample) each cost a tap plus a sheet.
- **Icon reuse and mixed families.** The brain icon marks three different rows, the clock two, and the network icon two. Material icons (privacy_tip, sd_storage) appear among Phosphor ones.

## Quick wins (copy or one-widget changes)

- About: retitle to "About", drop the app bar bug icon, join soft line breaks in `MarkdownText`.
- Guide: "Scan code" / "Paste code" in step 2, plus an "Add a server" button.
- Unloaded providers dialog: primary "Reload providers" in place of "Done".
- Model picker: show the "basic catalog" banner only when details are truly missing.
- Disconnect sheet: hide "No queued prompts. No unsent drafts. They stay…" when both counts are zero.
- Notifications: let the Background "Off" line wrap, use one name for "Keep live", and set the time picker's `helpText` to "Quiet from" / "Quiet until" with "Set".
- Diagnostics: confirm and error-colour the Performance "Clear" (or remove it).
- Older drafts review sheet: stack the actions (KitActionStack) and error-colour "Delete saved copy".
- Privacy: say "Delete" in both the rows and the sheets, with counted verbs ("Delete 2 drafts").
- Settings hub: Plugins subtitle becomes a plugin count, not "AI Team · Gas City". "Always allowed actions" becomes "Things the agent may do without asking".
- Appearance: move the Language row onto KitRow so its icon and chevron line up.
- Revoke access: use `showConfirmSheet` like every other confirmation.
