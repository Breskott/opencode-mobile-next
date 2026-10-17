// KitLiveStylePreview: Use this keeps the look; the current look cannot be
// "used" again; the reply-running switch drives the look's brighten.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _app({required bool current, required VoidCallback onUse}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: KitLiveStylePreview(
          style: kitLiveStyleById('mesh'),
          isCurrent: current,
          onUse: onUse,
        ),
      ),
    );

void main() {
  Widget preview(String style) => SizedBox(
    height: 700,
    child: KitLiveStylePreview(
      style: kitLiveStyleById(style),
      isCurrent: false,
      onUse: () {},
    ),
  );
  kitMotionStillTests(
    'KitLiveStylePreview',
    builds: {'default': () => preview('mesh')},
    changes: {
      'another look is shown': KitMotionChange(
        build: () => preview('mesh'),
        act: (tester, stage) => stage.rebuild(preview('aurora')),
        shows: 'Use this',
      ),
    },
  );

  testWidgets('Use this calls back', (tester) async {
    var used = 0;
    await tester.pumpWidget(_app(current: false, onUse: () => used++));
    await tester.tap(find.byKey(const ValueKey('live-style-use')));
    expect(used, 1);
  });

  testWidgets('the look in use cannot be chosen again', (tester) async {
    var used = 0;
    await tester.pumpWidget(_app(current: true, onUse: () => used++));
    await tester.tap(find.byKey(const ValueKey('live-style-use')));
    expect(used, 0);
  });

  testWidgets('the running switch toggles', (tester) async {
    await tester.pumpWidget(_app(current: false, onUse: () {}));
    final sw = find.descendant(
      of: find.byKey(const ValueKey('live-style-running')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(tester.widget<Switch>(sw).value, isTrue);
  });
}
