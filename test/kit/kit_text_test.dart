// KitText (lib/ui/kit/kit_text.dart), added by the visual language merge
// before the wave-0b gates existed. Its reduced-motion samples (G8x, MOT-7)
// and the first behaviour checks live here; kit-KitText-v2 owns this file
// and adds the full G19 contracts (LOOK-10–LOOK-17).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  kitMotionStillTests(
    'KitText',
    builds: {
      'default': () => const KitText('Fix flaky checkout test'),
      'rich': () => const KitText.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Needs you'),
            TextSpan(text: ' · 40 s ago'),
          ],
        ),
        role: KitTextRole.caption,
      ),
      'mono': () => const KitText(
        r'$ flutter test test/checkout_test.dart',
        role: KitTextRole.mono,
      ),
    },
  );

  testWidgets('KitText shows its words in the role size and the tone colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const KitText(
          'Needs you · 40 s ago',
          role: KitTextRole.caption,
          tone: KitTextTone.attention,
        ),
      ),
    );
    expect(find.text('Needs you · 40 s ago'), findsOneWidget);
    final style = tester.widget<Text>(find.byType(Text)).style!;
    final roles = ThemeRoles.resolve(AppTheme.dark());
    expect(style.fontSize, 12);
    expect(style.color, roles.attention);
  });

  testWidgets('KitText without a tone takes its role\'s own tone', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KitText('Settings', role: KitTextRole.largeTitle),
            KitText('Laptop', role: KitTextRole.label),
          ],
        ),
      ),
    );
    final roles = ThemeRoles.resolve(AppTheme.dark());
    Color? colour(String text) =>
        tester.widget<Text>(find.text(text)).style!.color;
    expect(colour('Settings'), roles.text1);
    expect(colour('Laptop'), roles.text2);
  });

  testWidgets('mono KitText stays left to right inside Arabic', (tester) async {
    await tester.pumpWidget(
      _host(
        const KitText('src/checkout.dart', role: KitTextRole.mono),
        direction: TextDirection.rtl,
      ),
    );
    expect(
      tester.widget<Text>(find.text('src/checkout.dart')).textDirection,
      TextDirection.ltr,
    );
  });
}
