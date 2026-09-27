import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'glass/kit_glass.dart';
import 'kit_bottom_inset.dart';
import 'kit_buttons.dart';
import 'kit_icon.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_needs_you.dart';
import 'kit_tappable.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// One destination. The same list builds the dock, the rail and the sidebar
/// (docs/ux-system/kit-api/KitNav.md).
@immutable
class KitNavDestination {
  const KitNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.needsYou = 0,
    this.pane,
    this.key,
  });

  /// "Work", "Inbox", "Project", "Settings": always visible (A11Y-1).
  final String label;

  /// An [AppIconography] glyph.
  final IconData icon;

  /// The fill glyph, dock only (LOOK-33).
  final IconData? selectedIcon;

  /// The [KitNeedsYou.badge] count (Inbox). KitNav never counts (AUTO-11).
  final int needsYou;

  /// Expanded and wider: this destination's list, shown in the sidebar.
  final WidgetBuilder? pane;

  /// The destination's hit area (a test handle, KIT-10).
  final Key? key;
}

enum KitNavLayout {
  /// compact: the floating glass dock at the bottom.
  dock,

  /// medium: a floating glass rail at the start, icons with labels.
  rail,

  /// expanded and large: the 296 dp sidebar at the start (wider with larger text,
  /// KitLayout.sidebarWidth).
  sidebar,
}

/// The shell's navigation frame (kit-v2.md §8.1, §8.2, §9.2; VL §4–§6).
/// [child] is the content (the shell's KitScreen with KitTopBar.shell on
/// compact/medium; the selected destination's detail pane on expanded+).
///
/// States: default (one selected), needs-you (a badge on a destination),
/// dock hidden (keyboard open), glass solid (Effects › Glass off, high
/// contrast, accessible navigation, remove animations: [KitGlass] falls
/// back). No disabled destination: an unavailable one is absent (LAY-15).
class KitNav extends StatelessWidget {
  const KitNav({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelected,
    required this.child,
    this.sidebarHeader,
    this.sidebarPrimary,
    this.navKey,
  }) : assert(
         destinations.length >= 2 && destinations.length <= 5,
         'KitNav takes two to five destinations',
       ),
       assert(selected >= 0 && selected < destinations.length);

  /// Two to five, in the caller's order.
  final List<KitNavDestination> destinations;

  /// An index into [destinations].
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget child;

  /// `KitShellControls(layout: sidebar)`; sidebar only.
  final Widget? sidebarHeader;

  /// The sidebar's pinned primary ("New conversation"); sidebar only.
  final KitAction? sidebarPrimary;

  /// A handle on the dock, rail or sidebar widget.
  final Key? navKey;

  /// The layout KitNav uses in this window (from [KitLayout.windowOf], with
  /// the short-window rule: < 480 dp tall keeps dock/rail).
  static KitNavLayout layoutOf(BuildContext context) {
    final window = KitLayout.windowOf(context);
    if (window == KitWindow.compact) return KitNavLayout.dock;
    if (window == KitWindow.medium || KitLayout.isShort(context)) {
      return KitNavLayout.rail;
    }
    return KitNavLayout.sidebar;
  }

  /// True below a KitNav whose sidebar is showing the selected destination's
  /// [KitNavDestination.pane]. KitScreen.twoPane reads it and leaves its own
  /// list out (the list is already in the sidebar).
  static bool hostsPane(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_KitNavScope>()?.hostsPane ??
      false;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final media = MediaQuery.of(context);
    final layout = layoutOf(context);
    final Widget frame;
    switch (layout) {
      case KitNavLayout.dock:
        // Hidden while the keyboard is open, at once (the keyboard moves).
        final keyboardOpen = media.viewInsets.bottom > 0;
        final dockWidth = media.size.width - 2 * tokens.gutter;
        final dockHeight = keyboardOpen
            ? 0.0
            : _dockHeight(context, destinations, dockWidth);
        frame = Stack(
          fit: StackFit.expand,
          children: [
            KitBottomInset.add(
              extraBottom: keyboardOpen ? 0 : tokens.space2 + dockHeight,
              child: _KitNavScope(hostsPane: false, child: child),
            ),
            if (!keyboardOpen)
              PositionedDirectional(
                start: tokens.gutter,
                end: tokens.gutter,
                bottom: media.padding.bottom + tokens.space2,
                child: KitNavBar(
                  key: navKey,
                  destinations: destinations,
                  selected: selected,
                  onSelected: onSelected,
                ),
              ),
          ],
        );
      case KitNavLayout.rail:
        final railBand = KitLayout.railWidth + tokens.space2;
        frame = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: railBand,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: tokens.space2,
                  top: media.padding.top + tokens.space2,
                  bottom: media.padding.bottom + tokens.space2,
                ),
                child: KitNavRail(
                  key: navKey,
                  destinations: destinations,
                  selected: selected,
                  onSelected: onSelected,
                ),
              ),
            ),
            Expanded(
              child: KitBottomInset.add(
                extraBottom: 0,
                start: railBand,
                child: _KitNavScope(hostsPane: false, child: child),
              ),
            ),
          ],
        );
      case KitNavLayout.sidebar:
        frame = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KitNavRail(
              key: navKey,
              destinations: destinations,
              selected: selected,
              onSelected: onSelected,
              extended: true,
              header: sidebarHeader,
              primary: sidebarPrimary,
            ),
            Expanded(
              child: KitBottomInset.add(
                extraBottom: 0,
                start: KitLayout.sidebarWidth(context),
                child: _KitNavScope(
                  hostsPane: destinations[selected].pane != null,
                  child: child,
                ),
              ),
            ),
          ],
        );
    }
    // One backdrop read for the dock, the rail and the top controls
    // (LOOK-28).
    return BackdropGroup(child: frame);
  }
}

class _KitNavScope extends InheritedWidget {
  const _KitNavScope({required this.hostsPane, required super.child});

  final bool hostsPane;

  @override
  bool updateShouldNotify(_KitNavScope oldWidget) =>
      hostsPane != oldWidget.hostsPane;
}

/// The floating dock (compact). Public for galleries and tests; the app
/// uses [KitNav].
///
/// States: none — its destinations always open (see [KitNav]).
class KitNavBar extends StatelessWidget {
  const KitNavBar({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final List<KitNavDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 2 * tokens.gutter;
        final metrics = _labelMetrics(
          context,
          destinations,
          width / destinations.length,
        );
        return KitGlass(
          dim: true,
          borderRadius: BorderRadius.circular(tokens.navRadius),
          child: SizedBox(
            height: _dockHeightFor(tokens, metrics),
            width: width,
            child: _KitNavItems(
              axis: Axis.horizontal,
              destinations: destinations,
              selected: selected,
              onSelected: onSelected,
              metrics: metrics,
              slotExtent: width / destinations.length,
            ),
          ),
        );
      },
    );
  }
}

/// The rail (medium) or, with [extended], the sidebar column (expanded+).
/// Public for galleries and tests; the app uses [KitNav].
///
/// States: none — its destinations always open (see [KitNav]).
class KitNavRail extends StatelessWidget {
  const KitNavRail({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelected,
    this.extended = false,
    this.header,
    this.primary,
  });

  final List<KitNavDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelected;

  /// The sidebar (296 dp, wider with larger text) instead of the glass rail.
  final bool extended;

  /// Sidebar only: the top controls (glass, VL §6).
  final Widget? header;

  /// Sidebar only: the pinned full-width primary.
  final KitAction? primary;

  @override
  Widget build(BuildContext context) =>
      extended ? _buildSidebar(context) : _buildRail(context);

  Widget _buildRail(BuildContext context) {
    final tokens = KitTokens.of(context);
    final metrics = _labelMetrics(context, destinations, KitLayout.railWidth);
    return SizedBox(
      width: KitLayout.railWidth,
      child: KitGlass(
        dim: true,
        borderRadius: BorderRadius.circular(tokens.navRadius),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.space2),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: _KitNavItems(
              axis: Axis.vertical,
              destinations: destinations,
              selected: selected,
              onSelected: onSelected,
              metrics: metrics,
              slotExtent: _itemExtent(tokens, metrics),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final media = MediaQuery.of(context);
    final pane = destinations[selected].pane;
    final action = primary;
    return Container(
      // 296 dp, wider with larger text (KitLayout.sidebarWidth).
      width: KitLayout.sidebarWidth(context),
      decoration: BoxDecoration(
        color: roles.ground,
        border: BorderDirectional(
          end: BorderSide(
            color: roles.hairline,
            width: KitTokens.hairlineWidth(context),
          ),
        ),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.space3,
        media.padding.top + tokens.space3,
        tokens.space3,
        media.padding.bottom + tokens.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          if (header != null) SizedBox(height: tokens.space3),
          _KitNavItems(
            axis: Axis.vertical,
            sidebar: true,
            destinations: destinations,
            selected: selected,
            onSelected: onSelected,
            metrics: const _LabelMetrics(maxScale: 1, labelHeight: 0),
            slotExtent: tokens.minTarget,
          ),
          if (pane != null) ...[
            SizedBox(height: tokens.sectionGap),
            Expanded(child: Builder(builder: pane)),
          ] else
            const Spacer(),
          if (action != null) ...[
            SizedBox(height: tokens.space3),
            KitButton.fromAction(action, role: KitButtonRole.primary),
          ],
        ],
      ),
    );
  }
}

// ── Metrics ─────────────────────────────────────────────────────────────

/// The lens: a clear pill behind the glyph, the chip's visual height and a
/// target-and-a-half wide.
double _lensHeight() => KitTokens.chipHeight;
double _lensWidth(KitTokens tokens) => tokens.minTarget + tokens.space2;

@immutable
class _LabelMetrics {
  const _LabelMetrics({required this.maxScale, required this.labelHeight});

  /// The label clamp here: up to [KitTokens.navLabelMaxScale], never beyond
  /// what fits one label per destination (A11Y-8).
  final double maxScale;

  /// One label line at the clamped scale, rounded up to a whole dp.
  final double labelHeight;
}

_LabelMetrics _labelMetrics(
  BuildContext context,
  List<KitNavDestination> destinations,
  double slotWidth,
) {
  final tokens = KitTokens.of(context);
  final style = KitText.styleOf(context, KitTextRole.label);
  final direction = Directionality.of(context);
  final room = slotWidth - tokens.space2;
  var maxScale = KitTokens.navLabelMaxScale;
  for (final destination in destinations) {
    final painter = TextPainter(
      text: TextSpan(text: destination.label, style: style),
      textDirection: direction,
      maxLines: 1,
    )..layout();
    if (painter.width > 0) maxScale = math.min(maxScale, room / painter.width);
    painter.dispose();
  }
  maxScale = maxScale.clamp(1.0, KitTokens.navLabelMaxScale);
  final scaler = MediaQuery.textScalerOf(
    context,
  ).clamp(maxScaleFactor: maxScale);
  final line = TextPainter(
    text: TextSpan(text: 'Ag', style: style),
    textDirection: direction,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final height = line.height.ceilToDouble();
  line.dispose();
  return _LabelMetrics(maxScale: maxScale, labelHeight: height);
}

/// Lens + label with [KitTokens.space1] above and below: 60 dp at 1.0, taller
/// when the labels grow.
double _dockHeightFor(KitTokens tokens, _LabelMetrics metrics) => math.max(
  tokens.navHeight,
  _lensHeight() + metrics.labelHeight + 2 * tokens.space1,
);

double _dockHeight(
  BuildContext context,
  List<KitNavDestination> destinations,
  double width,
) => _dockHeightFor(
  KitTokens.of(context),
  _labelMetrics(context, destinations, width / destinations.length),
);

/// Above the dock's lens: the lens and label centred in the bar.
double _dockTopPad(KitTokens tokens, _LabelMetrics metrics) =>
    ((_dockHeightFor(tokens, metrics) - _lensHeight() - metrics.labelHeight) /
            2)
        .floorToDouble();

/// One rail destination: lens, label and [KitTokens.space1] around both.
double _itemExtent(KitTokens tokens, _LabelMetrics metrics) => math.max(
  tokens.minTarget,
  _lensHeight() + metrics.labelHeight + 3 * tokens.space1,
);

// ── Destinations ────────────────────────────────────────────────────────

/// The destinations as one focus group: Tab enters at the selected one,
/// arrows move (Left/Right in the dock, Up/Down in the rail and sidebar),
/// Enter/Space selects (KitTappable).
class _KitNavItems extends StatefulWidget {
  const _KitNavItems({
    required this.axis,
    required this.destinations,
    required this.selected,
    required this.onSelected,
    required this.metrics,
    required this.slotExtent,
    this.sidebar = false,
  });

  final Axis axis;
  final List<KitNavDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelected;
  final _LabelMetrics metrics;

  /// A dock slot's width, a rail item's height, a sidebar row's minimum.
  final double slotExtent;
  final bool sidebar;

  @override
  State<_KitNavItems> createState() => _KitNavItemsState();
}

class _KitNavItemsState extends State<_KitNavItems> {
  final List<FocusNode> _nodes = [];

  void _syncNodes() {
    while (_nodes.length < widget.destinations.length) {
      _nodes.add(FocusNode(debugLabel: 'KitNav ${_nodes.length}'));
    }
    while (_nodes.length > widget.destinations.length) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final current = _nodes.indexWhere((node) => node.hasFocus);
    if (current < 0) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    int? step;
    if (widget.axis == Axis.horizontal) {
      if (key == LogicalKeyboardKey.arrowRight) step = rtl ? -1 : 1;
      if (key == LogicalKeyboardKey.arrowLeft) step = rtl ? 1 : -1;
    } else {
      if (key == LogicalKeyboardKey.arrowDown) step = 1;
      if (key == LogicalKeyboardKey.arrowUp) step = -1;
    }
    if (step == null) return KeyEventResult.ignored;
    final next = (current + step).clamp(0, _nodes.length - 1);
    _nodes[next].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _syncNodes();
    final tokens = KitTokens.of(context);
    final reduced = KitMotion.reduced(context);
    final metrics = widget.metrics;
    final items = <Widget>[
      for (var i = 0; i < widget.destinations.length; i++)
        // Roving tab stop: only the selected destination is a Tab stop; the
        // arrows reach the others.
        ExcludeFocusTraversal(
          excluding: i != widget.selected,
          child: _KitNavItem(
            destination: widget.destinations[i],
            selected: i == widget.selected,
            onTap: () => widget.onSelected(i),
            focusNode: _nodes[i],
            axis: widget.axis,
            sidebar: widget.sidebar,
            metrics: metrics,
            extent: widget.slotExtent,
            topPad: widget.axis == Axis.horizontal
                ? _dockTopPad(tokens, metrics)
                : tokens.space1,
          ),
        ),
    ];

    Widget body;
    if (widget.sidebar) {
      body = Column(mainAxisSize: MainAxisSize.min, children: items);
    } else {
      final lensWidth = _lensWidth(tokens);
      final lensHeight = _lensHeight();
      final duration = reduced ? Duration.zero : KitMotion.standard;
      final double lensStart;
      final double lensTop;
      if (widget.axis == Axis.horizontal) {
        lensStart =
            widget.selected * widget.slotExtent +
            (widget.slotExtent - lensWidth) / 2;
        lensTop = _dockTopPad(tokens, metrics);
      } else {
        lensStart = (KitLayout.railWidth - lensWidth) / 2;
        lensTop = widget.selected * widget.slotExtent + tokens.space1;
      }
      body = Stack(
        children: [
          AnimatedPositionedDirectional(
            duration: duration,
            curve: KitMotion.emphasized,
            start: lensStart,
            top: lensTop,
            width: lensWidth,
            height: lensHeight,
            child: const _KitNavLens(),
          ),
          if (widget.axis == Axis.horizontal)
            Row(children: items)
          else
            Column(mainAxisSize: MainAxisSize.min, children: items),
        ],
      );
    }
    return FocusTraversalGroup(
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: body,
      ),
    );
  }
}

/// The selected tab's glass lens: a clear pill with a one physical pixel
/// rim, never a second glass layer (glass never sits on glass, VL §6).
class _KitNavLens extends StatelessWidget {
  const _KitNavLens();

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tokens.roles.surface3,
        shape: StadiumBorder(
          side: BorderSide(
            color: tokens.roles.hairline,
            width: KitTokens.hairlineWidth(context),
          ),
        ),
      ),
    );
  }
}

class _KitNavItem extends StatefulWidget {
  const _KitNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.focusNode,
    required this.axis,
    required this.sidebar,
    required this.metrics,
    required this.extent,
    required this.topPad,
  });

  final KitNavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final FocusNode focusNode;
  final Axis axis;
  final bool sidebar;
  final _LabelMetrics metrics;
  final double extent;

  /// Above the lens, so glyph and lens line up (the lens is laid out by the
  /// group, not by the item).
  final double topPad;

  @override
  State<_KitNavItem> createState() => _KitNavItemState();
}

class _KitNavItemState extends State<_KitNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final reduced = KitMotion.reduced(context);
    final destination = widget.destination;
    final selected = widget.selected;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final count = destination.needsYou;
    final semanticsLabel = count > 0
        ? '${destination.label}${l10n.kitNeedsYouBadgeSuffix(count)}'
        : destination.label;
    final strong = selected || (_hovered && KitLayout.finePointer(context));
    final tone = strong ? KitTextTone.primary : KitTextTone.secondary;

    final Widget content;
    if (widget.sidebar) {
      content = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space3,
          vertical: tokens.space2,
        ),
        child: Row(
          children: [
            KitNeedsYou.badge(
              count: count,
              child: KitIcon(
                destination.icon,
                size: KitIconSize.medium,
                tone: tone,
              ),
            ),
            SizedBox(width: tokens.space3),
            Expanded(
              child: KitText(
                destination.label,
                role: KitTextRole.rowTitle,
                tone: tone,
              ),
            ),
          ],
        ),
      );
    } else {
      final glyph = selected
          ? destination.selectedIcon ?? destination.icon
          : destination.icon;
      final label = MediaQuery.withClampedTextScaling(
        maxScaleFactor: widget.metrics.maxScale,
        child: AnimatedSwitcher(
          duration: reduced ? Duration.zero : KitMotion.quick,
          child: KitText(
            destination.label,
            key: ValueKey(tone),
            role: KitTextRole.label,
            tone: tone,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      );
      final stack = Column(
        children: [
          SizedBox(height: widget.topPad),
          SizedBox(
            height: _lensHeight(),
            child: Center(
              child: KitNeedsYou.badge(
                count: count,
                child: KitIcon(glyph, tone: tone),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.space1),
            child: label,
          ),
        ],
      );
      content = widget.axis == Axis.horizontal
          ? SizedBox(
              width: widget.extent,
              height: double.infinity,
              child: stack,
            )
          : SizedBox(
              width: KitLayout.railWidth,
              height: widget.extent,
              child: stack,
            );
    }

    Widget tappable = KitTappable(
      onTap: widget.onTap,
      label: semanticsLabel,
      selected: selected,
      focusNode: widget.focusNode,
      tappableKey: destination.key,
      shape: widget.sidebar ? KitShape.button : KitShape.pill,
      surface: widget.sidebar
          ? (selected ? KitSurfaceLevel.surface3 : KitSurfaceLevel.ground)
          : KitSurfaceLevel.surface2,
      child: content,
    );
    if (widget.sidebar) {
      // The Desktop canvas: the selected row is a solid surface3 step.
      tappable = DecoratedBox(
        decoration: ShapeDecoration(
          color: selected ? tokens.roles.surface3 : Colors.transparent,
          shape: tokens.shapeOf(KitShape.button),
        ),
        child: tappable,
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: tappable,
    );
  }
}
