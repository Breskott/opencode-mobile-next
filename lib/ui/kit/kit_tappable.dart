// The one interactive primitive outside the named controls
// (docs/ux-system/kit-api/KitTappable.md): a region that acts on a tap, with
// a 48 dp target, a keyboard focus ring, a hover/pressed fill from the
// surface steps (never an ink ripple, VL §7) and, when it carries a [menu],
// the same right-click / long-press / Shift+F10 popup everywhere
// (`showKitMenu`, kit-KitMenu). `KitRow`, `KitSurface`-based cards,
// `KitBreadcrumb` and the chat parts build on it.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'kit_copy.dart';
import 'kit_layout.dart';
import 'kit_menu.dart';
import 'kit_motion.dart';
import 'kit_tokens.dart';

/// What a tappable is to a screen reader.
enum KitTappableRole { button, link }

/// The hover step and the pressed step after it, for a tappable that sits on
/// [surface] (KitTappable.md "Hover and pressed come from surface steps").
({KitSurfaceLevel hover, KitSurfaceLevel pressed}) _kitTappableFillLevels(
  KitTokens tokens,
  KitSurfaceLevel surface,
) {
  // The chip rule: from surface3 both fills step down to surface2.
  if (surface == KitSurfaceLevel.surface3) {
    return (hover: KitSurfaceLevel.surface2, pressed: KitSurfaceLevel.surface2);
  }
  KitSurfaceLevel step(KitSurfaceLevel level) => switch (level) {
    KitSurfaceLevel.ground => KitSurfaceLevel.surface1,
    KitSurfaceLevel.surface1 => KitSurfaceLevel.surface2,
    KitSurfaceLevel.surface2 => KitSurfaceLevel.surface3,
    KitSurfaceLevel.surface3 => KitSurfaceLevel.surface3,
  };
  final base = tokens.fillOf(surface);
  var hover = step(surface);
  while (hover != KitSurfaceLevel.surface3 && tokens.fillOf(hover) == base) {
    hover = step(hover);
  }
  final pressed = step(hover);
  return (hover: hover, pressed: pressed);
}

/// Paints the keyboard focus ring inside [shape]'s bounds (KitTappable.md
/// "Focus ring": exactly [KitTokens.focusRingWidth], in `accent`, following
/// [shape], never clipped by a parent because it is deflated to stay inside
/// the painted area).
class _KitTappableFocusRingPainter extends CustomPainter {
  const _KitTappableFocusRingPainter({
    required this.shape,
    required this.color,
    required this.width,
  });

  final ShapeBorder shape;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = shape.getOuterPath(rect);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant _KitTappableFocusRingPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.color != color ||
      oldDelegate.width != width;
}

/// The one region that acts on a tap, everywhere (KitTappable.md).
///
/// A 20×20 child sits centred in a 48×48 hit area; a larger child keeps its
/// own size. It always has a keyboard focus ring and, on a fine pointer, a
/// hover fill and the click cursor; a pressed fill replaces the ripple. With
/// a non-empty [menu], right-click, long-press, Shift+F10 and the Menu key
/// all open the same `showKitMenu` popup; to a screen reader the semantic
/// long-press is "Show actions" (it opens the same popup) and each item is
/// also a custom action. A disabled tappable offers no menu on any path.
///
/// States: enabled, hovered, pressed, focused, disabled ([onTap] null, which
/// requires [disabledReason]), selected (semantics only) and menu-open
/// (holds the pressed fill).
class KitTappable extends StatefulWidget {
  const KitTappable({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
    this.disabledReason,
    this.menu = const [],
    this.onLongPress,
    this.tooltip,
    this.shortcut,
    this.shape = KitShape.square,
    this.surface = KitSurfaceLevel.surface1,
    this.role = KitTappableRole.button,
    this.selected,
    this.autofocus = false,
    this.focusNode,
    this.tappableKey,
  }) : assert(
         onTap != null || disabledReason != null,
         'KitTappable needs disabledReason when onTap is null (STATE-8)',
       ),
       assert(
         onLongPress == null || menu.length == 0,
         'onLongPress is a compatibility hook only (KitRow.onLongPress, '
         'KIT-43): it cannot combine with menu. New code uses menu.',
       );

  /// What the region shows. It draws no look of its own beyond the hover,
  /// pressed and focus treatments; the child draws the content.
  final Widget child;

  /// What a tap does. Null disables the tappable (STATE-8): no fill, no
  /// cursor, no Tab stop, and [disabledReason] is required.
  final VoidCallback? onTap;

  /// The semantic name. Null when [child]'s own text names it — it merges
  /// into this node automatically.
  final String? label;

  /// Why [onTap] is null. Required in that case (a debug assert). The host
  /// must also show this as visible text nearby; KitTappable does not draw
  /// it.
  final String? disabledReason;

  /// Right-click, long-press, Shift+F10 or the Menu key open these through
  /// `showKitMenu`, and each item is also a `CustomSemanticsAction`.
  final List<KitMenuItem> menu;

  /// A compatibility hook only (`KitRow.onLongPress`, KIT-43): when set, a
  /// long-press calls it instead of opening a menu. Asserts [menu] is empty.
  /// New code uses [menu].
  final VoidCallback? onLongPress;

  /// Shown on hover (fine pointer, after the platform delay) and on keyboard
  /// focus. Never the only copy of a value the semantics lack.
  final String? tooltip;

  /// A hint appended to the tooltip, e.g. "Ctrl+Enter". The binding itself
  /// lives in the screen's `Shortcuts`.
  final String? shortcut;

  /// The hover fill, the pressed fill and the focus ring follow this shape.
  final KitShape shape;

  /// The surface step this tappable sits on; hover and pressed step up from
  /// it (KitSurface.md).
  final KitSurfaceLevel surface;

  final KitTappableRole role;

  /// Semantics only (a tab, the current item); the look is the child's.
  final bool? selected;

  final bool autofocus;
  final FocusNode? focusNode;

  /// A test handle on the gesture and semantics node (KIT-10).
  final Key? tappableKey;

  bool get _disabled => onTap == null;

  @override
  State<KitTappable> createState() => _KitTappableState();
}

class _KitTappableState extends State<KitTappable> {
  late FocusNode _focusNode;
  final _tooltipKey = GlobalKey<TooltipState>();
  // Keeps the focus/gesture/child subtree (and so the child's own state: a
  // scroll offset, a field's text) alive when the Tooltip wrapper comes or
  // goes with [KitTappable.tooltip].
  final _subtreeKey = GlobalKey(debugLabel: 'KitTappable subtree');
  bool _ownsFocusNode = false;
  bool _hovered = false;
  bool _pressed = false;
  bool _menuOpen = false;
  bool _focusRingVisible = false;

  @override
  void initState() {
    super.initState();
    _attachFocusNode();
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  void _attachFocusNode() {
    final given = widget.focusNode;
    if (given != null) {
      _focusNode = given;
      _ownsFocusNode = false;
    } else {
      _focusNode = FocusNode(debugLabel: 'KitTappable');
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_handleFocusChange);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
  }

  @override
  void didUpdateWidget(covariant KitTappable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _detachFocusNode();
    super.dispose();
  }

  void _handleFocusChange() {
    _setFocusRingVisible(
      _focusNode.hasFocus &&
          FocusManager.instance.highlightMode == FocusHighlightMode.traditional,
    );
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    if (!_focusNode.hasFocus) return;
    _setFocusRingVisible(mode == FocusHighlightMode.traditional);
  }

  void _setFocusRingVisible(bool visible) {
    if (visible == _focusRingVisible) return;
    setState(() => _focusRingVisible = visible);
    // "on keyboard focus" (KitTappable.md Behaviour, Tooltip): the same
    // event that shows the focus ring shows the tooltip.
    if (visible) _tooltipKey.currentState?.ensureTooltipVisible();
  }

  void _invokeMenuItem(KitMenuItem item) {
    final copyText = item.copyText;
    if (copyText != null) {
      KitCopy.copy(context, copyText(), redact: item.redact);
    } else {
      item.onSelected();
    }
  }

  Future<void> _openMenu(Offset? position) async {
    if (widget._disabled || widget.menu.isEmpty) return;
    setState(() => _menuOpen = true);
    try {
      await showKitMenu(context, items: widget.menu, position: position);
    } finally {
      if (mounted) setState(() => _menuOpen = false);
    }
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _pressed = true);
  }

  void _handleTapCancel() {
    setState(() => _pressed = false);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _pressed = false);
    widget.onTap?.call();
  }

  void _handleSecondaryTapUp(TapUpDetails details) {
    _openMenu(details.globalPosition);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final onLongPress = widget.onLongPress;
    if (onLongPress != null) {
      onLongPress();
      return;
    }
    if (widget.menu.isNotEmpty) {
      _openMenu(details.globalPosition);
      return;
    }
    // An empty menu with no onLongPress: show the tooltip if there is one
    // (KitTappable.md "with an empty menu, long-press shows the tooltip and
    // otherwise does nothing").
    _tooltipKey.currentState?.ensureTooltipVisible();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Only keys aimed at this tappable itself: a key bubbling up from a
    // focused descendant (a nested button, a text field) belongs to that
    // descendant and to the app's Shortcuts above us, never to the row.
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isActivate =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
    if (event is KeyDownEvent) {
      if (isActivate) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
      final isMenuKey =
          key == LogicalKeyboardKey.contextMenu ||
          (key == LogicalKeyboardKey.f10 &&
              HardwareKeyboard.instance.isShiftPressed);
      if (isMenuKey && widget.menu.isNotEmpty) {
        _openMenu(null);
        return KeyEventResult.handled;
      }
    } else if (event is KeyRepeatEvent && isActivate) {
      // Key repeat never fires onTap again; the press is still swallowed so
      // nothing else (e.g. a scrollable) reacts to it.
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final disabled = widget._disabled;
    final finePointer = KitLayout.finePointer(context);
    final reduced = KitMotion.reduced(context);
    final shapeBorder = tokens.shapeOf(widget.shape);

    _focusNode.canRequestFocus = !disabled;
    _focusNode.skipTraversal = disabled;

    final levels = _kitTappableFillLevels(tokens, widget.surface);
    Color fill = Colors.transparent;
    if (!disabled) {
      if (_pressed || _menuOpen) {
        fill = tokens.fillOf(levels.pressed);
      } else if (_hovered && finePointer) {
        fill = tokens.fillOf(levels.hover);
      }
    }

    final sized = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: tokens.minTarget,
        minHeight: tokens.minTarget,
      ),
      // widthFactor/heightFactor: 1 shrink-wraps to the child's own size (a
      // plain Center would instead expand to fill whatever the parent
      // offers, since these constraints are loose above the 48 dp floor).
      // The ConstrainedBox then clamps that size up to 48 when the child is
      // smaller, and leaves a larger child at its own size (KitTappable.md
      // "Target").
      child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
    );

    // One widget in every mode (the child subtree never remounts when
    // Effects Off toggles): under reduced motion the duration is zero, so
    // the fill changes at once and no ticker starts. A fill that appears or
    // deepens eases in on `enter`; one that clears eases out on `exit`.
    final Widget filled = AnimatedContainer(
      duration: reduced ? Duration.zero : KitMotion.quick,
      curve: fill.a == 0 ? KitMotion.exit : KitMotion.enter,
      decoration: ShapeDecoration(color: fill, shape: shapeBorder),
      child: sized,
    );

    final ringed = Stack(
      fit: StackFit.passthrough,
      children: [
        filled,
        if (_focusRingVisible)
          PositionedDirectional(
            start: 0,
            end: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _KitTappableFocusRingPainter(
                  shape: shapeBorder,
                  color: roles.accent,
                  width: KitTokens.focusRingWidth(context),
                ),
              ),
            ),
          ),
      ],
    );

    final gestured = MouseRegion(
      cursor: !disabled && finePointer
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: disabled ? null : (_) => setState(() => _hovered = true),
      onExit: disabled ? null : (_) => setState(() => _hovered = false),
      child: GestureDetector(
        key: widget.tappableKey,
        behavior: HitTestBehavior.opaque,
        onTapDown: disabled ? null : _handleTapDown,
        onTapCancel: disabled ? null : _handleTapCancel,
        onTapUp: disabled ? null : _handleTapUp,
        onSecondaryTapUp: (disabled || widget.menu.isEmpty)
            ? null
            : _handleSecondaryTapUp,
        onLongPressStart: disabled ? null : _handleLongPressStart,
        excludeFromSemantics: true,
        child: ringed,
      ),
    );

    final focused = KeyedSubtree(
      key: _subtreeKey,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: disabled ? null : _handleKeyEvent,
        child: gestured,
      ),
    );

    final tooltip = widget.tooltip;
    final Widget tipped;
    if (tooltip == null || tooltip.isEmpty) {
      tipped = focused;
    } else {
      final shortcut = widget.shortcut;
      tipped = Tooltip(
        key: _tooltipKey,
        message: shortcut == null ? tooltip : '$tooltip  $shortcut',
        excludeFromSemantics: true,
        // Touch and mouse taps never trigger it (MOT-11: no
        // Feedback.forLongPress haptic either); hover keeps working
        // regardless of trigger mode, and long-press/keyboard focus call
        // TooltipState.ensureTooltipVisible() explicitly above.
        triggerMode: TooltipTriggerMode.manual,
        child: focused,
      );
    }

    // A disabled tappable offers no menu to anyone: pointer and keyboard
    // get none (their handlers are null above), so neither does a screen
    // reader (A11Y-5, gesture-twin parity).
    final hasMenu = !disabled && widget.menu.isNotEmpty;
    final customActions = <CustomSemanticsAction, VoidCallback>{
      if (hasMenu)
        for (final item in widget.menu.where((item) => item.enabled))
          CustomSemanticsAction(label: item.label): () => _invokeMenuItem(item),
    };
    // The semantic long-press is the menu's twin, named "Show actions"
    // (KitTappable.md Accessibility); without a menu it is the KitRow
    // compatibility hook, if any.
    final VoidCallback? semanticLongPress = disabled
        ? null
        : hasMenu
        ? () => _openMenu(null)
        : widget.onLongPress;

    return Semantics(
      button: widget.role == KitTappableRole.button,
      link: widget.role == KitTappableRole.link,
      enabled: !disabled,
      selected: widget.selected,
      label: widget.label,
      hint: disabled ? widget.disabledReason : null,
      excludeSemantics: widget.label != null,
      onTap: disabled ? null : widget.onTap,
      onLongPress: semanticLongPress,
      onLongPressHint: hasMenu ? l10n.kitTappableShowActions : null,
      customSemanticsActions: customActions.isEmpty ? null : customActions,
      child: tipped,
    );
  }
}
