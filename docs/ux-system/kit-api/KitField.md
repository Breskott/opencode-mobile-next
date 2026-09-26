# KitField — API freeze (wave 0, 2026-09-26)

Unit: `kit-KitField` (wave 1, tier 1b, kind `kit-part`). Spec: kit-v2.md §1.4, §4.9, §4.10, §8; STANDARDS KIT-20, KIT-21, KIT-40, KIT-43, SEC-3, SEC-12, DATA-1, DATA-2, STATE-5, STATE-8; cut review C12, C23, C25. Where kit-v2.md and STANDARDS.md differ, STANDARDS wins (its §0.2).

## Purpose

The one labelled text input for everything except search: a visible label above the field, a helper or error line under it, a counter only near the limit, and the secret kind that is the only way to type a credential. It also carries the draft and the 8 s "Checking…" escalation, so no screen hand-builds either.

## Replaces

- **Map elements (kit-v2.json `assignment` → `KitField`): 26 elements on 25 pages.** They are add-agent-bearer, development-services-editor-sheet fields, embedded-question-options custom answer, form-sheet fields, integrations-connect-key-dialog key-field, integrations-mcp-oauth-code-dialog code-field, integrations-oauth-inputs-dialog prompt-field, isolated-task-sheet name, local-agent-project-sheet path-field, managed-workspaces-create-dialog branch, mcp-setup fields and mcp-headers, permission-sheet reject-message, phone-setup-ready name-field, project-folder-browser name, prompt-editor field, question-sheet custom answer, review-comment-sheet field, session-note editor, start-run-sheet objective, tailscale-setup address, team-agent-message-sheet field, team-board-add-sheet field, team-conversation composer (through KitComposer), team-host-sheet host-address and voice-composer-sheet draft field.
- **Files (map `file` of those pages) and their G16 baseline counts** (`test/kit_ratchet_baseline.json`):

  | File | TextField | TextFormField |
  |---|---|---|
  | `lib/ui/screens/mcp_setup_screen.dart` | – | 7 |
  | `lib/ui/widgets/form_renderer.dart` | 5 | – |
  | `lib/ui/screens/external_agents_screen.dart` | 4 | – |
  | `lib/ui/screens/development_services_screen.dart` | 3 | – |
  | `lib/ui/screens/team/start_run_sheet.dart` | 3 | – |
  | `lib/ui/screens/library/integration_tiles.dart` | 2 | 1 |
  | `lib/ui/screens/library/integrations_screen.dart` | 2 | – |
  | `lib/ui/widgets/team_host_form.dart` | 2 | – |
  | `lib/ui/screens/chat/permission_sheet.dart`, `chat/prompt_editor.dart`, `isolated_task_sheet.dart`, `managed_workspaces_screen.dart`, `phone_setup/phone_setup_ready_screen.dart`, `review_workspace.dart`, `session_note_screen.dart`, `tailscale_setup_screen.dart`, `widgets/folder_browser.dart`, `widgets/local_agent_onboarding.dart`, `widgets/question_options.dart`, `widgets/team_board_move_sheet.dart` | 1 each | – |
  | `activity_screen.dart`, `chat/team_conversation_view.dart`, `team/agent_screen.dart`, `lib/voice/voice_ui.dart` | 0 in G16 (the field is built another way, or the file is outside the G16 scan) | – |

- **Whole app:** G16 counts `TextField` 79 in 51 files and `TextFormField` 11 in 4 files. KitField takes every one that is not search (KitSearchField takes the 15 search sites) and not the chat composer's own field, which KitComposer builds from KitField.
- **Kit file it absorbs (C23, KIT-40):** `lib/ui/kit/kit_secret_field.dart` moves into this unit's write set. `KitSecretField` keeps its exact constructor and forwards to `KitField.secret` (see Public API). It is marked `/// Retired by kit-KitField: use KitField.secret` (KIT-43: no `@Deprecated`), and the old name is added as a G2 pattern so call sites only shrink. Its one caller is `mcp_setup_screen.dart:670`.
- **Existing tests it must keep green:** `test/kit/kit_secret_field_test.dart`. It finds `TextField` by type, checks `obscureText`, `autocorrect` and `enableSuggestions`, and taps the tooltips "Show value" and "Hide value". The secret kind therefore still builds a framework `TextField` inside, and the wrapper keeps the caller's reveal labels.

## File

`lib/ui/kit/kit_field.dart`. It holds `KitField`, `KitFieldKind` and `KitSecretField`. `lib/ui/kit/kit_secret_field.dart` becomes `export 'kit_field.dart' show KitSecretField;`, so existing imports compile. Tests go in `test/kit/kit_field_test.dart` (plus the existing `kit_secret_field_test.dart`), and galleries in `test/goldens/kit/kit_field_golden_test.dart`.

## Public API

```dart
/// What the field holds. It decides the keyboard, direction, face and
/// input rules; never the look.
enum KitFieldKind {
  text,       // words in the person's language; follows the locale
  multiline,  // grows from 3 to 8 lines, then scrolls; Enter inserts a line
  mono,       // a code, a command, an id: Geist Mono, LTR, no autocorrect
  path,       // a file or folder path: mono, LTR, no autocorrect or suggestions
  url,        // an address: mono, LTR, url keyboard, no autocorrect
  number,     // digits only (decimal with [decimal]); Arabic-Indic digits typed are normalised to ASCII
  secret,     // only through KitField.secret
}

class KitField extends StatefulWidget {
  const KitField({
    super.key,
    required this.label,                  // shown above the field; the semantic label
    this.controller,                      // null: the field owns one (or uses draft.controller)
    this.kind = KitFieldKind.text,
    this.hint,                            // an example only ("my-app"); never instead of the label
    this.helper,                          // ≤ 2 lines, wraps, never cut
    this.error,                           // replaces the helper; a live region
    this.maxLength,                       // the counter appears from 80 % of the limit
    this.maxLines,                        // null: 1, or 3→8 growing for multiline
    this.decimal = false,                 // number kind: allow one decimal separator
    this.draft,                           // required for multiline inside a sheet (G48)
    this.enabled = true,
    this.disabledReason,                  // required when !enabled (G37 assert)
    this.checkingSince,                   // non-null: "Checking…"; escalates after 8 s (KitSince)
    this.onSlow = const [],               // ≤ 2 ways out offered after 8 s ("Skip the check"); asserted
    this.action,                          // one icon action at the end (Browse, Paste); needs icon
    this.validator,                       // for use inside a framework Form; its message shows as [error]
    this.inputFormatters = const [],
    this.onChanged,
    this.onSubmitted,                     // single-line: Enter/IME action; multiline: Ctrl/Cmd+Enter
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
    this.selectAllOnFocus = false,        // KitDialog's "prefilled and selected"
    this.fieldKey,                        // on the inner editable
    this.actionKey,
  }) : assert(enabled || disabledReason != null),
       assert(kind != KitFieldKind.secret, 'use KitField.secret'),
       assert(draft == null || controller == null || identical(controller, draft.controller)),
       assert(action == null || action.icon != null),
       assert(onSlow.length <= 2);

  /// The chat composer's field (KitComposer.md, README.md decision D18):
  /// multiline, [label] is the accessible name but is not drawn (VL §5
  /// shows only the hint), no helper, error or counter line. A G2 pattern
  /// allows `KitField.composer(` only in lib/ui/kit/chat/kit_composer.dart;
  /// it is KIT-20's one exception.
  const KitField.composer({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,                     // Ctrl/Cmd+Enter (and Enter on a fine pointer, the composer's rule)
    this.contentInsertion,                // ContentInsertionConfiguration? IME images
    this.maxLines,                        // the composer's cap in lines
    this.enabled = true,
    this.disabledReason,
    this.fieldKey,
  });

  /// Obscured, with a reveal toggle and a Paste button. Never prefilled:
  /// initState asserts an empty controller. No suggestions, autocorrect
  /// or IME learning (enableIMEPersonalizedLearning: false). LTR and
  /// isolated. The value is excluded from semantics value, diagnostics,
  /// the report service and every copy part. [saved]: a value is stored
  /// already, so the field shows "Saved · Replace" and no input until
  /// the person chooses Replace.
  const KitField.secret({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.saved = false,
    this.onReplace,                       // called when the person chooses Replace
    this.enabled = true,
    this.disabledReason,
    this.checkingSince,
    this.onSlow = const [],
    this.validator,
    this.inputFormatters = const [],
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
    this.fieldKey,
    this.revealKey,
    this.pasteKey,
    this.replaceKey,
  });

  final String label;
  final TextEditingController? controller;
  final KitFieldKind kind;
  final String? hint;
  final String? helper;
  final String? error;
  final int? maxLength;
  final int? maxLines;
  final bool decimal;
  final KitDraft? draft;
  final bool enabled;
  final String? disabledReason;
  final DateTime? checkingSince;
  final List<KitAction> onSlow;       // the same type as KitStateView, KitStatusLine, KitChecklist and KitScanner (README.md, decision D14)
  final KitAction? action;
  final bool saved;
  final VoidCallback? onReplace;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool selectAllOnFocus;
  final ContentInsertionConfiguration? contentInsertion; // KitField.composer only
  final Key? fieldKey, actionKey, revealKey, pasteKey, replaceKey;
}

/// Retired by kit-KitField: use KitField.secret. Same constructor as
/// today; forwards to the secret kind, keeps the caller's reveal labels,
/// and does not assert an empty controller (its one caller, mcp-setup,
/// is fixed by its screen unit).
class KitSecretField extends StatelessWidget {
  const KitSecretField({
    super.key,
    required this.controller,
    required this.label,
    required this.showLabel,
    required this.hideLabel,
    this.hint,
    this.enabled = true,
    this.validator,
    this.inputFormatters = const [],
    this.fieldKey,
    this.revealKey,
  });
  // fields unchanged from today
}
```

- **No styling parameters.** There is no `decoration`, `style`, colour, padding or border. The look comes from `ThemeRoles`, `KitText` and `KitTokens`.
- **Kit copy** (ARB, `kit` prefix, en and ar in the same change): `kitFieldShow` "Show", `kitFieldHide` "Hide", `kitFieldPaste` "Paste", `kitFieldSaved` "Saved", `kitFieldReplace` "Replace", `kitFieldChecking` "Checking…", `kitFieldStillChecking` "Still checking after 8 s", `kitFieldCount` "{count} of {max}" (ICU plural), `kitFieldLimitReached` "Limit reached", `kitFieldErrorLabel` "Error" (the error line's semantic prefix).
- `KitSecretField` forwards `showLabel` and `hideLabel` as the reveal labels. `KitField.secret` itself uses `kitFieldShow` and `kitFieldHide` with the field label appended in semantics ("Show API key").

## States

The doc comment declares: `default`, `focused`, `filled`, `error`, `disabled`, `checking`, `checking-slow`, `counter` (from 80 %), `limit`. The secret kind adds `secret-masked`, `secret-revealed` and `secret-saved`. The multiline kind adds `multiline-draft-restored`.

- **Loading.** None of its own. A field whose value is being fetched is not shown until its host's state view has loaded.
- **Empty.** The label shows and the hint may show an example. There is no placeholder-only label.
- **Error.** Shown under the field as `secondary` text in `text1` with a neutral error glyph (LOOK-5 interim, until owner question B2), and never only at the top of a form. It replaces the helper, folds in with `KitReveal`, and is a live region announced once per new message. `validator` messages from a framework `Form` render the same way.
- **Disabled.** The input text is in `text3`. The reason shows in the helper line in `text2` (STATE-8), never only in a tooltip. Trailing actions are disabled with the same reason.
- **Working / checking.** When `checkingSince` is non-null, the helper line says "Checking…" and the field shows no spinner (KIT-21). After `KitMotion.escalateAfter` (8 s, via `KitSince`) it says "Still checking after 8 s" and shows the `onSlow` actions (at most 2) as tertiary text actions under the field (STATE-5).
- **Answered.** Not applicable.

## Tokens

All of the following exist on `feat/visual-language-v1` unless flagged.

- **ThemeRoles:**
  - `surface1`: the fill;
  - `hairline`: the 1 px border at rest;
  - `accent`: the focus ring, cursor and selection handles (LOOK-6);
  - `text1`: input text, and the error line and error border until B2;
  - `text2`: label, helper and counter;
  - `text3`: hint, disabled text and the hover border.
- **KitText roles:**
  - `label`: the field label above;
  - `body`: input text for text, multiline and number;
  - `mono`: input text for mono, path, url and secret;
  - `secondary`: helper and error;
  - `caption`: the counter, with tabular figures (LOOK-18).
- **KitTokens:**
  - `minTarget` (48);
  - `buttonHeight` (50): the single-line field height, so a field and a button line up;
  - `space1`–`space4`: label gap 8, inner padding 16, helper gap 4;
  - `smallIconSize` (20): error glyph and trailing icons;
  - `maxIconScale`.
- **KitMotion:** `standard` and `enter`/`exit` for the error, helper and counter fold; `quick` for the reveal and paste icon swap.
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.fieldRadius` = 14. The field corner radius, which today is `AppTheme.radiusControl` and has no kit token. KIT-9 and LOOK-19 need a named token. Owner: the coordinator's kit-token seam, not this unit.
  - `KitTokens.hairlineWidth(context)` and `focusRingWidth(context)`: the 1 px and 2 px physical strokes (LOOK-21). A pre-wave seam (STANDARDS §0.5 step 2).
  - `KitMotion.escalateAfter` (8 s): a pre-wave seam (MOT-1). This unit reads it through `KitSince`.

## Adaptive

- **Compact, medium, expanded and large.** The field fills the width of its column. It never sets its own maximum width, because the host (`KitScreen` reading width 720, `KitSheet`, `KitDialog`) caps it. The label always sits above the field in every window class; it never sits beside the field on wide windows.
- **Short windows (< 480 dp tall).** Multiline grows to at most 4 lines before it scrolls, so the pinned actions stay visible with the keyboard open.
- **Fine pointer (§8.3).** Hover shows the text cursor and turns the border `text3`, and trailing icon buttons show their tooltip. Targets stay 48 dp.
- **Keyboard (§8.3):**
  - Tab reaches the field, then its trailing actions (reveal, paste, action) in reading order.
  - The focus ring is always visible when focused from the keyboard.
  - Single-line: Enter calls `onSubmitted`.
  - Multiline: Enter inserts a new line, and Ctrl+Enter (Cmd+Enter on macOS) calls `onSubmitted`.
  - Esc is not consumed by the field, so the enclosing modal gets it and obeys its draft and dirty rules.

## Accessibility

- **Semantics.** The label is the semantic label (`textField: true`), and the helper or error is its hint. A secret never exposes its value in `value` (obscured semantics); it says "API key, obscured".
- **Targets.** The field is at least 48 dp tall. The reveal, paste, clear and action buttons are `KitIconButton`s with labels, 48 dp each, with no overlapping target areas (LAY-9).
- **Announcements.**
  - The error is announced once when it appears or changes.
  - The counter is announced once when it first appears at 80 % and once at the limit, never on every keystroke.
  - "Still checking after 8 s" is announced once.
- **200 % text.** The label, helper and error wrap. The helper is never truncated: this was the critical defect in integrations-mcp-oauth-code-dialog. The field grows in height, and trailing icons scale within `maxIconScale`.
- **Colour.** An error is never shown by colour alone: it has the glyph and the word (STATE-9).

## RTL

- `text`, `multiline` and `number` follow the locale. Number digits keep the typed shape on screen, and the value is normalised to ASCII digits.
- `mono`, `path`, `url` and `secret` are laid out LTR with bidi isolation and aligned to the start of the field (COPY-30, KIT-32).
- The label, helper, error and counter follow the locale.
- The trailing actions sit at the end, and the error glyph at the start of its line.
- Only directional insets are used (G7).

## Motion and haptics

- The error, helper swap and counter unfold with `KitReveal` (`KitMotion.standard`). There is no `AnimatedSize` (the map found one at 240 ms in permission-sheet-reject-message).
- The reveal and paste icons cross-fade on `KitMotion.quick`.
- Under `KitMotion.reduced` everything is instant, and one `pump()` settles (G8).
- Haptics: none (MOT-11).

## Data safety and honest state

- **Drafts (DATA-1, DATA-2, G48).** A `multiline` KitField inside a `showKitSheet` must have a `draft`; the gate G48 checks the call site. With a draft, the field restores the saved text on mount if its controller is empty, and saves on every change through `KitDraft.save` (key `oc.draft.<target>.<profileId>`, DATA-4). The host calls `draft.clear()` once the text is used.
- **Secrets (SEC-3, SEC-12, KIT-40, §4.10).**
  - `KitField.secret` is the only obscured input in the app; `obscureText` never appears outside `lib/ui/kit/`.
  - It is never prefilled: `initState` asserts an empty controller (G9).
  - After a value is stored, the host passes `saved: true`, and the field shows "Saved · Replace", never the value.
  - Suggestions, autocorrect, IME learning and autofill are off.
  - The value never reaches `KitCopy`, `KitDetailsFold`, `KitLogPanel`, `KitCodeBlock`, diagnostics or test output (SEC-2, G12).
  - Paste reads the clipboard once, on the person's tap.
- **Honest state.** A disabled field always shows its reason (STATE-8). Checking never looks like a finished field, and after 8 s it says so and offers a way out (STATE-5). The counter says "Limit reached" rather than silently refusing keystrokes.

## Depends on

- **KitSince** (kit-KitSince, C12): the 8 s escalation.
- **KitIconButton v2** (kit-KitIconButton-v2, C04): the reveal, paste and action buttons. They pass `tooltip:`, as frozen in `KitIconButton.md`, where `label:` is kept only as a forwarding alias.
- **KitAction v2** (kit-KitAction-v2): for `onSlow`, `action`, and the `disabledReason` rules. Edge added (README.md); tier 1a, so no tier change.
- **Existing parts:**
  - `KitDraft` (`kit_sheet.dart`);
  - `KitReveal`;
  - `KitMotion`;
  - `KitText`, `ThemeRoles` and `KitTokens` (VL merge).

## Tests required

In `test/kit/kit_field_test.dart` (G9, TEST-15), with `kit_secret_field_test.dart` kept green:

1. The label is visible above the field and is the semantic label. Tapping the label focuses the field.
2. The counter is absent below 80 % of `maxLength`, appears at 80 %, is announced once, and shows "Limit reached" at the limit. Typing past the limit changes nothing.
3. `error` replaces `helper`, is a live region, and is announced once per new message. A `Form` validator message renders in the same slot.
4. A disabled field without `disabledReason` throws an `AssertionError` (G37). A disabled field shows its reason, ignores input, and its trailing actions are disabled.
5. `checkingSince`: "Checking…" shows with no progress indicator in the field. After 8 s (fake async) it shows "Still checking after 8 s" and the `onSlow` actions, announced once. Three `onSlow` actions assert.
5a. `KitField.composer`: no visible label is drawn, the semantics label is `label`, and there is no helper, error or counter line.
6. The mono, path, url and secret kinds render LTR inside an Arabic locale, and text follows the locale.
7. Number: letters are rejected, "٣٤" becomes "34" in the value, and `decimal` allows one separator.
8. Multiline with a draft:
   - type, dispose, remount: the text is restored;
   - `KitDraft.clear` removes the key;
   - the key is `oc.draft.<target>.<profileId>`;
   - the secure-storage mock is in place when ProfileStore is touched (TEST-4).
9. Multiline Ctrl+Enter calls `onSubmitted`, and Enter inserts a newline. Single-line Enter calls `onSubmitted` once.
10. `KitField.secret`:
    - it asserts an empty controller at mount;
    - it is obscured, with no suggestions, no autocorrect and `enableIMEPersonalizedLearning` false;
    - reveal toggles, and the reveal button is not revealable while disabled;
    - Paste inserts the clipboard text;
    - semantics never contain the value;
    - `saved: true` shows "Saved · Replace" and no editable field, and Replace calls `onReplace` and shows an empty field.
11. The `KitSecretField` wrapper keeps the existing contract: a prefilled controller is allowed, and the caller's show and hide labels are used as tooltips.
12. `selectAllOnFocus` selects the initial text on focus.
13. Esc inside the field is not consumed (the enclosing test modal receives it).
14. Under reduced motion one `pump()` settles (G8).
15. The trailing action is a 48 dp labelled target, and its tooltip equals its label (G14).
16. It is in the G6 overflow matrix: 320–1600 dp and 915×412, text 1.0, 1.3 and 2.0, LTR and RTL, with no exception. The helper is not clipped at 2.0.

## Galleries required

`test/goldens/kit/kit_field_golden_test.dart`, at DPR 3 (TEST-9, TEST-20, 2 × 11 + 18 = 40 PNGs):

- **Every declared state, dark and light, at 412×915.** The states are default, focused, filled with helper, error, disabled with reason, checking, checking-slow, counter at 90 %, secret-masked, secret-saved, and multiline with 5 lines.
- **Default state, dark and light, at the other sizes:** 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **Default state at text 2.0 and in Arabic RTL, dark and light, at 412×915 and 1280×800.** The Arabic scene includes one path-kind field to show LTR isolation.
- Names follow `kit_field_<state>[_ar][_text2][_<W>x<H>]_<dark|light>.png`.

## Non-goals

- No floating label, outlined or underlined variants, or style parameters.
- No search behaviour (KitSearchField) and no composer chrome (KitComposer arranges a multiline KitField).
- No date or time entry (KitDateTimePicker).
- No autocomplete or suggestion list.
- No `Form` replacement: `Form` stays framework plumbing (C21 adds it to the §9.1 allowlist).
- No restoration of the plain `text` kind across a process kill (DATA-1 allows loss on a crash for non-multiline input).
- No migration of call sites; the wave-2 screen units do that.

## Open questions

None. `KitTokens.fieldRadius` (14) is added by the coordinator before wave 1 (`_new-tokens.md`). If it is missing when the unit starts, the unit reads `KitTokens.buttonRadius` (also 14) and records the gap under NOT proven.
