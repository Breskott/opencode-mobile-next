// screen-team-3 (wave 2b): the Work sheet's missing item is a designed
// state. (The agents list of this wave became the roles page; its tests
// are in team_roles_ui_test.dart.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/work_sheet.dart';

import 'screen_team_3_fixtures.dart';

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

Finder _key(String name) => find.byKey(ValueKey(name));

void main() {
  testWidgets('a work item the host no longer lists is a designed state', (
    tester,
  ) async {
    final (controller, _) = await team3Controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showWorkSheet(
                  context,
                  controller,
                  'gone',
                  now: () => team3Clock,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Work item gone'), findsOneWidget);
    expect(_key('team-work-sheet-missing'), findsOneWidget);
    expect(
      find.text('This work item is no longer on the host.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Close this sheet to see the task as it is now.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
