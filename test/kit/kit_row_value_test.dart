// KitRowValue (lib/ui/kit/kit_row.dart), added by the visual language merge
// before the wave-0b gates existed. Its reduced-motion samples (G8x, MOT-7)
// and the first behaviour checks live here; kit-KitRow-v2 rebuilds the part
// and adds its full contracts.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: SizedBox(
      width: 200,
      child: Align(alignment: AlignmentDirectional.centerEnd, child: child),
    ),
  ),
);

void main() {
  kitMotionStillTests(
    'KitRowValue',
    builds: {
      'default': () => const KitRowValue('Claude Sonnet 4'),
      'no chevron': () => const KitRowValue('Ask first', chevron: false),
    },
  );

  testWidgets('KitRowValue shows the value before a chevron', (tester) async {
    await tester.pumpWidget(_host(const KitRowValue('Claude Sonnet 4')));
    expect(find.text('Claude Sonnet 4'), findsOneWidget);
    expect(find.byIcon(AppIconography.chevronRight), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(AppIconography.chevronRight)).dx,
      greaterThan(tester.getCenter(find.text('Claude Sonnet 4')).dx),
    );
  });

  testWidgets('KitRowValue without a chevron shows only the value', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const KitRowValue('Ask first', chevron: false)),
    );
    expect(find.text('Ask first'), findsOneWidget);
    expect(find.byIcon(AppIconography.chevronRight), findsNothing);
  });

  testWidgets('a long KitRowValue stays on one line and never overflows', (
    tester,
  ) async {
    const long =
        'Claude Sonnet 4 with extended thinking on the office workstation';
    await tester.pumpWidget(_host(const KitRowValue(long)));
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
