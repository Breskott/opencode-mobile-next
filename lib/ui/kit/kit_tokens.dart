import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// The design tokens the kit's modal parts read (docs/ux-system/kit-v2.md):
/// every colour, radius, elevation, scrim, type style and spacing of
/// [KitSheet], [KitConfirmSheet] and their frames comes from here, never a
/// literal in the part, so a new visual language lands by changing tokens.
///
/// Provided as a [ThemeExtension] on the app's theme; without one, [of]
/// derives the values from the theme itself (its colour scheme, text theme,
/// bottom sheet and dialog themes), so the parts look as the theme says.
@immutable
class KitTokens extends ThemeExtension<KitTokens> {
  const KitTokens({
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
  });

  /// The spacing scale, smallest first (4, 8, 12, 16, 20, 24 by default).
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

  /// A bottom sheet's top corners; a centred panel's corners.
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

  /// Secondary words: subtitles, bodies, reasons, labels.
  final Color muted;
  final Color detailsSurface;
  final double detailsRadius;

  /// A confirmation's mark: the tonal circle and its icon.
  final double markSize;
  final double markIconSize;
  final double markTintAlpha;

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

  /// Tokens derived from [theme] (its sheet and dialog themes included).
  factory KitTokens.fallback(ThemeData theme) {
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = AppTheme.mutedOf(theme);
    double topRadius(ShapeBorder? shape, double orElse) =>
        shape is RoundedRectangleBorder
        ? (shape.borderRadius.resolve(TextDirection.ltr).topLeft.x)
        : orElse;
    final sheet = theme.bottomSheetTheme;
    final dialog = theme.dialogTheme;
    const mono = TextStyle(fontFamily: AppTheme.monoFamily);
    return KitTokens(
      space1: 4,
      space2: 8,
      space3: 12,
      space4: 16,
      space5: 20,
      space6: 24,
      rail: 20,
      sheetSurface:
          sheet.modalBackgroundColor ??
          sheet.backgroundColor ??
          scheme.surfaceContainerLow,
      panelSurface: dialog.backgroundColor ?? scheme.surfaceContainerHigh,
      sideSheetSurface: scheme.surfaceContainerLow,
      scrim: sheet.modalBarrierColor ?? Colors.black54,
      sheetRadius: topRadius(sheet.shape, 28),
      panelRadius: topRadius(dialog.shape, 28),
      sheetElevation: sheet.modalElevation ?? sheet.elevation ?? 1,
      panelElevation: dialog.elevation ?? 6,
      sideSheetElevation: 1,
      panelInset: 24,
      handleColor: scheme.onSurfaceVariant.withValues(alpha: .4),
      handleSize: const Size(32, 4),
      handleHeight: 20,
      muted: muted,
      detailsSurface: scheme.surfaceContainerHighest,
      detailsRadius: AppTheme.radiusControl,
      markSize: 44,
      markIconSize: 24,
      markTintAlpha: .14,
      maxIconScale: 1.5,
      sheetTitle: text.titleLarge ?? const TextStyle(),
      sheetSubtitle: (text.bodyMedium ?? const TextStyle()).copyWith(
        color: muted,
      ),
      confirmTitle: text.titleLarge ?? const TextStyle(),
      confirmBody: (text.bodyMedium ?? const TextStyle()).copyWith(
        color: muted,
        height: 1.4,
      ),
      note: (text.bodySmall ?? const TextStyle()).copyWith(color: muted),
      technicalValue: (text.bodyMedium ?? const TextStyle()).merge(mono),
      typedName: (text.bodyLarge ?? const TextStyle()).merge(mono),
      accent: scheme.primary,
      danger: scheme.error,
      minTarget: 48,
      smallIconSize: 18,
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
  );

  @override
  KitTokens lerp(covariant KitTokens? other, double t) {
    if (other == null) return this;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return KitTokens(
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
    );
  }
}
