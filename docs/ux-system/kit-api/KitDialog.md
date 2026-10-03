# KitDialog — API freeze (wave 0, 2026-09-26)

Unit: `kit-KitDialog` (wave 1, tier 1c, kind `kit-part`). Spec: kit-v2.md §1.3, §4.6, §8.2; STANDARDS KIT-11, KIT-15, MOT-2, DATA-1, DATA-3, STATE-8, COPY-8, COPY-9; Appendix A #23; cut review C25. STANDARDS wins where it differs from kit-v2.md.

## Purpose

The two jobs a dialog still has (principle 7, KIT-15): one short text entry (rename, a folder name, a code, a budget) and a blocking alert with at most one action. It is opened only through `showKitInputDialog` and `showKitAlert`. There is no general-purpose dialog.

## Replaces

- **Map elements (kit-v2.json `assignment` → `KitDialog`): 21 elements on 16 pages.** They are chat-rename-session-dialog (×3), chat-run-shell-dialog (×3), credential-management-sheet-rename-dialog, external-agent-detail-input-dialog, file-drop-failed-dialog (×2), integrations-authorization-launch-dialog, integrations-oauth-code-dialog, integrations-oauth-inputs-dialog, project-folder-new-dialog, project-folder-open-dialog, projects-rename-dialog, run-command-dialog, terminal-rename-dialog, usage-budget-dialog, workspace-rename-session-dialog and worktrees-create-dialog.
- **Files and their G1 baseline counts** (`showDialog(` / `AlertDialog(`). Confirmation dialogs in the same files go to `KitConfirmSheet`, not here.

  | File | showDialog( | AlertDialog( |
  |---|---|---|
  | `lib/ui/screens/chat_screen.dart` (6 elements) | 2 | 2 |
  | `lib/ui/screens/library/integrations_screen.dart` | 4 | 2 |
  | `lib/ui/screens/library/integration_tiles.dart` | – | 3 |
  | `lib/ui/screens/project_folder_actions.dart` | 2 | 2 |
  | `lib/ui/screens/workspace_screen.dart` | 2 | 2 |
  | `lib/ui/desktop/file_drop.dart` (the alert) | 1 | 1 |
  | `lib/ui/screens/library/credential_sheet.dart`, `external_agents_screen.dart`, `projects_screen.dart`, `terminal_screen.dart`, `worktrees_screen.dart`, `lib/ui/widgets/run_command_dialog.dart` | 1 each | 1 each |
  | `lib/ui/screens/usage_screen.dart` | – | 1 |

- **Whole app:** G1 counts `showDialog(` 30 in 21 files and `AlertDialog(` 30 in 22 files. KitDialog takes the input and alert ones. The rest go to `showKitConfirm` (confirmations), `showKitSheet` (detail views with a lone "Done", several fields) or `showKitTechnicalDetails` (a raw error).

## File

`lib/ui/kit/kit_dialog.dart`. Tests go in `test/kit/kit_dialog_test.dart` and galleries in `test/goldens/kit/kit_dialog_golden_test.dart`.

## Public API

```dart
/// One short text entry. Returns the submitted text, or null on cancel,
/// back, Esc or a tap outside. The field is KitField with [kind].
Future<String?> showKitInputDialog(
  BuildContext context, {
  required String title,                  // "Rename conversation"
  required String label,                  // visible field label, never placeholder-only
  required String confirmLabel,           // a verb naming the act: "Rename" (COPY-8)
  String? initial,                        // prefilled and selected on open
  String? hint,                           // an example ("my-branch"), never the label
  String? helper,                         // wraps to 2 lines, never cut
  KitFieldKind kind = KitFieldKind.text,  // text | mono | path | url | number | secret
  int? maxLength,                         // counter from 80 %
  int maxLines = 1,                       // > 1: wraps from one line up to this many (a long command reads whole); Enter submits, Shift+Enter adds a line
  String? Function(String value)? validate,          // null = valid; the reason otherwise
  Future<String?> Function(String value)? onSubmit,  // async; a non-null result is an error shown under the field
  KitAction? alternative,                 // e.g. "Remove budget": on its own line (destructive stacks)
  KitDraft? draft,                        // keep the text across dismissal and a process kill
  String? cancelLabel,                    // default: the existing kitConfirmCancel "Cancel"
  Key? dialogKey,
  Key? fieldKey,
  Key? confirmKey,
});

/// A blocking alert with at most one action. Completes when it closes.
/// Esc, back and Close dismiss it; a tap outside does not (it blocks).
Future<void> showKitAlert(
  BuildContext context, {
  required String title,                  // ≤ 4 fixed words (COPY-10)
  required String body,                   // ≤ 2 sentences
  List<KitTechnicalValue> details = const [], // one KitDetailsFold, last and collapsed
  KitAction? action,                      // at most one, e.g. "Open Files"; it closes the alert and runs
  String? closeLabel,                     // default: the existing kitSheetClose "Close"
  IconData? icon,                         // shown in an icon tile beside the title; never a "?"
  Key? alertKey,
  Key? closeKey,
});
```

- **Naming.** kit-v2.md §8.2 writes "`showKitDialog` / `showKitAlert`". The frozen names are `showKitInputDialog` and `showKitAlert` (KIT-11). There is no `showKitDialog` and no public `KitDialog` widget constructor for screens. The widget classes that draw the frames are private, and the galleries open them through the two functions (the harness's `open:` callback).
- **Returns:** `showKitInputDialog` gives `String?`, null on every dismissal; `showKitAlert` gives `Future<void>`.
- **Secret kind.** With `kind: secret` the dialog uses `KitField.secret`: `initial` must be null (assert), the text is never selected-for-copy, and the returned value goes straight to the caller's secure store (the OAuth-code dialog, the connect-key dialog).
- **Kit copy:** no new keys (COPY-18: one action, one key). The dialog reuses the existing `kitConfirmCancel` "Cancel", `kitSheetClose` "Close", and the discard question's `kitDiscardTitle`, `kitDiscardBody`, `kitDiscardConfirm` ("Discard changes") and `kitConfirmKeepEditing` ("Keep editing"), exactly as `showKitSheet`'s discard question does.

## States

The doc comment declares: `input-default`, `input-invalid` (the primary disabled with its reason), `input-error` (a submit error under the field), `input-working`, `input-discard` (the discard question in place), `alert`, `alert-with-action`, `alert-with-details`.

- **Loading.** None. The dialog opens with local data only.
- **Empty.** An empty field with `validate` failing: the primary is disabled with the reason shown as `KitAction.disabledReason` under it, for example "Name is empty" (STATE-8). Once the person has edited, the reason moves to the field's error line and the button's reason line is hidden, so it is never shown twice.
- **Error.** An error from `onSubmit` shows under the field, the typed text is kept, and the dialog stays open (DATA-14 by analogy).
- **Working.** While `onSubmit` runs, the primary shows `working`, the field and Cancel are disabled, Esc and back are ignored, and the barrier does not dismiss.
- **Disabled.** Only the primary, always with its reason.
- **Answered.** Not applicable.

## Tokens

All of the following exist on `feat/visual-language-v1` unless flagged.

- **ThemeRoles:**
  - `surface2`: the dialog panel, the same as `KitTokens.panelSurface`;
  - `scrim`: the barrier, with no blur (LOOK-22);
  - `text1`: title;
  - `text2`: body;
  - `surface3`: the icon tile.
  - Button roles come through `KitActionBlock`.
- **KitText roles:**
  - `title`: the dialog title;
  - `body`: the alert body, in `text2`;
  - the field's roles come through `KitField`.
- **KitTokens:**
  - `panelRadius` (24, the VL dialog panel);
  - `panelInset` (24);
  - `space2`–`space4`;
  - `iconTileSize` (30) and `iconTileRadius` (9);
  - `smallIconSize`;
  - `scrim`.
- **KitLayout (existing):** `confirmDialogWidth` (480): the one width of a centred 480 dp dialog, shared by confirmations and these dialogs (K2 §8.2). No new name (README.md, decision D2).
- **KitMotion:** `standard` with `enter`/`exit`, for the fade-in and fade-out only.
- **New tokens:** none of its own.

## Adaptive

- **Compact.** A centred dialog, the window width minus the 16 dp gutter (`KitTokens.gutter`) on each side. The actions are stacked full width: the primary (the verb) on top, then Cancel as a tertiary action. An `alternative` sits on its own line, and if it is destructive the block stacks by itself (§2.7).
- **Medium.** The same dialog, width capped at `confirmDialogWidth`. From medium the action block may be one end-aligned row with the primary at the end (LAY-13).
- **Expanded and large.** A centred dialog, 480 dp, with actions in one end-aligned row. Enter submits the input dialog (§8.2 "Enter as the primary for input").
- **Short windows (< 480 dp tall, a landscape phone).** The dialog body scrolls, and the field and the pinned actions stay visible above the keyboard.
- **Keyboard (§8.3, G14):**
  - Focus starts in the field, with the text selected.
  - Tab order is field → primary → alternative → Cancel, following reading order.
  - Enter or the IME action submits when valid.
  - Esc cancels, or asks the discard question when the text has changed and there is no draft (DATA-3).
  - An alert: focus starts on its action or Close, and Esc and Enter close it. Enter never runs `action`, because it may navigate away.
- **Fine pointer.** Hover highlights come from `KitButton`. Targets stay 48 dp.

## Accessibility

- The route is a named dialog route (`scopesRoute`, `namesRoute`) labelled by its title. Focus moves into the dialog on open and returns to the opener on close.
- The field is `KitField`, so its label, helper, error and counter follow KitField's rules. An error from `onSubmit` is announced once.
- The disabled primary's reason is visible text (STATE-8), never only a tooltip.
- Targets are 48 dp, with 8 dp between a destructive `alternative` and any other target (LAY-9).
- At 200 % text the title wraps to at least two lines and the helper is never truncated (the critical defect in integrations-mcp-oauth-code-dialog). The body scrolls while the actions stay reachable.
- An alert is announced as its title then its body once on open. Its details fold is collapsed and says "Details".

## RTL

- The title, body and actions follow the locale. The end-aligned action row mirrors, with the primary at the end.
- The mono, path, url and secret field kinds are LTR and isolated (through KitField). The details values are LTR through `KitDetailsFold`.
- A placeholder inside the title, such as a conversation name, is wrapped by the kit with `KitBidi.auto` (COPY-30).

## Motion and haptics

- The dialog cross-fades in and out on `KitMotion.standard`, with no scale (MOT-2, Appendix A #23: this replaces kit-v2.md's "fade and scale").
- The discard question replaces the content in place with a `KitReveal` swap. It adds no route (KIT-16).
- Under `KitMotion.reduced` everything is instant, and one `pump()` settles.
- Haptics: none (MOT-11). A destructive `alternative` never fires `commit` here, because a destructive act is confirmed by `showKitConfirm` from the caller.

## Data safety and honest state

- **Input survives mistakes (DATA-1, DATA-3).**
  - With a `draft`, back, Esc and Cancel keep the text silently, and reopening restores it.
  - Without a draft, a tap outside does nothing once the text differs from `initial`, and back or Esc asks the discard question inside the dialog, with "Keep editing" as the default.
  - An explicit Cancel tap closes without asking (it is the person's choice).
  - Rotation keeps the text, because the route and its state survive.
  - A process kill loses non-draft text, which DATA-1 allows. kit-v2.md's "restorable state" is met by `draft`, because the app has no `restorationScopeId`.
- **Async submit.** The text is kept on error. The dialog never closes on an error. It returns the value only after `onSubmit` returns null.
- **Secrets.** The secret kind never prefills (assert), and its value is never logged or returned through any path other than the Future.
- **Honest state.** A disabled submit always states why. "Working" is only the primary's own tap in flight (STATE-7). An alert never pretends to be a confirmation: it has at most one action and no "OK/Cancel" pair (KIT-15, COPY-8).

## Depends on

- **KitField** (kit-KitField): the field, its kinds and the draft wiring.
- **KitDetailsFold** (kit-KitDetailsFold): the alert's `details`.
- **KitAction v2** (kit-KitAction-v2): `disabledReason` under the primary, and the destructive stack in `KitActionBlock`. Edge added (README.md); tier 1a, so no tier change.
- **KitBidi** (a pre-wave seam, STANDARDS §0.5 step 2): the title placeholder.
- **Existing parts:** `KitButton`/`KitActionBlock`, `KitReveal`, `KitMotion`, `KitLayout`, `KitDraft`, and `KitText`/`ThemeRoles`/`KitTokens` (VL).

## Tests required

In `test/kit/kit_dialog_test.dart` (G9, G14, TEST-15):

1. Open: the field is focused and `initial` is selected. The title names the route.
2. `validate` failing on an empty field disables the primary, and its reason is visible under the primary. After the first edit the reason is shown once, under the field, and not under the button.
3. Enter or the IME action submits only when valid, and returns the text.
4. Async `onSubmit`:
   - `working` shows on the primary;
   - a second Enter is ignored;
   - Esc is ignored while working;
   - an error result stays open with the error under the field and the text kept;
   - null closes and returns the value.
5. Cancel returns null. Back and Esc return null when the text is unchanged.
6. Changed text without a draft: Esc and back show the discard question in place and add no route. "Keep editing" returns to the field with the text. "Discard changes" returns null. A barrier tap does nothing.
7. With a draft: Esc closes silently and the text is saved. Reopening restores it. The key is `oc.draft.<target>.<profileId>`.
8. Secret kind: a non-null `initial` asserts. The field is obscured, with no suggestions.
9. `alternative` destructive: rendered on its own line, stacked, and never beside the primary. Its target keeps 8 dp from others.
10. `showKitAlert`:
    - it has at most one action;
    - Close, Esc and back complete the Future;
    - a barrier tap does not;
    - `action` closes and runs;
    - `details` render in one collapsed fold, last;
    - the title and body are announced once.
11. Keyboard (desktop capabilities): Tab reaches the field, primary, alternative and Cancel in order. Enter on an alert does not run `action`.
12. Under reduced motion one `pump()` settles. The cross-fade has no scale transform in the tree (MOT-2).
13. Overflow (G6): at 320–1600 dp and 915×412, text 1.0, 1.3 and 2.0, LTR and RTL, there is no exception, the helper is not clipped at 2.0, and the actions are reachable.
14. `showKitInputDialog` and `showKitAlert` return Futures and accept `…Key` parameters (G4 manifest).

## Galleries required

`test/goldens/kit/kit_dialog_golden_test.dart`, at DPR 3 (TEST-9, 2 × 8 + 18 = 34 PNGs):

- **Every declared state, dark and light, at 412×915.** The states are input-default, input-invalid, input-error, input-working, input-discard, alert, alert-with-action, and alert-with-details (unfolded).
- **The input-default state, dark and light, at the other sizes:** 360×800, 915×412, 800×1280, 1280×800 and 1600×1000. The PC sizes show the 480 dp dialog with its end-aligned action row.
- **Input-default at text 2.0 and in Arabic RTL, dark and light, at 412×915 and 1280×800.** The Arabic scene uses a path-kind field to show LTR isolation.

## Non-goals

- No confirmation dialog (`showKitConfirm`), and no multi-field forms (`showKitSheet` or a screen).
- No detail view with a lone "Done" (`showKitSheet` or `KitDetailsFold`), and no raw-error dialog (`showKitTechnicalDetails`).
- No custom content slot, no second action on an alert, and no dialog stacked on a sheet: a sheet raises its own in-place swap (KIT-16).
- No restoration API.
- No migration of call sites (wave 2).

## Open questions

None. One K2 amendment for the coordinator's pass (STANDARDS §0.5 step 8): kit-v2.md §1.3 says both "`validate`: error under the field" and "Submit is disabled with its reason until valid". This freeze decides between them: the reason goes under the primary before the first edit, and under the field after it, never in both places.
