import 'package:flutter/material.dart';

import '../theme_roles.dart';

/// The type roles of the visual language (docs/design/visual-language-2026-09-26.md
/// §2, rounded to whole pixels per §7).
enum KitTextRole {
  /// 32/38, 650: the screen's own name (Settings, a project).
  largeTitle,

  /// 24/30, 650: a sheet's or a dialog's question.
  title,

  /// 17/22, 600: the top bar, card titles.
  headline,

  /// 16/24, 400: the transcript, paragraphs.
  body,

  /// 16/22, 500: a row's first line.
  rowTitle,

  /// 14/20, 400: a row's second line, meta.
  secondary,

  /// 13/18, 600: section labels (never uppercase).
  label,

  /// 12/16, 600, +0.02 em: "Needs you · 40 s ago".
  caption,

  /// 16/20, 600: buttons.
  button,

  /// 13/19, Geist Mono: code, commands, paths (isolated left to right).
  mono,
}

/// Which colour role a [KitText] paints in. Always an opaque role (§7: no
/// text at partial opacity).
enum KitTextTone {
  primary,
  secondary,
  tertiary,
  accent,
  onAccent,
  attention,
  danger,
  success,
}

/// Text in one of the kit's type roles (kit v2 §9.2, the first P9.7 part):
/// the role sets size, line height, weight and tracking; the [tone] sets
/// the colour from the theme's roles. Screens name the role, never a size.
///
/// Mono text is laid out left to right whatever the reading direction, so a
/// path or a command never reorders inside Arabic.
class KitText extends StatelessWidget {
  const KitText(
    this.text, {
    super.key,
    this.role = KitTextRole.body,
    this.tone,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.semanticsLabel,
  }) : span = null;

  /// Spans in one role; a span may carry its own tone colour
  /// ([KitText.toneColor]) or weight.
  const KitText.rich(
    InlineSpan this.span, {
    super.key,
    this.role = KitTextRole.body,
    this.tone,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.semanticsLabel,
  }) : text = '';

  final String text;
  final InlineSpan? span;
  final KitTextRole role;

  /// Null takes the role's own tone: [KitTextTone.secondary] for
  /// [KitTextRole.secondary], [KitTextRole.label] and [KitTextRole.caption],
  /// [KitTextTone.primary] for the rest.
  final KitTextTone? tone;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;
  final String? semanticsLabel;

  /// The base style of [role]: size, line height, weight, tracking and (for
  /// mono) the family. No colour: [styleOf] adds it.
  static TextStyle styleFor(KitTextRole role) => switch (role) {
    KitTextRole.largeTitle => const TextStyle(
      fontSize: 32,
      height: 38 / 32,
      fontWeight: FontWeight(650),
      letterSpacing: -0.8,
    ),
    KitTextRole.title => const TextStyle(
      fontSize: 24,
      height: 30 / 24,
      fontWeight: FontWeight(650),
      letterSpacing: -0.48,
    ),
    KitTextRole.headline => const TextStyle(
      fontSize: 17,
      height: 22 / 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.17,
    ),
    KitTextRole.body => const TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    KitTextRole.rowTitle => const TextStyle(
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    KitTextRole.secondary => const TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    KitTextRole.label => const TextStyle(
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    KitTextRole.caption => const TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.24,
    ),
    KitTextRole.button => const TextStyle(
      fontSize: 16,
      height: 20 / 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    KitTextRole.mono => const TextStyle(
      fontFamily: 'AppMono',
      fontSize: 13,
      height: 19 / 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
  };

  static KitTextTone defaultTone(KitTextRole role) => switch (role) {
    KitTextRole.secondary ||
    KitTextRole.label ||
    KitTextRole.caption => KitTextTone.secondary,
    _ => KitTextTone.primary,
  };

  static Color toneColor(ThemeRoles roles, KitTextTone tone) => switch (tone) {
    KitTextTone.primary => roles.text1,
    KitTextTone.secondary => roles.text2,
    KitTextTone.tertiary => roles.text3,
    KitTextTone.accent => roles.accent,
    KitTextTone.onAccent => roles.onAccent,
    KitTextTone.attention => roles.attention,
    KitTextTone.danger => roles.danger,
    KitTextTone.success => roles.success,
  };

  /// The resolved style of [role] in [tone] here: the theme's face (so an
  /// Arabic locale keeps its system face) with the role's metrics.
  static TextStyle styleOf(
    BuildContext context,
    KitTextRole role, {
    KitTextTone? tone,
  }) {
    final theme = Theme.of(context);
    final roles = ThemeRoles.resolve(theme);
    final face = theme.textTheme.bodyLarge;
    var style = styleFor(role);
    if (role != KitTextRole.mono) {
      style = style.copyWith(
        fontFamily: face?.fontFamily,
        fontFamilyFallback: face?.fontFamilyFallback,
        // Arabic (the system face) keeps zero tracking for connected
        // shaping.
        letterSpacing: face?.fontFamily == 'sans-serif'
            ? 0
            : style.letterSpacing,
      );
    }
    return style.copyWith(color: toneColor(roles, tone ?? defaultTone(role)));
  }

  /// Material's type scale said in the kit's roles, so a `Text` styled
  /// with `theme.textTheme.x` reads the same as its kit counterpart:
  /// headlineLarge is [KitTextRole.largeTitle], titleLarge [KitTextRole.title],
  /// titleMedium [KitTextRole.headline], bodyLarge [KitTextRole.body],
  /// bodySmall [KitTextRole.secondary], labelMedium [KitTextRole.label],
  /// labelSmall [KitTextRole.caption]. Every colour is the opaque `text1`.
  static TextTheme textTheme(TextTheme base, ThemeRoles roles) {
    TextStyle? role(TextStyle? slot, TextStyle metrics) => slot
        ?.merge(metrics)
        .copyWith(color: roles.text1, decorationColor: roles.text1);
    const display = FontWeight(650);
    return base.copyWith(
      displayLarge: role(
        base.displayLarge,
        const TextStyle(
          fontSize: 57,
          height: 64 / 57,
          fontWeight: display,
          letterSpacing: -1.4,
        ),
      ),
      displayMedium: role(
        base.displayMedium,
        const TextStyle(
          fontSize: 45,
          height: 52 / 45,
          fontWeight: display,
          letterSpacing: -1.1,
        ),
      ),
      displaySmall: role(
        base.displaySmall,
        const TextStyle(
          fontSize: 36,
          height: 44 / 36,
          fontWeight: display,
          letterSpacing: -0.9,
        ),
      ),
      headlineLarge: role(base.headlineLarge, styleFor(KitTextRole.largeTitle)),
      headlineMedium: role(
        base.headlineMedium,
        const TextStyle(
          fontSize: 28,
          height: 34 / 28,
          fontWeight: display,
          letterSpacing: -0.6,
        ),
      ),
      headlineSmall: role(base.headlineSmall, styleFor(KitTextRole.title)),
      titleLarge: role(base.titleLarge, styleFor(KitTextRole.title)),
      titleMedium: role(base.titleMedium, styleFor(KitTextRole.headline)),
      titleSmall: role(
        base.titleSmall,
        const TextStyle(
          fontSize: 15,
          height: 20 / 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      bodyLarge: role(base.bodyLarge, styleFor(KitTextRole.body)),
      bodyMedium: role(
        base.bodyMedium,
        const TextStyle(
          fontSize: 15,
          height: 22 / 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
      ),
      bodySmall: role(base.bodySmall, styleFor(KitTextRole.secondary)),
      labelLarge: role(
        base.labelLarge,
        const TextStyle(
          fontSize: 15,
          height: 20 / 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      labelMedium: role(base.labelMedium, styleFor(KitTextRole.label)),
      labelSmall: role(base.labelSmall, styleFor(KitTextRole.caption)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = styleOf(context, role, tone: tone);
    final mono = role == KitTextRole.mono;
    final span = this.span;
    final Widget child = span == null
        ? Text(
            text,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            softWrap: softWrap,
            semanticsLabel: semanticsLabel,
            textDirection: mono ? TextDirection.ltr : null,
          )
        : Text.rich(
            span,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            softWrap: softWrap,
            semanticsLabel: semanticsLabel,
            textDirection: mono ? TextDirection.ltr : null,
          );
    return child;
  }
}
