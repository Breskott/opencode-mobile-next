// The colour roles of the visual language (docs/design/visual-language-2026-09-26.md
// §3): Graphite is the default theme, every pack supplies the whole role
// set, and deriveRoles (the seam for a custom theme) keeps the contrast
// floors for any accent and ground.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/theme_packs.dart';

/// Every floor a role set promises, as failure lines.
List<String> _floors(String tag, ThemeRoles r) {
  final failures = <String>[];
  void floor(String what, Color fg, Color bg, double min) {
    final ratio = contrastRatio(fg, Color.alphaBlend(bg, r.ground));
    if (ratio < min) {
      failures.add('$tag $what ${ratio.toStringAsFixed(2)} < $min');
    }
  }

  final surfaces = {
    'ground': r.ground,
    'surface1': r.surface1,
    'surface2': r.surface2,
    'surface3': r.surface3,
  };
  for (final MapEntry(:key, :value) in surfaces.entries) {
    floor('text1 on $key', r.text1, value, 7);
    floor('text2 on $key', r.text2, value, 4.5);
    if (key != 'surface3') floor('text3 on $key', r.text3, value, 4.5);
  }
  floor('accent on ground', r.accent, r.ground, 4.5);
  floor('accent on surface1', r.accent, r.surface1, 4.5);
  floor('onAccent on accent', r.onAccent, r.accent, 4.5);
  floor('attention on ground', r.attention, r.ground, 4.5);
  floor('attention on surface1', r.attention, r.surface1, 4.5);
  floor(
    'attention on its card',
    r.attention,
    Color.alphaBlend(r.attentionSurface, r.surface1),
    4.5,
  );
  floor(
    'text1 on the needs-you card',
    r.text1,
    Color.alphaBlend(r.attentionSurface, r.surface1),
    7,
  );
  floor('badge text', r.onAttentionFill, r.attentionFill, 4.5);
  floor('danger on ground', r.danger, r.ground, 4.5);
  floor('danger on surface2', r.danger, r.surface2, 4.5);
  floor('onDangerFill on dangerFill', r.onDangerFill, r.dangerFill, 4.5);
  floor('success on ground', r.success, r.ground, 4.5);
  for (final code in [r.codeKeyword, r.codeString, r.codeType]) {
    floor('code on surface1', code, r.surface1, 4.5);
  }
  // Opaque text roles (§7: never text at partial opacity).
  for (final text in [r.text1, r.text2, r.text3, r.accent, r.attention]) {
    if (text.a != 1) failures.add('$tag a text role is translucent');
  }
  return failures;
}

void main() {
  test('Graphite is the default and keeps the spec palette', () {
    final dark = AppTheme.dark();
    final roles = dark.extension<ThemeRoles>()!;
    expect(roles.ground, const Color(0xFF0B0C0E));
    expect(roles.surface1, const Color(0xFF141518));
    expect(roles.surface2, const Color(0xFF1B1C20));
    expect(roles.surface3, const Color(0xFF26282D));
    expect(roles.text1, const Color(0xFFF3F3F1));
    expect(roles.accent, const Color(0xFF3DDC8A));
    expect(roles.attention, const Color(0xFFFFB547));
    expect(dark.scaffoldBackgroundColor, roles.ground);
    expect(dark.colorScheme.primary, roles.accent);
    expect(dark.colorScheme.onPrimary, roles.onAccent);
    expect(dark.colorScheme.surfaceContainerLow, roles.surface1);
    expect(dark.colorScheme.surfaceContainer, roles.surface2);
    expect(dark.colorScheme.surfaceContainerHighest, roles.surface3);
    expect(dark.colorScheme.error, roles.danger);
    expect(themePackLabels[ThemePackId.opencode], 'Graphite');

    final light = AppTheme.light().extension<ThemeRoles>()!;
    expect(light.ground, const Color(0xFFF3F3F1));
    expect(light.surface1, Colors.white);
    expect(light.text1, const Color(0xFF111214));
  });

  test('Graphite meets every contrast floor in both modes', () {
    expect([
      ..._floors('dark', graphiteDark),
      ..._floors('light', graphiteLight),
    ], isEmpty);
  });

  test('every theme pack supplies the whole role set, readable', () {
    final failures = <String>[];
    for (final id in ThemePackId.values.where(
      (id) => id != ThemePackId.dynamic,
    )) {
      for (final brightness in Brightness.values) {
        final roles = themePack(id).palette(brightness).themeRoles;
        expect(roles.brightness, brightness, reason: id.name);
        failures.addAll(_floors('${id.name}/${brightness.name}', roles));
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('a custom accent and ground derive a readable role set', () {
    // The seam for a custom theme: the person picks an accent and a ground.
    const accents = [
      Color(0xFF3DDC8A),
      Color(0xFF5AB0FF),
      Color(0xFFFF8A4C),
      Color(0xFFC7A6FF),
      Color(0xFFFFEB3B), // too light for a light theme
      Color(0xFF1A237E), // too dark for a dark theme
      Color(0xFF808080), // mid grey: carries neither ink nor white
      Color(0xFFE91E63),
    ];
    const darkGrounds = [
      Color(0xFF000000),
      Color(0xFF0B0C0E),
      Color(0xFF1E1E2E),
      Color(0xFF002B36),
      Color(0xFF2D2A2E),
    ];
    const lightGrounds = [
      Color(0xFFFFFFFF),
      Color(0xFFF3F3F1),
      Color(0xFFFDF6E3),
      Color(0xFFE1E2E7),
      Color(0xFFEFF1F5),
    ];
    final failures = <String>[];
    for (final accent in accents) {
      for (final (brightness, grounds) in [
        (Brightness.dark, darkGrounds),
        (Brightness.light, lightGrounds),
      ]) {
        for (final ground in grounds) {
          final roles = deriveRoles(
            accent: accent,
            ground: ground,
            brightness: brightness,
          );
          failures.addAll(
            _floors(
              '${accent.toARGB32().toRadixString(16)} on '
              '${ground.toARGB32().toRadixString(16)}',
              roles,
            ),
          );
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('withAccent swaps only the accent and keeps it readable', () {
    for (final option in graphiteAccents) {
      final dark = graphiteDark.withAccent(option.dark);
      final light = graphiteLight.withAccent(option.light);
      expect(dark.surface1, graphiteDark.surface1);
      expect(dark.attention, graphiteDark.attention);
      expect(light.danger, graphiteLight.danger);
      expect(_floors('dark ${option.name}', dark), isEmpty);
      expect(_floors('light ${option.name}', light), isEmpty);
    }
  });

  test('packs change colours only: shape, space and type are fixed', () {
    final reference = KitTokens.fromRoles(
      graphiteDark,
      AppTheme.dark().textTheme,
    );
    for (final id in ThemePackId.values.where(
      (id) => id != ThemePackId.dynamic,
    )) {
      final theme = AppTheme.dark(themePack(id));
      final tokens = theme.extension<KitTokens>()!;
      expect(tokens.panelCornerRadius, reference.panelCornerRadius);
      expect(tokens.cardRadius, reference.cardRadius);
      expect(tokens.sheetRadius, reference.sheetRadius);
      expect(tokens.rowHeight, reference.rowHeight);
      expect(tokens.navHeight, reference.navHeight);
      expect(tokens.rowTitle.fontSize, reference.rowTitle.fontSize);
      expect(theme.textTheme.bodyLarge?.fontFamily, AppTheme.sansFamily);
      expect(theme.colorScheme.primary, tokens.roles.accent);
    }
  });

  test('type sizes are whole pixels and the faces are Geist', () {
    for (final role in KitTextRole.values) {
      final size = KitText.styleFor(role).fontSize!;
      expect(size, size.roundToDouble(), reason: role.name);
    }
    expect(KitText.styleFor(KitTextRole.mono).fontFamily, AppTheme.monoFamily);
    final text = AppTheme.dark().textTheme;
    for (final style in [
      text.headlineLarge,
      text.titleLarge,
      text.titleMedium,
      text.bodyLarge,
      text.bodyMedium,
      text.bodySmall,
      text.labelLarge,
      text.labelMedium,
      text.labelSmall,
    ]) {
      expect(style?.fontFamily, AppTheme.sansFamily);
      expect(style?.fontSize, style!.fontSize!.roundToDouble());
      expect(style.color?.a, 1);
    }
  });
}
