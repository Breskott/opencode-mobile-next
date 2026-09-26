// KitDialog (docs/ux-system/kit-api/KitDialog.md; kit-v2.md §1.3, §4.6,
// §8.2): the two jobs a dialog still has. One short text entry
// ([showKitInputDialog]) and a blocking alert with at most one action
// ([showKitAlert]). There is no general-purpose dialog and no public widget:
// the frames below are private and open only through the two functions.
//
// Declared states: `input-default`, `input-invalid` (the primary disabled
// with its reason), `input-error` (a submit error under the field),
// `input-working`, `input-discard` (the discard question in place),
// `alert`, `alert-with-action`, `alert-with-details`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'kit_buttons.dart';
import 'kit_field.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_sheet.dart';
import 'kit_technical_value.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';
import 'motion/kit_reveal.dart';

/// One short text entry: a rename, a folder name, a code, a budget.
/// Returns the submitted text, or null on cancel, back, Esc or a tap
/// outside. The field is a [KitField] of [kind].
///
/// - [label] is the field's visible label (never placeholder-only); [hint]
///   is an example; [helper] wraps and is never cut.
/// - [confirmLabel] is a verb naming the act ("Rename", COPY-8).
/// - [initial] is prefilled and selected on open (never with
///   [KitFieldKind.secret], which is never prefilled).
/// - [validate] returns null when the text is valid, the reason otherwise.
///   Before the first edit the reason sits under the disabled primary;
///   after it, under the field; never in both places.
/// - [onSubmit] runs with the text: the primary shows it is working, the
///   field and Cancel are disabled, and Esc, back and a tap outside are
///   ignored. A non-null result is an error shown under the field; the text
///   is kept and the dialog stays open. The dialog returns the text only
///   after [onSubmit] returns null.
/// - [alternative] ("Remove budget") sits on its own line; a destructive
///   one stacks the actions on every window. Choosing it closes the dialog
///   (null) and runs it.
/// - [draft] keeps the text across dismissal and a process kill: back, Esc
///   and Cancel close silently and reopening restores it. The caller clears
///   it once the text is used. Without a draft, changed text makes a tap
///   outside do nothing and back or Esc ask the discard question inside
///   the dialog ("Keep editing" is the default); an explicit Cancel closes.
///
/// Compact: the window width minus the gutters, the actions stacked full
/// width (primary, alternative, Cancel). From medium: at most
/// [KitLayout.confirmDialogWidth] wide, the actions in one end-aligned row.
/// Enter or the IME action submits when valid.
Future<String?> showKitInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String? initial,
  String? hint,
  String? helper,
  KitFieldKind kind = KitFieldKind.text,
  int? maxLength,
  String? Function(String value)? validate,
  Future<String?> Function(String value)? onSubmit,
  KitAction? alternative,
  KitDraft? draft,
  String? cancelLabel,
  Key? dialogKey,
  Key? fieldKey,
  Key? confirmKey,
}) async {
  assert(
    kind != KitFieldKind.secret || initial == null,
    'showKitInputDialog: a secret is never prefilled (SEC-3)',
  );
  assert(
    kind != KitFieldKind.secret || draft == null,
    'showKitInputDialog: a secret is never kept in a draft',
  );
  final controller = draft?.controller ?? TextEditingController();
  if (draft != null) {
    await draft.restore();
    if (!context.mounted) return null;
  }
  if (controller.text.isEmpty && initial != null) controller.text = initial;
  if (kind != KitFieldKind.secret && controller.text.isNotEmpty) {
    // Selected on open, before the field takes focus, so no selection
    // handles are raised over the helper (a programmatic select after
    // focus shows them).
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }
  final spec = _KitInputSpec(
    title: title,
    label: label,
    confirmLabel: confirmLabel,
    initial: initial ?? '',
    hint: hint,
    helper: helper,
    kind: kind,
    maxLength: maxLength,
    validate: validate,
    onSubmit: onSubmit,
    alternative: alternative,
    draft: draft,
    cancelLabel: cancelLabel,
    fieldKey: fieldKey,
    confirmKey: confirmKey,
  );
  return _presentKitDialog<String>(
    context,
    builder: (dialogContext) => _KitInputDialog(
      key: dialogKey,
      spec: spec,
      controller: controller,
      // The dialog's state disposes a controller it was lent, after the
      // route's exit fade; a draft's controller stays the caller's.
      ownsController: draft == null,
    ),
  );
}

/// A blocking alert with at most one action. Completes when it closes.
/// Esc, back and Close dismiss it; a tap outside does not (it blocks).
///
/// - [title] is at most four fixed words (COPY-10); [body] at most two
///   sentences.
/// - [details] are technical values in one [KitDetailsFold], last and
///   collapsed.
/// - [action] ("Open Files") closes the alert and then runs. Enter never
///   runs it (it may navigate away): Enter and Esc close.
/// - [closeLabel] defaults to "Close"; [icon] shows in an icon tile beside
///   the title.
Future<void> showKitAlert(
  BuildContext context, {
  required String title,
  required String body,
  List<KitTechnicalValue> details = const [],
  KitAction? action,
  String? closeLabel,
  IconData? icon,
  Key? alertKey,
  Key? closeKey,
}) async {
  await _presentKitDialog<void>(
    context,
    builder: (dialogContext) => _KitAlert(
      key: alertKey,
      title: title,
      body: body,
      details: details,
      action: action,
      closeLabel: closeLabel,
      icon: icon,
      closeKey: closeKey,
    ),
  );
}

AppLocalizations _l10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Pushes the one dialog frame: the scrim (no blur, LOOK-22), a centred
/// panel on `surface2` with the VL dialog radius, cross-faded on
/// [KitMotion.standard] with no scale (MOT-2). The route's own barrier never
/// dismisses; the content decides what a tap outside does ([_KitBarrierTap]).
Future<T?> _presentKitDialog<T>(
  BuildContext context, {
  required Widget Function(BuildContext context) builder,
}) {
  final tokens = KitTokens.of(context);
  final reduced = KitMotion.reduced(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: tokens.scrim,
    transitionDuration: reduced ? Duration.zero : KitMotion.standard,
    pageBuilder: (dialogContext, _, _) => _KitDialogFrame(child: builder),
    transitionBuilder: (dialogContext, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: KitMotion.enter,
        reverseCurve: KitMotion.exit.flipped,
      ),
      child: child,
    ),
  );
}

/// Handed to the content so it can say what a tap outside does.
typedef _BarrierHandler = ValueNotifier<VoidCallback?>;

class _KitDialogFrame extends StatefulWidget {
  const _KitDialogFrame({required this.child});

  final Widget Function(BuildContext context) child;

  @override
  State<_KitDialogFrame> createState() => _KitDialogFrameState();
}

class _KitDialogFrameState extends State<_KitDialogFrame> {
  final _BarrierHandler _barrier = _BarrierHandler(null);

  @override
  void dispose() {
    _barrier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final media = MediaQuery.of(context);
    final window = KitLayout.modalWindowOf(context);
    final available = media.size.width - 2 * tokens.gutter;
    final width = window == KitWindow.compact
        ? available
        : available.clamp(0.0, KitLayout.confirmDialogWidth);
    return Stack(
      children: [
        // A tap outside: the content decides (blocks by default).
        PositionedDirectional(
          start: 0,
          end: 0,
          top: 0,
          bottom: 0,
          child: ExcludeSemantics(
            child: GestureDetector(
              key: const ValueKey('kit-dialog-barrier'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _barrier.value?.call(),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.gutter),
                child: SizedBox(
                  width: width.floorToDouble(),
                  child: Material(
                    color: tokens.panelSurface,
                    elevation: tokens.panelElevation,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.panelRadius),
                    ),
                    child: Semantics(
                      scopesRoute: true,
                      explicitChildNodes: true,
                      child: _KitDialogBarrierScope(
                        handler: _barrier,
                        child: Builder(builder: widget.child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KitDialogBarrierScope extends InheritedWidget {
  const _KitDialogBarrierScope({required this.handler, required super.child});

  final _BarrierHandler handler;

  static _BarrierHandler? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_KitDialogBarrierScope>()?.handler;

  @override
  bool updateShouldNotify(_KitDialogBarrierScope old) => false;
}

/// The panel's layout: a scrolling body over pinned actions, on the VL
/// dialog inset, so the field and the actions stay reachable on a short
/// window and at 200 % text.
class _KitDialogLayout extends StatelessWidget {
  const _KitDialogLayout({required this.body, required this.actions});

  final List<Widget> body;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.panelInset,
              tokens.panelInset,
              tokens.panelInset,
              tokens.space4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: body,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            tokens.panelInset,
            0,
            tokens.panelInset,
            tokens.panelInset,
          ),
          child: actions,
        ),
      ],
    );
  }
}

/// The dialog's title: it names the route and wraps, never cut (A11Y-8).
class _KitDialogTitle extends StatelessWidget {
  const _KitDialogTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    namesRoute: true,
    child: KitText(title, role: KitTextRole.title),
  );
}

class _KitInputSpec {
  const _KitInputSpec({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initial,
    required this.kind,
    this.hint,
    this.helper,
    this.maxLength,
    this.validate,
    this.onSubmit,
    this.alternative,
    this.draft,
    this.cancelLabel,
    this.fieldKey,
    this.confirmKey,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initial;
  final String? hint;
  final String? helper;
  final KitFieldKind kind;
  final int? maxLength;
  final String? Function(String value)? validate;
  final Future<String?> Function(String value)? onSubmit;
  final KitAction? alternative;
  final KitDraft? draft;
  final String? cancelLabel;
  final Key? fieldKey;
  final Key? confirmKey;
}

class _KitInputDialog extends StatefulWidget {
  const _KitInputDialog({
    super.key,
    required this.spec,
    required this.controller,
    required this.ownsController,
  });

  final _KitInputSpec spec;
  final TextEditingController controller;
  final bool ownsController;

  @override
  State<_KitInputDialog> createState() => _KitInputDialogState();
}

class _KitInputDialogState extends State<_KitInputDialog> {
  final _focus = FocusNode(debugLabel: 'kit-dialog-field');
  final _keys = FocusNode(debugLabel: 'kit-dialog', skipTraversal: true);
  _BarrierHandler? _barrier;
  late String _lastText = widget.controller.text;
  bool _edited = false;
  bool _working = false;
  bool _discarding = false;
  String? _submitError;

  _KitInputSpec get _spec => widget.spec;

  String get _text => widget.controller.text;

  bool get _dirty => _spec.draft == null && _text != _spec.initial;

  String? get _invalid => _spec.validate?.call(_text);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _barrier = _KitDialogBarrierScope.of(context)?..value = _onBarrierTap;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    if (widget.ownsController) widget.controller.dispose();
    _focus.dispose();
    _keys.dispose();
    super.dispose();
  }

  void _onText() {
    if (_text == _lastText) return;
    _lastText = _text;
    setState(() {
      _edited = true;
      _submitError = null;
    });
  }

  void _close([String? value]) {
    if (!mounted) return;
    _barrier?.value = null;
    Navigator.of(context).pop(value);
  }

  void _onBarrierTap() {
    // Changed text without a draft: a stray tap never loses it (DATA-1).
    if (_working || _discarding || _dirty) return;
    _close();
  }

  /// Back or Esc.
  void _requestClose() {
    if (_working) return;
    if (_discarding) {
      _keepEditing();
      return;
    }
    if (_dirty) {
      _focus.unfocus();
      setState(() => _discarding = true);
      return;
    }
    _close();
  }

  void _keepEditing() {
    setState(() => _discarding = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _submit() async {
    if (_working || _discarding || _invalid != null) return;
    final value = _text;
    final onSubmit = _spec.onSubmit;
    if (onSubmit == null) {
      _close(value);
      return;
    }
    setState(() {
      _working = true;
      _submitError = null;
    });
    String? error;
    try {
      error = await onSubmit(value);
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (!mounted) return;
    if (error != null) {
      setState(() => _submitError = error);
      _focus.requestFocus();
      return;
    }
    _close(value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      // The discard question answers its own Esc (Keep editing).
      if (_discarding) return KeyEventResult.ignored;
      _requestClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n(context);
    return PopScope<Object?>(
      canPop: !_working && !_discarding && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Focus(
        focusNode: _keys,
        // A key handler only: the text inside keeps its own nodes.
        includeSemantics: false,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            KitReveal(child: _discarding ? null : _input(context, l10n)),
            KitReveal(
              child: _discarding
                  ? SingleChildScrollView(
                      child: KitConfirmSheet(
                        key: const ValueKey('kit-dialog-discard'),
                        title: l10n.kitDiscardTitle,
                        body: l10n.kitDiscardBody,
                        confirmLabel: l10n.kitDiscardConfirm,
                        cancelLabel: l10n.kitConfirmKeepEditing,
                        kind: KitConfirmKind.discard,
                        onConfirm: _close,
                        onCancel: _keepEditing,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(BuildContext context, AppLocalizations l10n) {
    final tokens = KitTokens.of(context);
    final spec = _spec;
    final invalid = _invalid;
    // The reason sits under the primary before the first edit, under the
    // field after it; never in both places (KitDialog.md, States).
    final fieldError = _submitError ?? (_edited ? invalid : null);
    final buttonReason = _edited ? null : invalid;
    final working = _working;
    final workingReason = working ? l10n.kitWorking : null;
    void submitted(String _) => unawaited(_submit());
    final Widget field = spec.kind == KitFieldKind.secret
        ? KitField.secret(
            label: spec.label,
            controller: widget.controller,
            hint: spec.hint,
            helper: spec.helper,
            error: fieldError,
            enabled: !working,
            disabledReason: workingReason,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: submitted,
            fieldKey: spec.fieldKey,
          )
        : KitField(
            label: spec.label,
            controller: spec.draft == null ? widget.controller : null,
            draft: spec.draft,
            kind: spec.kind,
            hint: spec.hint,
            helper: spec.helper,
            error: fieldError,
            maxLength: spec.maxLength,
            enabled: !working,
            disabledReason: workingReason,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: submitted,
            fieldKey: spec.fieldKey,
          );
    final alternative = spec.alternative;
    return _KitDialogLayout(
      body: [
        _KitDialogTitle(spec.title),
        SizedBox(height: tokens.space4),
        field,
      ],
      actions: KitActionBlock(
        primary: KitAction(
          key: spec.confirmKey,
          label: spec.confirmLabel,
          working: working,
          onPressed: invalid == null ? () => unawaited(_submit()) : null,
          disabledReason: buttonReason,
        ),
        tertiary: [
          if (alternative != null)
            KitAction(
              key: alternative.key,
              label: alternative.label,
              icon: alternative.icon,
              destructive: alternative.destructive,
              disabledReason: alternative.disabledReason,
              onPressed: alternative.onPressed == null || working
                  ? null
                  : () {
                      _close();
                      alternative.onPressed!();
                    },
            ),
          KitAction(
            key: const ValueKey('kit-dialog-cancel'),
            label: spec.cancelLabel ?? l10n.kitConfirmCancel,
            // An explicit Cancel closes without asking; a draft keeps the
            // text anyway.
            onPressed: working ? null : _close,
          ),
        ],
      ),
    );
  }
}

class _KitAlert extends StatefulWidget {
  const _KitAlert({
    super.key,
    required this.title,
    required this.body,
    required this.details,
    this.action,
    this.closeLabel,
    this.icon,
    this.closeKey,
  });

  final String title;
  final String body;
  final List<KitTechnicalValue> details;
  final KitAction? action;
  final String? closeLabel;
  final IconData? icon;
  final Key? closeKey;

  @override
  State<_KitAlert> createState() => _KitAlertState();
}

class _KitAlertState extends State<_KitAlert> {
  final _focus = FocusNode(debugLabel: 'kit-alert');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Esc and Enter close; Enter never runs the action, which may navigate
    // away (KitDialog.md, Keyboard).
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final l10n = _l10n(context);
    final action = widget.action;
    final icon = widget.icon;
    final close = KitAction(
      key: widget.closeKey ?? const ValueKey('kit-alert-close'),
      label: widget.closeLabel ?? l10n.kitSheetClose,
      onPressed: _close,
    );
    return Focus(
      focusNode: _focus,
      autofocus: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: _KitDialogLayout(
        body: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                _KitDialogIconTile(icon),
                SizedBox(width: tokens.space3),
              ],
              Expanded(child: _KitDialogTitle(widget.title)),
            ],
          ),
          SizedBox(height: tokens.space2),
          KitText(
            widget.body,
            role: KitTextRole.body,
            tone: KitTextTone.secondary,
          ),
          if (widget.details.isNotEmpty) ...[
            SizedBox(height: tokens.space3),
            KitDetailsFold(values: widget.details),
          ],
        ],
        actions: action == null
            ? KitActionBlock(secondary: close)
            : KitActionBlock(
                primary: KitAction(
                  key: action.key,
                  label: action.label,
                  icon: action.icon,
                  disabledReason: action.disabledReason,
                  onPressed: action.onPressed == null
                      ? null
                      : () {
                          _close();
                          action.onPressed!();
                        },
                ),
                secondary: close,
              ),
      ),
    );
  }
}

/// The alert's icon tile beside the title: `surface3`, the VL tile size and
/// radius, the glyph in `text1`.
class _KitDialogIconTile extends StatelessWidget {
  const _KitDialogIconTile(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final glyph = tokens.iconSize(context, tokens.smallIconSize);
    return ExcludeSemantics(
      child: Container(
        width: tokens.iconTileSize,
        height: tokens.iconTileSize,
        decoration: BoxDecoration(
          color: roles.surface3,
          borderRadius: BorderRadius.circular(tokens.iconTileRadius),
        ),
        child: Center(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Icon(icon, size: glyph, color: roles.text1),
          ),
        ),
      ),
    );
  }
}
