// KitWidgetPreview: a drawing of the home-screen widget in the chosen style.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _part(
  KitWidgetPreviewSize size, {
  KitWidgetPreviewBackground background = KitWidgetPreviewBackground.solid,
  Color accent = const Color(0xFF48AC6F),
}) => KitWidgetPreview(size: size, background: background, accent: accent);

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  kitMotionStillTests(
    'KitWidgetPreview',
    builds: {
      'compact': () => _part(KitWidgetPreviewSize.compact),
      'card': () => _part(KitWidgetPreviewSize.card),
      'list': () => _part(KitWidgetPreviewSize.list),
    },
    changes: {
      'the layout changes': KitMotionChange(
        build: () => _part(KitWidgetPreviewSize.compact),
        act: (tester, stage) => stage.rebuild(_part(KitWidgetPreviewSize.list)),
        shows: 'Write the release notes',
      ),
    },
  );

  testWidgets('each layout shows sample words, never the person\'s own', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_part(KitWidgetPreviewSize.card)));
    await tester.pumpAndSettle();
    expect(find.text('Fix the sign-in page'), findsOneWidget);
    expect(find.text('Editing files'), findsOneWidget);
    await tester.pumpWidget(_app(_part(KitWidgetPreviewSize.compact)));
    await tester.pumpAndSettle();
    expect(find.text('Working'), findsOneWidget);
    await tester.pumpWidget(_app(_part(KitWidgetPreviewSize.list)));
    await tester.pumpAndSettle();
    expect(find.text('Allow'), findsOneWidget);
  });

  testWidgets('a see-through ground is drawn without a fill', (tester) async {
    await tester.pumpWidget(
      _app(
        _part(
          KitWidgetPreviewSize.card,
          background: KitWidgetPreviewBackground.transparent,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fills = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .whereType<Color>();
    expect(fills.any((c) => c.a == 0), isTrue);
  });

  testWidgets('is one labelled widget for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_part(KitWidgetPreviewSize.card)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Widget preview'), findsOneWidget);
    expect(find.bySemanticsLabel('Editing files'), findsNothing);
    handle.dispose();
  });
}
