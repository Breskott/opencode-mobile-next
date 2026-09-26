part of 'kit_sheet.dart';

/// What a confirmation asks about (§1.2, §4.2). It sets the tone, the
/// default icon and the cancel word.
enum KitConfirmKind {
  /// Accent: sharing, a harmless start that still needs a yes ("Share
  /// conversation?" says who can see it). Cancel: "Cancel".
  neutral,

  /// Error tone: ends running work. Cancel: "Keep running".
  stop,

  /// Error tone: deletes. Cancel: "Cancel".
  destructive,

  /// Error tone: drops unsaved input. Cancel: "Keep editing".
  discard;

  /// Loses data or ends running work: error-filled confirm, commit haptic.
  bool get isDanger => this != KitConfirmKind.neutral;
}

/// Asks before an act that cannot be undone (§1.2; use Undo for anything
/// reversible, and nothing for harmless acts, §4.1). True only when the
/// confirm action was chosen; back, swipe, Esc, a tap outside and cancel
/// are false.
///
/// - [title] is a question naming the thing ("Stop fox?"); [body] says
///   what happens and whether it can be undone, in at most two sentences.
/// - [confirmLabel] is a verb naming the act ("Delete conversation"),
///   never OK or Yes. [cancelLabel] defaults by [kind].
/// - [consequences] are counted facts that go with the act ("3 queued
///   prompts will be deleted"), each an attention line.
/// - [typedName] (heavy deletes): the confirm stays disabled, with its
///   reason shown, until this exact name is typed.
/// - [alternative] is a safer path ("Export first"); choosing it closes
///   the question (false) and runs it.
/// - [details] are technical values, folded under Details, left to right.
/// - [action], when given, runs inside the question: the confirm shows it
///   is working, and a failure keeps the question open with a notice and
///   Try again, so it never closes on an error.
///
/// Raised from inside a [showKitSheet] (its body, or a pinned action), it
/// replaces that sheet's content in place and adds no route (§4.7).
/// Otherwise it adapts to the window (§8.2): a bottom sheet on a compact
/// window, capped at 560 dp on a medium one, a centred 480 dp dialog on an
/// expanded or large one. Esc cancels; Enter confirms only a [neutral]
/// question — a stop, delete or discard needs a click, or Tab to the
/// button.
///
/// A stop, delete or discard plays [KitHaptics.commit] when confirmed.
Future<bool> showKitConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  KitConfirmKind kind = KitConfirmKind.neutral,
  String? cancelLabel,
  IconData? icon,
  List<String> consequences = const [],
  String? typedName,
  KitAction? alternative,
  List<KitTechnicalValue> details = const [],
  Future<void> Function()? action,
  RequestRoutes? routes,
  Key? sheetKey,
  Key? confirmKey,
}) async {
  if (routes?.isPending == false) return false;
  final spec = _KitConfirmSpec(
    title: title,
    body: body,
    confirmLabel: confirmLabel,
    kind: kind,
    cancelLabel: cancelLabel,
    icon: icon,
    consequences: consequences,
    typedName: typedName,
    alternative: alternative,
    details: details,
    action: action,
    sheetKey: sheetKey,
    confirmKey: confirmKey,
  );
  final host = _KitSheetScope.maybeOf(context);
  if (host != null && host.mounted) return host.ask(spec);
  final window = KitLayout.modalWindowOf(context);
  final shape = window.isWide ? _KitModalShape.panel : _KitModalShape.bottom;
  final result = await _presentKitModal<bool>(
    context,
    shape: shape,
    maxWidth: switch (window) {
      KitWindow.compact => KitLayout.sheetMaxWidth,
      KitWindow.medium => KitLayout.confirmMediumWidth,
      _ => KitLayout.confirmDialogWidth,
    },
    dismissible: true,
    enableDrag: true,
    builder: (sheetContext) {
      routes?.own(ModalRoute.of(sheetContext));
      void close(bool value) => Navigator.of(sheetContext).pop(value);
      final question = _KitConfirmBody(
        spec: spec,
        onConfirm: () => close(true),
        onCancel: () => close(false),
      );
      if (shape != _KitModalShape.bottom) {
        // A panel has no handle above the icon: the same air instead.
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12),
          child: question,
        );
      }
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KitHandle(
                  onDismiss: () =>
                      unawaited(Navigator.of(sheetContext).maybePop()),
                ),
                question,
              ],
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}

class _KitConfirmSpec {
  const _KitConfirmSpec({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.kind,
    this.cancelLabel,
    this.icon,
    this.consequences = const [],
    this.typedName,
    this.alternative,
    this.details = const [],
    this.action,
    this.sheetKey,
    this.confirmKey,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final KitConfirmKind kind;
  final String? cancelLabel;
  final IconData? icon;
  final List<String> consequences;
  final String? typedName;
  final KitAction? alternative;
  final List<KitTechnicalValue> details;
  final Future<void> Function()? action;
  final Key? sheetKey;
  final Key? confirmKey;
}

class _KitConfirmBody extends StatelessWidget {
  const _KitConfirmBody({
    required this.spec,
    required this.onConfirm,
    required this.onCancel,
  });

  final _KitConfirmSpec spec;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => KitConfirmSheet(
    key: spec.sheetKey,
    title: spec.title,
    body: spec.body,
    confirmLabel: spec.confirmLabel,
    kind: spec.kind,
    cancelLabel: spec.cancelLabel,
    icon: spec.icon,
    consequences: spec.consequences,
    typedName: spec.typedName,
    alternative: spec.alternative,
    details: spec.details,
    action: spec.action,
    confirmKey: spec.confirmKey,
    onConfirm: onConfirm,
    onCancel: onCancel,
  );
}

/// The confirmation itself (§1.2), drawn by [showKitConfirm]; also used on
/// its own for goldens. Start-aligned on the rails: the icon in a tonal
/// circle, the title, the body, the consequences, the typed name, then the
/// confirm with the cancel under it (full width), the alternative on a
/// line of its own, and Details last.
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
    this.typedName,
    this.alternative,
    this.details = const [],
    this.action,
    this.confirmKey,
    this.working = false,
    this.failed = false,
  });

  final String title;
  final String body;
  final String confirmLabel;

  /// Called once the act is confirmed (and [action], if any, finished).
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final KitConfirmKind kind;
  final String? cancelLabel;
  final IconData? icon;
  final List<String> consequences;
  final String? typedName;
  final KitAction? alternative;
  final List<KitTechnicalValue> details;
  final Future<void> Function()? action;
  final Key? confirmKey;

  /// Opens already working, or already failed (goldens).
  final bool working;
  final bool failed;

  static IconData iconFor(KitConfirmKind kind) => switch (kind) {
    KitConfirmKind.stop => AppIconography.stop,
    KitConfirmKind.destructive => AppIconography.delete,
    KitConfirmKind.discard => AppIconography.editOff,
    KitConfirmKind.neutral => AppIconography.info,
  };

  static String cancelFor(BuildContext context, KitConfirmKind kind) {
    final l10n = _l10n(context);
    return switch (kind) {
      KitConfirmKind.stop => l10n.kitConfirmKeepRunning,
      KitConfirmKind.discard => l10n.kitConfirmKeepEditing,
      _ => l10n.kitConfirmCancel,
    };
  }

  @override
  State<KitConfirmSheet> createState() => _KitConfirmSheetState();
}

class _KitConfirmSheetState extends State<KitConfirmSheet> {
  final _focus = FocusNode(debugLabel: 'kit-confirm');
  TextEditingController? _typed;
  late bool _working = widget.working;
  late bool _failed = widget.failed;

  @override
  void initState() {
    super.initState();
    if (widget.typedName != null) {
      _typed = TextEditingController()..addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _typed?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  bool get _nameMatches =>
      widget.typedName == null || _typed?.text == widget.typedName;

  bool get _enabled => _nameMatches && !_working;

  Future<void> _confirm() async {
    if (!_enabled) return;
    if (widget.kind.isDanger) KitHaptics.commit(context);
    final action = widget.action;
    if (action == null) {
      widget.onConfirm();
      return;
    }
    setState(() {
      _working = true;
      _failed = false;
    });
    try {
      await action();
    } catch (_) {
      // The error's text may carry a server's words or a credential; the
      // notice says only that it did not finish.
      if (mounted) {
        setState(() {
          _working = false;
          _failed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _working = false);
    widget.onConfirm();
  }

  void _cancel() {
    if (_working) return;
    widget.onCancel();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    // Enter confirms only a neutral question, and only while nothing else
    // (a focused button, the typed name) has taken the key (§8.2).
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        widget.kind == KitConfirmKind.neutral &&
        FocusManager.instance.primaryFocus == _focus) {
      unawaited(_confirm());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = _l10n(context);
    final danger = widget.kind.isDanger;
    final tint = danger ? theme.colorScheme.error : theme.colorScheme.primary;
    final muted = AppTheme.mutedOf(theme);
    final typedName = widget.typedName;
    final alternative = widget.alternative;
    return PopScope<Object?>(
      canPop: !_working,
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon ?? KitConfirmSheet.iconFor(widget.kind),
                    size: 24,
                    color: tint,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                namesRoute: true,
                child: Text(widget.title, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 6),
              Text(
                widget.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.4,
                ),
              ),
              for (final consequence in widget.consequences) ...[
                const SizedBox(height: 8),
                KitNotice(
                  message: consequence,
                  tone: AppStatusTone.attention,
                  liveRegion: false,
                ),
              ],
              if (typedName != null) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('kit-confirm-typed-name'),
                  controller: _typed,
                  enabled: !_working,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: AppTheme.monoFamily,
                  ),
                  decoration: InputDecoration(
                    // The name is isolated left to right inside the
                    // sentence, so a branch or path never reorders.
                    labelText: l10n.kitConfirmTypeName(
                      '\u2066$typedName\u2069',
                    ),
                  ),
                  onSubmitted: (_) => unawaited(_confirm()),
                ),
              ],
              if (_failed) ...[
                const SizedBox(height: 12),
                KitNotice(
                  key: const ValueKey('kit-confirm-failed'),
                  message: l10n.kitConfirmFailed,
                  tone: AppStatusTone.failure,
                  actions: [
                    KitAction(
                      label: l10n.kitTryAgain,
                      onPressed: () => unawaited(_confirm()),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              KitButton.primary(
                key: widget.confirmKey,
                label: widget.confirmLabel,
                destructive: danger,
                working: _working,
                // Keeps its fill while working; a second tap is ignored.
                onPressed: _nameMatches ? () => unawaited(_confirm()) : null,
              ),
              if (!_nameMatches) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.kitConfirmTypeNameReason,
                  key: const ValueKey('kit-confirm-reason'),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
              const SizedBox(height: 8),
              KitButton.secondary(
                key: const ValueKey('kit-confirm-cancel'),
                label:
                    widget.cancelLabel ??
                    KitConfirmSheet.cancelFor(context, widget.kind),
                onPressed: _working ? null : _cancel,
              ),
              if (alternative != null) ...[
                const SizedBox(height: 4),
                KitInset(
                  child: KitButton.fromAction(
                    KitAction(
                      key: alternative.key,
                      label: alternative.label,
                      icon: alternative.icon,
                      onPressed: alternative.onPressed == null || _working
                          ? null
                          : () {
                              _cancel();
                              alternative.onPressed!();
                            },
                    ),
                    role: KitButtonRole.tertiary,
                  ),
                ),
              ],
              if (widget.details.isNotEmpty) ...[
                const SizedBox(height: 8),
                _KitDetailsFold(values: widget.details),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A minimal technical fold for the confirmation's [KitTechnicalValue]s,
/// private until `KitDetailsFold` (§1.8) joins the kit: a muted "Details"
/// row that unfolds label and mono value pairs, left to right, selectable.
class _KitDetailsFold extends StatefulWidget {
  const _KitDetailsFold({required this.values});

  final List<KitTechnicalValue> values;

  @override
  State<_KitDetailsFold> createState() => _KitDetailsFoldState();
}

class _KitDetailsFoldState extends State<_KitDetailsFold> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final seen = <String>{};
    final values = [
      for (final value in widget.values)
        if (seen.add(value.value)) value,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _open,
          child: KitInset(
            child: TextButton.icon(
              key: const ValueKey('kit-details-toggle'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: muted,
                padding: const EdgeInsets.symmetric(
                  horizontal: KitButton.tertiaryInset,
                ),
              ),
              onPressed: () => setState(() => _open = !_open),
              iconAlignment: IconAlignment.end,
              icon: Icon(
                _open ? AppIconography.chevronUp : AppIconography.chevronDown,
                size: 18,
              ),
              label: Text(_l10n(context).kitDetails),
            ),
          ),
        ),
        KitReveal(
          child: !_open
              ? null
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (index, value) in values.indexed) ...[
                        if (index > 0) const SizedBox(height: 8),
                        Text(
                          value.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: SelectableText(
                            value.value,
                            key: value.key,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: AppTheme.monoFamily,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
