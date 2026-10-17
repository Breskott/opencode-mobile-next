// KitFloatingPanel: a card over a dimmed ground that closes when the ground
// is tapped, and rides above the keyboard.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _part({VoidCallback? onDismiss}) =>
    KitFloatingPanel(onDismiss: onDismiss, child: const Text('Inside'));

Widget _app(Widget child, {double keyboard = 0}) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
    child: app!,
  ),
  home: child,
);

void main() {
  kitMotionStillTests(
    'KitFloatingPanel',
    builds: {'default': () => _part(onDismiss: () {})},
    changes: {
      'closing is switched off': KitMotionChange(
        build: () => _part(onDismiss: () {}),
        act: (tester, stage) => stage.rebuild(_part()),
        shows: 'Inside',
      ),
    },
  );

  testWidgets('tapping the ground closes it; tapping the card does not', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(_app(_part(onDismiss: () => closed++)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inside'));
    expect(closed, 0);
    await tester.tapAt(const Offset(10, 10));
    expect(closed, 1);
  });

  testWidgets('while closing is off the ground ignores taps', (tester) async {
    await tester.pumpWidget(_app(_part()));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    expect(find.text('Inside'), findsOneWidget);
  });

  testWidgets('rises above the keyboard', (tester) async {
    await tester.pumpWidget(_app(_part(onDismiss: () {})));
    await tester.pumpAndSettle();
    final resting = tester.getBottomLeft(find.text('Inside')).dy;
    await tester.pumpWidget(_app(_part(onDismiss: () {}), keyboard: 300));
    await tester.pumpAndSettle();
    expect(
      resting - tester.getBottomLeft(find.text('Inside')).dy,
      closeTo(300, 1),
    );
  });
}
