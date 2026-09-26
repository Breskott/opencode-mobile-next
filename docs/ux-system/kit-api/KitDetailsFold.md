# KitDetailsFold and KitTechnicalValue — API freeze (wave 0)

Unit: `kit-KitDetailsFold` (wave 1, tier 1b, kind `kit-part`). Write set (work-units.json): `lib/ui/kit/kit_details_fold.dart` (new), `lib/ui/kit/kit_technical_value.dart` and `lib/ui/kit/kit_confirm_sheet.dart` (C23), plus `test/kit/kit_details_fold_test.dart` and `test/goldens/kit/kit_details_fold_golden_test.dart`. Spec: kit-v2.md §1.8, §4.3, §4.10; C23, C25. Rules: KIT-32, KIT-33, COPY-11, COPY-30, SEC-2, SEC-4, LOOK-16, LAY-8, A11Y-2, A11Y-8, MOT-5, TEST-5, KIT-43.

## Purpose

The one place where technical truth lives on a page or sheet: addresses, paths, ids, branches, raw errors and engine words. It is collapsed by default, sits last, and shows every value once, copyable and isolated left-to-right. `showKitTechnicalDetails` shows a standalone raw error the same way.

## Replaces

- **Map elements (kit-v2.json `assignment` → `KitDetailsFold`): 25 elements on 22 pages.**
  - builtin-server-setup (address-and-checksum);
  - chat-message-error-details-dialog and chat-prompt-error-details-dialog (chat-error-details-dialog, the error dialogs whose text cannot be copied);
  - connection-status-details-sheet (…-error);
  - development-services-confirm-sheet (path-command);
  - embedded-team-technical-value (technical-value);
  - gate-sheet (gate-details, gate-kicker);
  - isolated-task-sheet (…-path);
  - session-import (session-import-preview);
  - skills-preview-sheet (path);
  - team-agent (team-agent-technical), team-agent-details-sheet (agent-details-values);
  - team-host-details-sheet (host-details-values), team-plugin-sheet (team-sheet-details);
  - team-run-details-sheet (run-details-values), team-run-overview-tab (team-run-summary);
  - termux-processes-details-sheet (command-folder, pid-subtitle);
  - voice-composer-sheet and voice-model-setup-sheet (…-technical-details);
  - work-sheet (work-code, work-details);
  - workspace-directory-details-dialog (…-close: a blocking dialog that holds only a path);
  - workspace-session-details-sheet (…-lines).
- **Merged proposal names:** `KitCopyValue`, `KitDetailsFold`, `KitDetailsRow`, `KitTechnicalDetails`.
- **Code this unit changes (C23):**
  - the private `_KitDetailsFold` in `lib/ui/kit/kit_confirm_sheet.dart` (VL branch lines 526–610) is deleted, and `KitConfirmSheet`'s `details` render through the public part with the same toggle key `kit-details-toggle` (used by `test/saved_permissions_screen_test.dart:119`);
  - `lib/ui/kit/kit_technical_value.dart` gains the additive fields below.
- **Code reach, adopted by other units (not this one):**
  - `KitStateView`'s private fold (`kit_state_view.dart:189-248`, labels `e7SetupDetails`/`e7SetupHideDetails`) → kit-KitStateView-v2;
  - `TeamTechnicalValue` (`lib/ui/widgets/team_technical_details.dart:206`, 44 calls in 6 files: work_sheet 13, run_screen 9, agent_screen 7, gate_sheet 6, plugins_screen 4, itself 5) becomes a wrapper over `KitTechnicalValue` in shared-team-2 (C37);
  - `showKitAlert(details:)` (KitDialog.md) and `showKitConfirm(details:)`;
  - the technical `ExpansionTile`s in `team/agent_screen.dart`, `team/gate_sheet.dart` and `team/work_sheet.dart` (3 of the 17 `ExpansionTile`s in G16);
  - technical `SelectableText` (53 uses in 39 files in G16; the largest: `workspace_screen.dart` 4, `tool_card.dart` 3, `development_services_screen.dart`, `termux_processes_screen.dart`, `tools_screen.dart`, `running_work_sheet.dart` 2 each);
  - the chat error-details dialogs (`chat/chat_states.dart`) → `showKitTechnicalDetails` in chat-6 (C38).
- **Widgets retired by this unit directly:** none outside the kit (kit-part finish line: no call site outside the kit changes).

## File

- `lib/ui/kit/kit_details_fold.dart`: `KitDetailsFold`, `showKitTechnicalDetails`.
- `lib/ui/kit/kit_technical_value.dart`: `KitTechnicalValue` (additive). It also adds `export 'kit_details_fold.dart' show KitDetailsFold, showKitTechnicalDetails;`, so `kit_sheet.dart`, whose library holds the `kit_confirm_sheet.dart` part and already imports `kit_technical_value.dart`, sees the public fold without an edit to `kit_sheet.dart` (not in this write set).
- Tests: `test/kit/kit_details_fold_test.dart`. Gallery: `test/goldens/kit/kit_details_fold_golden_test.dart`.

## Public API

```dart
/// One technical value a person may need but never reads first (K2 §1.8,
/// §4.10). Shown last, folded, mono, isolated left to right, copyable.
/// Never a secret (SEC-4): the fold refuses one.
@immutable
class KitTechnicalValue {
  const KitTechnicalValue(
    this.label,
    this.value, {
    this.copyable = true,
    this.key,
    this.spoken,          // NEW. How a screen reader says it: "100.64.0.3, port 4096"
  });

  /// What it is, in the person's words: "Address", "Branch", "Interaction id".
  final String label;

  /// The value exactly as it is. Shown mono, LTR, wrapping anywhere,
  /// selectable. Copied as is (after redaction).
  final String value;
  final bool copyable;

  /// On the value's text (tests find the value by it).
  final Key? key;

  /// Null reads [value].
  final String? spoken;
}

/// The one technical fold (K2 §1.8, §4.3; KIT-33). A 48 dp "Details" row
/// that unfolds, in this order: [notes], [values], [text], [child].
///
/// States: collapsed, open, empty (nothing to show: the part draws nothing).
class KitDetailsFold extends StatefulWidget {
  const KitDetailsFold({
    super.key,
    this.values = const [],   // deduplicated by value: a value shows once
    this.notes = const [],    // plain lines above the values: what to check
    this.text,                // raw technical text (an error, a response): one mono block
    this.child,               // richer technical content: a KitLogPanel
    this.label,               // the toggle's words; null = l10n.kitDetails ("Details")
    this.initiallyExpanded = false,
    this.expanded,            // controlled; null = the fold keeps its own state
    this.onExpansionChanged,
    this.foldKey,             // the toggle; null = ValueKey('kit-details-toggle')
    this.textKey,             // the raw text block (KitStateView passes 'kit-state-details-text')
    this.copyAllKey,
  }) : assert(expanded == null || onExpansionChanged != null);

  final List<KitTechnicalValue> values;
  final List<String> notes;
  final String? text;
  final Widget? child;
  final String? label;
  final bool initiallyExpanded;
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;
  final Key? foldKey, textKey, copyAllKey;

  /// Lines of [text] shown before "Show all {count} lines" unfolds the rest
  /// in place.
  static const int textPreviewLines = 12;

  /// True when there is nothing to fold (no values, notes, text or child):
  /// hosts use it to leave the fold out.
  bool get isEmpty;
}

/// A standalone raw error (a chat error's details, a failed request): a
/// showKitSheet titled [title] with the fold's content already open, the
/// [text] whole (no preview cap), the [values], and "Copy all".
/// Returns when the sheet closes. Replaces every raw-error AlertDialog (§4.3).
Future<void> showKitTechnicalDetails(
  BuildContext context, {
  required String title,        // the failure in words: "Couldn't send"
  required String text,         // raw technical text; redacted before it is shown
  List<KitTechnicalValue> values = const [],
  List<String> notes = const [],
  Key? sheetKey,
});
```

- **Copy controls.** Each copyable value has a trailing `KitIconButton.copy(text: () => KitRedact.text(value.value), tooltip: l10n.kitCopyValue(label))` ("Copy address"). "Copy all" is a tertiary text action (`KitAction.copy`, label `l10n.kitCopyAll`) under the content when there are 2 or more copyable values, or any `text`. It copies `label: value` lines, then the text, all redacted.
- **K2 correction (C25).** K2 §1.8 puts the standalone text "in a KitCodeBlock". KitDetailsFold does not depend on kit-KitCodeBlock (both tier 1b, no edge), so the raw text is the fold's own mono block: `KitText` role `mono`, LTR, selectable, wrapping anywhere, with no syntax colour. A host that has code rather than an error passes a `KitCodeBlock` as `child`.
- **Names (README.md, decision D9).** The controlled-fold parameters are `initiallyExpanded`, `expanded` and `onExpansionChanged`, the same names as `KitExpandRow`, `KitMessage`, `KitToolRow` and `KitWorkLine`.
- **Compatibility (KIT-43).** `KitTechnicalValue(label, value, {copyable, key})` is unchanged; `spoken` is new and optional. `showKitConfirm(details:)`, `showKitAlert(details:)` and `KitStateView(detailValues:)` keep taking `List<KitTechnicalValue>`.
- **Internal keys (TEST-5):** `kit-details-toggle` (default toggle), `kit-details-value-<index>`, `kit-details-copy-<index>`, `kit-details-text` (default text block), `kit-details-copy-all`, `kit-details-show-all`.
- **Kit copy (ARB, `kit` prefix, en + ar):** `kitDetails` (exists, "Details"), `kitDetailsHide` "Hide details", `kitCopyAll` "Copy all", `kitCopyValue` "Copy {label}", `kitDetailsShowAll` "{count, plural, other{Show all {count} lines}}", `kitDetailsValueSpoken` "{label}: {value}".

## States

| State | Look | Notes |
|---|---|---|
| collapsed (default) | a 48 dp tertiary row: `label` in `text2` and a 20 dp chevron-down at the end | the only state most people see |
| open | the chevron turns up; the content block unfolds under the row | label stays "Details"; semantics say expanded (no second label needed; `kitDetailsHide` is the semantic hint for the collapse action) |
| open, long text | the first `textPreviewLines` lines, then "Show all {count} lines" | unfolds in place with `KitReveal` |
| empty | draws nothing (`SizedBox.shrink`) | a fold with nothing inside is never a dead toggle |
| value refused | debug: `AssertionError` naming the label; release: the value shown as `KitRedact.text(value)` | SEC-4 |

Loading, error, disabled, working and answered do not apply: the fold shows only what its host already has. KIT-12 doc comment: "States: collapsed, open, empty".

## Tokens

- **ThemeRoles:** `text2` (toggle words, chevron, value labels, notes), `text1` (values and raw text), `hairline` (1 physical px separators between value rows, inset to the text start).
- **KitText:** `button` weight is not used; the toggle is `secondary` at `text2` (a tertiary row, LOOK-23); value labels `secondary`; values and text `mono`; notes `secondary`.
- **KitTokens (VL branch):** `detailsSurface` and `detailsRadius` (14) for the content block, `space2`/`space3` (padding and gaps), `minTarget` (48, the toggle and copy targets), `smallIconSize` (20, chevron), `note` and `technicalValue` styles.
- **Pre-wave seams (STANDARDS §0.5 step 2):** `KitTokens.hairlineWidth(context)` (LOOK-21), `KitCopy.copy`, `KitBidi.ltr` (COPY-30), `KitRedact` (see Depends on).
- **New token (pre-wave, `_new-tokens.md`):** `KitTokens.detailsLabelColumn` = 160, the label column from expanded up (see Adaptive). Without it the part would need a literal (KIT-9).

## Adaptive

| Window | Behaviour |
|---|---|
| compact | each value is two lines: label, then value; the copy button at the end of the value line |
| medium | the same |
| expanded / large | label and value on one row: label in a `detailsLabelColumn` column, value filling the rest, copy at the end; a value that does not fit wraps inside its column. The fold is capped by its host (`readingWidth`). |

- **Keyboard (LAY-10):** the toggle is focusable with the visible focus ring; Enter and Space toggle it. When open, Tab moves through each copy button, "Show all" and "Copy all" in reading order.
- **Pointer:** hover highlights the toggle row and the copy buttons; the value text is mouse-selectable (`SelectionArea` inside the kit). Right-click on a value adds nothing (no row menu).

## Accessibility

- The toggle is `Semantics(button: true, expanded: expanded, label: label, onTapHint: expanded ? kitDetailsHide : kitDetails)`.
- Each value is one semantic node, "Address: 100.64.0.3, port 4096" (`kitDetailsValueSpoken` with `spoken ?? value`), with the copy button as its own labelled node ("Copy address").
- Opening and closing is not announced (the expanded state is); "Copied" is announced once by `KitCopy`.
- Targets: toggle 48 dp tall across the fold's width; copy buttons 48×48 with 8 dp between neighbours (LAY-9).
- 200 % text: labels, values, notes and text wrap; nothing is truncated or ellipsised (A11Y-8). The chevron does not scale.

## RTL

- The toggle, labels and notes follow the locale: the label at the start, the chevron at the end.
- Values and the raw text are LTR blocks: `Directionality(ltr)` around a mono `KitText`, aligned to the start of their row in both directions (COPY-30, LAY-8), so a path inside Arabic never reorders.
- `spoken` and the semantic value line wrap the value in `KitBidi.ltr`.

## Motion and haptics

- Unfold and fold: `KitReveal` on `KitMotion.standard`, `enter`/`exit`. The chevron is `KitSpin.chevron(expanded: expanded)` (KitMotionParts; `standard` with `emphasized`, a transform, MOT-5; README.md, decision D10).
- "Show all" unfolds with `KitReveal`, never `AnimatedSize`.
- Under `KitMotion.reduced(context)` both are instant and settle after one `pump()` (MOT-7).
- Haptics: none (MOT-11).

## Data safety and honest state

- **Secrets (SEC-2, SEC-4).** Every `value.value`, `notes` line and `text` passes through `KitRedact.text` before it is shown or copied. In debug a `KitTechnicalValue` whose value `KitRedact.containsSecret` matches fails an assert naming the label; the raw text is masked, not refused, because error bodies may quote headers.
- **One of each (KIT-33).** A value appears once (deduplicated by value; the first label wins). The host puts the fold last; kit-KitScreen-v2's debug walk asserts at most one fold per screen and that it is last (KitScreen.md rule 7).
- **Engine words** (convoy, formula, PTY, SSE, `127.0.0.1`) may appear only inside the fold, `KitLogPanel`, `KitCodeBlock` or `KitTechnicalValue` (COPY-11). The glossary gate relies on this.
- **Copy all** copies exactly what the fold shows (redacted), never more.

## Depends on

- **kit-KitIconButton-v2** (tier 1a): `KitIconButton.copy` per value (C25).
- **Edges added** (README.md), all tier 1a so this unit stays in tier 1b: kit-KitAction-v2 (the "Copy all" text action, `KitAction.copy`), kit-KitSheet-v2 (the confirm part's `KitConsequences` and `_KitIconTile`, KitConfirmSheet.md) and kit-KitMotionParts (`KitSpin.chevron`).
- **Pre-wave seams:** `KitCopy.copy` (KIT-23), `KitBidi` (COPY-30), `KitTokens.hairlineWidth`, `KitMotion` (VL), and **`KitRedact`**: `lib/ui/kit/kit_redact.dart` with `static String text(String)` and `static bool containsSecret(String)`. `KitCopy` already has to redact (KitAction.md, KitIconButton.md), so the redactor is a pre-wave seam that the coordinator adds with `KitCopy`; this unit does not build it. Its patterns are display-safe: provider keys (`sk-…`, `sk-ant-…`, `sk-proj-…`, `AIza…`, `ghp_`/`gho_`/`ghs_`/`github_pat_`, `xox?-`), `Bearer` tokens, `Authorization`/`Proxy-Authorization` header values, `api_key|token|secret|password=` pairs, URL user-info and JWTs. It must **not** use `AppDiagnostics.sanitize`'s generic "32+ characters" rule, which would mask file paths and commit SHAs, the values this fold exists to show. This answers KitNotice.md's open question: `KitReportHook.redact` and this fold call the same `KitRedact.text`.
- **Existing kit parts:** `KitReveal`, `KitButton`, `showKitSheet` (for `showKitTechnicalDetails`), `KitText`, `KitTokens`.
- **Depended on by:** kit-KitStateView-v2 (details slot), kit-KitDialog (`showKitAlert` details), kit-KitLogPanel (`KitLogPanel.fold`), kit-KitScreen-v2 (debug last-fold check), `KitConfirmSheet` (this unit), and in wave 2 shared-team-2, shared-shell-1, screen-chat-1, screen-phone-1, screen-system-1, screen-voice-1.

## Tests required

In `test/kit/kit_details_fold_test.dart`:

1. Collapsed by default: values, notes and text are absent. Tapping `kit-details-toggle` shows them; tapping again hides them. `initiallyExpanded: true` starts open.
2. Controlled mode: with `expanded: false` a tap calls `onExpansionChanged(true)` once and does not open until the host rebuilds with `expanded: true`.
3. Deduplication: two values with the same `value` render once, with the first label.
4. Copy: the copy button of "Address" writes exactly the value to the clipboard through `KitCopy`, announces "Copied" once, and shows no `SnackBar`. "Copy all" appears with 2+ values or any text, and copies `label: value` lines plus the text.
5. Redaction (G12): a `text` containing `sk-ant-FAKE…` and `Authorization: Bearer FAKE…` renders and copies without either token. A value that is a fake key trips the debug assert.
6. Paths survive redaction: `/home/user/project/lib/some_long_file_name.dart` and a 40-character commit SHA render unchanged.
7. Long text: 30 lines show 12 plus "Show all 30 lines"; tapping it shows all 30 in place.
8. Semantics: the toggle has `expanded` false then true; a value node reads "Address: 100.64.0.3, port 4096" when `spoken` is given; each copy button is labelled "Copy address".
9. RTL: under `TextDirection.rtl` the value text's `Directionality` is LTR and its start edge aligns with the label's start edge.
10. Empty: a fold with nothing to show renders no toggle (`isEmpty` true).
11. Reduced motion (G8): under `disableAnimations` and under Effects motion Off, a toggle settles after one `pump()` with no running ticker.
12. `showKitTechnicalDetails`: opens a sheet titled `title` with the whole text (no preview cap) and "Copy all"; back and Close return; the future completes.
13. `KitConfirmSheet` regression: `showKitConfirm(details: [...])` still shows the values behind `kit-details-toggle` (the existing `saved_permissions_screen_test.dart` case keeps passing unchanged).
14. Overflow (G6): open, with a 200-character path, at 320 and 412 dp wide × text 1.0/1.3/2.0 × LTR/RTL: no overflow exception.

## Galleries required

`test/goldens/kit/kit_details_fold_golden_test.dart`, DPR 3.0, `TargetPlatform.android`, on a `surface1` panel and inside a sheet body (`surface2`), names per TEST-20 (`kit_details_fold_<state>[_ar][_text2][_<W>x<H>]_<dark|light>.png`).

- **Each state at 412×915, dark and light:** `collapsed`, `open_values` (4 values, one long path, one note), `open_text` (a 30-line raw error, preview cap), `open_child` (a placeholder log child), `technical_details_sheet` (`showKitTechnicalDetails`). 5 × 2 = 10 PNGs.
- **`open_values` at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000, dark and light:** 10 PNGs (the 1280 and 1600 shots show the label column).
- **`open_values` at text 2.0 and in Arabic RTL, at 412×915 and 1280×800, dark and light:** 8 PNGs. The Arabic shots use a Latin path to prove LTR isolation.
- **Total:** 28 PNGs.

## Non-goals

- No syntax colour and no code block inside the fold (a host passes `KitCodeBlock` as `child`).
- No redactor implementation (pre-wave seam).
- No screen adoption; `TeamTechnicalValue`, `KitStateView` and the chat dialogs move in their own units.
- No row menu, editing or sharing of values.
- No persistence of the open state across visits.

## Open questions

None. `KitRedact` (display-safe patterns, above) is a pre-wave seam listed in `_new-tokens.md`, added with `KitCopy`. If it is absent when this unit starts, the unit is blocked by PROC-32 (kind `dependency`); it must not build its own.
