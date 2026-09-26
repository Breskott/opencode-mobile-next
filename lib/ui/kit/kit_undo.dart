import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import 'kit_bottom_inset.dart';
import 'kit_buttons.dart';
import 'kit_icon_button.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// Shows the one Undo bar (docs/ux-system/kit-api/KitUndo.md; K2 §1.17,
/// §4.1, §4.8; STANDARDS KIT-34, DATA-11, MOT-1, MOT-11). Returns at once —
/// the one modal-family entry point that is not a `Future` (KIT-11).
///
/// Two ways to use it (DATA-11):
/// - act now, undo = inverse: do the act, then call this with [onUndo]
///   running the inverse call (only where the gateway exposes one);
/// - deferred commit (a local act): hide the thing, pass [onCommit] to do
///   the act for real and [onUndo] to put it back. [onCommit] runs exactly
///   once unless Undo is taken.
///
/// One bar at a time: a new call first commits the pending one (its
/// [onCommit] runs before this bar shows) — see [KitUndo.commitPending].
/// The window is [KitUndo.window]; never auto-dismissed under accessible
/// navigation (`MediaQuery.accessibleNavigationOf`), which shows a Dismiss
/// action instead. If [onUndo] throws or its future errors: with
/// [onUndoFailed], it receives the error and a `tryAgain` callback and the
/// host shows its own failure notice; without it, the bar itself switches
/// to its failure form (kit copy `kitUndoFailed`, action `kitTryAgain`, no
/// timeout, Dismiss).
void showKitUndo(
  BuildContext context, {
  required String message,
  required FutureOr<void> Function() onUndo,
  FutureOr<void> Function()? onCommit,
  void Function(Object error, VoidCallback tryAgain)? onUndoFailed,
  String? undoLabel,
  Key? key,
  Key? undoKey,
}) {
  _KitUndoHost.instance.show(
    context,
    message: message,
    onUndo: onUndo,
    onCommit: onCommit,
    onUndoFailed: onUndoFailed,
    undoLabel: undoLabel,
    barKey: key,
    undoKey: undoKey,
  );
}

/// The kit's one snackbar (KitUndo.md): "done, with Undo", one at a time,
/// floating above the dock, the composer and a pinned primary. Never
/// constructed directly — [showKitUndo] is the only entry point.
///
/// States: default (message + Undo), working (Undo tapped, an async
/// `onUndo` in flight), error (`onUndo` failed and no `onUndoFailed` was
/// given) and, under accessible navigation, a Dismiss variant of default.
/// No loading or empty; disabled does not exist (an Undo that cannot run is
/// not offered). KIT-12's fixed vocabulary ({loading, empty, error,
/// disabled, working, answered}) does not have words for "default" or the
/// accessible variant; KitUndo.md names them this way and this unit follows
/// it verbatim (PROC-20 note in the QA record).
abstract final class KitUndo {
  /// How long the bar stays when nothing is pressed. Not a motion; a named
  /// kit wait (MOT-1).
  static const Duration window = KitMotion.undoWindow;

  /// Commits a pending bar now (runs its `onCommit`, closes it). Called by
  /// the kit on route pop and `AppLifecycleState.paused`; public for the
  /// app's lifecycle wiring and tests. No-op when nothing is pending.
  static void commitPending() => _KitUndoHost.instance.commitPending();

  /// Tests only.
  @visibleForTesting
  static bool get debugHasPending => _KitUndoHost.instance.hasPending;
}

/// One shown bar's request and its mutable, in-flight state (working, a
/// failed undo). A fresh instance per [showKitUndo] call.
class _PendingUndo extends ChangeNotifier {
  _PendingUndo({
    required this.message,
    required this.onUndo,
    required this.onCommit,
    required this.onUndoFailed,
    required this.undoLabel,
    required this.barKey,
    required this.undoKey,
    required this.clearance,
  });

  final String message;
  final FutureOr<void> Function() onUndo;
  final FutureOr<void> Function()? onCommit;
  final void Function(Object error, VoidCallback tryAgain)? onUndoFailed;
  final String? undoLabel;
  final Key? barKey;
  final Key? undoKey;

  /// Read once at show time (KitBottomInset.md, KitUndo.md §Adaptive).
  final KitClearance clearance;

  Timer? _timer;
  bool working = false;
  Object? error;

  void startTimer(VoidCallback onElapsed) {
    _timer?.cancel();
    _timer = Timer(KitUndo.window, onElapsed);
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void setWorking(bool value) {
    if (working == value) return;
    working = value;
    notifyListeners();
  }

  void setError(Object value) {
    error = value;
    working = false;
    notifyListeners();
  }

  @override
  void dispose() {
    cancelTimer();
    super.dispose();
  }
}

/// The app-wide (one at a time, KIT-34) controller behind [showKitUndo]: one
/// [OverlayEntry] inserted lazily into the root overlay on first show, the
/// route-pop and app-pause commit triggers, and the Ctrl+Z accelerator.
class _KitUndoHost {
  _KitUndoHost._();

  static final _KitUndoHost instance = _KitUndoHost._();

  final ValueNotifier<_PendingUndo?> current = ValueNotifier(null);
  OverlayEntry? _entry;
  bool _lifecycleObserved = false;

  bool get hasPending => current.value != null;

  void show(
    BuildContext context, {
    required String message,
    required FutureOr<void> Function() onUndo,
    FutureOr<void> Function()? onCommit,
    void Function(Object error, VoidCallback tryAgain)? onUndoFailed,
    String? undoLabel,
    Key? barKey,
    Key? undoKey,
  }) {
    final previous = current.value;
    if (previous != null) _commit(previous);

    final overlay = Overlay.of(context, rootOverlay: true);
    final clearance = KitBottomInset.read(context);
    final route = ModalRoute.of(context);
    // Item 6: never auto-dismissed under accessible navigation. Read once,
    // like the clearance above: the bar's own build reads it again (live)
    // to decide whether to show Dismiss.
    final accessible = MediaQuery.accessibleNavigationOf(context);

    final pending = _PendingUndo(
      message: message,
      onUndo: onUndo,
      onCommit: onCommit,
      onUndoFailed: onUndoFailed,
      undoLabel: undoLabel,
      barKey: barKey,
      undoKey: undoKey,
      clearance: clearance,
    );
    route?.popped.then((_) {
      if (identical(current.value, pending)) _commit(pending);
    });
    current.value = pending;
    _ensureOverlayEntry(overlay);
    _ensureLifecycleObserver();
    _ensureKeyHandler();
    if (!accessible) pending.startTimer(() => _commit(pending));
  }

  void _ensureOverlayEntry(OverlayState overlay) {
    final entry = _entry;
    if (entry != null && entry.mounted) return;
    _entry = OverlayEntry(builder: (context) => const _KitUndoOverlay());
    overlay.insert(_entry!);
  }

  void _ensureLifecycleObserver() {
    if (_lifecycleObserved) return;
    _lifecycleObserved = true;
    WidgetsBinding.instance.addObserver(_KitUndoLifecycleObserver(this));
  }

  // Re-armed on every show(), not guarded by an "added once" flag: a test
  // harness clears HardwareKeyboard's own handler list between tests to
  // keep them hermetic (HardwareKeyboard.clearState), which would otherwise
  // silently drop this after the first test that shows a bar. Removing
  // first keeps this idempotent (never more than one registration).
  void _ensureKeyHandler() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    final pending = current.value;
    if (pending == null || event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyZ) return false;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return false;
    // The focused node's context sits inside EditableText's own build
    // output (a Focus wrapper), not on an EditableText element itself, so
    // an ancestor lookup is what actually finds it.
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final typing =
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (typing) return false;
    attemptUndo(pending);
    return true;
  }

  void onAppPaused() {
    final pending = current.value;
    if (pending != null) _commit(pending);
  }

  void commitPending() {
    final pending = current.value;
    if (pending != null) _commit(pending);
  }

  void dismiss(_PendingUndo pending) => _commit(pending);

  void _commit(_PendingUndo pending) {
    pending.cancelTimer();
    if (!identical(current.value, pending)) return;
    current.value = null;
    final onCommit = pending.onCommit;
    pending.dispose();
    if (onCommit == null) return;
    Future.sync(onCommit).catchError((Object error, StackTrace stack) {
      // Item 5: onCommit owns its own errors' presentation; an error that
      // escapes it is never swallowed, and the bar is already gone.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'opencode_mobile kit',
          context: ErrorDescription('while committing a KitUndo bar'),
        ),
      );
    });
  }

  /// The Undo tap and every "Try again": guarded against a second tap while
  /// [_PendingUndo.working] (item 9), then routes success (bar closes) or
  /// failure (hands off to `onUndoFailed`, or the bar's own failure form).
  void attemptUndo(_PendingUndo pending) {
    if (pending.working) return;
    pending.cancelTimer();
    pending.setWorking(true);
    Future.sync(pending.onUndo).then(
      (_) {
        if (identical(current.value, pending)) current.value = null;
        pending.dispose();
      },
      onError: (Object error, StackTrace stack) {
        final onUndoFailed = pending.onUndoFailed;
        if (onUndoFailed != null) {
          if (identical(current.value, pending)) current.value = null;
          // Handed off entirely (the host shows its own KitNotice failure):
          // reset (not dispose) so a later `tryAgain` can still run
          // `attemptUndo` on this same request.
          pending.setWorking(false);
          onUndoFailed(error, () => attemptUndo(pending));
        } else {
          pending.setError(error);
        }
      },
    );
  }
}

class _KitUndoLifecycleObserver with WidgetsBindingObserver {
  _KitUndoLifecycleObserver(this._host);

  final _KitUndoHost _host;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _host.onAppPaused();
  }
}

/// The overlay's one persistent widget: rebuilds whenever the pending bar
/// changes identity or its own working/error state notifies.
class _KitUndoOverlay extends StatelessWidget {
  const _KitUndoOverlay();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<_PendingUndo?>(
    valueListenable: _KitUndoHost.instance.current,
    builder: (context, pending, _) => _KitUndoTransition(pending: pending),
  );
}

/// Motion (KitUndo.md §Motion): in, slides up `space2` and fades over
/// `KitMotion.standard` on `KitMotion.enter`; out, fades over
/// `KitMotion.quick` on `KitMotion.exit`. Under `KitMotion.reduced`,
/// appears and disappears at once and settles in one `pump()` (G8x).
class _KitUndoTransition extends StatefulWidget {
  const _KitUndoTransition({required this.pending});

  final _PendingUndo? pending;

  @override
  State<_KitUndoTransition> createState() => _KitUndoTransitionState();
}

class _KitUndoTransitionState extends State<_KitUndoTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KitMotion.standard,
    reverseDuration: KitMotion.quick,
  );
  _PendingUndo? _shown;
  bool _ranInitialEntrance = false;

  @override
  void initState() {
    super.initState();
    _shown = widget.pending;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ranInitialEntrance) return;
    _ranInitialEntrance = true;
    if (widget.pending != null) {
      if (KitMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _KitUndoTransition old) {
    super.didUpdateWidget(old);
    final next = widget.pending;
    final reduced = KitMotion.reduced(context);
    if (next == null) {
      if (old.pending == null) return;
      if (reduced) {
        setState(() => _shown = null);
        _controller.value = 0;
        return;
      }
      final leaving = old.pending;
      _controller.reverse().whenCompleteOrCancel(() {
        if (mounted && widget.pending == null && identical(_shown, leaving)) {
          setState(() => _shown = null);
        }
      });
      return;
    }
    final sameBar = identical(old.pending, next);
    setState(() => _shown = next);
    if (sameBar) return;
    if (reduced) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final tokens = KitTokens.of(context);
    final media = MediaQuery.of(context);
    final isShort = KitLayout.isShort(context);
    final window = isShort ? KitWindow.compact : KitLayout.windowOf(context);
    final keyboardBottom = media.viewInsets.bottom + media.padding.bottom;
    final bottom =
        math.max(shown.clearance.bottom, keyboardBottom) + tokens.space2;

    Widget bar = AnimatedBuilder(
      animation: CurvedAnimation(
        parent: _controller,
        curve: KitMotion.enter,
        reverseCurve: KitMotion.exit,
      ),
      builder: (context, child) => Opacity(
        opacity: _controller.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - _controller.value) * tokens.space2),
          child: child,
        ),
      ),
      child: ListenableBuilder(
        listenable: shown,
        builder: (context, _) => _KitUndoBar(pending: shown),
      ),
    );

    if (window == KitWindow.compact) {
      return PositionedDirectional(
        start: tokens.gutter,
        end: tokens.gutter,
        bottom: bottom,
        child: bar,
      );
    }
    return PositionedDirectional(
      start: shown.clearance.start + tokens.gutter,
      bottom: bottom,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: KitLayout.undoMaxWidth),
        child: bar,
      ),
    );
  }
}

/// The bar's content for [pending]'s current state (default, working, error,
/// or the accessible-navigation Dismiss variant of default).
class _KitUndoBar extends StatelessWidget {
  const _KitUndoBar({required this.pending});

  final _PendingUndo pending;

  @override
  Widget build(BuildContext context) {
    final host = _KitUndoHost.instance;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final accessible = MediaQuery.accessibleNavigationOf(context);
    final failed = pending.error;
    final showDismiss = accessible || failed != null;
    final message = failed == null
        ? pending.message
        : l10n.kitUndoFailed(pending.message);
    final actionLabel = failed == null
        ? (pending.undoLabel ?? l10n.kitUndoAction)
        : l10n.kitTryAgain;
    final semanticLabel = '$actionLabel, $message';

    final action = Semantics(
      key: pending.undoKey,
      button: true,
      label: semanticLabel,
      onTap: () => host.attemptUndo(pending),
      excludeSemantics: true,
      child: KitButton(
        role: KitButtonRole.tertiary,
        label: actionLabel,
        working: pending.working,
        expand: false,
        onPressed: () => host.attemptUndo(pending),
      ),
    );
    final dismiss = !showDismiss
        ? null
        : KitIconButton(
            icon: AppIconography.close,
            label: l10n.kitSheetDismiss,
            onPressed: () => host.dismiss(pending),
          );

    return Semantics(
      key: pending.barKey,
      container: true,
      liveRegion: true,
      child: Material(
        color: roles.surface3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
          side: BorderSide(
            color: roles.hairline,
            width: KitTokens.hairlineWidth(context),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: tokens.space4,
            vertical: tokens.space3,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = _stacks(
                context,
                constraints.maxWidth,
                message,
                actionLabel,
                tokens,
                hasDismiss: dismiss != null,
              );
              final text = KitText(message, role: KitTextRole.body);
              if (!stacked) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: text),
                    SizedBox(width: tokens.space3),
                    action,
                    if (dismiss != null) ...[
                      SizedBox(width: tokens.space2),
                      dismiss,
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  text,
                  SizedBox(height: tokens.space2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      action,
                      if (dismiss != null) ...[
                        SizedBox(width: tokens.space2),
                        dismiss,
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The action (and Dismiss) move under the message when both would not
  /// fit on one line (long words, large text): the same stacking rule as
  /// `KitStatusLine` (Accessibility, A11Y-8).
  bool _stacks(
    BuildContext context,
    double width,
    String message,
    String actionLabel,
    KitTokens tokens, {
    required bool hasDismiss,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final messageWidth = measure(message, KitText.styleFor(KitTextRole.body));
    final actionWidth =
        measure(actionLabel, KitText.styleFor(KitTextRole.button)) +
        2 * KitButton.tertiaryInset;
    final chrome = tokens.space3 + (hasDismiss ? tokens.space2 + 48 : 0);
    return messageWidth + actionWidth + chrome > width;
  }
}
