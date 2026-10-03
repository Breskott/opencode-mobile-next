// KitGroupNote (slice-P3.10, docs/ux-system/kit-api/KitGroupNote.md): the one
// muted line under a row group that says what it leaves out, with a Why.
import 'kit_motion_still.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: app!,
  ),
  home: Scaffold(body: ListView(children: [child])),
);

void main() {
  kitMotionStillTests(
    'KitGroupNote',
    builds: {
      'with explanation action': () => KitGroupNote(
        message: 'Two settings are unavailable',
        action: KitAction(label: 'Why', onPressed: () {}),
      ),
      'words only': () =>
          const KitGroupNote(message: 'Two settings are unavailable'),
    },
  );

  const message = "2 settings aren't available on this server";

  testWidgets('says what is missing and runs its action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        KitGroupNote(
          message: message,
          action: KitAction(
            key: const ValueKey('why'),
            label: 'Why',
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text(message), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('why')));
    expect(taps, 1);
  });

  testWidgets('words alone without an action', (tester) async {
    await tester.pumpWidget(_host(const KitGroupNote(message: message)));
    expect(find.text(message), findsOneWidget);
    expect(find.byType(KitButton), findsNothing);
  });

  testWidgets('the action wraps under the words at 320 dp and 2x text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        KitGroupNote(
          message: message,
          action: KitAction(
            key: const ValueKey('why'),
            label: 'Why',
            onPressed: () {},
          ),
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    final words = tester.getRect(find.text(message));
    final why = tester.getRect(find.byKey(const ValueKey('why')));
    expect(why.top, greaterThanOrEqualTo(words.bottom - 1));
  });
}
