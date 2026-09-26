# KitChecklist — API freeze (wave 0)

Unit: `kit-KitChecklist` (wave 1, tier 1d, kind `kit-part`). Spec: kit-v2.md §1.12, §2.8, §4.9, with cut review C24 (`setup_progress_view.dart` moves into this unit), C25 (dependencies) and C26 (the person-step row, and waiting/done/failed goldens from P1.1). Rules: STATE-5, STATE-6, STATE-11, KIT-37, AUTO-19, MOT-6, A11Y-3, TEST-5.

## Purpose

A job made of steps, with steps only the person can do mixed in: phone setup, Termux, Claude Code, AI Team turn-on, the voice model, worktree creation, and a team task's cycle. It has:

- a mark per step, one bar for the whole job, and the estimate and cost before the start;
- Stop and Resume;
- a failure on its own row with Try again;
- a folded log;
- a one-line compact form (the team stage strip).

It promotes `SetupProgressView` into the kit.

## Replaces

- **Map elements, 18 on 16 pages (kit-v2.json `new[KitChecklist]`):**
  - `builtin-server-setup` (four-step-list, step-primaries);
  - `embedded-local-agent-onboarding-block` (steps);
  - `embedded-mobile-task-list` (embedded-mobile-task-list-progress);
  - `embedded-team-cycle-strip` (cycle-stages);
  - `embedded-team-merge-section` (merge-checks);
  - `guide` (guide-steps);
  - `isolated-task-sheet` (isolated-task-sheet-progress);
  - `local-agent-page` (install-steps, sign-in);
  - `phone-setup-progress` (checklist);
  - `tailscale-setup` (tailscale-setup-step1);
  - `team-phone-onboarding-steps` (steps-marks);
  - `team-run-overview-tab` (team-run-stage-line);
  - `termux-setup-checking` (progress-line);
  - `termux-setup-connected` (steps-done);
  - `termux-setup-get-termux` (steps);
  - `work-sheet` (team-work-sheet-cycle).
- **Merged gap names:** `KitActionStep`, `KitChecklist`, `KitStageStrip`, `KitStepList`, `KitStepRow`.
- **Absorbed widget:** `SetupProgressView` (`lib/ui/widgets/setup_progress_view.dart`, 785 lines; G16: AnimatedSwitcher 1, Container 1, Directionality 1, Divider 1, FadeTransition 1, Icon 1, ScaleTransition 1, SingleChildScrollView 3, Text 5, TextButton 1, TweenAnimationBuilder 1). The file joins this unit's write set (C24). It becomes a thin adapter that maps `SetupProgress` and `SetupComponent` to a `KitStateView` (head: scene, title, body, overall bar) whose `content` is a `KitChecklist`. It keeps its public constructor and statics (`networkError`, `formatBytePair`, `sceneFor`), and every existing key (TEST-5):
  - `setup-progress-checklist`;
  - `setup-progress-row-<id>`;
  - `setup-progress-continue`;
  - `setup-progress-cancel`;
  - `setup-progress-details`;
  - `setup-progress-overall`;
  - `setup-progress-job-error`.

  The kit must not import `lib/builtin/`, so the mapping stays in the adapter.
- **Retires:** slice-P1.1 (the person-step checklist, C41; its app-resume re-check goes to slice-P1.2).

## File

- `lib/ui/kit/kit_checklist.dart` (`KitChecklist`, `KitStep`)
- `lib/ui/widgets/setup_progress_view.dart`, the adapter (C24)
- Tests: `test/kit/kit_checklist_test.dart`
- Gallery: `test/goldens/kit/kit_checklist_golden_test.dart`

## Public API

```dart
class KitStep {
  const KitStep({
    required this.title,           // "Download Ubuntu"
    required this.state,           // KitMarkState: waiting, working, done, failed
    this.paused = false,           // with waiting/working: a heat pause, a resumable force stop (KitStatusMark.paused)
    this.supporting,               // "29 of 30 MB · about 1 min left"; the failure's reason; "Already installed"
    this.personAction,             // a step only the person can do: "Allow", "Get Termux" → needs-you mark + its button
    this.retry,                    // "Try again": on the failed row only (asserted)
    this.value,                    // 0..1 within this step when measured: a thin bar under the row while working
    this.key,
  });

  final String title;
  final KitMarkState state;
  final bool paused;
  final String? supporting;
  final KitAction? personAction;
  final KitAction? retry;
  final double? value;
  final Key? key;
}

class KitChecklist extends StatelessWidget {
  const KitChecklist({
    super.key,
    required this.steps,
    this.progress,                 // KitProgress.staged: one bar for the whole job (omit when the host shows it)
    this.estimate,                 // before the start, in words: "about 8 minutes the first time"
    this.cost = const [],          // before the start: KitNotice.cost items (KIT-37)
    this.stop,                     // KitAction "Stop"; the caller confirms only when work would be lost
    this.resume,                   // KitAction "Continue setup": after a failure, a force stop or a heat pause
    this.log,                      // a KitLogPanel, folded under Details
    this.since,                    // the last progress event; the working step escalates after 8 s
    this.onSlow = const [],        // ≤ 2 ways out after the escalation
    this.compact = false,          // one line "Step 3 of 7 · Reviewing · next: merge" that unfolds to the list
    this.next,                     // compact only: the next step's words, "merge"
    this.checklistKey,             // the steps column: 'setup-progress-checklist' in the adapter
    this.detailsKey,               // the log fold's toggle: 'setup-progress-details' in the adapter
  });

  final List<KitStep> steps;
  final KitProgress? progress;
  final String? estimate;
  final List<String> cost;
  final KitAction? stop;
  final KitAction? resume;
  final KitLogPanel? log;
  final DateTime? since;
  final List<KitAction> onSlow;
  final bool compact;
  final String? next;
  final Key? checklistKey;
  final Key? detailsKey;
}
```

**Amendments to K2 §1.12:**

- `KitStep.paused` replaces the `KitMarkState.paused` enum value. See KitStatusMark.md: an enum value would break `team_conversation_view.dart:884` and `:1018` (R11, KIT-43).
- `KitStep.value`, `cost`, `since`, `onSlow`, `next` and the two keys are optional additions. They are needed for SetupProgressView parity (per-row byte bars, the keys) and for §4.9 ("KitChecklist takes `since`"), and K2's own States paragraph asks for the cost line before the start.

## States

| State | What shows |
|---|---|
| before the start | every step waiting; `estimate` and the `KitNotice.cost` line above the steps (K2 States); the host's primary starts it |
| working | one row working (its mark, `supporting`, and an optional thin bar from `value`); `progress` staged and determinate where known (STATE-6) |
| person step | that row leads with `KitNeedsYou.mark()` (instead of its state mark), shows `personAction` as a secondary button on the row, and its supporting line starts with "Needs you · " |
| slow (escalated) | after 8 s since `since`: the working row's supporting line reads KitSince's "Still waiting after 8 s"; `onSlow` actions appear under the list; one announcement |
| failed | the failed row shows its reason and `retry` on that row; the job-level `resume` ("Continue setup") under the list; the log fold may be opened on request, never automatically |
| paused | the paused row's mark; the caller's supporting ("Resumes when the phone cools"); `resume` when the person can resume now |
| stopped (force stop, cancelled) | the rows keep their marks; `resume` shows |
| done | every mark done; `KitHaptics.done` fires once when the job turns done while visible |
| compact | one line, "Step 3 of 7 · Reviewing · next: merge", with the working mark; tapping or Enter unfolds the full list in place |
| empty | an assert: a checklist has at least one step |
| loading | none of its own: a job that has not reported yet lists its steps as waiting (SetupProgressView's rule: "the screen never opens empty") |
| disabled | an action with `onPressed: null` shows its `disabledReason` (kit-KitAction-v2) |

KIT-12 doc comment: "States: before-start, working, person-step, slow, failed, paused, stopped, done, compact (+ disabled actions)".

## Tokens

- **ThemeRoles:**
  - marks per KitStatusMark (the shared tone map);
  - the needs-you mark `attention`;
  - titles `text1`, supporting `text2`, "Already installed" `text2`;
  - the thin per-row bar `accent` on `surface3`;
  - separators `hairline` at `hairlineWidth` (pre-wave).
- **KitText:** `rowTitle` (step title), `secondary` (supporting), `label` (the compact line).
- **KitTokens:**
  - `rowHeight` (54, one line) and `rowHeightTwoLine` (60);
  - `gutter`, `space2`, `space3`, `space4`, `sectionGap` (22, between the list and the log fold);
  - `minTarget`;
  - `smallIconSize`;
  - `loadingBarHeight` (2, the thin per-row bar) and `progressBarHeight` (4, the job bar through KitProgress): both pre-wave names in `_new-tokens.md`.
- **New tokens:** none of its own.

## Adaptive

- **compact:** one column of full-width rows on the host's rails, then the actions (KitActionBlock: resume primary, stop tertiary), then the Details fold with the log.
- **medium:** the same, capped by the host at `KitLayout.readingWidth` (720).
- **expanded / large:** the same single column at `readingWidth`. With a fine pointer and `log` open, the log may take the full height of the host's detail pane (the host decides); the list does not split into columns.
- **Short windows:** the adapter's head scrolls with the list (LAY-3).
- **Pointer and keyboard:**
  - Tab order: person actions and Try again in row order, then resume and stop, then the Details fold;
  - Enter and Space activate;
  - the compact line is one button (Enter unfolds, and Esc does nothing);
  - hover highlights actionable rows only;
  - a row without an action is not focusable, but its text is readable in traversal.

## Accessibility

- **Each row is one semantics node:** "Step 2 of 5, Download, working, 29 of 30 MB" (K2). A person step adds "needs you, {personAction label}". The row's mark is excluded, because the words say it.
- **Announcements:** the job header is the live region, not the rows (A11Y-3). That is the `progress` line when present, or else a visually hidden summary node the checklist owns. A step or state change is announced once, and a byte-count tick is not.
- **Targets:** person actions, Try again, resume and stop are 48 dp, with 8 dp between them. Stop is destructive-tinted text only when it loses work (LOOK-5), never red for a harmless cancel.
- **200 % text:** titles wrap to 2 lines and supporting lines wrap. The row grows, and a row's action moves under its words.

## RTL

- The marks sit at the start and actions at the end or under the words, with directional padding (G7). Byte counts and sizes in `supporting` are wrapped with `KitBidi.ltr` by the caller or adapter (COPY-30).
- The per-row bar fills from the start (it mirrors).
- The log is LTR inside its panel (KitLogPanel).

## Motion and haptics

- Marks cross-fade on `KitMotion.quick`. A row that appears (a new person step) unfolds with `KitAnimatedRows`. The compact line unfolds with `KitReveal`. The per-row bar animates on `KitMotion.standard` (paint only).
- **Reduced motion:** instant. The working mark is a still dot.
- **No loops:** the list has none. The host's illustration may be the one ambient loop while waiting (MOT-6).
- **Haptics:** `KitHaptics.done` once when every step turns done while the checklist is visible (K2). Nothing on failures or stops (MOT-11).

## Data safety and honest state

- **Marks come from the engine**, never inferred. "Waiting" is never ticked as done (the map defect). A step from an existing install is done with "Already installed" (STATE-11). A resumed job starts at its step.
- **Try again appears only on the failed row.** `retry` on a row that is not failed asserts.
- **Stop does not confirm by itself.** The caller confirms only when work would be lost (`showKitConfirm` kind `stop`; DATA-11). Otherwise stopping is "neither" and just stops.
- **The bar never goes backwards within a job** (KitProgress rule; SetupProgressView's "eases towards the furthest point").
- **No silent waits:** a working step with `since` escalates after 8 s (STATE-5). The adapter passes the time of the last progress report.
- **The log is redacted** by KitLogPanel (SEC-4) and folded by default.
- **The adapter keeps SetupProgressView's honest words:**
  - "No internet connection · Continue when you're back online" for network failures (`networkError`);
  - "Stopped" and "Interrupted" bodies;
  - the job error when no row carries the failure (`setup-progress-job-error`).

## Depends on

- **Wave-1 units (C25):**
  - kit-KitLogPanel;
  - kit-KitProgress-v2;
  - kit-KitNotice-v2 (`.cost`);
  - kit-KitStatusMark-v2 (`paused`, words);
  - kit-KitNeedsYou (the person-step mark and span);
  - kit-KitAction-v2 (`disabledReason`);
  - kit-KitSince.
- **Existing:** `KitRow` geometry, `KitActionBlock`, `KitAnimatedRows`, `KitReveal`, `KitHaptics`, `KitStateView` (the adapter's head).
- **Pre-wave:** `KitMotion.escalateAfter`, `KitBidi`, `KitTokens.hairlineWidth`.

## Tests required

In `test/kit/kit_checklist_test.dart`, using KitSince's fake clock:

1. **Row semantics:** each row reads "Step n of N, {title}, {state word}[, {supporting}]". A person step reads "needs you" and its action label.
2. **Person step:** the row shows the needs-you mark and the `personAction` button. Tapping calls it once.
3. **Retry placement:** `retry` renders only on the failed row. `retry` on a non-failed step asserts.
4. **Escalation:** with `since` 8 s ago, the working row's supporting line reads "Still waiting after 8 s" and `onSlow` actions appear, with exactly one announcement. At 7 s nothing changes.
5. **Done haptic:** a transition from working to all done calls `KitHaptics.done` once (not with Vibration off, and not on a first build that is already done).
6. **Before the start:** `estimate` and `cost` render before any step starts (all waiting), and not once a step is working.
7. **Compact:** `compact: true` renders one line, "Step 3 of 7 · {title} · next: {next}". Tap and Enter unfold the list, and it folds back.
8. **The log:** it is folded by default. The Details toggle (`detailsKey`) opens it.
9. **Adapter parity:** `SetupProgressView` renders:
   - the keys `setup-progress-checklist`, `setup-progress-row-<id>`, `setup-progress-continue` (after a failure with `canContinue`), `setup-progress-cancel` (while running), `setup-progress-details` and `setup-progress-overall`;
   - the no-internet body on a network failure;
   - the job error with `setup-progress-job-error` when no row failed.

   The existing phone-setup tests that assert behaviour keep passing. Look-level finder changes are listed per TEST-19.
10. **Reduced motion:** the checklist settles after one `pump()` (G8).
11. **Keyboard** (G14x, desktop): Tab visits person actions, Try again, resume, stop and Details in order.

## Galleries required

`test/goldens/kit/kit_checklist_golden_test.dart`, DPR 3, Android platform, inside a KitStateView host with the setup-steps scene at its finished frame.

- **Declared states × dark and light at 412×915** (C26 and P1.1 require waiting, done and failed in dark, light and at 200 %):
  - before-start (estimate and cost);
  - working;
  - person-step;
  - slow;
  - failed;
  - paused;
  - done;
  - compact.
- **Default (working)** × dark and light at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **Text 2.0** (before-start, failed, done) and **Arabic** (working, failed) at 412×915 and 1280×800.
- **Names:** `kit_checklist_<state>…png`. About 48 PNGs, under the 60 cap.

## Non-goals

- No engine or setup logic, and no pre-flight (AUTO-19 is the engine's and the start screen's).
- No confirmation of Stop inside the kit.
- No screen adoption beyond the SetupProgressView adapter. The Termux, Claude Code, team onboarding and guide screens adopt it in wave 2 or 3.
- No per-step logs: there is one log per job (§4.4).

## Open questions

None.
