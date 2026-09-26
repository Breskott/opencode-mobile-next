import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;

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
/// When a label does not fit on one line — a long word, or text at 2.0 — the
/// frozen spec turns this into a vertical stack of full-width
/// `KitChoiceRow`s (kit-KitChoiceList, KIT-24). That dependency has not
/// merged into this integration branch yet, so this build renders the
/// single-row form only; see docs/qa/revamp-kit-KitSegmented/README.md for
/// the blocked scope. Nothing here invents a substitute stacked layout
/// (R14): the row form is today's behaviour, kept as is until the
/// dependency lands.
///
/// States: disabled.
class KitSegmented<T> extends StatefulWidget {
  // Not `const`: [selected] must be checked against [segments] at
  // construction (G37), and `Iterable.any` with a closure is not a constant
  // expression, so this constructor cannot itself be `const`.
  KitSegmented({
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
       ),
       assert(
         segments.length < 2 ||
             segments.length > 4 ||
             segments.any((s) => s.value == selected),
         'KitSegmented.selected must be the value of one of its segments.',
       );

  /// 2 to 4 choices (G37).
  final List<KitSegment<T>> segments;

  /// One of [segments]' values (G37).
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
  State<KitSegmented<T>> createState() => _KitSegmentedState<T>();
}

class _KitSegmentedState<T> extends State<KitSegmented<T>> {
  late List<FocusNode> _nodes;
  final Set<int> _hovered = {};
  late int _tabbableIndex;

  @override
  void initState() {
    super.initState();
    _nodes = _buildNodes();
    _tabbableIndex = _indexOfSelected();
    _syncNodes();
  }

  List<FocusNode> _buildNodes() => [
    for (var i = 0; i < widget.segments.length; i++)
      FocusNode(
        debugLabel: 'kit-segmented-$i',
        onKeyEvent: (node, event) => _handleKey(i, event),
      ),
  ];

  int _indexOfSelected() {
    final i = widget.segments.indexWhere((s) => s.value == widget.selected);
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(covariant KitSegmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments.length != widget.segments.length) {
      for (final node in _nodes) {
        node.dispose();
      }
      _nodes = _buildNodes();
      _tabbableIndex = _indexOfSelected();
    } else if (oldWidget.selected != widget.selected &&
        !_nodes.any((n) => n.hasFocus)) {
      // Value is truth (DATA-11): with nothing here focused, the tab stop
      // follows the host's selection rather than drifting on its own.
      _tabbableIndex = _indexOfSelected();
    }
    _syncNodes();
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _controlEnabled => widget.onChanged != null;

  void _syncNodes() {
    if (!_controlEnabled || !widget.segments[_tabbableIndex].enabled) {
      final fallback = widget.segments.indexWhere((s) => s.enabled);
      if (fallback >= 0) _tabbableIndex = fallback;
    }
    for (var i = 0; i < _nodes.length; i++) {
      final enabled = _controlEnabled && widget.segments[i].enabled;
      _nodes[i]
        ..canRequestFocus = enabled
        ..skipTraversal = i != _tabbableIndex;
    }
  }

  int? _nextEnabled(int from, {required bool forward}) {
    final n = widget.segments.length;
    for (var step = 1; step <= n; step++) {
      final i = forward ? (from + step) % n : (from - step + n) % n;
      if (_controlEnabled && widget.segments[i].enabled) return i;
    }
    return null;
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    int? target;
    // Arrows move focus only; they never select (the same rule as
    // KitChoiceList).
    if (key == LogicalKeyboardKey.arrowRight) {
      target = _nextEnabled(index, forward: !rtl);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      target = _nextEnabled(index, forward: rtl);
    }
    if (target != null && target != index) {
      setState(() {
        _tabbableIndex = target!;
        _syncNodes();
      });
      _nodes[target].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _select(int index) {
    final segment = widget.segments[index];
    if (!_controlEnabled || !segment.enabled) return;
    setState(() {
      _tabbableIndex = index;
      _syncNodes();
    });
    _nodes[index].requestFocus();
    if (segment.value != widget.selected) widget.onChanged!(segment.value);
  }

  String _formatCount(BuildContext context, int count) =>
      NumberFormat.decimalPattern(
        Localizations.localeOf(context).toString(),
      ).format(count);

  /// Distinct reasons to show under the control, in first-seen order.
  List<String> _reasons() {
    if (!_controlEnabled) return [widget.disabledReason!];
    final seen = <String>{};
    return [
      for (final segment in widget.segments)
        if (!segment.enabled && seen.add(segment.disabledReason!))
          segment.disabledReason!,
    ];
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: widget.semanticsLabel,
    child: ListenableBuilder(
      listenable: Listenable.merge(_nodes),
      builder: (context, _) => _content(context),
    ),
  );

  Widget _content(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final reduced = KitMotion.reduced(context);
    final hairline = KitTokens.hairlineWidth(context);
    final n = widget.segments.length;
    final selectedIndex = _indexOfSelected();
    final indicatorAlign = n > 1
        ? AlignmentDirectional(-1 + selectedIndex * (2 / (n - 1)), 0)
        : AlignmentDirectional.center;
    final reasons = _reasons();

    final track = Container(
      // `BoxDecoration.border` already insets the child by its own width
      // (`Container` folds a decoration's padding in), so no extra padding
      // is added here; the track is taller by that inset so a segment never
      // shrinks under [KitTokens.minTarget] (A11Y-3).
      height: tokens.minTarget + 2 * hairline,
      decoration: BoxDecoration(
        color: roles.surface1,
        borderRadius: BorderRadius.circular(tokens.buttonRadius),
        border: Border.all(color: roles.hairline, width: hairline),
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
                  border: Border.all(color: roles.hairline, width: hairline),
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

    if (reasons.isEmpty) return track;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        track,
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
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.space1 / 2),
                  child: KitText(reason, role: KitTextRole.secondary),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _segment(BuildContext context, int index, {required bool reduced}) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final segment = widget.segments[index];
    final isSelected = segment.value == widget.selected;
    final enabled = _controlEnabled && segment.enabled;
    final hovered = enabled && !isSelected && _hovered.contains(index);
    final node = _nodes[index];
    final focused = node.hasFocus;

    final Color color = !enabled
        ? roles.text3
        : isSelected
        ? roles.text1
        : roles.text2;
    final Color? fill = hovered
        ? (roles.isDark ? roles.surface2 : roles.surface3)
        : null;
    final iconSize = tokens.iconSize(context, tokens.smallIconSize);

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
              key: const ValueKey('kit-segmented-check'),
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
          child: Text(
            segment.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KitText.styleOf(
              context,
              KitTextRole.label,
              tone: !enabled
                  ? KitTextTone.tertiary
                  : isSelected
                  ? KitTextTone.primary
                  : KitTextTone.secondary,
            ),
          ),
        ),
        if (count != null) ...[
          SizedBox(width: tokens.space1),
          Text(
            _formatCount(context, count),
            style: KitText.styleOf(
              context,
              KitTextRole.caption,
              tone: !enabled
                  ? KitTextTone.tertiary
                  : isSelected
                  ? KitTextTone.primary
                  : KitTextTone.secondary,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? () => _select(index) : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: enabled ? (_) => setState(() => _hovered.add(index)) : null,
        onExit: (_) => setState(() => _hovered.remove(index)),
        child: InkWell(
          key: segment.key,
          focusNode: node,
          canRequestFocus: enabled,
          onTap: enabled ? () => _select(index) : null,
          borderRadius: BorderRadius.circular(
            tokens.buttonRadius - tokens.space1,
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: tokens.minTarget),
            alignment: Alignment.center,
            padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.space2),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(
                tokens.buttonRadius - tokens.space1,
              ),
              border: focused
                  ? Border.all(
                      color: roles.accent,
                      width: KitTokens.focusRingWidth(context),
                    )
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
