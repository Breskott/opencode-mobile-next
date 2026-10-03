// Behaviour tests for the 2026-09-30 run 3 UI items: a refused project
// command reads as a plain sentence with a way forward and the code under
// Details (P1-1), and the protection line (P1-2).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/phone_project_engine.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/team_project_controller.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_project_editors.dart';
import 'package:opencode_mobile/ui/screens/team/projects/team_refusal.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'kit/kit_harness.dart';

final _l = lookupAppLocalizations(const Locale('en'));

class _Gateway implements OrchestrationProjectGateway {
  _Gateway({this.code, this.throwing});
  final String? code;
  final Object? throwing;
  @override
  Future<TeamWorkspace> teamWorkspace() async => const TeamWorkspace(
    servers: [TeamServer(id: 'pc', name: 'Home PC')],
  );
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() => const Stream.empty();
  @override
  Future<TeamCommandResult> executeProject(TeamProjectCommand command) async {
    if (throwing != null) throw throwing!;
    return TeamCommandResult(accepted: false, code: code ?? '');
  }

  @override
  Future<void> close() async {}
  @override
  Future<void> deleteLocalData() async {}
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String value) async {
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> _fail(WidgetTester tester, _Gateway gateway) async {
  final controller = TeamProjectController(gateway);
  await controller.load();
  addTearDown(controller.dispose);
  final context = await pumpKitHost(
    tester,
    effects: const KitEffects(motion: KitMotionLevel.off),
  );
  unawaited(openTeamNewProject(context, controller));
  await tester.pumpAndSettle();
  await _tap(tester, 'Single lane');
  await _tap(tester, 'No limit');
  await _type(tester, 'goal', 'Read saved articles');
  await _type(tester, 'repoName', 'App');
  await _type(tester, 'repoPath', '/root/projects/app');
  await _tap(tester, 'Home PC');
  final start = find.text('Start planning').last;
  await tester.ensureVisible(start);
  await tester.pumpAndSettle();
  await tester.tap(start);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('the table: known codes read plainly, unknown ones name the action', () {
    final known = teamRefusalFor(
      _l,
      TeamProjectAction.createProject,
      'importFailed',
    );
    expect(known.message, _l.teamRefusalImportFailed);
    expect(known.code, 'importFailed');
    final unknown = teamRefusalFor(
      _l,
      TeamProjectAction.createProject,
      'somethingNew',
    );
    expect(unknown.message, "The team couldn't start planning.");
    expect(unknown.message, isNot(contains('somethingNew')));
    expect(unknown.code, 'somethingNew');
  });

  testWidgets('a refused Start planning says why, how to go on, and keeps '
      'the code under Details', (tester) async {
    await _fail(tester, _Gateway(code: 'importFailed'));
    expect(find.text(_l.teamProjectEditorSaveFailed), findsNothing);
    expect(find.text(_l.teamRefusalImportFailed), findsOneWidget);
    expect(find.text(_l.teamRefusalImportFailedNext), findsOneWidget);
    expect(find.text(_l.teamProjectRetry), findsWidgets);
    expect(find.text('importFailed'), findsNothing);
    final toggle = find.byKey(const ValueKey('kit-details-toggle'));
    await tester.ensureVisible(toggle);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(toggle);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('importFailed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an unknown code names the action, code only under Details', (
    tester,
  ) async {
    await _fail(tester, _Gateway(code: 'brandNewCode'));
    expect(find.text("The team couldn't start planning."), findsOneWidget);
    expect(find.text('brandNewCode'), findsNothing);
    final toggle = find.byKey(const ValueKey('kit-details-toggle'));
    await tester.ensureVisible(toggle);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(toggle);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('brandNewCode'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an adapter failure keeps its safe code', (tester) async {
    await _fail(
      tester,
      _Gateway(throwing: const PhoneEngineException('engineClosed')),
    );
    expect(find.text(_l.teamRefusalEngineClosed), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
