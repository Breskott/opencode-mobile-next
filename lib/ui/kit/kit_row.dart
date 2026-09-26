import 'package:flutter/material.dart';

import '../app_iconography.dart';
import 'kit_tokens.dart';

/// A list row (design standard §6): a leading icon or status dot, a
/// one-line title, a one-line muted supporting line, and a trailing value,
/// chevron or single icon action. State lives in the row (a tinted icon, a
/// "Needs you" word in [supporting]), not in cards above the list.
///
/// One line each is the rule. A list whose titles are the person's own words
/// (conversation titles) may let them wrap with [titleMaxLines] and
/// [supportingMaxLines], so large text does not cut them to a few letters.
class KitRow extends StatelessWidget {
  const KitRow({
    super.key,
    required this.title,
    this.leading,
    this.supporting,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.titleMaxLines = 1,
    this.supportingMaxLines = 1,
    this.below,
    this.titleKey,
    this.supportingKey,
    this.padding,
    this.enabled = true,
    this.destructive = false,
  });

  final Widget? leading;
  final String title;

  /// Muted by default; spans may carry their own colour for a state word.
  final InlineSpan? supporting;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// One line by default (§6). A row whose title is the person's own long
  /// words (a run's objective) may take two.
  final int titleMaxLines;

  /// One line by default (§6); two where the line's end carries the state
  /// ("… · Finished 5h ago").
  final int supportingMaxLines;

  /// Shown under the supporting line: where a trailing state word moves at
  /// large text instead of squeezing the title.
  final Widget? below;

  /// Keys of the title and supporting texts, for tests.
  final Key? titleKey;
  final Key? supportingKey;

  /// The row's own padding; by default the 16 dp rails of a list. A row
  /// inside a block that already sits on the rails (a state, a card's
  /// content) passes its own, usually no side padding.
  final EdgeInsetsGeometry? padding;

  /// False for an action that cannot run now: the row dims and ignores
  /// taps. Its supporting line says why (§2: a disabled control needs a
  /// visible reason).
  final bool enabled;

  /// An action that deletes or ends something: an error-coloured title
  /// (tint the leading icon to match), and it always confirms before
  /// acting (§2).
  final bool destructive;

  /// A leading icon in its tile (visual language §4): 30 dp of `surface3`
  /// with 9 dp corners, the icon in `text1` unless [color] is given.
  static Widget icon(BuildContext context, IconData icon, {Color? color}) {
    final tokens = KitTokens.of(context);
    return SizedBox.square(
      dimension: tokens.iconTileSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.roles.surface3,
          borderRadius: BorderRadius.circular(tokens.iconTileRadius),
        ),
        child: Center(
          child: Icon(icon, size: 20, color: color ?? tokens.roles.text1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final supporting = this.supporting;
    final titleColor = destructive ? tokens.roles.danger : null;
    final Widget row = InkWell(
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: ConstrainedBox(
        // 54 dp with one line, 60 with two (§4).
        constraints: BoxConstraints(
          minHeight: supporting == null && below == null
              ? tokens.rowHeight
              : tokens.rowHeightTwoLine,
        ),
        child: Padding(
          padding:
              padding ??
              EdgeInsetsDirectional.fromSTEB(
                16,
                8,
                trailing == null ? 16 : 4,
                8,
              ),
          child: Row(
            children: [
              if (leading case final leading?) ...[
                leading,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      key: titleKey,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.rowTitle.copyWith(color: titleColor),
                    ),
                    if (supporting != null) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        supporting,
                        key: supportingKey,
                        maxLines: supportingMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.rowSupporting,
                      ),
                    ],
                    if (below case final below?) ...[
                      const SizedBox(height: 2),
                      below,
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
    if (enabled) return row;
    return Opacity(opacity: .5, child: row);
  }
}

/// A row's trailing value in `text3`, optionally before the chevron
/// (visual language §5: "Claude Sonnet 4 ›"). The value is what the row
/// is set to now; the chevron says the row opens a screen.
///
/// States: none — the row it sits in carries the states.
class KitRowValue extends StatelessWidget {
  const KitRowValue(this.value, {super.key, this.chevron = true});

  final String value;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.minTarget),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.rowValue,
            ),
          ),
          if (chevron)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: tokens.space1,
                end: tokens.space3,
              ),
              child: Icon(
                AppIconography.chevronRight,
                size: 20,
                color: tokens.roles.text3,
              ),
            )
          else
            SizedBox(width: tokens.space4),
        ],
      ),
    );
  }
}

/// Rows grouped on one panel (visual language §4, §5): `surface1`, 18 dp
/// corners, a hairline of exactly one physical pixel between rows, inset
/// to where the row's words start, with an optional section [label] 8 dp
/// above. No per-row menus: a row's rarer actions open on long-press or
/// right-click (`KitRowMenu`).
///
/// States: none — each row it holds carries its own states.
class KitRowGroup extends StatelessWidget {
  const KitRowGroup({
    super.key,
    required this.children,
    this.label,
    this.labelTrailing,
    this.leadingIcons = true,
    this.margin,
  });

  final List<Widget> children;

  /// The section's name above the panel (never uppercase).
  final String? label;
  final Widget? labelTrailing;

  /// Whether the rows lead with an icon tile: the separators then start
  /// where the words do.
  final bool leadingIcons;

  /// Around the group; the screen gutter at the sides by default.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final inset = leadingIcons
        ? tokens.space4 + tokens.iconTileSize + tokens.space3
        : tokens.space4;
    final label = this.label;
    return Padding(
      padding: margin ?? EdgeInsets.symmetric(horizontal: tokens.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: tokens.space1,
                end: tokens.space1,
                bottom: tokens.labelGap,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(label, style: tokens.sectionLabel),
                    ),
                  ),
                  ?labelTrailing,
                ],
              ),
            ),
          Material(
            color: tokens.roles.surface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0,
                      thickness: 0,
                      indent: inset,
                      color: tokens.roles.hairline,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
