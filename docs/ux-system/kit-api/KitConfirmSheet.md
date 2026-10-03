# KitConfirmSheet — API freeze (wave 0, 2026-09-26)

Unit: none of its own. `lib/ui/kit/kit_confirm_sheet.dart` is in the write set of `kit-KitDetailsFold` (wave 1, tier 1b; cut review C23: "the private _KitDetailsFold is replaced by the public part"; `build_units.py` aliases KitConfirmSheet → KitDetailsFold). Scope: the existing API, with only the visual-language look and the swap to the public `KitDetailsFold`. Spec: kit-v2.md §1.2, §4.1, §4.2, §4.7, §8.2; visual language §1, §5 "Sheets" and "Buttons", §7; the approved render `docs/design/visual-language-2026-09-26/Confirm.png`. Rules: KIT-11, KIT-16, KIT-39, KIT-43, LOOK-5, LOOK-6, LOOK-21, LOOK-23, LOOK-25, LAY-9, LAY-10, COPY-8, COPY-9, COPY-30, DATA-11, DATA-12, DATA-13, DATA-14, MOT-11, A11Y-8.

## Purpose

The one question asked before an act that cannot be undone: a server-destructive act, ending running work, or dropping input that cannot be kept. It is opened by `showKitConfirm`, which returns true only when the confirm was chosen. Raised inside a `KitSheet`, it replaces that sheet's content in place.

## Replaces

- **Map elements (kit-v2.json `assignment` → `KitConfirmSheet`): 116 elements on 85 pages.** Each confirmation's frame, its confirm and cancel buttons and its icon are assigned here. The pages, grouped by module:
  - **chat:**
    - chat-cancel-inbox-send-sheet, chat-delete-message-sheet, chat-discard-queued-draft-sheet, chat-draft-attachment-recovery-sheet, chat-leave-unsaved-draft-sheet, chat-pending-photo-sheet, chat-read-aloud-consent-sheet;
    - chat-resend-queued-draft-sheet, chat-revert-confirm-sheet, chat-share-confirm-sheet, chat-stash-attachments-unavailable-sheet, chat-stash-restore-confirm-sheet;
    - prompt-editor-discard-sheet, prompt-stash-delete-sheet, session-note-discard-dialog, stage-revert-sheet, staged-revert-confirm-sheet.
  - **team:** gate-sheet-confirm-sheet, team-agent-restart-confirm-sheet, team-agent-stop-confirm-sheet, team-board-cancel-confirm-sheet, team-cycle-stop-confirm-sheet, team-merge-approve-sheet, team-merge-confirm-sheet, team-phone-remove-sheet, team-phone-stop-sheet, team-run-cancel-confirm-sheet, team-turn-off-sheet.
  - **phone and Termux:**
    - builtin-server-remove-confirm-sheet, phone-setup-progress-stop-sheet, remove-local-agents-confirm-sheet, restart-local-agents-sheet, stop-local-agents-confirm-sheet;
    - termux-processes-stop-group-sheet, termux-processes-stop-one-sheet, termux-setup-replace-installed-sheet, termux-setup-restart-sheet, termux-setup-start-installed-sheet, termux-setup-switch-runtime-sheet, termux-setup-unchecked-install-sheet, termux-setup-update-sheet;
    - termux-storage-clean-sheet, voice-model-setup-sheet-delete-dialog.
  - **library, servers and settings:**
    - app-diagnostics-clear-sheet, command-auth-sheet-confirm-sheet, console-organization-switch-dialog, credential-management-sheet-remove-sheet, development-services-confirm-sheet;
    - external-agent-detail-delete-sheet, external-agents-delete-sheet, external-link-dialog, external-task-cancel-sheet, external-task-forget-sheet;
    - integrations-disconnect-provider-sheet, integrations-forget-pending-auth-sheet, integrations-forget-uncertain-auth-sheet, integrations-remove-mcp-sheet;
    - plugins-clear-mappings-sheet, privacy-settings-clear-drafts-sheet, privacy-settings-clear-queued-sheet, profile-editor-discard-sheet, profile-monitor-switch-server-dialog;
    - provider-quota-clear-dialog, provider-quota-enroll-dialog, saved-permissions-revoke-dialog, server-settings-upgrade-sheet, servers-remove-server-sheet, settings-disconnect-sheet, usage-budget-clear-dialog.
  - **work and projects:**
    - confirm-sheet, form-sheet-dismiss-confirm-sheet, global-sessions-continue-here-sheet, legacy-drafts-delete-sheet, managed-workspaces-remove-dialog, permission-sheet-always-dialog;
    - project-health-git-init-dialog, question-sheet-dismiss-dialog, session-destination-confirm-dialog, shell-output-stop-dialog, terminal-remove-sheet;
    - workspace-archive-session-sheet, workspace-delete-session-sheet, workspace-share-session-sheet, worktrees-remove-dialog, worktrees-reset-dialog.

  Some of these pages leave the confirmation for Undo or for no question at all (K2 §4.1, DATA-11). The screen unit decides that from the table; this part is where the remaining ones land.
- **Code it is the destination for** (G1 baseline, outside the kit):
  - `showConfirmSheet(`: 70 uses in 37 files. `lib/ui/widgets/confirm_sheet.dart` already forwards to `showKitConfirm`, and the wrapper is deleted by the unit that brings its count to zero (KIT-38);
  - the confirming share of `AlertDialog(`: 30 uses in 22 files;
  - `showKitConfirm(` itself is already called at 17 sites in 15 files.
- **Merged gap names:** `KitConfirmSheet`, `KitDiscardGuard`.
- **Retired inside the kit by this change:**
  - the private `_KitDetailsFold` (`kit_confirm_sheet.dart`, VL branch), which becomes the public `KitDetailsFold`;
  - the private `_KitConsequences`, which becomes `KitConsequences` from kit-KitSheet-v2;
  - the tint-in-a-`Container` mark;
  - the `⁦…⁩` literal around the typed name.

## File

- **Part:** `lib/ui/kit/kit_confirm_sheet.dart` (`part of 'kit_sheet.dart'`), edited by kit-KitDetailsFold.
- **Tests:** `test/kit/kit_confirm_sheet_test.dart`.
- **Gallery:** `test/goldens/kit/kit_confirm_sheet_golden_test.dart`.
- **Ownership.** `build_units.py` assigns a test to the one unit of its concurrency set whose files it imports (R08). In tier 1b only kit-KitDetailsFold writes the `kit_sheet.dart` library's files, so both existing files land in its `tests` list and it regenerates and reviews these goldens (TEST-6). No write-set change is needed; README.md lists the check.

## Public API

This stays as on `feat/visual-language-v1` (K2 §1.2 plus the code's `action`, `working` and `failed`, which stand under KIT-39), with no renames (KIT-43). The one addition is the optional `consequenceItems` (README.md, decision D22): marked facts, so a confirmation can say what is kept as well as what is lost (DATA-8, the approved Confirm.png). It is additive; every existing call compiles and renders as before.

```dart
enum KitConfirmKind {
  neutral,     // cancel "Cancel"; never the error tone
  stop,        // ends running work; cancel "Keep running"
  destructive, // deletes; cancel "Cancel"
  discard;     // drops unsaved input; cancel "Keep editing"
  bool get isDanger => this != KitConfirmKind.neutral;
}

/// True only when the confirm was chosen; back, swipe, Esc, a tap outside,
/// cancel, the alternative and a RequestRoutes close are false.
Future<bool> showKitConfirm(
  BuildContext context, {
  required String title,               // a question naming the thing, ending "?" (COPY-9)
  required String body,                // what happens, whether it can be undone; ≤ 2 sentences
  required String confirmLabel,        // verb + thing: "Delete conversation" (COPY-8)
  KitConfirmKind kind = KitConfirmKind.neutral,
  String? cancelLabel,                 // default by kind
  IconData? icon,                      // default by kind; never "?"
  List<String> consequences = const [],// counted facts (DATA-13)
  List<KitConsequence>? consequenceItems, // NEW (D22): marked facts (lost, kept, info); when given, [consequences] must be empty (assert)
  String? typedName,                   // heavy deletes (DATA-12)
  KitAction? alternative,              // a safer path: "Export first"
  List<KitTechnicalValue> details = const [], // in KitDetailsFold, last, collapsed
  Future<void> Function()? action,     // runs inside the question: working, failure stays open
  RequestRoutes? routes,
  Key? sheetKey,
  Key? confirmKey,
});

/// The question itself, drawn by showKitConfirm; also used alone in goldens.
class KitConfirmSheet extends StatefulWidget {
  const KitConfirmSheet({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.kind = KitConfirmKind.neutral,
    this.cancelLabel,
    this.icon,
    this.consequences = const [],
    this.consequenceItems,  // NEW (D22)
    this.typedName,
    this.alternative,
    this.details = const [],
    this.action,
    this.confirmKey,
    this.working = false,   // goldens: opens working
    this.failed = false,    // goldens: opens failed
  });

  static IconData iconFor(KitConfirmKind kind); // stop · delete · editOff · info
  static String cancelFor(BuildContext context, KitConfirmKind kind);
}
```

**What changes (look and internals only):**

| # | Today (VL branch) | After | Rule |
|---|---|---|---|
| 1 | Neutral mark tinted with `accent` at `markTintAlpha` | Neutral mark: `_KitIconTile` neutral, a `surface3` tile with the glyph in `text1`. The accent is not a mark colour | LOOK-6, LOOK-23 |
| 2 | Danger kinds tinted with `danger` in a `Container` | Danger kinds: a `danger` tile at `markTintAlpha` with the glyph in `danger`, drawn through the library's private `_KitIconTile` (added by kit-KitSheet-v2), 44 dp, radius 12, as in Confirm.png | LOOK-5, LOOK-23 |
| 3 | `_KitConsequences` (radius 14, literal 20 and `top: 1`) | `KitConsequences`. `consequenceItems` are drawn as given. Plain `consequences` keep today's rule: for a danger kind the first fact is `lost` and the rest `info`; for neutral every fact is `info` | LOOK-25, KIT-9 |
| 4 | `_KitDetailsFold` | `KitDetailsFold(values: details)`, last and collapsed. Its toggle keeps the internal key `kit-details-toggle`, which 4 test references use (TEST-5) | K2 §4.3, KIT-33 |
| 5 | The typed name label built with a `⁦$name⁩` literal, the field at mono 16 | The label is `kitConfirmTypeName(KitBidi.ltr(name))`, and the field text uses `typedName`, mono 13 (§0.5 step 1). It stays a kit-private field (Open questions) | COPY-30, LOOK-12 |
| 6 | Title and body `Text` | `KitText` roles `title` and `body` (text2), which wrap and are never cut | A11Y-8 |
| 7 | Separators `Divider(thickness: 0)` | `hairlineWidth(context)` | LOOK-21 |
| 8 | The failure `KitNotice` | Unchanged call. Its look (the neutral error glyph in `text1`, no red) comes from kit-KitNotice-v2 | LOOK-5 |

- **Unchanged behaviour:**
  - the cancel word by kind;
  - Enter confirms only `neutral`;
  - `KitHaptics.commit` only for danger kinds;
  - the alternative closes the question (false) and then runs;
  - a failed `action` keeps the question open with Try again;
  - raised inside a `KitSheet`, it swaps in place.
- **Internal keys kept (TEST-5):** `kit-confirm-cancel`, `kit-confirm-reason`, `kit-confirm-typed-name`, `kit-confirm-failed` and `kit-details-toggle`.
- **Kit copy:** the existing keys only: `kitConfirmCancel`, `kitConfirmKeepRunning`, `kitConfirmKeepEditing`, `kitConfirmTypeName`, `kitConfirmTypeNameReason`, `kitConfirmFailed`, `kitTryAgain`, `kitDetails`.

## States

The doc comment declares: `neutral`, `stop`, `destructive`, `discard`, `typed-waiting` (disabled with its reason), `typed-ready`, `working`, `failed`, `with-alternative`, `details-open`, `in-place` (inside a sheet).

- **Loading, empty and error of data:** none. A confirmation opens with local words only (STATE-20: local data).
- **Disabled.** Only the confirm, while the typed name does not match. Its reason "Type the name exactly as shown to turn this on." is visible under it (STATE-8, DATA-12).
- **Working.** While `action` runs:
  - the confirm shows `working` and keeps its fill;
  - cancel, the alternative and the field are disabled;
  - back and Esc are ignored (`PopScope`).
- **Failed.** The question stays open with the `KitNotice` "That didn't finish. You can try again." and Try again. It never closes on an error (DATA-14). The error's text is not shown, because it may hold a credential (SEC-2).
- **Answered:** not applicable. The act's receipt is the caller's.

## Tokens

All exist on `feat/visual-language-v1` unless flagged.

- **ThemeRoles:**
  - `surface2`, the sheet and panel;
  - `surface3`, the neutral tile and the cancel button (secondary);
  - `text1`, the title, the neutral glyph and the typed name;
  - `text2`, the body, the reason, and the consequence info and kept glyphs;
  - `danger`, the danger glyph and tile tint;
  - `dangerFill`/`onDangerFill`, the confirm of stop, destructive and discard, through `KitButton.primary(destructive: true)` (LOOK-5);
  - `accent`/`onAccent`, the neutral confirm's fill only (LOOK-6);
  - `hairline`;
  - `scrim`, with no blur;
  - `insetSurface`, the consequences panel.
- **KitText:**
  - `title` (`confirmTitle`);
  - `body` in text2 (`confirmBody`);
  - `secondary` (`note`, the reason);
  - `rowTitle` (consequences);
  - `mono` (`typedName`, `technicalValue`);
  - `button`.
- **KitTokens:**
  - `rail`, `space1`–`space5`;
  - `markSize` (44), `markIconSize` (22), `markRadius` (12), `markTintAlpha`;
  - `iconSize(context, …)` with `maxIconScale` (1.5);
  - `sheetSurface`, `sheetRadius`, `panelRadius`, `panelInset`;
  - `minTarget`, `buttonHeight` (50), `smallIconSize`, `panelCornerRadius`.
- **KitLayout (existing):** `sheetMaxWidth` (640, compact), `confirmMediumWidth` (560), `confirmDialogWidth` (480).
- **Pre-wave seams (flagged):** `KitTokens.hairlineWidth(context)`, `focusRingWidth(context)`, `KitBidi.ltr`.
- **New tokens:** none.

## Adaptive

| Class | Shape | Buttons |
|---|---|---|
| compact | bottom sheet with grabber | stacked full width: confirm on top, the reason under it, cancel under that (Confirm.png) |
| medium | bottom sheet capped at 560 dp | stacked, as compact |
| expanded / large | centred dialog of 480 dp, no grabber | one end-aligned row: cancel, then confirm at the end; the reason under the row |
| short (< 480 tall) | compact | stacked |

- **In place inside a `KitSheet`, on any class:** it takes the sheet's width and replaces the content. Its own back step (Esc or back) returns to the content (KIT-16).
- **The keyboard (G14, LAY-10):**
  - Esc cancels;
  - Enter confirms only `neutral`, and only while focus is on the question itself;
  - a stop, delete or discard needs a click, or Tab to the confirm and Space or Enter on it;
  - Tab order: the typed-name field, confirm, cancel, the alternative, Details.
- **A fine pointer** adds hover highlights only. Targets stay 48 dp.

## Accessibility

- **Focus.** The title is the route name and a header. On open, focus sits on the question. Neither the tile nor the consequence glyphs are in semantics.
- **The typed-name field** is labelled "Type {name} to confirm", with the name isolated LTR. The confirm's disabled reason is visible text and its semantic hint.
- **Targets:** buttons are 50 dp tall, 48 dp minimum. There are 12 dp (`space3`) between the confirm and cancel, above LAY-9's 8 dp around a destructive target.
- **Announcements:** the failure notice is one live region, announced once. Working is exposed as the confirm's busy semantics.
- **200 % text:**
  - the title wraps without an ellipsis;
  - both buttons wrap to two lines;
  - the body scrolls inside the sheet, and the answers stay reachable.

## RTL

- The tile, title, body and consequences sit at the start. The expanded row mirrors, with the confirm at the end.
- The typed name and every details value are LTR-isolated: `KitBidi.ltr` in the label, an LTR field, and `KitDetailsFold` values. A branch or path inside Arabic never reorders.
- Glyphs are not mirrored (stop, delete, edit-off and info are not directional).

## Motion and haptics

- **Standalone:** it opens and closes like a `KitSheet` (a slide on `standard`, or a cross-fade for the dialog; no scale).
- **In place:** the swap is the sheet host's `KitReveal` (kit_sheet.dart, kit-KitSheet-v2).
- **The failure notice** enters with `KitEntrance`. Under `KitMotion.reduced` everything is instant, and one `pump()` settles.
- **Haptics:** `KitHaptics.commit` exactly once when a `stop`, `destructive` or `discard` confirm is chosen. Nothing for `neutral`, nothing with Vibration off, and nothing on cancel or the alternative (MOT-11).

## Data safety and honest state

- **False on every dismissal.** Only the confirm answers true. The alternative answers false, then runs.
- **Consequences** list everything else the act removes, with counts (DATA-13): the "3 queued prompts" of servers-remove-server-sheet.
- **The typed name** enables the confirm only on an exact match (DATA-12).
- **The error tone** is used only for stop, destructive and discard. Restart, cancelling a pending send, withdrawing to draft and a removal that can be redone use `neutral`, which paints no `dangerFill` and no danger glyph (LOOK-5). The kind is the caller's; the part guarantees neutral never paints red.
- **Honest state:** the body says whether the act can be undone (COPY-9). The question never closes on an error (DATA-14).
- **`routes`:** when the request it guards is answered elsewhere, the question closes and returns false. It returns false at once if the request is already answered.
- **Never both confirmed and undoable** (DATA-11). That is the caller's treatment choice. This part offers no Undo.

## Depends on

- **kit-KitSheet-v2:** the same library: the frame, `_presentKitModal`, `_KitSheetScope`, the in-place swap, `KitConsequences` and the icon-tile look.
  - **Edge added** (README.md): `kit-KitDetailsFold.after += ['kit-KitSheet-v2']`. Sheet-v2 is tier 1a and DetailsFold 1b, so no tier moves, and the two units never edit one library at the same time.
- **kit-KitDetailsFold:** the same unit (`KitDetailsFold`, `KitTechnicalValue`).
- **Existing:** `KitButton`/`KitAction`/`KitInset`, `KitNotice`, `KitHaptics`, `KitEntrance`, `KitLayout`, `RequestRoutes`, VL tokens.
- **Pre-wave:** `KitBidi`, `hairlineWidth`, `focusRingWidth`.
- **Look only, no code edge:** kit-KitNotice-v2 (the failure notice's look) and kit-KitAction-v2 (the reason-line style).

## Tests required

The existing tests in `test/kit/kit_confirm_sheet_test.dart` and the `showKitConfirm` group in `test/kit/kit_keyboard_test.dart` keep passing unchanged:

- false on cancel, back, swipe and a tap outside;
- true on confirm;
- the cancel word by kind;
- the error tone only for danger kinds, never "?";
- the typed name exact match;
- the commit haptic per kind, never with Vibration off (also through `showConfirmSheet`);
- no route added from a KitSheet, and from a pinned action;
- a failed act stays open with Try again;
- the alternative closes and runs;
- details fold open, LTR;
- adapts to the window;
- `showConfirmSheet` maps onto the kit;
- Esc cancels, Enter confirms neutral, and Enter does not confirm danger kinds.

Added:

1. **LOOK-5/LOOK-6 (G9x):**
   - `neutral` paints no `dangerFill`, no `danger` glyph and no `accent` in the tile (the tile is `surface3`);
   - `stop`, `destructive` and `discard` paint `dangerFill` on the confirm and the danger tint on the tile.
2. **Consequences:**
   - for `destructive`, the first fact carries the danger glyph and the others the info glyph;
   - for `neutral`, every fact carries the info glyph;
   - separators are `1/devicePixelRatio`;
   - `consequenceItems` with a `kept` fact draws the kept mark and its words ("2 edited files are kept"), and passing both `consequences` and `consequenceItems` asserts (D22).
3. **Details through the public part:**
   - collapsed at first;
   - `kit-details-toggle` opens it;
   - a repeated value is shown once;
   - values are LTR and selectable;
   - a value the redactor matches is refused (the KitDetailsFold contract, reached through `details:`).
4. **Typed name:** the rendered label contains the name wrapped by `KitBidi.ltr`, and a source scan finds no U+2066–U+2069 literal in `kit_confirm_sheet.dart` (COPY-30).
5. **200 %:** at `textScaler` 2.0 the title is not truncated, both buttons are fully visible, and there is no overflow at 320, 360 and 412 wide.
6. **`routes`:** flipping `isPending` while the question is open closes it, and the result is false.
7. **Reduced motion (G8):** the failed state and the in-place swap settle after one `pump()`.

## Galleries required

`test/goldens/kit/kit_confirm_sheet_golden_test.dart`, DPR 3.0, Android, VL fonts. Names per TEST-20 (the size is left out for 412×915; the existing `kit_confirm_destructive_412x915_*` PNGs are renamed in the same commit).

- **Every declared state × dark and light at 412×915:**
  - neutral;
  - stop-working;
  - destructive (with consequences, as Confirm.png);
  - discard;
  - typed-waiting;
  - typed-ready;
  - failed;
  - with-alternative;
  - details-open;
  - in-place (over a sheet's content).
- **destructive × dark and light** at 360×800, 915×412, 800×1280, 1280×800 (the 480 dialog) and 1600×1000.
- **Text 2.0 and Arabic** (destructive), each at 412×915 and 1280×800, dark and light.

That is 38 PNGs.

## Non-goals

- No new parameter on `showKitConfirm` or `KitConfirmSheet`, and no call site outside the kit changes.
- The wrapper `lib/ui/widgets/confirm_sheet.dart` stays in shared-shell-1 until its callers reach zero (KIT-38, C40).
- No choice of kind for any screen. Whether an act is confirmed, undone or neither is decided at the call site by DATA-11.
- No Undo, no receipt, and no snackbar from the confirmation.
- The sheet frame (KitSheet.md) and the details fold itself (the KitDetailsFold API freeze) are specified elsewhere.

## Open questions

None. Both scope questions are settled in the cross-check (README.md, decision D22):

1. **Kept facts.** kit-KitDetailsFold adds the optional `consequenceItems: List<KitConsequence>?` (above), using kit-KitSheet-v2's `KitConsequence` and `KitConsequenceMark` (an existing edge). Plain `consequences` keep the lost-then-info rule.
2. **The typed-name field.** Wave 1 keeps a kit-private field (visible label, LTR, no suggestions, autocorrect off). The edge to kit-KitField is not added, because it would move kit-KitDetailsFold and everything after it one tier. kit-hygiene (2d) swaps it to `KitField(kind: mono)`.
