// AI Team roles (crit roles-ui 2026-09-29): the Agents page lists roles, not
// generated worker names; a live worker shows as the role its task was
// given to (or "Worker"); the role page edits, creates and deletes roles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/team_roles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/team_agents_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'revamp/screen_team_3_fixtures.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Finder _key(String name) => find.byKey(ValueKey(name));

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

/// The agents page over the screen-team-3 team, with [roles] remembered
/// for the given task ids first.
Future<TeamRolesController> _pump(
  WidgetTester tester, {
  Map<String, String> taskRoles = const {},
}) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (controller, _) = await team3Controller();
  addTearDown(controller.dispose);
  final prefs = await SharedPreferences.getInstance();
  final roles = teamRolesFor(prefs, controller.profileId);
  for (final entry in taskRoles.entries) {
    await roles.rememberTaskRole(entry.key, entry.value);
  }
  await tester.pumpWidget(
    _app(
      TeamAgentsScreen(
        controller: controller,
        roles: roles,
        now: () => team3Clock,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return roles;
}

void main() {
  testWidgets('roles are the rows: the five built-ins, none twice, no '
      'generated worker names', (tester) async {
    await _pump(tester);
    for (final id in TeamRoleIds.builtIn) {
      expect(_key('team-role-$id'), findsOneWidget, reason: id);
    }
    expect(find.text(_en.teamRoleNameFrontend), findsOneWidget);
    expect(find.textContaining('furiosa'), findsNothing);
    expect(_key('team-roles-new'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a live worker with no known role is one "Worker" row', (
    tester,
  ) async {
    await _pump(tester);
    expect(_key('team-role-worker-furiosa'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('team-role-worker-furiosa'),
        matching: find.text(_en.teamUiAgentRoleWorker),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a worker shows as the role its task was given to, first', (
    tester,
  ) async {
    await _pump(tester, taskRoles: {'oc-loy': TeamRoleIds.frontend});
    // The worker is the Frontend role now: no separate Worker row.
    expect(_key('team-role-worker-furiosa'), findsNothing);
    expect(
      find.descendant(
        of: _key('team-role-frontend'),
        matching: find.textContaining(
          'Add subtract function',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(_key('team-role-frontend')).dy,
      lessThan(tester.getTopLeft(_key('team-role-general')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('New role: an example fills the form and Create adds the '
      'role', (tester) async {
    final roles = await _pump(tester);
    await tester.tap(_key('team-roles-new'));
    await tester.pumpAndSettle();
    expect(_key('team-role'), findsOneWidget);
    // Nothing to save yet.
    expect(tester.widget<Widget>(_key('team-role-save')), isNotNull);
    await tester.tap(_key('team-role-example-docs'));
    await tester.pumpAndSettle();
    await tester.tap(_key('team-role-save'));
    await tester.pumpAndSettle();
    expect(roles.roles.map((r) => r.name), contains(_en.teamRoleExampleDocs));
    // Back on the agents page, the new role is a row.
    expect(find.text(_en.teamRoleExampleDocs), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a built-in role can be edited and reset; an own role is '
      'deleted after a question naming it', (tester) async {
    final roles = await _pump(tester);
    await tester.tap(_key('team-role-tester'));
    await tester.pumpAndSettle();
    expect(_key('team-role-reset'), findsOneWidget);
    expect(_key('team-role-delete'), findsNothing);
    await tester.enterText(
      _key('team-role-purpose'),
      'Breaks things on purpose',
    );
    await tester.pump();
    await tester.tap(_key('team-role-save'));
    await tester.pumpAndSettle();
    expect(roles.byId(TeamRoleIds.tester)!.purpose, 'Breaks things on purpose');

    final own = await roles.add(
      name: 'Docs writer',
      purpose: 'Guides',
      instructions: 'Write guides.',
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('team-role-${own.id}'));
    await tester.pumpAndSettle();
    await tester.tap(_key('team-role-delete'));
    await tester.pumpAndSettle();
    expect(find.text(_en.teamRoleDeleteTitle('Docs writer')), findsOneWidget);
    await tester.tap(_key('team-role-delete-confirm'));
    await tester.pumpAndSettle();
    expect(roles.byId(own.id), isNull);
    expect(tester.takeException(), isNull);
  });
}
