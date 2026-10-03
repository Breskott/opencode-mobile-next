// KitSkeletonRows (lib/ui/kit/kit_progress.dart): the loading placeholder
// rows must read on every surface they sit on, in light and dark. On a light
// grouped card (surface1, white) the old surface2/surfaceContainerHigh bars
// were the card's own colour, so the AI Team intro showed an empty card while
// the phone pre-flight ran (docs/qa/slice-goldens-app-2026-09-28).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_progress.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// Every filled shape the skeleton draws.
List<Color> _shapeColors(WidgetTester tester) => [
  for (final box in tester.widgetList<Container>(
    find.descendant(
      of: find.byType(KitSkeletonRows),
      matching: find.byType(Container),
    ),
  ))
    if (box.decoration case BoxDecoration(:final color?)) color,
];

void main() {
  for (final light in [true, false]) {
    final theme = light ? AppTheme.light() : AppTheme.dark();
    final roles = ThemeRoles.resolve(theme);
    final levels = {
      'ground': roles.ground,
      'surface1 (grouped card)': roles.surface1,
      'surface2 (sheet)': roles.surface2,
      'surface3': roles.surface3,
    };
    for (final MapEntry(key: level, value: fill) in levels.entries) {
      testWidgets('skeleton shapes stand out on $level, '
          '${light ? 'light' : 'dark'}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ColoredBox(
                color: fill,
                child: const KitSkeletonRows(count: 2),
              ),
            ),
          ),
        );
        final colors = _shapeColors(tester);
        // A leading mark, a title bar and a supporting bar per row.
        expect(colors, hasLength(6));
        for (final color in colors) {
          final seen = Color.alphaBlend(color, fill);
          expect(
            _contrast(seen, fill),
            greaterThanOrEqualTo(1.15),
            reason:
                'a skeleton shape ($color) must be visible on $level '
                '($fill), not the fill itself',
          );
        }
      });
    }
  }
}
