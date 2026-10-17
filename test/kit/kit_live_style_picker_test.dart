// KitLiveStylePicker: every look is a tile, the chosen one is marked, and
// tapping a tile hands the look to the host (which opens the preview).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  kitMotionStillTests(
    'KitLiveStylePicker',
    builds: {
      'default': () => SizedBox(
        height: 900,
        child: KitLiveStylePicker(selectedId: 'aurora', onOpen: (_) {}),
      ),
    },
    changes: {
      'another look is chosen': KitMotionChange(
        build: () => SizedBox(
          height: 900,
          child: KitLiveStylePicker(selectedId: 'aurora', onOpen: (_) {}),
        ),
        act: (tester, stage) => stage.rebuild(
          SizedBox(
            height: 900,
            child: KitLiveStylePicker(selectedId: 'mesh', onOpen: (_) {}),
          ),
        ),
        shows: 'Breathing mesh',
      ),
    },
  );

  testWidgets('shows the looks and marks the chosen one', (tester) async {
    tester.view.physicalSize = const Size(412, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(KitLiveStylePicker(selectedId: 'aurora', onOpen: (_) {})),
    );
    await tester.pump();
    expect(find.text('Aurora drift'), findsOneWidget);
    expect(find.text('Breathing mesh'), findsOneWidget);
    expect(find.bySemanticsLabel('Aurora drift, selected'), findsOneWidget);
  });

  testWidgets('tapping a tile opens that look', (tester) async {
    tester.view.physicalSize = const Size(412, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    KitLiveStyle? opened;
    await tester.pumpWidget(
      _app(KitLiveStylePicker(selectedId: 'aurora', onOpen: (s) => opened = s)),
    );
    await tester.tap(find.byKey(const ValueKey('live-style-mesh')));
    expect(opened?.id, 'mesh');
  });

  testWidgets('an unknown stored id marks the default', (tester) async {
    tester.view.physicalSize = const Size(412, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(KitLiveStylePicker(selectedId: 'gone', onOpen: (_) {})),
    );
    expect(find.bySemanticsLabel('Aurora drift, selected'), findsOneWidget);
  });
}
