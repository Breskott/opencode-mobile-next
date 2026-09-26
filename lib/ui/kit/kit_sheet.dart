/// The one sheet frame and the one confirmation (docs/ux-system/kit-v2.md
/// §1.1, §1.2, §4.1, §4.2, §4.7, §8.2).
///
/// Both adapt to the window (§8.1, [KitLayout]): a bottom sheet on a phone,
/// a capped bottom sheet on a medium window, a centred panel (or an
/// end-side sheet for a full-height sheet) on a tablet in landscape, a PC
/// or the web. Esc closes the top one and obeys the same draft and unsaved
/// input rules as a swipe down.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import '../widgets/request_routes.dart';
import 'kit_buttons.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_notice.dart';
import 'kit_progress.dart';
import 'kit_technical_value.dart';
import 'motion/kit_haptics.dart';
import 'motion/kit_reveal.dart';

part 'kit_confirm_sheet.dart';

AppLocalizations _l10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// How tall a [showKitSheet] opens.
enum KitSheetHeight {
  /// As tall as its content needs, up to 90 % of the window.
  content,

  /// Half the window: a list the person scrolls.
  half,

  /// Nearly the whole window; an end-side sheet on a wide window (§8.2).
  full,
}

/// Typed input kept across dismissal, per target and server profile
/// (§1.1 data safety, gate G10). Its key is `oc.draft.<target>.<profileId>`,
/// so `ProfileStore.profileScopedPreferenceKeys` sweeps it when the profile
/// is deleted.
///
/// A sheet opened with a draft restores the saved text into [controller]
/// (when the field is empty), saves every change, and lets swipe, back,
/// Esc and close dismiss it silently: nothing is lost, so nothing is asked.
/// The caller calls [clear] once the input is used (sent, saved).
///
/// The caller owns [controller] and disposes it after the sheet closes.
@immutable
class KitDraft {
  const KitDraft({
    required this.target,
    required this.profileId,
    required this.controller,
    this.prefs,
  });

  /// What the text is for, stable across launches: `note.<sessionId>`.
  final String target;
  final String profileId;
  final TextEditingController controller;

  /// The store; defaults to [SharedPreferences.getInstance].
  final SharedPreferences? prefs;

  static String keyFor(String target, String profileId) {
    assert(target.isNotEmpty && profileId.isNotEmpty);
    return 'oc.draft.$target.$profileId';
  }

  String get key => keyFor(target, profileId);

  Future<SharedPreferences> _store() async =>
      prefs ?? await SharedPreferences.getInstance();

  /// Puts the saved text back into an empty [controller].
  Future<void> restore() async {
    final saved = (await _store()).getString(key);
    if (saved != null && saved.isNotEmpty && controller.text.isEmpty) {
      controller.text = saved;
    }
  }

  /// Saves what [controller] holds now (an empty field removes the key).
  Future<void> save() async {
    final store = await _store();
    final text = controller.text;
    if (text.isEmpty) {
      await store.remove(key);
    } else {
      await store.setString(key, text);
    }
  }

  /// Forgets the saved text: the input was used.
  Future<void> clear() async => (await _store()).remove(key);
}

/// Opens [body] in the one sheet frame (§1.1): a handle, a header (title,
/// optional subtitle, close), a scrolling body and pinned actions.
///
/// It adapts to the window (§8.2): a bottom sheet on a compact window, a
/// bottom sheet capped at 640 dp on a medium one, a centred panel of up to
/// 560 dp on an expanded or large one, where [KitSheetHeight.full] becomes
/// an end-side sheet of 400–480 dp. A short window (a phone in landscape)
/// keeps the bottom sheet.
///
/// An action closes the sheet with `Navigator.pop(context, result)` from
/// the caller's context (the sheet is the top route of that navigator) or
/// with [KitSheet.close] from inside [body].
///
/// Data safety: with a [draft], swipe down, back, Esc and close keep the
/// text silently. With only [dirty], the frame owns the swipe (on its
/// handle and header) and catches back and Esc, and asks the discard
/// question inside the sheet (§4.7: never a sheet on a sheet). A
/// [showKitConfirm] raised from inside [body] also replaces the content in
/// place and adds no route. [dismissible] is false only while an
/// irreversible step runs, and the body says so.
///
/// With [routes], the sheet closes itself when its request is answered
/// elsewhere.
Future<T?> showKitSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder body,
  String? subtitle,
  KitSheetHeight height = KitSheetHeight.content,
  KitAction? primary,
  KitAction? secondary,
  List<KitAction> tertiary = const [],
  ValueListenable<bool>? dirty,
  KitDraft? draft,
  ValueListenable<bool>? loading,
  RequestRoutes? routes,
  bool dismissible = true,
  Key? sheetKey,
}) async {
  if (routes?.isPending == false) return null;
  final window = KitLayout.modalWindowOf(context);
  final shape = !window.isWide
      ? _KitModalShape.bottom
      : height == KitSheetHeight.full
      ? _KitModalShape.side
      : _KitModalShape.panel;
  // A sheet guarding unsaved input owns its swipe (the route's own drag
  // would dismiss it without asking).
  final ownsDrag = dirty != null && draft == null;
  return _presentKitModal<T>(
    context,
    shape: shape,
    maxWidth: shape == _KitModalShape.bottom
        ? KitLayout.sheetMaxWidth
        : KitLayout.dialogPanelWidth,
    dismissible: dismissible,
    enableDrag: !ownsDrag,
    builder: (sheetContext) {
      routes?.own(ModalRoute.of(sheetContext));
      return _KitSheetHost(
        title: title,
        subtitle: subtitle,
        body: body,
        height: height,
        shape: shape,
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        dirty: dirty,
        draft: draft,
        loading: loading,
        dismissible: dismissible,
        sheetKey: sheetKey,
      );
    },
  );
}

/// The one sheet frame (§1.1), drawn by [showKitSheet]; also used on its
/// own for goldens and for a full-screen variant on tablets.
///
/// A handle (bottom sheets only), a header with the title, an optional
/// muted subtitle and the close button at the end, the one loading bar,
/// the scrolling [child], and the pinned action block. At 200 % text the
/// title and subtitle wrap to two lines and the actions stay pinned while
/// the body scrolls.
class KitSheet extends StatelessWidget {
  const KitSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.primary,
    this.secondary,
    this.tertiary = const [],
    this.onClose,
    this.loading = false,
    this.handle = true,
    this.fill = false,
    this.onPullDown,
  });

  /// The place in the person's words, at most four words.
  final String title;
  final String? subtitle;

  /// The body; it scrolls inside the frame, so it is never its own
  /// scroll view or Scaffold.
  final Widget child;
  final KitAction? primary;
  final KitAction? secondary;
  final List<KitAction> tertiary;

  /// Null hides the close button (while an irreversible step runs).
  final VoidCallback? onClose;
  final bool loading;

  /// The drag handle on top (bottom sheets).
  final bool handle;

  /// Fill the height the frame is given ([KitSheetHeight.half], `full`)
  /// instead of shrinking to the content.
  final bool fill;

  /// A swipe down on the handle or header, where the frame owns the drag
  /// (a sheet guarding unsaved input).
  final VoidCallback? onPullDown;

  /// Closes the sheet [context] is inside with [result]: the person chose
  /// an action, so nothing is asked.
  static void close<T>(BuildContext context, [T? result]) =>
      Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = _l10n(context);
    final subtitle = this.subtitle;
    final hasActions =
        primary != null || secondary != null || tertiary.isNotEmpty;
    Widget top = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (handle) _KitHandle(onDismiss: onClose),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20, handle ? 0 : 12, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 10, end: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        namesRoute: true,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.mutedOf(theme),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (onClose case final close?)
                IconButton(
                  key: const ValueKey('kit-sheet-close'),
                  tooltip: l10n.kitSheetClose,
                  onPressed: close,
                  icon: const Icon(AppIconography.close),
                ),
            ],
          ),
        ),
      ],
    );
    if (onPullDown case final pull?) {
      top = _PullDown(onPullDown: pull, child: top);
    }
    final scroll = SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, hasActions ? 8 : 20),
      child: child,
    );
    return Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        KitLoadingBar(loading: loading, label: l10n.kitSheetLoading),
        Flexible(fit: fill ? FlexFit.tight : FlexFit.loose, child: scroll),
        if (hasActions)
          Padding(
            key: const ValueKey('kit-sheet-actions'),
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
            child: KitActionBlock(
              primary: primary,
              secondary: secondary,
              tertiary: tertiary,
            ),
          ),
      ],
    );
  }
}

/// The drag handle: a short bar with a spoken "Dismiss" action.
class _KitHandle extends StatelessWidget {
  const _KitHandle({this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: onDismiss == null ? null : _l10n(context).kitSheetDismiss,
      onDismiss: onDismiss,
      child: SizedBox(
        height: 20,
        child: Center(
          child: Container(
            key: const ValueKey('kit-sheet-handle'),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// A swipe down the frame owns: far or fast enough, it asks to close.
class _PullDown extends StatefulWidget {
  const _PullDown({required this.onPullDown, required this.child});

  final VoidCallback onPullDown;
  final Widget child;

  @override
  State<_PullDown> createState() => _PullDownState();
}

class _PullDownState extends State<_PullDown> {
  double _pulled = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onVerticalDragStart: (_) => _pulled = 0,
    onVerticalDragUpdate: (details) => _pulled += details.delta.dy,
    onVerticalDragEnd: (details) {
      if (_pulled > 48 || (details.primaryVelocity ?? 0) > 700) {
        widget.onPullDown();
      }
      _pulled = 0;
    },
    child: widget.child,
  );
}

enum _KitModalShape { bottom, panel, side }

/// Pushes a kit modal in the shape the window asks for (§8.2). The route
/// always goes on the caller's own navigator, so `Navigator.pop(context)`
/// from the caller closes it.
Future<T?> _presentKitModal<T>(
  BuildContext context, {
  required _KitModalShape shape,
  required double maxWidth,
  required bool dismissible,
  required bool enableDrag,
  required WidgetBuilder builder,
}) {
  final reduced = KitMotion.reduced(context);
  final style = reduced
      ? AnimationStyle.noAnimation
      : AnimationStyle(
          duration: KitMotion.standard,
          reverseDuration: KitMotion.standard,
          curve: KitMotion.enter,
          reverseCurve: KitMotion.exit,
        );
  switch (shape) {
    case _KitModalShape.bottom:
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: dismissible,
        enableDrag: dismissible && enableDrag,
        showDragHandle: false,
        constraints: BoxConstraints(maxWidth: maxWidth),
        sheetAnimationStyle: style,
        builder: builder,
      );
    case _KitModalShape.panel:
      return showDialog<T>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: dismissible,
        animationStyle: style,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * .9,
            ),
            child: builder(dialogContext),
          ),
        ),
      );
    case _KitModalShape.side:
      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: dismissible,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: Colors.black54,
        transitionDuration: reduced ? Duration.zero : KitMotion.standard,
        pageBuilder: (dialogContext, _, _) {
          final width = (MediaQuery.sizeOf(dialogContext).width * .4).clamp(
            KitLayout.sideSheetMinWidth,
            KitLayout.sideSheetMaxWidth,
          );
          final theme = Theme.of(dialogContext);
          return Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: Material(
                color: theme.colorScheme.surfaceContainerLow,
                elevation: 1,
                child: SafeArea(child: builder(dialogContext)),
              ),
            ),
          );
        },
        transitionBuilder: (dialogContext, animation, _, child) {
          final rtl = Directionality.of(dialogContext) == TextDirection.rtl;
          return SlideTransition(
            position: Tween(begin: Offset(rtl ? -1 : 1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: KitMotion.enter),
                ),
            child: child,
          );
        },
      );
  }
}

/// A question asked in place of a sheet's content (§4.7).
class _KitAsk {
  _KitAsk(this.spec);

  final _KitConfirmSpec spec;
  final done = Completer<bool>();
}

/// Lets a [showKitConfirm] raised from inside a sheet find that sheet.
class _KitSheetScope extends InheritedWidget {
  const _KitSheetScope({required this.host, required super.child});

  final _KitSheetHostState host;

  /// The sheet [context] is inside; or, for a context outside it (a
  /// pinned action's callback uses the caller's context), the kit sheet
  /// that is the top route of [context]'s navigator.
  static _KitSheetHostState? maybeOf(BuildContext context) {
    final inside = context.getInheritedWidgetOfExactType<_KitSheetScope>();
    if (inside != null) return inside.host;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return null;
    for (final host in _KitSheetHostState._live.reversed) {
      final route = host._route;
      if (route != null && route.isCurrent && route.navigator == navigator) {
        return host;
      }
    }
    return null;
  }

  @override
  bool updateShouldNotify(_KitSheetScope old) => old.host != host;
}

/// The live sheet: its draft, its unsaved-input guard, Esc, and the
/// question asked in place.
class _KitSheetHost extends StatefulWidget {
  const _KitSheetHost({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.height,
    required this.shape,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.dirty,
    required this.draft,
    required this.loading,
    required this.dismissible,
    required this.sheetKey,
  });

  final String title;
  final String? subtitle;
  final WidgetBuilder body;
  final KitSheetHeight height;
  final _KitModalShape shape;
  final KitAction? primary;
  final KitAction? secondary;
  final List<KitAction> tertiary;
  final ValueListenable<bool>? dirty;
  final KitDraft? draft;
  final ValueListenable<bool>? loading;
  final bool dismissible;
  final Key? sheetKey;

  @override
  State<_KitSheetHost> createState() => _KitSheetHostState();
}

class _KitSheetHostState extends State<_KitSheetHost> {
  /// Open kit sheets, newest last.
  static final _live = <_KitSheetHostState>[];

  final _focus = FocusNode(debugLabel: 'kit-sheet');
  _KitAsk? _ask;
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft != null) {
      unawaited(draft.restore());
      draft.controller.addListener(_saveDraft);
    }
    widget.dirty?.addListener(_rebuild);
    widget.loading?.addListener(_rebuild);
    _live.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _live.remove(this);
    widget.draft?.controller.removeListener(_saveDraft);
    widget.dirty?.removeListener(_rebuild);
    widget.loading?.removeListener(_rebuild);
    final ask = _ask;
    if (ask != null && !ask.done.isCompleted) ask.done.complete(false);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _saveDraft() => unawaited(widget.draft?.save());

  /// Unsaved input that no draft keeps.
  bool get _unsaved => widget.draft == null && (widget.dirty?.value ?? false);

  /// Replaces the content with [spec]'s question until it is answered.
  Future<bool> ask(_KitConfirmSpec spec) {
    final previous = _ask;
    if (previous != null && !previous.done.isCompleted) {
      previous.done.complete(false);
    }
    final ask = _KitAsk(spec);
    setState(() => _ask = ask);
    return ask.done.future;
  }

  void _answer(bool confirmed) {
    final ask = _ask;
    if (ask == null) return;
    setState(() => _ask = null);
    if (!ask.done.isCompleted) ask.done.complete(confirmed);
    _focus.requestFocus();
  }

  /// Back, Esc, the close button, a swipe or a tap outside, when the route
  /// may not simply pop.
  Future<void> _blockedPop() async {
    if (!widget.dismissible) return;
    if (_ask != null) {
      _answer(false);
      return;
    }
    if (!_unsaved) return;
    final l10n = _l10n(context);
    final discard = await ask(
      _KitConfirmSpec(
        title: l10n.kitDiscardTitle,
        body: l10n.kitDiscardBody,
        confirmLabel: l10n.kitDiscardConfirm,
        kind: KitConfirmKind.discard,
      ),
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  void _close() => unawaited(Navigator.of(context).maybePop());

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.shape;
    final ask = _ask;
    final size = MediaQuery.sizeOf(context);
    final fill = widget.height != KitSheetHeight.content;
    final bottom = shape == _KitModalShape.bottom;
    Widget content = KitSheet(
      key: widget.sheetKey,
      title: widget.title,
      subtitle: widget.subtitle,
      primary: widget.primary,
      secondary: widget.secondary,
      tertiary: widget.tertiary,
      loading: widget.loading?.value ?? false,
      handle: bottom,
      fill: fill || shape == _KitModalShape.side,
      onClose: widget.dismissible ? _close : null,
      onPullDown: bottom && widget.dismissible && widget.dirty != null
          ? _close
          : null,
      child: Builder(builder: widget.body),
    );
    // The question takes the content's place; the content keeps its state
    // (typed text) underneath, out of sight and out of focus. The content
    // keeps its place in the tree, so nothing in it is rebuilt from scratch.
    content = Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ask != null) ...[
          if (bottom) _KitHandle(onDismiss: () => _answer(false)),
          Flexible(
            fit: fill ? FlexFit.tight : FlexFit.loose,
            child: SingleChildScrollView(
              child: KitEntrance(
                child: _KitConfirmBody(
                  spec: ask.spec,
                  onConfirm: () => _answer(true),
                  onCancel: () => _answer(false),
                ),
              ),
            ),
          ),
        ],
        Flexible(
          key: const ValueKey('kit-sheet-content'),
          fit: fill && ask == null ? FlexFit.tight : FlexFit.loose,
          child: ExcludeFocus(
            excluding: ask != null,
            child: Visibility(
              visible: ask == null,
              maintainState: true,
              child: content,
            ),
          ),
        ),
      ],
    );
    final maxHeight = size.height;
    final double? fixed = switch ((shape, widget.height)) {
      (_KitModalShape.side, _) => null,
      (_, KitSheetHeight.half) => maxHeight * .5,
      (_KitModalShape.bottom, KitSheetHeight.full) => maxHeight * .95,
      (_, KitSheetHeight.full) => maxHeight * .9,
      _ => null,
    };
    content = fixed != null
        ? SizedBox(height: fixed, child: content)
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight * .9),
            child: content,
          );
    if (bottom) {
      // The pinned actions ride above the keyboard.
      content = Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(top: false, child: content),
      );
    }
    return _KitSheetScope(
      host: this,
      child: PopScope<Object?>(
        canPop: widget.dismissible && ask == null && !_unsaved,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_blockedPop());
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: content,
        ),
      ),
    );
  }
}
