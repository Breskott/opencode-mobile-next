import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;

import 'kit_choice_list.dart';
import 'kit_motion.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// One choice of a [KitSegmented] group
/// (docs/ux-system/kit-api/KitSegmented.md): a value, its visible label and
/// optional leading icon and count, and whether it can be chosen right now.
/// An icon alone is never enough — [label] always carries the words.
@immutable
class KitSegment<T> {
  const KitSegment({
    required this.value,
    required this.label,
    this.icon,
    this.count,
    this.enabled = true,
    this.disabledReason,
    this.key,
  }) : assert(
         enabled || disabledReason != null,
         'KitSegment.disabledReason is required when enabled is false: a '
         'disabled choice always shows why (STATE-8).',
       );

  final T value;
  final String label;
  final IconData? icon;

  /// "Needs you 2": tabular figures, part of the label's semantics.
  final int? count;
  final bool enabled;

  /// Shown as text under the control when this segment is disabled:
  /// "Chosen at install · reinstall to change".
  final String? disabledReason;
  final Key? key;
}

/// One choice among 2–4 short, always-visible options (design standard §2,
/// §5; kit v2 §1.6, §8.2; docs/ux-system/kit-api/KitSegmented.md): a scope, a
/// mode, a range or a filter. Full width, start-aligned, never a centred
/// pill, and marks the chosen segment with a check rather than colour alone.
///
/// Its scenes (KitSegmented.md "States"): default (one selected),
/// with-counts, segment-disabled (the reason under the control), disabled
/// (the whole control, with its reason) and stacked.
///
/// Stacked (KIT-24, Appendix A #78): the part measures, the way KitAskLine
/// does, whether every segment's check, icon, label and count fit on one
/// line in its equal share of the width. When one does not, or the text
/// scale is 2.0 or more, the track gives way to a vertical stack of
/// full-width [KitChoiceRow]s with radio marks: the same order, values and
/// keys, a disabled segment's reason on its own row, and still one
/// mutually exclusive group with one Tab stop (Arrow Up and Down, Home and
/// End, and Left and Right in reading order move focus there). Nothing
/// truncates in either form. The switch is a layout change with no
/// animation.
///
/// States: disabled.
class KitSegmented<T> extends StatelessWidget {
  const KitSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.semanticsLabel,
    this.disabledReason,
  }) : assert(
         segments.length >= 2 && segments.length <= 4,
         'KitSegmented needs 2 to 4 segments (KitSegmented.md); use '
         'KitPickerRow for more.',
       ),
       assert(
         onChanged != null || disabledReason != null,
         'KitSegmented.disabledReason is required when onChanged is null.',
       );

  /// 2 to 4 choices (G37).
  final List<KitSegment<T>> segments;

  /// One of [segments]' values (G37, checked when the control builds).
  final T selected;

  /// Null disables the whole control (then [disabledReason] is required).
  /// Called once per activation of a *different* enabled segment; activating
  /// the selected segment does nothing.
  final ValueChanged<T>? onChanged;

  /// The group's name ("Time range"): announced, and named by a visible
  /// `SectionLabel` above the control (the caller's job, not this part's).
  final String semanticsLabel;

  /// Shown as text under the control when [onChanged] is null.
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    // Not in the constructor: `Iterable.any` is not a constant expression,
    // and the constructor stays `const` as the frozen API declares it.
    assert(
      segments.any((s) => s.value == selected),
      'KitSegmented.selected must be the value of one of its segments.',
    );
    return _SegmentedGroup<T>(part: this);
  }
}

/// The focus, hover and press bookkeeping behind [KitSegmented]. The
/// selection itself is never kept here: value is truth (DATA-11).
class _SegmentedGroup<T> extends StatefulWidget {
  const _SegmentedGroup({required this.part});

  final KitSegmented<T> part;

  @override
  State<_SegmentedGroup<T>> createState() => _SegmentedGroupState<T>();
}

class _SegmentedGroupState<T> extends State<_SegmentedGroup<T>> {
  late List<FocusNode> _nodes;

  /// The stacked form's rows. Their own nodes: a [KitChoiceRow]'s
  /// KitTappable installs its own key handler on the node it is given.
  late List<FocusNode> _stackNodes;

  /// The segment holding keyboard focus; null while focus is outside the
  /// group, so Tab enters on the selected segment again.
  int? _focused;

  /// The segment showing the keyboard focus ring (focus came from the
  /// keyboard: `FocusHighlightMode.traditional`).
  int? _ring;
  int? _hovered;
  int? _pressed;

  KitSegmented<T> get _part => widget.part;
  List<KitSegment<T>> get _segments => _part.segments;
  bool get _controlEnabled => _part.onChanged != null;
  bool _canChoose(int index) => _controlEnabled && _segments[index].enabled;

  @override
  void initState() {
    super.initState();
    _nodes = _buildNodes();
    _stackNodes = _buildStackNodes();
  }

  List<FocusNode> _buildNodes() => [
    for (var i = 0; i < _segments.length; i++)
      FocusNode(
        debugLabel: 'kit-segmented-$i',
        onKeyEvent: (node, event) => _handleKey(i, event),
      ),
  ];

  List<FocusNode> _buildStackNodes() => [
    for (var i = 0; i < _segments.length; i++)
      FocusNode(debugLabel: 'kit-segmented-row-$i'),
  ];

  @override
  void didUpdateWidget(covariant _SegmentedGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.segments.length != _segments.length) {
      for (final node in [..._nodes, ..._stackNodes]) {
        node.dispose();
      }
      _nodes = _buildNodes();
      _stackNodes = _buildStackNodes();
      _focused = _ring = _hovered = _pressed = null;
    }
  }

  @override
  void dispose() {
    for (final node in [..._nodes, ..._stackNodes]) {
      node.dispose();
    }
    super.dispose();
  }

  int _selectedIndex() {
    final i = _segments.indexWhere((s) => s.value == _part.selected);
    return i < 0 ? 0 : i;
  }

  /// Where Tab enters the group: the selected segment, or the first one
  /// that can be chosen when the selected one cannot.
  int _entryIndex() {
    final selected = _selectedIndex();
    if (_canChoose(selected)) return selected;
    for (var i = 0; i < _segments.length; i++) {
      if (_canChoose(i)) return i;
    }
    return selected;
  }

  /// The group is one Tab stop (§8.2, G14): only the focused segment, or
  /// the entry segment when nothing here is focused, takes part in Tab.
  int _stopIndex() {
    final focused = _focused;
    return focused != null && focused < _nodes.length ? focused : _entryIndex();
  }

  /// [_OneStopPolicy]'s view of the group: which nodes are segments (both
  /// forms; only one is mounted) and which of them Tab may reach.
  bool _isSegmentNode(FocusNode node) =>
      _nodes.contains(node) || _stackNodes.contains(node);

  bool _isStopNode(FocusNode node) {
    final stop = _stopIndex();
    return node == _nodes[stop] || node == _stackNodes[stop];
  }

  late final _policy = _OneStopPolicy(
    isSegment: _isSegmentNode,
    isStop: _isStopNode,
  );

  void _groupFocusChanged(bool hasFocus) {
    if (hasFocus || _focused == null) return;
    setState(() => _focused = null);
  }

  void _segmentFocusChanged(int index, bool hasFocus) {
    if (!hasFocus) return;
    setState(() => _focused = index);
  }

  int? _nextChoosable(int from, {required bool forward}) {
    final n = _segments.length;
    for (var step = 1; step <= n; step++) {
      final i = forward ? (from + step) % n : (from - step + n) % n;
      if (_canChoose(i)) return i;
    }
    return null;
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final right = key == LogicalKeyboardKey.arrowRight;
    if (!right && key != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    // Arrows follow the reading direction and move focus only; they never
    // select (the same rule as KitChoiceList). They stay inside the group,
    // even when no other segment can take focus.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final target = _nextChoosable(index, forward: right != rtl);
    if (target != null && target != index) _nodes[target].requestFocus();
    return KeyEventResult.handled;
  }

  /// The stacked form's arrows: Up and Down (Home and End jump; Left and
  /// Right follow the reading direction), focus only, never a selection;
  /// they stay inside the group.
  KeyEventResult _handleStackKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final at = _stackNodes.indexWhere((node) => node.hasPrimaryFocus);
    if (at < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final choosable = [
      for (var i = 0; i < _segments.length; i++)
        if (_canChoose(i)) i,
    ];
    // Left and Right keep working as in the row form (reading direction),
    // so a person who learned them is not stranded when the part stacks.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final next =
        key == LogicalKeyboardKey.arrowDown ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowRight);
    final previous =
        key == LogicalKeyboardKey.arrowUp ||
        key ==
            (rtl
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft);
    final int? target;
    if (next || previous) {
      target = _nextChoosable(at, forward: next);
    } else if (key == LogicalKeyboardKey.home) {
      target = choosable.firstOrNull;
    } else if (key == LogicalKeyboardKey.end) {
      target = choosable.lastOrNull;
    } else {
      return KeyEventResult.ignored;
    }
    if (target != null && target != at) _stackNodes[target].requestFocus();
    return KeyEventResult.handled;
  }

  /// A tap, Space/Enter or the semantics tap. It never moves focus: a touch
  /// does not leave a keyboard ring behind.
  void _choose(int index) {
    if (!_canChoose(index)) return;
    final value = _segments[index].value;
    if (value != _part.selected) _part.onChanged!(value);
  }

  void _setHovered(int index, bool hovered) {
    final next = hovered ? index : (_hovered == index ? null : _hovered);
    if (next != _hovered) setState(() => _hovered = next);
  }

  void _setPressed(int index, bool pressed) {
    final next = pressed ? index : (_pressed == index ? null : _pressed);
    if (next != _pressed) setState(() => _pressed = next);
  }

  String _formatCount(BuildContext context, int count) =>
      NumberFormat.decimalPattern(
        Localizations.localeOf(context).toString(),
      ).format(count);

  /// Distinct reasons to show under the control, in first-seen order.
  List<String> _reasons() {
    if (!_controlEnabled) return [_part.disabledReason!];
    final seen = <String>{};
    return [
      for (final segment in _segments)
        if (!segment.enabled && seen.add(segment.disabledReason!))
          segment.disabledReason!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: _part.semanticsLabel,
      child: FocusTraversalGroup(
        policy: _policy,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onFocusChange: _groupFocusChanged,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = _stacks(context, constraints.maxWidth);
              return _withReasons(
                context,
                stacked ? _stack(context) : _track(context),
                // In the stack a disabled segment's reason is on its row;
                // only the whole control's reason stays under it.
                stacked
                    ? [if (!_controlEnabled) _part.disabledReason!]
                    : _reasons(),
              );
            },
          ),
        ),
      ),
    );
  }

  /// KIT-24: whether any segment's one line (check, icon, label, count and
  /// insets) is wider than its equal share of [width], or the text is at
  /// 2.0 or more. Measured like KitAskLine, with the styles the row draws.
  bool _stacks(BuildContext context, double width) {
    final tokens = KitTokens.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = KitText.styleOf(context, KitTextRole.label);
    if (labelStyle.fontSize case final size?
        when scaler.scale(size) / size >= 2) {
      return true;
    }
    if (!width.isFinite) return false;
    final direction = Directionality.of(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final result = painter.width.ceilToDouble();
      painter.dispose();
      return result;
    }

    final countStyle = KitText.styleOf(
      context,
      KitTextRole.caption,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final iconSize = tokens.iconSize(context, tokens.smallIconSize);
    final share =
        (width - 2 * KitTokens.hairlineWidth(context)) / _segments.length;
    for (final segment in _segments) {
      var needed =
          2 * tokens.space2 +
          iconSize +
          tokens.space1 +
          measure(segment.label, labelStyle);
      if (segment.icon != null) needed += iconSize + tokens.space1;
      if (segment.count case final count?) {
        needed +=
            tokens.space1 + measure(_formatCount(context, count), countStyle);
      }
      if (needed > share) return true;
    }
    return false;
  }

  Widget _withReasons(
    BuildContext context,
    Widget control,
    List<String> reasons,
  ) {
    if (reasons.isEmpty) return control;
    final tokens = KitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        control,
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: tokens.space2,
            top: tokens.space1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final reason in reasons)
                KitText(reason, role: KitTextRole.secondary),
            ],
          ),
        ),
      ],
    );
  }

  /// The stacked form (KIT-24): one full-width [KitChoiceRow] per segment
  /// in a `surface1` panel, as KitChoiceList draws its rows.
  Widget _stack(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final iconSize = tokens.iconSize(context, tokens.smallIconSize);
    final rows = <Widget>[
      for (var i = 0; i < _segments.length; i++)
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onFocusChange: (focused) => _segmentFocusChanged(i, focused),
          child: _row(context, i, iconSize: iconSize),
        ),
    ];
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _handleStackKey,
      child: Material(
        color: roles.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 0,
                  thickness: 0,
                  indent: tokens.gutter + tokens.smallIconSize + tokens.space3,
                  color: roles.hairline,
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int index, {required double iconSize}) {
    final roles = KitTokens.of(context).roles;
    final segment = _segments[index];
    final enabled = _canChoose(index);
    final count = segment.count;
    return KitChoiceRow<T>(
      key: segment.key,
      choice: KitChoice<T>(
        value: segment.value,
        title: count == null
            ? segment.label
            : '${segment.label} · ${_formatCount(context, count)}',
        leading: segment.icon == null
            ? null
            : Icon(
                segment.icon,
                size: iconSize,
                color: enabled ? roles.text2 : roles.text3,
              ),
        enabled: segment.enabled,
        disabledReason: segment.disabledReason,
      ),
      selected: segment.value == _part.selected,
      focusNode: _stackNodes[index],
      onTap: enabled ? () => _choose(index) : null,
    );
  }

  Widget _track(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final reduced = KitMotion.reduced(context);
    final hairline = KitTokens.hairlineWidth(context);
    final n = _segments.length;
    final selectedIndex = _selectedIndex();
    final indicatorAlign = n > 1
        ? AlignmentDirectional(-1 + selectedIndex * (2 / (n - 1)), 0)
        : AlignmentDirectional.center;

    return Container(
      // `BoxDecoration.border` already insets the child by its own width
      // (`Container` folds a decoration's padding in), so no extra padding
      // is added here; the track is taller by that inset so a segment never
      // shrinks under [KitTokens.minTarget] (A11Y-3).
      height: tokens.minTarget + 2 * hairline,
      decoration: BoxDecoration(
        color: roles.surface1,
        borderRadius: BorderRadius.circular(tokens.buttonRadius),
        border: Border.all(
          color: roles.hairline,
          width: KitTokens.hairlineWidth(context),
        ),
      ),
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          AnimatedAlign(
            duration: reduced ? Duration.zero : KitMotion.quick,
            curve: KitMotion.enter,
            alignment: indicatorAlign,
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: roles.surface3,
                  borderRadius: BorderRadius.circular(
                    tokens.buttonRadius - tokens.space1,
                  ),
                  border: Border.all(
                    color: roles.hairline,
                    width: KitTokens.hairlineWidth(context),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(child: _segment(context, i, reduced: reduced)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, int index, {required bool reduced}) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final segment = _segments[index];
    final isSelected = segment.value == _part.selected;
    final enabled = _canChoose(index);
    final radius = BorderRadius.circular(tokens.buttonRadius - tokens.space1);

    // Hover and pressed are surface steps above the surface1 track, never
    // overlays (KitTappable's rule, README.md decision D11): hover is the
    // next step whose colour differs (surface2 in dark, surface3 in light),
    // pressed the step after that, at most surface3. The selected segment
    // already sits on the surface3 indicator.
    final KitSurfaceLevel? step = !enabled || isSelected
        ? null
        : _pressed == index
        ? KitSurfaceLevel.surface3
        : _hovered == index
        ? (roles.isDark ? KitSurfaceLevel.surface2 : KitSurfaceLevel.surface3)
        : null;
    final iconSize = tokens.iconSize(context, tokens.smallIconSize);
    final tone = !enabled
        ? KitTextTone.tertiary
        : isSelected
        ? KitTextTone.primary
        : KitTextTone.secondary;
    final Color color = !enabled
        ? roles.text3
        : isSelected
        ? roles.text1
        : roles.text2;

    final count = segment.count;
    final label = count == null
        ? segment.label
        : '${segment.label}, ${_formatCount(context, count)}';

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: isSelected ? 1 : 0,
          duration: reduced ? Duration.zero : KitMotion.quick,
          curve: KitMotion.enter,
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: tokens.space1),
            child: Icon(
              Icons.check,
              size: iconSize,
              color: !enabled ? roles.text3 : roles.accent,
            ),
          ),
        ),
        if (segment.icon case final icon?) ...[
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: tokens.space1),
        ],
        Flexible(
          // One line that always fits: when it would not, the part stacks
          // instead (KIT-24, [_stacks]); nothing truncates.
          child: Text(
            segment.label,
            maxLines: 1,
            softWrap: false,
            style: KitText.styleOf(context, KitTextRole.label, tone: tone),
          ),
        ),
        if (count != null) ...[
          SizedBox(width: tokens.space1),
          Text(
            _formatCount(context, count),
            style: KitText.styleOf(
              context,
              KitTextRole.caption,
              tone: tone,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ],
    );

    return Semantics(
      key: segment.key,
      container: true,
      excludeSemantics: true,
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? () => _choose(index) : null,
      child: FocusableActionDetector(
        focusNode: _nodes[index],
        enabled: enabled,
        includeFocusSemantics: false,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _choose(index);
              return null;
            },
          ),
        },
        onFocusChange: (focused) => _segmentFocusChanged(index, focused),
        onShowFocusHighlight: (show) => setState(
          () => _ring = show ? index : (_ring == index ? null : _ring),
        ),
        // Hover comes from the pointer itself, not the focus highlight mode:
        // a mouse on a phone or tablet leaves that mode on touch.
        child: MouseRegion(
          onEnter: enabled ? (_) => _setHovered(index, true) : null,
          onExit: (_) => _setHovered(index, false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: enabled ? (_) => _setPressed(index, true) : null,
            onTapUp: enabled ? (_) => _setPressed(index, false) : null,
            onTapCancel: enabled ? () => _setPressed(index, false) : null,
            onTap: enabled ? () => _choose(index) : null,
            child: Container(
              constraints: BoxConstraints(minHeight: tokens.minTarget),
              alignment: Alignment.center,
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: tokens.space2,
              ),
              decoration: BoxDecoration(
                color: step == null ? null : tokens.fillOf(step),
                borderRadius: radius,
              ),
              // The keyboard ring is painted over the segment, inside its
              // bounds, so it never moves the content (LOOK-21: 2 physical px
              // in accent).
              foregroundDecoration: _ring == index
                  ? BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: roles.accent,
                        width: KitTokens.focusRingWidth(context),
                      ),
                    )
                  : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The group's one Tab stop (§8.2, G14), decided when Tab is pressed
/// rather than by switching `skipTraversal` on the segments' nodes: a node
/// property changed by a new selection is announced after the frame, and
/// inside the part's LayoutBuilder that announcement would leave a frame
/// callback behind, so one pump() would no longer settle (G8).
class _OneStopPolicy extends WidgetOrderTraversalPolicy {
  _OneStopPolicy({required this.isSegment, required this.isStop});

  final bool Function(FocusNode node) isSegment;
  final bool Function(FocusNode node) isStop;

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) => super
      .sortDescendants(descendants, currentNode)
      .where((node) => node == currentNode || !isSegment(node) || isStop(node));
}
