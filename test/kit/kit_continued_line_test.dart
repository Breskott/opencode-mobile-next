// KitContinuedLine: the quiet line between two conversations opens the other
// one, and a conversation that is gone turns the line off.
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
  testWidgets('a tap opens the other conversation', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _app(
        KitContinuedLine(
          text: 'Continued in Claude Code',
          onOpen: () => opened++,
        ),
      ),
    );
    await tester.tap(find.text('Continued in Claude Code'));
    expect(opened, 1);
  });

  testWidgets('a conversation that is gone says so and does not open', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _app(
        KitContinuedLine(
          text: 'Continued in Claude Code',
          onOpen: () => opened++,
          gone: true,
        ),
      ),
    );
    expect(
      find.text('This conversation is no longer available.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('continued-line')));
    expect(opened, 0);
  });

  kitMotionStillTests(
    'KitContinuedLine',
    builds: {
      'default': () =>
          KitContinuedLine(text: 'Continued in Claude Code', onOpen: () {}),
      'gone': () => KitContinuedLine(
        text: 'Continued in Claude Code',
        onOpen: () {},
        gone: true,
      ),
    },
    changes: {
      'the other conversation goes': KitMotionChange(
        build: () =>
            KitContinuedLine(text: 'Continued in Claude Code', onOpen: () {}),
        act: (tester, stage) => stage.rebuild(
          KitContinuedLine(
            text: 'Continued in Claude Code',
            onOpen: () {},
            gone: true,
          ),
        ),
        shows: 'This conversation is no longer available.',
      ),
    },
  );
}
