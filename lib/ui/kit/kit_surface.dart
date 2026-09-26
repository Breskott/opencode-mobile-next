import 'package:flutter/material.dart';

import '../theme_roles.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

/// How much inside space a [KitSurface] gives its child
/// (docs/ux-system/kit-api/KitSurface.md): none (0), compact
/// ([KitTokens.space3], 12) or panel ([KitTokens.space4], 16).
enum KitSurfacePadding { none, compact, panel }

/// The one solid box (KitSurface.md; visual language §4): a fill from the
/// surface steps ([KitSurfaceLevel]), a token [shape] and token [padding],
/// with an optional hairline [outlined] edge (LOOK-21). Depth comes from the
/// surface steps, never from a shadow — a surface never casts one.
///
/// Contract resolution (STANDARDS §0.2, KIT-42, Appendix A #24 and #41):
/// there is no "raised", "tonal" or "glass" level. "Raised" is `surface1`
/// (the panel look); the attention look belongs only to `KitNeedsYou`,
/// `KitRequestCard` and `KitNotice.card`; glass is not a level at all —
/// `KitGlass` stays the one glass part and this widget never wraps it.
///
/// Not interactive: a surface that opens something wraps in `KitTappable`
/// (`KitTappable(shape: KitShape.panel, child: KitSurface.panel(...))`), so
/// the hover, pressed and focus looks follow the same shape. KitSurface
/// itself paints through a `Material` of type canvas at elevation 0, so a
/// descendant that needs a Material ancestor (a field, a menu anchor) keeps
/// working.
///
/// States: none — a surface only draws its own fill and shape.
class KitSurface extends StatelessWidget {
  const KitSurface({
    super.key,
    required this.child,
    this.level = KitSurfaceLevel.surface1,
    this.shape = KitShape.panel,
    this.padding = KitSurfacePadding.panel,
    this.outlined = false,
    this.clip = true,
  }) : _panelTitle = null,
       _panelIcon = null,
       _panelTitleKey = null,
       _inset = false,
       _tileIcon = null,
       _tileTone = null,
       _tileSemanticsLabel = null;

  /// A grouped panel (VL §5; `KitPanel`'s look): `surface1`, the panel
  /// shape, panel padding, and an optional one-line header — a
  /// [KitTokens.smallIconSize] [icon] in `text2` and a headline [title] in
  /// `text1` — above [child].
  const KitSurface.panel({
    super.key,
    required this.child,
    String? title,
    IconData? icon,
    this.padding = KitSurfacePadding.panel,
    Key? titleKey,
  }) : level = KitSurfaceLevel.surface1,
       shape = KitShape.panel,
       outlined = false,
       clip = true,
       _panelTitle = title,
       _panelIcon = icon,
       _panelTitleKey = titleKey,
       _inset = false,
       _tileIcon = null,
       _tileTone = null,
       _tileSemanticsLabel = null;

  /// A panel set into a sheet or a dialog, such as a confirmation's
  /// consequences: [KitTokens.insetSurface] (`surface1` in dark, `ground` in
  /// light).
  const KitSurface.inset({
    super.key,
    required this.child,
    this.padding = KitSurfacePadding.panel,
  }) : level = KitSurfaceLevel.surface1,
       shape = KitShape.panel,
       outlined = false,
       clip = true,
       _panelTitle = null,
       _panelIcon = null,
       _panelTitleKey = null,
       _inset = true,
       _tileIcon = null,
       _tileTone = null,
       _tileSemanticsLabel = null;

  /// A leading icon in its tile (VL §4, LOOK-34): [KitTokens.iconTileSize]
  /// of `surface3` with [KitTokens.iconTileRadius] corners, a
  /// [KitTokens.smallIconSize] glyph in [tone] (`text1` by default). It
  /// replaces tonal circles (LOOK-23).
  const KitSurface.tile(
    IconData icon, {
    super.key,
    KitTextTone? tone,
    String? semanticsLabel,
  }) : child = const SizedBox.shrink(),
       level = KitSurfaceLevel.surface3,
       shape = KitShape.tile,
       padding = KitSurfacePadding.none,
       outlined = false,
       clip = true,
       _panelTitle = null,
       _panelIcon = null,
       _panelTitleKey = null,
       _inset = false,
       _tileIcon = icon,
       _tileTone = tone,
       _tileSemanticsLabel = semanticsLabel;

  final Widget child;
  final KitSurfaceLevel level;
  final KitShape shape;
  final KitSurfacePadding padding;

  /// A hairline edge, exactly one physical pixel (LOOK-21). Only the default
  /// constructor exposes this; every named form is opinionated.
  final bool outlined;

  /// Clips [child] to [shape] (`ClipRRect`'s job). Only the default
  /// constructor exposes this; every named form clips.
  final bool clip;

  final String? _panelTitle;
  final IconData? _panelIcon;
  final Key? _panelTitleKey;
  final bool _inset;
  final IconData? _tileIcon;
  final KitTextTone? _tileTone;
  final String? _tileSemanticsLabel;

  static EdgeInsetsGeometry _paddingOf(
    KitTokens tokens,
    KitSurfacePadding padding,
  ) => switch (padding) {
    KitSurfacePadding.none => EdgeInsets.zero,
    KitSurfacePadding.compact => EdgeInsetsDirectional.all(tokens.space3),
    KitSurfacePadding.panel => EdgeInsetsDirectional.all(tokens.space4),
  };

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    if (_tileIcon case final tileIcon?) {
      return _buildTile(tokens, roles, tileIcon);
    }
    final fill = _inset ? tokens.insetSurface : tokens.fillOf(level);
    final base = tokens.shapeOf(shape);
    final resolvedShape = outlined && base is OutlinedBorder
        ? base.copyWith(
            side: BorderSide(
              color: roles.hairline,
              width: KitTokens.hairlineWidth(context),
            ),
          )
        : base;
    return Material(
      type: MaterialType.canvas,
      color: fill,
      elevation: 0,
      shape: resolvedShape,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: _content(tokens),
    );
  }

  Widget _content(KitTokens tokens) => Padding(
    padding: _paddingOf(tokens, padding),
    child: kitPanelBody(
      tokens,
      title: _panelTitle,
      icon: _panelIcon,
      titleKey: _panelTitleKey,
      child: child,
    ),
  );

  Widget _buildTile(KitTokens tokens, ThemeRoles roles, IconData icon) {
    final color = KitText.toneColor(roles, _tileTone ?? KitTextTone.primary);
    final glyph = Icon(icon, size: tokens.smallIconSize, color: color);
    final label = _tileSemanticsLabel;
    final content = label == null
        ? ExcludeSemantics(child: glyph)
        : Semantics(
            image: true,
            label: label,
            excludeSemantics: true,
            child: glyph,
          );
    return Material(
      type: MaterialType.canvas,
      color: tokens.fillOf(level),
      elevation: 0,
      shape: tokens.shapeOf(shape),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: tokens.iconTileSize,
        height: tokens.iconTileSize,
        child: Center(child: content),
      ),
    );
  }
}

/// Kit-internal, not part of `KitSurface`'s frozen API: the panel header — a
/// [KitTokens.smallIconSize] [icon] in `text2` at the start and a headline
/// [title] — a [KitTokens.labelGap] above [child]; just [child] when there is
/// neither. It is the one source of truth for that header, shared by
/// `KitSurface.panel` and `KitPanel`'s custom-padding / `onTap` path, so a
/// change to the header (such as the planned `Icon` → `KitIcon` swap)
/// reaches both. Screens name `KitSurface.panel`, never this.
Widget kitPanelBody(
  KitTokens tokens, {
  required Widget child,
  String? title,
  IconData? icon,
  Key? titleKey,
}) {
  if (title == null && icon == null) return child;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: tokens.smallIconSize, color: tokens.roles.text2),
            SizedBox(width: tokens.labelGap),
          ],
          if (title != null)
            Expanded(
              child: KitText(title, key: titleKey, role: KitTextRole.headline),
            ),
        ],
      ),
      SizedBox(height: tokens.labelGap),
      child,
    ],
  );
}
