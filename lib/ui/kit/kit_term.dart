/// A word that explains itself (docs/ux-system/kit-api/KitTerm.md, K2 §1.20):
/// tap, long-press or hover shows a short explanation anchored to the word,
/// with an optional "Learn more" into the Guide. Replaces a separate page
/// and the old 24 dp `InfoLabel` hit area (R12).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerEnterEvent, PointerExitEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;

import '../../l10n/app_localizations.dart';
import 'kit_buttons.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_sheet.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

AppLocalizations _l10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// A term that explains itself (K2 §1.20). A standalone widget at least
/// 48×48 dp: use it as a label, a heading word or at the end of a line,
/// never in the middle of a paragraph (a paragraph says it in words).
///
/// States: default, open (the explanation shows), hovered, focused.
class KitTerm extends StatelessWidget {
  const KitTerm(
    this.term, {
    super.key,
    required this.explanation,
    this.learnMore,
    this.role,
    this.termKey,
  });

  final String term;
  final String explanation;
  final KitAction? learnMore;

  /// The [KitText] role to match the text around it; null keeps the
  /// ambient [DefaultTextStyle].
  final KitTextRole? role;
  final Key? termKey;

  @override
  Widget build(BuildContext context) => _KitTermCore(
    termKey: termKey ?? const ValueKey('kit-term'),
    term: term,
    explanation: explanation,
    learnMore: learnMore,
    role: role,
  );
}

/// Shows [explanation] for [term] without a [KitTerm] on screen (a toolbar
/// button that explains "MCP"; `InfoLabel.show`). The bubble anchors to
/// [context]'s render box; when it cannot fit, it opens as a sheet (see
/// [KitTerm]'s Presentation). Completes when it closes.
Future<void> showKitTerm(
  BuildContext context, {
  required String term,
  required String explanation,
  KitAction? learnMore,
}) {
  final box = context.findRenderObject();
  final anchor = box is RenderBox && box.hasSize && box.attached
      ? (box.localToGlobal(Offset.zero) & box.size)
      : Rect.zero;
  final tokens = KitTokens.of(context);
  final screenSize = MediaQuery.sizeOf(context);
  if (_estimatedBubbleHeight(
        context,
        tokens,
        term: term,
        explanation: explanation,
        hasLearnMore: learnMore != null,
      ) >
      screenSize.height * KitTokens.termBubbleMaxHeight) {
    return showKitSheet<void>(
      context,
      title: term,
      height: KitSheetHeight.content,
      sheetKey: const ValueKey('kit-term-sheet'),
      tertiary: [?learnMore],
      body: (inner) => KitText(explanation, role: KitTextRole.secondary),
    );
  }
  final completer = Completer<void>();
  final scrollPosition = Scrollable.maybeOf(context)?.position;
  late OverlayEntry entry;
  var closing = false;
  void close() {
    if (closing) return;
    closing = true;
    if (scrollPosition != null) scrollPosition.removeListener(close);
    entry.remove();
    if (!completer.isCompleted) completer.complete();
  }

  entry = OverlayEntry(
    builder: (overlayContext) => _KitTermStandaloneBubble(
      anchor: anchor,
      screenSize: screenSize,
      term: term,
      explanation: explanation,
      learnMore: learnMore,
      onClose: close,
    ),
  );
  scrollPosition?.addListener(close);
  Overlay.of(context).insert(entry);
  return completer.future;
}

/// A rough height for the bubble at [tokens]' spacing, wrapped at the
/// popover width: enough to decide bubble vs. sheet before building either
/// (KitTerm.md "Sheet (long text)").
double _estimatedBubbleHeight(
  BuildContext context,
  KitTokens tokens, {
  required String term,
  required String explanation,
  required bool hasLearnMore,
}) {
  final maxWidth = math.max(
    0.0,
    math.min(
          KitLayout.popoverMaxWidth,
          MediaQuery.sizeOf(context).width - tokens.gutter * 2,
        ) -
        tokens.space3 * 2,
  );
  double lineHeightOf(TextStyle style, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  var height = tokens.space2 * 2;
  height += lineHeightOf(KitText.styleOf(context, KitTextRole.label), term);
  height += tokens.space1;
  height += lineHeightOf(
    KitText.styleOf(context, KitTextRole.secondary),
    explanation,
  );
  if (hasLearnMore) height += tokens.space2 + tokens.minTarget;
  return height;
}

/// The bubble's content: the term, its explanation and an optional "Learn
/// more", shared by the anchored [_KitTermBubble] and the standalone
/// [showKitTerm] overlay.
class _KitTermPanel extends StatelessWidget {
  const _KitTermPanel({
    required this.term,
    required this.explanation,
    required this.learnMore,
    required this.learnMoreFocusNode,
    required this.onLearnMore,
  });

  final String term;
  final String explanation;
  final KitAction? learnMore;
  final FocusNode? learnMoreFocusNode;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KitLayout.popoverMaxWidth),
      child: Material(
        key: const ValueKey('kit-term-bubble'),
        color: roles.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KitTokens.popoverRadius),
          side: BorderSide(
            color: roles.hairline,
            width: KitTokens.hairlineWidth(context),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: tokens.space3,
            vertical: tokens.space2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KitText(term, role: KitTextRole.label),
              SizedBox(height: tokens.space1),
              KitText(explanation, role: KitTextRole.secondary),
              if (learnMore case final action?) ...[
                SizedBox(height: tokens.space2),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Focus(
                    focusNode: learnMoreFocusNode,
                    child: KitButton.fromAction(
                      KitAction(
                        key: const ValueKey('kit-term-learn-more'),
                        label: action.label,
                        onPressed: onLearnMore,
                      ),
                      role: KitButtonRole.tertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// How [KitTerm] was opened: it decides how a mouse leaving it behaves and
/// where focus goes once it closes.
enum _OpenedBy { pointer, hover, keyboard }

class _KitTermCore extends StatefulWidget {
  const _KitTermCore({
    required this.term,
    required this.explanation,
    required this.learnMore,
    required this.role,
    required this.termKey,
  });

  final String term;
  final String explanation;
  final KitAction? learnMore;
  final KitTextRole? role;

  /// Placed on the interactive [Semantics] node itself (TEST-5), not on
  /// this widget: `find.byKey` must resolve to a render object that owns
  /// its semantics and hit-tests normally, not to the
  /// [CompositedTransformTarget]'s layer-annotation box.
  final Key termKey;

  @override
  State<_KitTermCore> createState() => _KitTermCoreState();
}

class _KitTermCoreState extends State<_KitTermCore>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _overlay = OverlayPortalController();
  final _focusNode = FocusNode(debugLabel: 'kit-term');
  final _learnMoreFocusNode = FocusNode(debugLabel: 'kit-term-learn-more');
  late final AnimationController _fade;
  Timer? _hoverTimer;
  bool _hovered = false;
  bool _preferBelow = true;
  _OpenedBy? _openedBy;
  ScrollPosition? _scrollPosition;

  /// No spec states a value for the hover-open delay (KitTerm.md); this
  /// seam picks one short enough to feel responsive, long enough that a
  /// pointer passing over the word does not flash it open.
  static const _hoverDelay = Duration(milliseconds: 400);

  bool get _open => _overlay.isShowing;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: KitMotion.quick);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _scrollPosition?.removeListener(_closeForScroll);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _learnMoreFocusNode.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _closeForScroll() => _close();

  void _toggle(_OpenedBy by) {
    if (_open) {
      _close();
    } else {
      _requestOpen(by);
    }
  }

  /// Decides between the bubble and the sheet (KitTerm.md "Sheet (long
  /// text)"): estimated ahead of building either, so the person never sees
  /// one flash before the other.
  void _requestOpen(_OpenedBy by) {
    _hoverTimer?.cancel();
    final tokens = KitTokens.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    if (_estimatedBubbleHeight(
          context,
          tokens,
          term: widget.term,
          explanation: widget.explanation,
          hasLearnMore: widget.learnMore != null,
        ) >
        screenHeight * KitTokens.termBubbleMaxHeight) {
      unawaited(_openAsSheet(context));
      return;
    }
    _measure();
    setState(() => _openedBy = by);
    _overlay.show();
    if (KitMotion.reduced(context)) {
      _fade.value = 1;
    } else {
      unawaited(_fade.forward(from: 0));
    }
    _scrollPosition = Scrollable.maybeOf(context)?.position;
    _scrollPosition?.addListener(_closeForScroll);
    if (by == _OpenedBy.keyboard && widget.learnMore != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) _learnMoreFocusNode.requestFocus();
      });
    }
  }

  void _close({bool returnFocus = true}) {
    if (!_open) return;
    _scrollPosition?.removeListener(_closeForScroll);
    _scrollPosition = null;
    final reduced = KitMotion.reduced(context);
    if (reduced) {
      _overlay.hide();
      setState(() => _openedBy = null);
    } else {
      unawaited(
        _fade.reverse(from: _fade.value).then((_) {
          if (mounted) {
            _overlay.hide();
            setState(() => _openedBy = null);
          }
        }),
      );
    }
    if (returnFocus && mounted) _focusNode.requestFocus();
  }

  void _measure() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) {
      _preferBelow = true;
      return;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final spaceBelow = screenHeight - (topLeft.dy + box.size.height);
    final spaceAbove = topLeft.dy;
    _preferBelow = spaceBelow >= spaceAbove;
  }

  Future<void> _openAsSheet(BuildContext context) async {
    final term = widget.term;
    final explanation = widget.explanation;
    final learnMore = widget.learnMore;
    await showKitSheet<void>(
      context,
      title: term,
      height: KitSheetHeight.content,
      sheetKey: const ValueKey('kit-term-sheet'),
      tertiary: [?learnMore],
      body: (inner) => KitText(explanation, role: KitTextRole.secondary),
    );
    if (mounted) _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _toggle(_OpenedBy.keyboard);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _open) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onLearnMore() {
    final action = widget.learnMore;
    _close();
    action?.onPressed?.call();
  }

  void _onEnter(PointerEnterEvent _) {
    if (!KitLayout.finePointer(context)) return;
    setState(() => _hovered = true);
    if (_open) return;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(_hoverDelay, () {
      if (mounted && _hovered && !_open) _requestOpen(_OpenedBy.hover);
    });
  }

  void _onExit(PointerExitEvent _) {
    _hoverTimer?.cancel();
    setState(() => _hovered = false);
    if (_open && _openedBy == _OpenedBy.hover) {
      _close(returnFocus: false);
    }
  }

  TextStyle _baseStyle(BuildContext context) {
    final role = widget.role;
    if (role == null) return DefaultTextStyle.of(context).style;
    return KitText.styleOf(context, role, tone: KitTextTone.primary);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final l10n = _l10n(context);
    final base = _baseStyle(context);
    // The term itself is always text1 (K2 §1.20 Look), whatever role or
    // ambient style set its size and weight; only the underline is text2.
    final textStyle = base.copyWith(
      color: roles.text1,
      decoration: TextDecoration.underline,
      decorationColor: roles.text2,
      decorationStyle: TextDecorationStyle.dotted,
    );
    final hoverFill = roles.isDark ? roles.surface2 : roles.surface3;
    final showFocusRing = _focusNode.hasFocus;

    final body = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: tokens.minTarget,
        minHeight: tokens.minTarget,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _hovered ? hoverFill : null,
          borderRadius: BorderRadius.circular(tokens.buttonRadius),
          border: showFocusRing
              ? Border.all(
                  color: roles.accent,
                  width: KitTokens.focusRingWidth(context),
                )
              : null,
        ),
        child: Padding(
          // Enough clearance that the focus ring and the hover fill never
          // sit hard against the glyph's own paint bounds.
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: tokens.space2,
            vertical: tokens.space1,
          ),
          child: Align(
            alignment: AlignmentDirectional.center,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(widget.term, style: textStyle),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _overlay,
          overlayChildBuilder: (overlayContext) {
            final rtl = Directionality.of(context) == TextDirection.rtl;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: () => _close(),
                  ),
                ),
                CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: _preferBelow
                      ? (rtl ? Alignment.bottomRight : Alignment.bottomLeft)
                      : (rtl ? Alignment.topRight : Alignment.topLeft),
                  followerAnchor: _preferBelow
                      ? (rtl ? Alignment.topRight : Alignment.topLeft)
                      : (rtl ? Alignment.bottomRight : Alignment.bottomLeft),
                  offset: Offset(
                    0,
                    _preferBelow ? tokens.space1 : -tokens.space1,
                  ),
                  child: FadeTransition(
                    opacity: _fade,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: () {},
                      child: Focus(
                        // Escape closes the bubble from anywhere inside it
                        // (the term's own Focus is not an ancestor of the
                        // overlay content, and focus may have moved onto
                        // Learn more), returning focus to the term.
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.escape) {
                            _close();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Semantics(
                          liveRegion: true,
                          container: true,
                          onDismiss: () => _close(),
                          label: l10n.kitTermClose,
                          child: _KitTermPanel(
                            term: widget.term,
                            explanation: widget.explanation,
                            learnMore: widget.learnMore,
                            learnMoreFocusNode: _learnMoreFocusNode,
                            onLearnMore: _onLearnMore,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: MouseRegion(
            onEnter: _onEnter,
            onExit: _onExit,
            child: Focus(
              focusNode: _focusNode,
              onKeyEvent: _onKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _focusNode.requestFocus();
                  _toggle(_OpenedBy.pointer);
                },
                onLongPress: () {
                  _focusNode.requestFocus();
                  _toggle(_OpenedBy.pointer);
                },
                child: Semantics(
                  key: widget.termKey,
                  button: true,
                  label: widget.term,
                  hint: l10n.kitTermHint,
                  onTapHint: l10n.kitTermShow,
                  excludeSemantics: true,
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The [showKitTerm] popover: the same panel as [KitTerm]'s bubble, placed
/// at a fixed position derived from [anchor] once (there is no word on
/// screen to track, and a scroll closes it rather than following it).
class _KitTermStandaloneBubble extends StatefulWidget {
  const _KitTermStandaloneBubble({
    required this.anchor,
    required this.screenSize,
    required this.term,
    required this.explanation,
    required this.learnMore,
    required this.onClose,
  });

  final Rect anchor;
  final Size screenSize;
  final String term;
  final String explanation;
  final KitAction? learnMore;
  final VoidCallback onClose;

  @override
  State<_KitTermStandaloneBubble> createState() =>
      _KitTermStandaloneBubbleState();
}

class _KitTermStandaloneBubbleState extends State<_KitTermStandaloneBubble>
    with SingleTickerProviderStateMixin {
  final _focusNode = FocusNode(debugLabel: 'kit-term-popover');
  late final AnimationController _fade;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: KitMotion.quick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      if (KitMotion.reduced(context)) {
        _fade.value = 1;
      } else {
        unawaited(_fade.forward(from: 0));
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    if (KitMotion.reduced(context)) {
      widget.onClose();
      return;
    }
    unawaited(_fade.reverse(from: _fade.value).then((_) => widget.onClose()));
  }

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
    final tokens = KitTokens.of(context);
    final l10n = _l10n(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final anchor = widget.anchor;
    final screen = widget.screenSize;
    final preferBelow = (screen.height - anchor.bottom) >= anchor.top;
    final maxLeft = math.max(
      tokens.gutter,
      screen.width - tokens.gutter - KitLayout.popoverMaxWidth,
    );
    // Distance from the reading direction's start edge (LAY-8, R23): the
    // anchor rect itself is always in absolute left-to-right coordinates.
    final startDistance = rtl
        ? (screen.width - anchor.right).clamp(tokens.gutter, maxLeft)
        : anchor.left.clamp(tokens.gutter, maxLeft);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: _close,
            ),
          ),
          PositionedDirectional(
            top: preferBelow ? anchor.bottom + tokens.space1 : null,
            bottom: preferBelow
                ? null
                : screen.height - anchor.top + tokens.space1,
            start: startDistance,
            child: FadeTransition(
              opacity: _fade,
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _onKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: () {},
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    onDismiss: _close,
                    label: l10n.kitTermClose,
                    child: _KitTermPanel(
                      term: widget.term,
                      explanation: widget.explanation,
                      learnMore: widget.learnMore,
                      learnMoreFocusNode: null,
                      onLearnMore: () {
                        final action = widget.learnMore;
                        _close();
                        action?.onPressed?.call();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
