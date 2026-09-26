import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme_roles.dart';
import 'kit_text.dart';

/// The design tokens the kit's parts read (docs/ux-system/kit-v2.md, the
/// visual language in docs/design/visual-language-2026-09-26.md §3–§7):
/// every colour, radius, height, scrim, type style and spacing of a kit part
/// comes from here, never a literal in the part, so a new visual language
/// (or a new theme) lands by changing tokens.
///
/// Colours are the theme's [roles]; shape, space and type are fixed by the
/// visual language. Provided as a [ThemeExtension] on the app's theme;
/// without one, [of] derives the tokens from the theme's roles.
@immutable
class KitTokens extends ThemeExtension<KitTokens> {
  const KitTokens({
    required this.roles,
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.space6,
    required this.rail,
    required this.sheetSurface,
    required this.panelSurface,
    required this.sideSheetSurface,
    required this.scrim,
    required this.sheetRadius,
    required this.panelRadius,
    required this.sheetElevation,
    required this.panelElevation,
    required this.sideSheetElevation,
    required this.panelInset,
    required this.handleColor,
    required this.handleSize,
    required this.handleHeight,
    required this.muted,
    required this.detailsSurface,
    required this.detailsRadius,
    required this.markSize,
    required this.markIconSize,
    required this.markTintAlpha,
    required this.markRadius,
    required this.maxIconScale,
    required this.sheetTitle,
    required this.sheetSubtitle,
    required this.confirmTitle,
    required this.confirmBody,
    required this.note,
    required this.technicalValue,
    required this.typedName,
    required this.accent,
    required this.danger,
    required this.minTarget,
    required this.smallIconSize,
    required this.panelCornerRadius,
    required this.cardRadius,
    required this.buttonRadius,
    required this.buttonHeight,
    required this.iconTileSize,
    required this.iconTileRadius,
    required this.codeRadius,
    required this.composerRadius,
    required this.composerRadiusWide,
    required this.rowHeight,
    required this.rowHeightTwoLine,
    required this.gutter,
    required this.sectionGap,
    required this.labelGap,
    required this.navHeight,
    required this.navRadius,
    required this.rowTitle,
    required this.rowSupporting,
    required this.rowValue,
    required this.sectionLabel,
    required this.cardCaption,
    required this.cardTitle,
  });

  /// The theme's colour roles (ground, surfaces, text, accent, attention,
  /// danger, …). Parts read colours from here.
  final ThemeRoles roles;

  /// The spacing scale, smallest first (4, 8, 12, 16, 20, 24).
  final double space1;
  final double space2;
  final double space3;
  final double space4;
  final double space5;
  final double space6;

  /// A modal part's side rails.
  final double rail;

  final Color sheetSurface;
  final Color panelSurface;
  final Color sideSheetSurface;

  /// The veil behind a modal part.
  final Color scrim;

  /// A bottom sheet's top corners (30); a centred dialog panel's (24).
  final double sheetRadius;
  final double panelRadius;
  final double sheetElevation;
  final double panelElevation;
  final double sideSheetElevation;

  /// The space a centred panel keeps from the window's edges.
  final double panelInset;

  final Color handleColor;
  final Size handleSize;

  /// The band the handle sits in.
  final double handleHeight;

  /// Secondary words: subtitles, bodies, reasons, labels (`text2`).
  final Color muted;
  final Color detailsSurface;
  final double detailsRadius;

  /// A confirmation's mark: an icon tile, its icon and tint, its corners.
  final double markSize;
  final double markIconSize;
  final double markTintAlpha;
  final double markRadius;

  /// How far a leading icon may grow with the person's text size.
  final double maxIconScale;

  final TextStyle sheetTitle;
  final TextStyle sheetSubtitle;
  final TextStyle confirmTitle;
  final TextStyle confirmBody;

  /// A small muted line: a disabled action's reason, a details label.
  final TextStyle note;

  /// A technical value (path, host): mono.
  final TextStyle technicalValue;

  /// The typed-name field's text: mono.
  final TextStyle typedName;

  /// The tone of a neutral question's mark.
  final Color accent;

  /// The tone of a stop, delete or discard: it loses data or ends work.
  final Color danger;

  /// The smallest touch target, everywhere (§8.3: never smaller on a PC).
  final double minTarget;

  /// A small trailing icon (a fold's chevron).
  final double smallIconSize;

  /// A grouped panel's corners (18).
  final double panelCornerRadius;

  /// A needs-you or request card's corners (22).
  final double cardRadius;

  /// A button's corners (14) and a full-width button's height (50).
  final double buttonRadius;
  final double buttonHeight;

  /// A row's leading icon tile: 30 dp of `surface3`, 9 dp corners.
  final double iconTileSize;
  final double iconTileRadius;

  /// A code block's corners.
  final double codeRadius;

  /// The composer: 26 on a phone, 18 on a PC.
  final double composerRadius;
  final double composerRadiusWide;

  /// A row with one line (54) and with two (60).
  final double rowHeight;
  final double rowHeightTwoLine;

  /// The screen gutter (16), the space between sections (22), and between a
  /// section's label and its panel (8).
  final double gutter;
  final double sectionGap;
  final double labelGap;

  /// The floating tab bar: 60 dp tall, 22 dp corners.
  final double navHeight;
  final double navRadius;

  /// A row's title, its second line and its trailing value.
  final TextStyle rowTitle;
  final TextStyle rowSupporting;
  final TextStyle rowValue;

  /// A section's label above its panel (never uppercase).
  final TextStyle sectionLabel;

  /// A needs-you card's caption ("Needs you · 40 s ago") and its title.
  final TextStyle cardCaption;
  final TextStyle cardTitle;

  /// A panel set into a sheet or a dialog (a confirmation's consequences):
  /// one step below the sheet's `surface2`, which in light is the ground.
  Color get insetSurface => roles.isDark ? roles.surface1 : roles.ground;

  /// The tokens in force: the theme's extension, or ones derived from it.
  static KitTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<KitTokens>() ?? KitTokens.fallback(theme);
  }

  /// [size] grown with the person's text size, up to [maxIconScale], so a
  /// leading icon keeps up with the words beside it.
  double iconSize(BuildContext context, double size) => MediaQuery.textScalerOf(
    context,
  ).clamp(maxScaleFactor: maxIconScale).scale(size);

  /// Tokens derived from [theme]'s roles and type.
  factory KitTokens.fallback(ThemeData theme) =>
      KitTokens.fromRoles(ThemeRoles.resolve(theme), theme.textTheme);

  /// The visual language's tokens in the colours of [r], with [text] (the
  /// theme's type scale, already in the kit's roles) for the styles.
  factory KitTokens.fromRoles(ThemeRoles r, TextTheme text) {
    // The theme's face (Geist, or the system face under an Arabic locale,
    // where tracking stays zero for connected shaping) with the role's
    // metrics; mono keeps its own face.
    final face = text.bodyLarge;
    final system = face?.fontFamily == 'sans-serif';
    TextStyle role(KitTextRole role, Color color) {
      final style = KitText.styleFor(role);
      if (role == KitTextRole.mono) return style.copyWith(color: color);
      return style.copyWith(
        fontFamily: face?.fontFamily,
        fontFamilyFallback: face?.fontFamilyFallback,
        letterSpacing: system ? 0 : style.letterSpacing,
        color: color,
      );
    }

    return KitTokens(
      roles: r,
      space1: 4,
      space2: 8,
      space3: 12,
      space4: 16,
      space5: 20,
      space6: 24,
      rail: 20,
      sheetSurface: r.surface2,
      panelSurface: r.surface2,
      sideSheetSurface: r.surface2,
      scrim: r.scrim,
      sheetRadius: 30,
      panelRadius: 24,
      sheetElevation: 0,
      panelElevation: 0,
      sideSheetElevation: 0,
      panelInset: 24,
      handleColor: r.text3,
      handleSize: const Size(36, 5),
      handleHeight: 22,
      muted: r.text2,
      detailsSurface: r.isDark ? r.surface1 : r.ground,
      detailsRadius: 14,
      markSize: 44,
      markIconSize: 22,
      markTintAlpha: .16,
      markRadius: 12,
      maxIconScale: 1.5,
      sheetTitle: role(KitTextRole.title, r.text1),
      sheetSubtitle: role(KitTextRole.secondary, r.text2),
      confirmTitle: role(KitTextRole.title, r.text1),
      confirmBody: role(KitTextRole.body, r.text2),
      note: role(KitTextRole.secondary, r.text2),
      technicalValue: role(KitTextRole.mono, r.text1),
      typedName: role(KitTextRole.mono, r.text1).copyWith(fontSize: 16),
      accent: r.accent,
      danger: r.danger,
      minTarget: 48,
      smallIconSize: 20,
      panelCornerRadius: 18,
      cardRadius: 22,
      buttonRadius: 14,
      buttonHeight: 50,
      iconTileSize: 30,
      iconTileRadius: 9,
      codeRadius: 14,
      composerRadius: 26,
      composerRadiusWide: 18,
      rowHeight: 54,
      rowHeightTwoLine: 60,
      gutter: 16,
      sectionGap: 22,
      labelGap: 8,
      navHeight: 60,
      navRadius: 22,
      rowTitle: role(KitTextRole.rowTitle, r.text1),
      rowSupporting: role(KitTextRole.secondary, r.text2),
      rowValue: role(KitTextRole.secondary, r.text3).copyWith(fontSize: 15),
      sectionLabel: role(KitTextRole.label, r.text2),
      cardCaption: role(KitTextRole.caption, r.attention),
      cardTitle: role(KitTextRole.headline, r.text1),
    );
  }

  @override
  KitTokens copyWith({
    Color? sheetSurface,
    Color? panelSurface,
    Color? sideSheetSurface,
    Color? scrim,
    double? sheetRadius,
    double? panelRadius,
    Color? muted,
    TextStyle? sheetTitle,
    TextStyle? confirmTitle,
    TextStyle? confirmBody,
  }) => KitTokens(
    roles: roles,
    space1: space1,
    space2: space2,
    space3: space3,
    space4: space4,
    space5: space5,
    space6: space6,
    rail: rail,
    sheetSurface: sheetSurface ?? this.sheetSurface,
    panelSurface: panelSurface ?? this.panelSurface,
    sideSheetSurface: sideSheetSurface ?? this.sideSheetSurface,
    scrim: scrim ?? this.scrim,
    sheetRadius: sheetRadius ?? this.sheetRadius,
    panelRadius: panelRadius ?? this.panelRadius,
    sheetElevation: sheetElevation,
    panelElevation: panelElevation,
    sideSheetElevation: sideSheetElevation,
    panelInset: panelInset,
    handleColor: handleColor,
    handleSize: handleSize,
    handleHeight: handleHeight,
    muted: muted ?? this.muted,
    detailsSurface: detailsSurface,
    detailsRadius: detailsRadius,
    markSize: markSize,
    markIconSize: markIconSize,
    markTintAlpha: markTintAlpha,
    markRadius: markRadius,
    maxIconScale: maxIconScale,
    sheetTitle: sheetTitle ?? this.sheetTitle,
    sheetSubtitle: sheetSubtitle,
    confirmTitle: confirmTitle ?? this.confirmTitle,
    confirmBody: confirmBody ?? this.confirmBody,
    note: note,
    technicalValue: technicalValue,
    typedName: typedName,
    accent: accent,
    danger: danger,
    minTarget: minTarget,
    smallIconSize: smallIconSize,
    panelCornerRadius: panelCornerRadius,
    cardRadius: cardRadius,
    buttonRadius: buttonRadius,
    buttonHeight: buttonHeight,
    iconTileSize: iconTileSize,
    iconTileRadius: iconTileRadius,
    codeRadius: codeRadius,
    composerRadius: composerRadius,
    composerRadiusWide: composerRadiusWide,
    rowHeight: rowHeight,
    rowHeightTwoLine: rowHeightTwoLine,
    gutter: gutter,
    sectionGap: sectionGap,
    labelGap: labelGap,
    navHeight: navHeight,
    navRadius: navRadius,
    rowTitle: rowTitle,
    rowSupporting: rowSupporting,
    rowValue: rowValue,
    sectionLabel: sectionLabel,
    cardCaption: cardCaption,
    cardTitle: cardTitle,
  );

  @override
  KitTokens lerp(covariant KitTokens? other, double t) {
    if (other == null) return this;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return KitTokens(
      roles: roles.lerp(other.roles, t),
      space1: d(space1, other.space1),
      space2: d(space2, other.space2),
      space3: d(space3, other.space3),
      space4: d(space4, other.space4),
      space5: d(space5, other.space5),
      space6: d(space6, other.space6),
      rail: d(rail, other.rail),
      sheetSurface: c(sheetSurface, other.sheetSurface),
      panelSurface: c(panelSurface, other.panelSurface),
      sideSheetSurface: c(sideSheetSurface, other.sideSheetSurface),
      scrim: c(scrim, other.scrim),
      sheetRadius: d(sheetRadius, other.sheetRadius),
      panelRadius: d(panelRadius, other.panelRadius),
      sheetElevation: d(sheetElevation, other.sheetElevation),
      panelElevation: d(panelElevation, other.panelElevation),
      sideSheetElevation: d(sideSheetElevation, other.sideSheetElevation),
      panelInset: d(panelInset, other.panelInset),
      handleColor: c(handleColor, other.handleColor),
      handleSize: Size.lerp(handleSize, other.handleSize, t)!,
      handleHeight: d(handleHeight, other.handleHeight),
      muted: c(muted, other.muted),
      detailsSurface: c(detailsSurface, other.detailsSurface),
      detailsRadius: d(detailsRadius, other.detailsRadius),
      markSize: d(markSize, other.markSize),
      markIconSize: d(markIconSize, other.markIconSize),
      markTintAlpha: d(markTintAlpha, other.markTintAlpha),
      markRadius: d(markRadius, other.markRadius),
      maxIconScale: d(maxIconScale, other.maxIconScale),
      sheetTitle: s(sheetTitle, other.sheetTitle),
      sheetSubtitle: s(sheetSubtitle, other.sheetSubtitle),
      confirmTitle: s(confirmTitle, other.confirmTitle),
      confirmBody: s(confirmBody, other.confirmBody),
      note: s(note, other.note),
      technicalValue: s(technicalValue, other.technicalValue),
      typedName: s(typedName, other.typedName),
      accent: c(accent, other.accent),
      danger: c(danger, other.danger),
      minTarget: d(minTarget, other.minTarget),
      smallIconSize: d(smallIconSize, other.smallIconSize),
      panelCornerRadius: d(panelCornerRadius, other.panelCornerRadius),
      cardRadius: d(cardRadius, other.cardRadius),
      buttonRadius: d(buttonRadius, other.buttonRadius),
      buttonHeight: d(buttonHeight, other.buttonHeight),
      iconTileSize: d(iconTileSize, other.iconTileSize),
      iconTileRadius: d(iconTileRadius, other.iconTileRadius),
      codeRadius: d(codeRadius, other.codeRadius),
      composerRadius: d(composerRadius, other.composerRadius),
      composerRadiusWide: d(composerRadiusWide, other.composerRadiusWide),
      rowHeight: d(rowHeight, other.rowHeight),
      rowHeightTwoLine: d(rowHeightTwoLine, other.rowHeightTwoLine),
      gutter: d(gutter, other.gutter),
      sectionGap: d(sectionGap, other.sectionGap),
      labelGap: d(labelGap, other.labelGap),
      navHeight: d(navHeight, other.navHeight),
      navRadius: d(navRadius, other.navRadius),
      rowTitle: s(rowTitle, other.rowTitle),
      rowSupporting: s(rowSupporting, other.rowSupporting),
      rowValue: s(rowValue, other.rowValue),
      sectionLabel: s(sectionLabel, other.sectionLabel),
      cardCaption: s(cardCaption, other.cardCaption),
      cardTitle: s(cardTitle, other.cardTitle),
    );
  }
}
