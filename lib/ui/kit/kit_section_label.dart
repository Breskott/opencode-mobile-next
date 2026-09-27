import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'kit_term.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// A section's name above its content (visual language §5, slice-R4): the
/// one section caption, at the same start inset as [KitRowGroup]'s label,
/// a [KitField]'s label and a [KitDetailsFold]'s title, so every heading on
/// a page or sheet starts on one line. Never uppercase; a heading for
/// screen readers.
///
/// Replaces `SectionLabel` in `widgets/product_states.dart`.
///
/// **Inset.** [margin] is the gutter at the sides by default, like a
/// [KitRowGroup]; a surface that already pads its content (a sheet, a
/// panel) passes [EdgeInsets.zero], and the words then start at its own
/// padding. The words themselves carry no inset of their own.
///
/// **Gap.** A section is separated from what comes before it by
/// [KitTokens.sectionGap]. [gapBefore] null means exactly that, except when
/// the label is the first thing in its scroll view or on its page (nothing
/// above it to separate from), where it is 0. An explicit spacer right before the label
/// (a `SizedBox` of fixed height in the same column or list, or in a
/// `SliverToBoxAdapter` just before) collapses into the gap, so a caller's
/// older spacing never doubles it. Pass a number to force a gap, 0 for
/// none.
///
/// **Explanation.** With [explanation] the words are a [KitTerm]: tap,
/// long-press or hover explains them (Providers, MCP servers, Resources).
/// Its 48 dp target reaches into the space above and below the words
/// instead of adding to it, so the words keep a plain label's place.
///
/// States: none — a caption only names its section.
class KitSectionLabel extends StatelessWidget {
  const KitSectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.explanation,
    this.margin,
    this.gapBefore,
    this.textKey,
  });

  /// The section's name, in sentence case.
  final String text;

  /// A small status or action at the end of the line ("3 new", a
  /// [KitIconButton]); it drops under the words when both do not fit.
  final Widget? trailing;

  /// What the words mean, shown by a [KitTerm] on them.
  final String? explanation;

  /// Around the label (the sides only; the top is [gapBefore], the bottom
  /// [KitTokens.labelGap]). The gutter at the sides by default.
  final EdgeInsetsGeometry? margin;

  /// The space above; see the class comment.
  final double? gapBefore;

  /// On the words (or the [KitTerm]'s word), for tests.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final explanation = this.explanation;
    final trailing = this.trailing;
    final Widget words;
    // How far a KitTerm's 48 dp target reaches past its words above and
    // below; taken back out of the gap above and the label gap below, so
    // an explained label keeps a plain label's rhythm (the target overlaps
    // the empty space rather than pushing the section apart).
    var reach = 0.0;
    if (explanation == null) {
      words = Semantics(
        header: true,
        child: KitText(
          text,
          key: textKey,
          role: KitTextRole.label,
          tone: KitTextTone.secondary,
        ),
      );
    } else {
      // A KitTerm pads its word by space2 inside its 48 dp target; pulled
      // back by that much, the word starts on the same line as a plain
      // label's, and the target reaches into the gutter instead.
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final style = KitText.styleOf(context, KitTextRole.label);
      final size = style.fontSize ?? 13;
      final line =
          MediaQuery.textScalerOf(context).scale(size) * (style.height ?? 1);
      final target = line + 2 * tokens.space1 > tokens.minTarget
          ? line + 2 * tokens.space1
          : tokens.minTarget;
      reach = (target - line) / 2;
      words = Semantics(
        header: true,
        child: Transform.translate(
          offset: Offset(rtl ? tokens.space2 : -tokens.space2, 0),
          child: KitTerm(
            text,
            explanation: explanation,
            role: KitTextRole.label,
            termKey: textKey,
          ),
        ),
      );
    }
    return Padding(
      padding: margin ?? EdgeInsets.symmetric(horizontal: tokens.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KitSectionGap(gap: gapBefore, trim: reach),
          Padding(
            padding: EdgeInsetsDirectional.only(
              bottom: reach >= tokens.labelGap ? 0 : tokens.labelGap - reach,
            ),
            child: trailing == null
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: words,
                  )
                // A Wrap, not a Row: when the words and the trailing part do
                // not fit on one line at large text, the trailing part drops
                // under the words instead of overflowing the edge.
                : Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: tokens.space2,
                    runSpacing: tokens.space1,
                    children: [words, trailing],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The space above a section: [KitTokens.sectionGap] when [gap] is null,
/// except as the first thing in a scroll view or page (0), less any fixed-height
/// spacer right before it, less [trim] (never below 0).
class _KitSectionGap extends LeafRenderObjectWidget {
  const _KitSectionGap({this.gap, this.trim = 0});

  /// Null for the section gap rule; a number is used as it is.
  final double? gap;

  /// Taken off the result: how far the label's own target already reaches
  /// into the space above its words.
  final double trim;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderKitSectionGap(
    gap: gap,
    trim: trim,
    sectionGap: KitTokens.of(context).sectionGap,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderKitSectionGap renderObject,
  ) {
    renderObject
      ..gap = gap
      ..trim = trim
      ..sectionGap = KitTokens.of(context).sectionGap
      // Where the box sits may have changed with the rebuild (a row inserted
      // above it) even when its own values did not.
      ..markNeedsLayout();
  }
}

class _RenderKitSectionGap extends RenderBox {
  _RenderKitSectionGap({
    required double? gap,
    required double trim,
    required double sectionGap,
  }) : _gap = gap,
       _trim = trim,
       _sectionGap = sectionGap;

  double _trim;
  set trim(double value) {
    if (value == _trim) return;
    _trim = value;
    markNeedsLayout();
  }

  double? _gap;
  set gap(double? value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _sectionGap;
  set sectionGap(double value) {
    if (value == _sectionGap) return;
    _sectionGap = value;
    markNeedsLayout();
  }

  double _height() {
    final raw = _rawHeight();
    return raw <= _trim ? 0 : raw - _trim;
  }

  double _rawHeight() {
    final gap = _gap;
    if (gap != null) return gap;
    // Walk up while this box is the first thing in each parent. Reaching a
    // viewport that way means nothing scrolls above the section.
    RenderObject node = this;
    while (true) {
      final parent = node.parent;
      // Nothing above it anywhere on the page (a body that does not
      // scroll): no gap either.
      if (parent == null) return 0;
      final data = node.parentData;
      if (parent is RenderAbstractViewport) {
        if (parent is RenderViewportBase && parent.axis != Axis.vertical) {
          return _sectionGap;
        }
        if (data is ContainerParentDataMixin<RenderObject>) {
          final previous = data.previousSibling;
          if (previous != null) return _less(_spacerHeight(previous));
        }
        return 0;
      }
      if (data is SliverMultiBoxAdaptorParentData) {
        // A list: the live children are contiguous, so the previous live
        // child is the one right before; when it is not built (index > 0
        // with none before it), no spacer is assumed.
        if ((data.index ?? 0) > 0) {
          final previous = data.previousSibling;
          return previous == null
              ? _sectionGap
              : _less(_spacerHeight(previous));
        }
      } else if (data is ContainerParentDataMixin<RenderObject> &&
          _stacksVertically(parent)) {
        final previous = data.previousSibling;
        if (previous != null) return _less(_spacerHeight(previous));
      }
      node = parent;
    }
  }

  /// The section gap less a spacer already above it, never below 0.
  double _less(double spacer) =>
      spacer >= _sectionGap ? 0 : _sectionGap - spacer;

  /// Whether the parent lays its children out one below another.
  static bool _stacksVertically(RenderObject parent) =>
      (parent is RenderFlex && parent.direction == Axis.vertical) ||
      (parent is RenderSliver && parent is! RenderSliverCrossAxisGroup);

  /// The height of a fixed spacer (a childless `SizedBox`, also inside a
  /// `SliverToBoxAdapter`), looking through wrappers that draw nothing; 0
  /// for anything else.
  static double _spacerHeight(RenderObject node) {
    RenderObject? current = node;
    if (current is RenderSliverToBoxAdapter) current = current.child;
    while (current is RenderProxyBox) {
      if (current is RenderConstrainedBox && current.child == null) {
        final c = current.additionalConstraints;
        return c.hasTightHeight ? c.minHeight : 0;
      }
      current = current.child;
    }
    return 0;
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => _height();

  @override
  double computeMaxIntrinsicHeight(double width) => _height();

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(Size(0, _height()));

  @override
  void performLayout() {
    size = constraints.constrain(Size(0, _height()));
  }
}
