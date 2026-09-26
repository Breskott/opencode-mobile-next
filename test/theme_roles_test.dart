// The colour roles of the visual language (docs/design/visual-language-2026-09-26.md
// §3): Graphite is the default theme, every pack supplies the whole role
// set, and deriveRoles (the seam for a custom theme) keeps the contrast
// floors for any accent and ground.
import 'dart:math' as math;

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

/// CIE L*a*b* (D65) of an opaque sRGB colour.
List<double> _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = (r * .4124564 + g * .3575761 + b * .1804375) / .95047;
  final y = r * .2126729 + g * .7151522 + b * .0721750;
  final z = (r * .0193339 + g * .1191920 + b * .9503041) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// CIEDE2000 colour difference of two opaque sRGB colours, for LOOK-39.
double _deltaE2000(Color c1, Color c2) => _deltaE2000Lab(_lab(c1), _lab(c2));

/// CIEDE2000 of two L*a*b* colours (Sharma, Wu and Dalal 2005).
double _deltaE2000Lab(List<double> lab1, List<double> lab2) {
  double rad(double deg) => deg * math.pi / 180;
  double deg(double rad) => rad * 180 / math.pi;
  final [l1, a1, b1] = lab1;
  final [l2, a2, b2] = lab2;
  final cBar =
      (math.sqrt(a1 * a1 + b1 * b1) + math.sqrt(a2 * a2 + b2 * b2)) / 2;
  final cBar7 = math.pow(cBar, 7);
  final g = .5 * (1 - math.sqrt(cBar7 / (cBar7 + math.pow(25, 7))));
  final a1p = (1 + g) * a1, a2p = (1 + g) * a2;
  final c1p = math.sqrt(a1p * a1p + b1 * b1);
  final c2p = math.sqrt(a2p * a2p + b2 * b2);
  final h1p = (deg(math.atan2(b1, a1p)) + 360) % 360;
  final h2p = (deg(math.atan2(b2, a2p)) + 360) % 360;
  final dLp = l2 - l1;
  final dCp = c2p - c1p;
  var dh = h2p - h1p;
  if (c1p * c2p == 0) {
    dh = 0;
  } else if (dh > 180) {
    dh -= 360;
  } else if (dh < -180) {
    dh += 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dh / 2));
  final lBarp = (l1 + l2) / 2;
  final cBarp = (c1p + c2p) / 2;
  double hBarp;
  if (c1p * c2p == 0) {
    hBarp = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hBarp = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hBarp = (h1p + h2p + 360) / 2;
  } else {
    hBarp = (h1p + h2p - 360) / 2;
  }
  final t =
      1 -
      .17 * math.cos(rad(hBarp - 30)) +
      .24 * math.cos(rad(2 * hBarp)) +
      .32 * math.cos(rad(3 * hBarp + 6)) -
      .20 * math.cos(rad(4 * hBarp - 63));
  final dTheta = 30 * math.exp(-math.pow((hBarp - 275) / 25, 2));
  final cBarp7 = math.pow(cBarp, 7);
  final rc = 2 * math.sqrt(cBarp7 / (cBarp7 + math.pow(25, 7)));
  final sl =
      1 +
      .015 * math.pow(lBarp - 50, 2) / math.sqrt(20 + math.pow(lBarp - 50, 2));
  final sc = 1 + .045 * cBarp;
  final sh = 1 + .015 * cBarp * t;
  final rt = -math.sin(rad(2 * dTheta)) * rc;
  return math.sqrt(
    math.pow(dLp / sl, 2) +
        math.pow(dCp / sc, 2) +
        math.pow(dHp / sh, 2) +
        rt * (dCp / sc) * (dHp / sh),
  );
}

/// The distance between two colours' hues on the colour wheel, 0–180°.
double _hueDistance(Color a, Color b) {
  final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
  return d > 180 ? 360 - d : d;
}

/// LOOK-39 for [accent] against a role set's attention and danger.
List<String> _apart(String tag, Color accent, ThemeRoles r) => [
  for (final (name, other) in [
    ('attention', r.attention),
    ('danger', r.danger),
  ]) ...[
    if (_hueDistance(accent, other) < 30)
      '$tag hue ${_hueDistance(accent, other).toStringAsFixed(0)}° '
          'from $name < 30°',
    if (_deltaE2000(accent, other) < 20)
      '$tag ΔE2000 ${_deltaE2000(accent, other).toStringAsFixed(1)} '
          'from $name < 20',
  ],
];

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

  test('the ΔE2000 used for LOOK-39 matches the published reference', () {
    // Sharma, Wu and Dalal (2005), table 1: pairs 1, 7 and 17.
    expect(
      _deltaE2000Lab([50, 2.6772, -79.7751], [50, 0, -82.7485]),
      closeTo(2.0425, 1e-4),
    );
    expect(_deltaE2000Lab([50, 0, 0], [50, -1, 2]), closeTo(2.3669, 1e-4));
    expect(_deltaE2000Lab([50, 2.5, 0], [73, 25, -18]), closeTo(27.1492, 1e-4));
    expect(_deltaE2000(Colors.black, Colors.white), closeTo(100, .01));
    expect(_hueDistance(const Color(0xFFFF0000), const Color(0xFF00FFFF)), 180);
    expect(_hueDistance(const Color(0xFFFF0000), const Color(0xFFFF00FF)), 60);
  });

  test(
    'Graphite offers green, blue, teal and violet; teal replaced orange',
    () {
      // Owner decision B15: amber means only "needs you", so no accent is
      // orange.
      expect(graphiteAccents.map((option) => option.name), [
        'green',
        'blue',
        'teal',
        'violet',
      ]);
      final teal = graphiteAccents.firstWhere(
        (option) => option.name == 'teal',
      );
      expect(teal.dark, const Color(0xFF3CCFCF));
      expect(teal.light, const Color(0xFF0D7377));
      // Teal passes LOOK-8 as chosen: the contrast guard leaves it alone.
      expect(graphiteDark.withAccent(teal.dark).accent, teal.dark);
      expect(graphiteLight.withAccent(teal.light).accent, teal.light);
      for (final (roles, accent) in [
        (graphiteDark, teal.dark),
        (graphiteLight, teal.light),
      ]) {
        final tag = 'teal/${roles.brightness.name}';
        expect(
          contrastRatio(onColor(accent), accent),
          greaterThanOrEqualTo(4.5),
          reason: '$tag onAccent on accent',
        );
        expect(
          contrastRatio(accent, roles.ground),
          greaterThanOrEqualTo(4.5),
          reason: '$tag accent on ground',
        );
        expect(
          contrastRatio(accent, roles.surface1),
          greaterThanOrEqualTo(4.5),
          reason: '$tag accent on surface1',
        );
      }
    },
  );

  test(
    'every Graphite accent keeps clear of attention and danger (LOOK-39)',
    () {
      final failures = <String>[];
      for (final option in graphiteAccents) {
        for (final (roles, raw) in [
          (graphiteDark, option.dark),
          (graphiteLight, option.light),
        ]) {
          final tag = '${option.name}/${roles.brightness.name}';
          failures
            ..addAll(_apart(tag, raw, roles))
            ..addAll(
              _apart('$tag guarded', roles.withAccent(raw).accent, roles),
            );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
      // The check bites: the orange that teal replaced fails it.
      expect(
        _apart('orange', const Color(0xFFFF8A4C), graphiteDark),
        isNotEmpty,
      );
      expect(
        _apart('orange', const Color(0xFFC2410C), graphiteLight),
        isNotEmpty,
      );
    },
  );

  test('floating glass has its own rim and shadow roles in every theme', () {
    // LOOK-20: the one shadow is 30 % black in both brightnesses. LOOK-21:
    // the rim is a light line on top and a darker line at the bottom.
    const shadow = Color(0x4D000000);
    expect(graphiteDark.glassShadow, shadow);
    expect(graphiteLight.glassShadow, shadow);
    expect(graphiteDark.glassRimLight, const Color(0x33FFFFFF));
    expect(graphiteDark.glassRimDark, const Color(0x80000000));
    expect(graphiteLight.glassRimLight, const Color(0xE6FFFFFF));
    expect(graphiteLight.glassRimDark, const Color(0x1A000000));
    for (final roles in [graphiteDark, graphiteLight]) {
      expect(
        roles.glassRimLight.computeLuminance(),
        greaterThan(roles.glassRimDark.computeLuminance()),
      );
    }
    // Derived: every pack and a custom theme carry them.
    for (final brightness in Brightness.values) {
      final defaults = brightness == Brightness.dark
          ? graphiteDark
          : graphiteLight;
      final custom = deriveRoles(
        accent: const Color(0xFFE91E63),
        ground: brightness == Brightness.dark
            ? const Color(0xFF1E1E2E)
            : const Color(0xFFFDF6E3),
        brightness: brightness,
      );
      final packs = [
        for (final id in ThemePackId.values.where(
          (id) => id != ThemePackId.dynamic,
        ))
          themePack(id).palette(brightness).themeRoles,
      ];
      for (final roles in [custom, ...packs]) {
        expect(roles.glassShadow, shadow);
        expect(roles.glassRimLight, defaults.glassRimLight);
        expect(roles.glassRimDark, defaults.glassRimDark);
      }
    }
    // They survive copyWith and lerp.
    expect(graphiteDark.copyWith().glassRimLight, graphiteDark.glassRimLight);
    expect(
      graphiteDark.lerp(graphiteLight, 1).glassRimLight,
      graphiteLight.glassRimLight,
    );
    final tokens = KitTokens.fromRoles(
      graphiteLight,
      AppTheme.light().textTheme,
    );
    expect(tokens.glassShadows, hasLength(1));
    expect(tokens.glassShadows.single.color, shadow);
    expect(tokens.glassShadows.single.blurRadius, 16);
    expect(tokens.glassShadows.single.offset, const Offset(0, 6));
  });

  test('every Material type slot is one role, with no other size', () {
    // LOOK-12, LOOK-17: no 57/45/36/28/20/15 anywhere in the type scale.
    bool same(TextStyle a, TextStyle b) =>
        a.fontSize == b.fontSize &&
        a.height == b.height &&
        a.fontWeight == b.fontWeight &&
        a.letterSpacing == b.letterSpacing;
    final roleSizes = {
      for (final role in KitTextRole.values) KitText.styleFor(role).fontSize,
    };
    expect(roleSizes, {32, 24, 17, 16, 14, 13, 12});
    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      final text = theme.textTheme;
      final slots = {
        'displayLarge': text.displayLarge,
        'displayMedium': text.displayMedium,
        'displaySmall': text.displaySmall,
        'headlineLarge': text.headlineLarge,
        'headlineMedium': text.headlineMedium,
        'headlineSmall': text.headlineSmall,
        'titleLarge': text.titleLarge,
        'titleMedium': text.titleMedium,
        'titleSmall': text.titleSmall,
        'bodyLarge': text.bodyLarge,
        'bodyMedium': text.bodyMedium,
        'bodySmall': text.bodySmall,
        'labelLarge': text.labelLarge,
        'labelMedium': text.labelMedium,
        'labelSmall': text.labelSmall,
      };
      for (final MapEntry(:key, :value) in slots.entries) {
        final roles = KitTextRole.values.where(
          (role) =>
              role != KitTextRole.mono && same(value!, KitText.styleFor(role)),
        );
        expect(roles, isNotEmpty, reason: '$key is no role: $value');
      }
      // The top bar's title is the headline role.
      expect(
        same(
          theme.appBarTheme.titleTextStyle!,
          KitText.styleFor(KitTextRole.headline),
        ),
        isTrue,
      );
    }
    // The button role is 16/20 (LOOK-12), not the old 15.
    expect(KitText.styleFor(KitTextRole.button).fontSize, 16);
  });

  test('a row value is the secondary role and a typed name is mono 13', () {
    final tokens = AppTheme.dark().extension<KitTokens>()!;
    final secondary = KitText.styleFor(KitTextRole.secondary);
    expect(tokens.rowValue.fontSize, secondary.fontSize);
    expect(tokens.rowValue.height, secondary.height);
    expect(tokens.rowValue.fontWeight, secondary.fontWeight);
    expect(tokens.rowValue.color, graphiteDark.text3);
    final mono = KitText.styleFor(KitTextRole.mono);
    expect(tokens.typedName.fontFamily, AppTheme.monoFamily);
    expect(tokens.typedName.fontSize, 13);
    expect(tokens.typedName.height, mono.height);
  });
}
