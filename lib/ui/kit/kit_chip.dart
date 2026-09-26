// KitChip: the one small rounded label (docs/ux-system/kit-api/KitChip.md,
// visual language §4-§5). Five kinds share one look: plain (a fact), action
// (a tap target or an on/off filter, replacing FilterChip), removable (a
// chosen thing with its own × target, replacing InputChip), count (a label
// with a number, "Tasks · 3") and summary (folded work that opens, "Read 3
// files · edited 1"). Replaces Chip, ActionChip, InputChip and FilterChip;
// ChoiceChip stays with KitSegmented (KIT-24).
//
// States: there is no disabled chip (STATE-8: a chip that cannot act now is
// not shown) and no loading, empty or error state (KIT-12: a chip shows a
// value its host already has). Declared states: selected (action) and
// expanded (summary).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/app_localizations.dart';
import '../app_iconography.dart';
import 'kit_motion.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// The five kinds a [KitChip] can be (KitChip.md "Purpose").
enum KitChipKind { plain, action, removable, count, summary }

/// A small rounded label (visual language §4-§5). Every kind carries a
/// word, never colour alone (STATE-9), and has a 48 dp hit area around a
/// visually smaller pill ([KitTokens.chipHeight], 32).
///
/// Internal keys (TEST-5): `kit-chip-remove` (the × target) and
/// `kit-chip-check` (the selected check).
class KitChip extends StatelessWidget {
  /// A fact that does nothing when tapped: "main", "3 agents".
  const KitChip({super.key, required this.label, this.icon})
    : kind = KitChipKind.plain,
      onPressed = null,
      onRemove = null,
      count = null,
      selected = null,
      expanded = null;

  /// A tap target ("Open in terminal"). With [selected] non-null it is an
  /// on/off filter (replaces FilterChip): a check at the start when on,
  /// toggled semantics. One choice among several is `KitSegmented`, not
  /// this (KIT-24).
  const KitChip.action({
    super.key,
    required this.label,
    required VoidCallback this.onPressed,
    this.icon,
    this.selected,
  }) : kind = KitChipKind.action,
       onRemove = null,
       count = null,
       expanded = null;

  /// Something the person chose that can be taken out: an attachment, a
  /// form value (replaces InputChip). The × at the end is its own 48 dp
  /// target labelled `l10n.kitChipRemove(label)`.
  const KitChip.removable({
    super.key,
    required this.label,
    required VoidCallback this.onRemove,
    this.icon,
    this.onPressed,
  }) : kind = KitChipKind.removable,
       count = null,
       selected = null,
       expanded = null;

  /// A label with a number: "Tasks · 3". The number uses tabular figures
  /// and `intl` formatting for the locale; semantics "Tasks, 3".
  const KitChip.count({
    super.key,
    required this.label,
    required int this.count,
    this.onPressed,
    this.icon,
  }) : kind = KitChipKind.count,
       onRemove = null,
       selected = null,
       expanded = null;

  /// Folded work that opens: "Read 3 files · edited 1" (the transcript's
  /// work chip, visual language §5). [expanded] non-null adds a chevron
  /// (down folded, up open) and expanded semantics.
  const KitChip.summary({
    super.key,
    required this.label,
    required VoidCallback this.onPressed,
    this.icon,
    this.expanded,
  }) : kind = KitChipKind.summary,
       onRemove = null,
       count = null,
       selected = null;

  final KitChipKind kind;

  /// The chip's words, from the caller's ARB (COPY-1). A name the person or
  /// the server chose is wrapped by the caller with `KitBidi.auto` (COPY-30).
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VoidCallback? onRemove;
  final int? count;
  final bool? selected;
  final bool? expanded;

  static const _removeKey = ValueKey('kit-chip-remove');
  static const _checkKey = ValueKey('kit-chip-check');

  /// Test-only (TEST-5): the removable chip's body tap zone is a sibling of
  /// its visible label, not an ancestor of it (the label stays in the
  /// static pill so the × can sit beside it in one continuous surface), so
  /// a test needs a handle of its own to find it and check its focus.
  static const _bodyKey = ValueKey('kit-chip-body');

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final reduceMotion = KitMotion.reduced(context);
    final labelStyle = _labelStyle(context, tokens);

    switch (kind) {
      case KitChipKind.plain:
        return _staticPill(
          context: context,
          tokens: tokens,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: tokens.smallIconSize, color: roles.text2),
                SizedBox(width: tokens.space1),
              ],
              Flexible(
                child: _EllipsisLabel(text: label, style: labelStyle(false)),
              ),
            ],
          ),
        );

      case KitChipKind.action:
        final selected = this.selected;
        return _interactivePill(
          context: context,
          tokens: tokens,
          onTap: onPressed,
          semanticsLabel: label,
          toggled: selected,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected == true) ...[
                AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : KitMotion.quick,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Icon(
                    AppIconography.check,
                    key: _checkKey,
                    size: tokens.smallIconSize,
                    color: roles.accent,
                  ),
                ),
                SizedBox(width: tokens.space1),
              ],
              if (icon != null && selected != true) ...[
                Icon(icon, size: tokens.smallIconSize, color: roles.text1),
                SizedBox(width: tokens.space1),
              ],
              Flexible(
                child: _EllipsisLabel(text: label, style: labelStyle(true)),
              ),
            ],
          ),
        );

      case KitChipKind.summary:
        final expanded = this.expanded;
        return _interactivePill(
          context: context,
          tokens: tokens,
          onTap: onPressed,
          semanticsLabel: label,
          expanded: expanded,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: tokens.smallIconSize, color: roles.text1),
                SizedBox(width: tokens.space1),
              ],
              Flexible(
                child: _EllipsisLabel(text: label, style: labelStyle(true)),
              ),
              if (expanded != null) ...[
                SizedBox(width: tokens.space1),
                AnimatedRotation(
                  turns: expanded ? .5 : 0,
                  duration: reduceMotion ? Duration.zero : KitMotion.standard,
                  curve: KitMotion.emphasized,
                  child: Icon(
                    AppIconography.chevronDown,
                    size: tokens.smallIconSize,
                    color: roles.text1,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ],
          ),
        );

      case KitChipKind.count:
        final count = this.count!;
        final formatted = NumberFormat.decimalPattern(
          Localizations.localeOf(context).toLanguageTag(),
        ).format(count);
        final span = TextSpan(
          style: labelStyle(false),
          children: [
            TextSpan(text: label),
            const TextSpan(text: ' · '),
            TextSpan(
              text: formatted,
              style: labelStyle(
                true,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        );
        final composedLabel = '$label, $formatted';
        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: tokens.smallIconSize, color: roles.text2),
              SizedBox(width: tokens.space1),
            ],
            Flexible(child: _EllipsisSpan(span: span, semantics: null)),
          ],
        );
        if (onPressed == null) {
          return Semantics(
            label: composedLabel,
            container: true,
            excludeSemantics: true,
            child: _staticPill(
              context: context,
              tokens: tokens,
              child: content,
            ),
          );
        }
        return _interactivePill(
          context: context,
          tokens: tokens,
          onTap: onPressed,
          semanticsLabel: composedLabel,
          child: content,
        );

      case KitChipKind.removable:
        return _removablePill(context: context, tokens: tokens);
    }
  }

  /// The label's type: [KitTextRole.secondary] (14/20) in [KitTextTone.primary]
  /// (`text1`) where the States table calls for emphasis (action, removable,
  /// summary and a count's number), [KitTextTone.secondary] (`text2`)
  /// otherwise (plain, and a count's own label).
  TextStyle Function(bool emphasized) _labelStyle(
    BuildContext context,
    KitTokens tokens,
  ) {
    final emphasizedStyle = KitText.styleOf(
      context,
      KitTextRole.secondary,
      tone: KitTextTone.primary,
    );
    final quietStyle = KitText.styleOf(
      context,
      KitTextRole.secondary,
      tone: KitTextTone.secondary,
    );
    return (emphasized) => emphasized ? emphasizedStyle : quietStyle;
  }

  /// The non-interactive kinds: `plain`, and `count` without [onPressed].
  Widget _staticPill({
    required BuildContext context,
    required KitTokens tokens,
    required Widget child,
  }) => _PillSurface(tokens: tokens, child: child);

  /// A single tappable zone spanning the whole chip: `action`, `summary`,
  /// `count` with [onPressed], and `removable`'s body when [onPressed] is
  /// set. Enlarges the tap target to 48 dp (KitChip.md "Accessibility:
  /// Target") without growing the visual pill past [KitTokens.chipHeight].
  Widget _interactivePill({
    required BuildContext context,
    required KitTokens tokens,
    required VoidCallback? onTap,
    required String semanticsLabel,
    bool? toggled,
    bool? expanded,
    required Widget child,
  }) {
    final roles = tokens.roles;
    return Semantics(
      button: true,
      label: semanticsLabel,
      toggled: toggled,
      expanded: expanded,
      onTap: onTap,
      container: true,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: tokens.minTarget,
          minHeight: tokens.minTarget,
        ),
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: [
            _PillSurface(tokens: tokens, child: child),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                shape: const StadiumBorder(),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const StadiumBorder(),
                  hoverColor: roles.surface2,
                  highlightColor: roles.surface2,
                  splashColor: roles.surface2,
                  focusColor: Colors.transparent,
                  child: onTap == null
                      ? null
                      : Builder(
                          builder: (context) => _FocusRingHost(tokens: tokens),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _removablePill({
    required BuildContext context,
    required KitTokens tokens,
  }) {
    final roles = tokens.roles;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final removeLabel = l10n.kitChipRemove(label);
    final labelStyle = _labelStyle(context, tokens);
    final bodyOnPressed = onPressed;

    // The visible content (icon, label, the × glyph) sits in the static
    // pill; when the body is a tap target too, that content carries no
    // semantics of its own, because the real 48 dp hit zone below (whose
    // rect is what a screen reader should report as the target) already
    // declares the same label (KitChip.md "Accessibility: Target").
    Widget visualRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: tokens.smallIconSize, color: roles.text1),
          SizedBox(width: tokens.space1),
        ],
        Flexible(
          child: _EllipsisLabel(text: label, style: labelStyle(true)),
        ),
        SizedBox(width: tokens.space1),
        Icon(
          AppIconography.close,
          size: tokens.smallIconSize,
          color: roles.text2,
        ),
      ],
    );
    if (bodyOnPressed != null) {
      visualRow = ExcludeSemantics(child: visualRow);
    }

    final removeControl = Semantics(
      key: _removeKey,
      button: true,
      label: removeLabel,
      container: true,
      excludeSemantics: true,
      onTap: onRemove,
      child: Tooltip(
        message: removeLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onRemove,
            hoverColor: roles.surface2,
            highlightColor: roles.surface2,
            splashColor: roles.surface2,
            focusColor: Colors.transparent,
            child: Builder(
              builder: (context) => _FocusRingHost(tokens: tokens),
            ),
          ),
        ),
      ),
    );

    Widget stack = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: tokens.minTarget,
        minHeight: tokens.minTarget,
      ),
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          _PillSurface(tokens: tokens, child: visualRow),
          if (bodyOnPressed != null)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              end: tokens.minTarget,
              child: Semantics(
                key: _bodyKey,
                button: true,
                label: label,
                container: true,
                excludeSemantics: true,
                onTap: bodyOnPressed,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: bodyOnPressed,
                    hoverColor: roles.surface2,
                    highlightColor: roles.surface2,
                    splashColor: roles.surface2,
                    focusColor: Colors.transparent,
                  ),
                ),
              ),
            ),
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            width: tokens.minTarget,
            child: removeControl,
          ),
        ],
      ),
    );

    // Delete/Backspace on either focused zone removes the chip (KitChip.md
    // "Keyboard"). canRequestFocus: false keeps this out of Tab order; the
    // event still bubbles here from whichever zone holds focus.
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.backspace) {
          onRemove!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: stack,
    );
  }
}

/// The pill's own decoration and visual height (KitChip.md "200 % text":
/// "the pill grows in height with the text (chipHeight is a minimum)"):
/// the kit's `surface3` stadium ([KitShape.pill]), with [KitTokens.space3]
/// inner horizontal padding.
class _PillSurface extends StatelessWidget {
  const _PillSurface({required this.tokens, required this.child});

  final KitTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: KitTokens.chipHeight),
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: tokens.roles.surface3,
        shape: tokens.shapeOf(KitShape.pill),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.space3),
        child: child,
      ),
    ),
  );
}

/// Draws the keyboard focus ring (KitChip.md "States": "a 2-physical-pixel
/// accent focus ring around the pill") by reading the ambient [InkWell]'s
/// own [FocusNode] through [Focus.of] — no extra focus node or tab stop.
class _FocusRingHost extends StatelessWidget {
  const _FocusRingHost({required this.tokens});

  final KitTokens tokens;

  @override
  Widget build(BuildContext context) {
    final hasFocus = Focus.of(context).hasFocus;
    if (!hasFocus) return const SizedBox.expand();
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(
            color: tokens.roles.accent,
            width: KitTokens.focusRingWidth(context),
          ),
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// One line of [text] that ellipsises when it does not fit (A11Y-8), with
/// the full value in semantics and a tooltip (long-press on touch, hover on
/// a fine pointer) only when it is actually truncated (KitChip.md
/// "Adaptive").
class _EllipsisLabel extends StatelessWidget {
  const _EllipsisLabel({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => _EllipsisSpan(
    span: TextSpan(text: text, style: style),
    semantics: text,
  );
}

/// As [_EllipsisLabel], for a multi-styled [span] (the `count` kind's
/// "label · number"). [semantics] overrides the announced label; null keeps
/// [Text.rich]'s own (the full, untruncated plain text of [span]).
class _EllipsisSpan extends StatelessWidget {
  const _EllipsisSpan({required this.span, required this.semantics});

  final InlineSpan span;
  final String? semantics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : double.infinity;
      var truncated = false;
      if (maxWidth.isFinite) {
        final painter = TextPainter(
          text: span,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout(maxWidth: maxWidth);
        truncated = painter.didExceedMaxLines;
        painter.dispose();
      }
      final text = Text.rich(
        span,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        semanticsLabel: semantics,
      );
      if (!truncated) return text;
      return Tooltip(message: semantics ?? span.toPlainText(), child: text);
    },
  );
}

/// Lays chips out in a wrapping row with the kit's spacing: [KitTokens.space2]
/// between chips, and a run spacing that keeps every chip's 48 dp hit area
/// clear of the next run's (LAY-9): [KitTokens.minTarget] minus
/// [KitTokens.chipHeight]. Start-aligned in both directions.
class KitChipWrap extends StatelessWidget {
  const KitChipWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Wrap(
      spacing: tokens.space2,
      runSpacing: tokens.minTarget - KitTokens.chipHeight,
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: children,
    );
  }
}
