// KitProgressRow (docs/ux-system/kit-api/KitProgressRow.md): a row holding a
// measured amount — a quota window, one item downloading, the context used,
// a budget. A title, a determinate bar, the amount in words and, when the
// data is old, its age. [KitProgressRow.segments] shows a stacked bar with a
// worded legend, for example what fills a conversation's context.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_layout.dart';
import 'kit_motion.dart';
import 'kit_row_parts.dart' show KitChevron;
import 'kit_text.dart';
import 'kit_tokens.dart';

/// One named share of a [KitProgressRow.segments] stacked bar.
class KitProgressSegment {
  const KitProgressSegment({
    required this.label,
    required this.value,
    this.valueLabel,
  });

  /// "Conversation".
  final String label;

  /// Share of the whole, 0..1; the segments sum to <= 1 (asserted in
  /// debug, scaled to fit in release — KitProgressRow.md "Data safety").
  final double value;

  /// "41k tokens".
  final String? valueLabel;
}

/// One slice actually drawn and listed: either a caller [KitProgressSegment]
/// unchanged, or the folded "Other" bucket (KitProgressRow.md "Purpose": at
/// most 4 named segments, the rest summed into one).
class _Slice {
  const _Slice({required this.label, required this.value, this.valueLabel});
  final String label;
  final double value;
  final String? valueLabel;
}

/// A row holding a measured amount (KitProgressRow.md), built from
/// `KitProgress`'s bar tokens: a quota window, one item downloading, the
/// context used, a budget. The row has a title, a determinate bar, the
/// amount in words and, when the data is old, its age.
///
/// States: loading (`value == null`), loaded (under 80 %), near limit
/// (80–99 %, automatic), at limit (100 %, automatic), stale (`asOf` set),
/// segments, empty. Error and disabled are not in this part: the host
/// carries an error on a `KitNotice` on its section, and a `null` [onTap]
/// is simply not tappable.
class KitProgressRow extends StatelessWidget {
  const KitProgressRow({
    super.key,
    required this.title,
    required this.value,
    this.valueLabel,
    this.leading,
    this.tone,
    this.asOf,
    this.onTap,
    this.titleKey,
    this.valueKey,
  }) : assert(
         tone != AppStatusTone.attention,
         'KitProgressRow: tone must not be attention — STANDARDS LOOK-4 '
         'reserves it for "needs you"; near and at the limit are carried by '
         'words, not colour.',
       ),
       segments = const [],
       _isSegments = false;

  /// A stacked bar with a worded legend under it: what fills a conversation's
  /// context, a budget by provider. At most 4 named segments; the rest are
  /// summed into one "Other" segment.
  const KitProgressRow.segments({
    super.key,
    required this.title,
    required this.segments,
    this.valueLabel,
    this.leading,
    this.asOf,
    this.onTap,
    this.titleKey,
    this.valueKey,
  }) : value = null,
       tone = null,
       _isSegments = true;

  /// "Claude · 5-hour window".
  final String title;

  /// 0..1 (clamped for drawing); null while unknown: a skeleton bar, never
  /// a spinner.
  final double? value;

  /// "62 % · resets in 3 h".
  final String? valueLabel;
  final Widget? leading;

  /// Null is automatic (near/at-limit words from [value]); never
  /// [AppStatusTone.attention] (asserted).
  final AppStatusTone? tone;

  /// Last-known data: shown as "as of 10:42" (offline or stale). A row
  /// without it must be live data — that is the caller's contract.
  final DateTime? asOf;

  /// Opens the detail; adds a [KitChevron].
  final VoidCallback? onTap;
  final List<KitProgressSegment> segments;
  final Key? titleKey;

  /// The key of the value/legend text, for tests.
  final Key? valueKey;

  /// True for [KitProgressRow.segments], where [segments] carries the bar
  /// instead of [value].
  final bool _isSegments;

  bool get _tappable => onTap != null;
  bool get _automatic => !_isSegments && tone == null;
  bool get _nearLimit =>
      _automatic && value != null && value! >= 0.8 && value! < 1.0;
  bool get _atLimit => _automatic && value != null && value! >= 1.0;

  /// At most 4 named segments, then one "Other" folding in the rest.
  List<_Slice> _slices(AppLocalizations l10n) {
    final head = segments.length <= 4 ? segments : segments.take(4);
    final slices = [
      for (final s in head)
        _Slice(label: s.label, value: s.value, valueLabel: s.valueLabel),
    ];
    if (segments.length > 4) {
      final other = segments.skip(4).fold<double>(0, (sum, s) => sum + s.value);
      slices.add(_Slice(label: l10n.kitProgressRowOther, value: other));
    }
    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = AppTheme.rolesOf(theme);
    final tokens = KitTokens.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final reduceMotion = KitMotion.reduced(context);
    final isLoading = !_isSegments && value == null;

    final slices = _isSegments ? _slices(l10n) : const <_Slice>[];
    final rawSum = slices.fold<double>(0, (sum, s) => sum + s.value);
    assert(
      rawSum <= 1 + 1e-9,
      'KitProgressRow.segments: segments sum to $rawSum, must be at most 1 '
      '(KitProgressRow.md "Data safety and honest state")',
    );
    final scale = rawSum > 1 ? 1 / rawSum : 1.0;

    Color colorFor(int index) =>
        index < 4 ? tokens.segmentFills[index] : roles.surface3;

    final wordsSpans = isLoading
        ? const <InlineSpan>[]
        : _wordsSpans(context, l10n, roles);
    final topLine = wordsSpans.isEmpty
        ? null
        : KitText.rich(
            TextSpan(children: wordsSpans),
            key: valueKey,
            role: KitTextRole.secondary,
            tabular: true,
          );

    final Widget bar;
    if (isLoading) {
      bar = SizedBox(
        width: double.infinity,
        height: KitTokens.progressBarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: roles.surface3,
            borderRadius: BorderRadius.circular(KitTokens.progressBarRadius),
          ),
        ),
      );
    } else if (_isSegments) {
      bar = _SegmentsBar(
        slices: slices,
        scale: scale,
        colorFor: colorFor,
        roles: roles,
      );
    } else {
      final color = switch (tone) {
        AppStatusTone.neutral => roles.text3,
        AppStatusTone.ok => roles.success,
        AppStatusTone.failure => roles.text1,
        AppStatusTone.progress => roles.accent,
        _ => _atLimit ? roles.text1 : roles.accent,
      };
      bar = _ScalarBar(
        value: (value ?? 0).clamp(0.0, 1.0),
        color: color,
        roles: roles,
        reduceMotion: reduceMotion,
      );
    }

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final trailingFits =
            !_isSegments &&
            topLine != null &&
            _fitsTrailing(context, constraints.maxWidth, tokens);
        final titleText = KitText(
          title,
          key: titleKey,
          role: KitTextRole.rowTitle,
          maxLines: trailingFits ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        );
        final line = topLine == null
            ? null
            : _CrossFadeLine(
                reduceMotion: reduceMotion,
                contentKey: ValueKey((_nearLimit, _atLimit)),
                child: topLine,
              );
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            tokens.gutter,
            tokens.space2,
            _tappable ? tokens.space1 : tokens.gutter,
            tokens.space2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading case final leading?) ...[
                    leading,
                    SizedBox(width: tokens.space3),
                  ],
                  Expanded(
                    child: trailingFits
                        ? Row(
                            children: [
                              Flexible(child: titleText),
                              SizedBox(width: tokens.space2),
                              line!,
                            ],
                          )
                        : titleText,
                  ),
                  if (_tappable) const KitChevron(),
                ],
              ),
              if (!trailingFits && line != null) ...[
                SizedBox(height: tokens.space1),
                line,
              ],
              SizedBox(height: tokens.space2),
              bar,
              if (_isSegments) ...[
                SizedBox(height: tokens.space2),
                _Legend(slices: slices, colorFor: colorFor, tokens: tokens),
              ],
            ],
          ),
        );
      },
    );

    final panel = ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.rowHeightTwoLine),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: roles.surface1,
          borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
        ),
        child: _tappable
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
                child: content,
              )
            : content,
      ),
    );

    return Semantics(
      container: true,
      button: _tappable,
      onTap: onTap,
      label: _mergedLabel(context, l10n, isLoading, slices),
      child: ExcludeSemantics(child: panel),
    );
  }

  /// KitStatusLine's `_stacks` measurement, applied to the title and the
  /// value line instead: whether both fit on the title's row (expanded /
  /// large, KitProgressRow.md "Adaptive"). Never at 1.3x text and above
  /// (Accessibility: the trailing layout falls back to stacked).
  bool _fitsTrailing(BuildContext context, double width, KitTokens tokens) {
    final scaler = MediaQuery.textScalerOf(context);
    if (scaler.scale(100) / 100 >= 1.3) return false;
    double measure(String text, TextStyle style) {
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

    final titleWidth = measure(title, KitText.styleFor(KitTextRole.rowTitle));
    final lineWidth = measure(
      valueLabel ?? '',
      KitText.styleFor(KitTextRole.secondary),
    );
    final reserved =
        tokens.gutter +
        (_tappable ? tokens.space1 : tokens.gutter) +
        (leading == null ? 0 : tokens.iconTileSize + tokens.space3) +
        (_tappable ? 48 : 0) +
        tokens.space2 * 2;
    return titleWidth + lineWidth + reserved <= width;
  }

  List<InlineSpan> _wordsSpans(
    BuildContext context,
    AppLocalizations l10n,
    ThemeRoles roles,
  ) {
    final words = <(String, TextStyle?)>[];
    if (valueLabel case final v? when v.isNotEmpty) words.add((v, null));
    if (_nearLimit) {
      words.add((
        l10n.kitProgressRowNearLimit,
        KitText.styleFor(KitTextRole.label).copyWith(color: roles.text1),
      ));
    }
    if (_atLimit) {
      words.add((
        l10n.kitProgressRowAtLimit,
        KitText.styleFor(KitTextRole.label).copyWith(color: roles.text1),
      ));
    }
    if (asOf case final at?) {
      words.add((
        l10n.kitProgressRowAsOf(_formatAsOf(context, at)),
        KitText.styleFor(KitTextRole.caption).copyWith(color: roles.text3),
      ));
    }
    return [
      for (var i = 0; i < words.length; i++)
        TextSpan(text: (i == 0 ? '' : ' · ') + words[i].$1, style: words[i].$2),
    ];
  }

  String _formatAsOf(BuildContext context, DateTime at) => DateFormat.Hm(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(at.toLocal());

  /// The one merged semantics node (KitProgressRow.md "Accessibility"):
  /// "{title}, {percent} percent, {valueLabel}[, near limit][, as of
  /// 10:42]"; for segments: "{title}, {valueLabel}; {label} {valueLabel};
  /// …".
  String _mergedLabel(
    BuildContext context,
    AppLocalizations l10n,
    bool isLoading,
    List<_Slice> slices,
  ) {
    if (isLoading) return '$title, ${l10n.kitProgressRowLoading}';
    if (_isSegments) {
      final parts = <String>[
        if (valueLabel case final v? when v.isNotEmpty) '$title, $v' else title,
        for (final s in slices) [s.label, ?s.valueLabel].join(' '),
      ];
      if (asOf case final at?) {
        parts.add(l10n.kitProgressRowAsOf(_formatAsOf(context, at)));
      }
      return parts.join('; ');
    }
    final percent = ((value ?? 0) * 100).round();
    final parts = <String>[
      title,
      l10n.kitProgressRowPercent(percent),
      if (valueLabel case final v? when v.isNotEmpty) v,
      if (_nearLimit) l10n.kitProgressRowNearLimit,
      if (_atLimit) l10n.kitProgressRowAtLimit,
      if (asOf case final at?)
        l10n.kitProgressRowAsOf(_formatAsOf(context, at)),
    ];
    return parts.join(', ');
  }
}

/// Cross-fades [child] on [KitMotion.quick] when [contentKey] changes (a
/// newly crossed limit word — KitProgressRow.md "Motion and haptics").
/// Instant under reduced motion.
class _CrossFadeLine extends StatelessWidget {
  const _CrossFadeLine({
    required this.reduceMotion,
    required this.contentKey,
    required this.child,
  });

  final bool reduceMotion;
  final Key contentKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: reduceMotion ? Duration.zero : KitMotion.quick,
    switchInCurve: KitMotion.enter,
    switchOutCurve: KitMotion.exit,
    child: KeyedSubtree(key: contentKey, child: child),
  );
}

/// A single determinate bar (KitProgressRow.md "loaded"/"near
/// limit"/"at limit"/"stale"/"empty"): a track and a fill that animates to
/// its new value on [KitMotion.standard], jumping under reduced motion.
class _ScalarBar extends StatelessWidget {
  const _ScalarBar({
    required this.value,
    required this.color,
    required this.roles,
    required this.reduceMotion,
  });

  final double value;
  final Color color;
  final ThemeRoles roles;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    Widget track(double v) => SizedBox(
      width: double.infinity,
      height: KitTokens.progressBarHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KitTokens.progressBarRadius),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: roles.surface3)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: v,
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
    if (reduceMotion) return track(value);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: KitMotion.standard,
      curve: KitMotion.enter,
      builder: (context, v, _) => track(v),
    );
  }
}

/// The stacked bar for [KitProgressRow.segments]: up to 4 named shares plus
/// the unfilled remainder, each an [Expanded] slice so the proportions stay
/// exact regardless of width. A slice coloured `surface3` (the 4th named
/// segment, or "Other") carries a 1 physical px hairline edge so two such
/// slices next to each other stay legible (`_new-tokens.md`).
class _SegmentsBar extends StatelessWidget {
  const _SegmentsBar({
    required this.slices,
    required this.scale,
    required this.colorFor,
    required this.roles,
  });

  final List<_Slice> slices;
  final double scale;
  final Color Function(int index) colorFor;
  final ThemeRoles roles;

  static const _flexUnit = 100000;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var used = 0;
    for (var i = 0; i < slices.length; i++) {
      final flex = ((slices[i].value * scale) * _flexUnit).round();
      if (flex <= 0) continue;
      used += flex;
      final color = colorFor(i);
      final muted = color == roles.surface3;
      children.add(
        Expanded(
          flex: flex,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              border: muted
                  ? BorderDirectional(
                      start: BorderSide(
                        color: roles.hairline,
                        width: KitTokens.hairlineWidth(context),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      );
    }
    final leftover = _flexUnit - used;
    if (leftover > 0) {
      children.add(
        Expanded(
          flex: leftover,
          child: ColoredBox(color: roles.surface3),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: KitTokens.progressBarHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KitTokens.progressBarRadius),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// The legend under a segments bar: one row per segment (mark swatch,
/// label, value label), flowing in two columns at width and count
/// (KitProgressRow.md "Adaptive": >= 3 segments, >= `readingWidth / 2` per
/// column).
class _Legend extends StatelessWidget {
  const _Legend({
    required this.slices,
    required this.colorFor,
    required this.tokens,
  });

  final List<_Slice> slices;
  final Color Function(int index) colorFor;
  final KitTokens tokens;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (var i = 0; i < slices.length; i++) _row(slices[i], colorFor(i)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            rows.length >= 3 && constraints.maxWidth >= KitLayout.readingWidth;
        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) SizedBox(height: tokens.space1),
                rows[i],
              ],
            ],
          );
        }
        final columnWidth = (constraints.maxWidth - tokens.space3) / 2;
        return Wrap(
          spacing: tokens.space3,
          runSpacing: tokens.space1,
          children: [
            for (final r in rows) SizedBox(width: columnWidth, child: r),
          ],
        );
      },
    );
  }

  Widget _row(_Slice slice, Color color) => Row(
    children: [
      DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: KitTokens.swatchDot),
      ),
      SizedBox(width: tokens.space2),
      Expanded(
        child: KitText(
          slice.label,
          role: KitTextRole.secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (slice.valueLabel case final v?) ...[
        SizedBox(width: tokens.space2),
        KitText(v, role: KitTextRole.secondary, tabular: true),
      ],
    ],
  );
}
