// The return brief on the Work tab, after the cleanup (2026-09-24): a
// finished result nobody has looked at carries an "Unreviewed" mark in its
// own row, with Review results and Mark as reviewed in the row's menu. The
// separate "Unreviewed work" card is gone; its acknowledgement rules stay:
// marking reviewed never views the conversation or answers a request, a
// refused save keeps the mark, and a project switch never hides another
// project's work.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api2/models.dart';
import 'package:opencode_mobile/ui/kit/kit.dart' show KitRow;
import 'package:opencode_mobile/ui/screens/run_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'support/return_brief_fixture.dart';
import 'return_brief_state_test.dart' show BriefTestPreferences;

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _containing(String part) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data ?? widget.textSpan?.toPlainText() ?? '').contains(part),
);

Finder get _mark => _containing('Unreviewed');

// Since 23b2efb5 (Work tab from kit parts) on KitRow v2 (08a7741e) a row has
// no per-row menu button: its rarer actions open on long-press.
Future<void> _menu(WidgetTester tester, String item) async {
  await tester.longPress(
    find
        .ancestor(
          of: find.text('Polish the mobile checkout'),
          matching: find.byType(KitRow),
        )
        .first,
  );
  await frames(tester);
  await tester.tap(find.text(item).last);
  await frames(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  testWidgets('an unreviewed result is marked in its row, and there is no '
      'separate card', (tester) async {
    final c = await briefController(requests: true);
    addTearDown(c.dispose);
    await tester.pumpWidget(briefApp(c));
    await frames(tester);
    expect(_mark, findsOneWidget);
    expect(find.text('Unreviewed work'), findsNothing);
    expect(find.text('Dismiss shown items'), findsNothing);
    expect(find.textContaining('Dismissing keeps'), findsNothing);
    // The one waiting on a permission is "needs you", never unreviewed.
    expect(_containing('Permission needed'), findsOneWidget);
  });

  testWidgets('Mark as reviewed never views the conversation or answers a '
      'request, and lasts until the next result', (tester) async {
    final c = await briefController(requests: true);
    addTearDown(c.dispose);
    await tester.pumpWidget(briefApp(c));
    await frames(tester);
    await _menu(tester, 'Mark as reviewed');
    expect(_mark, findsNothing);
    expect(c.isSessionUnread(c.sessionsById['results']!), isTrue);
    expect(c.permissions.keys, ['p1']);
    expect((c.repository as BriefRepository).views, isEmpty);

    final restarted = await briefController(requests: true);
    addTearDown(restarted.dispose);
    await tester.pumpWidget(briefApp(restarted));
    await frames(tester);
    expect(_mark, findsNothing);
    restarted.sessionsById['results'] = briefSession('results', idle: 21);
    restarted.publish();
    await frames(tester);
    expect(_mark, findsOneWidget);
  });

  testWidgets('a refused save keeps the mark and says so; a retry clears it', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    final backend = BriefTestPreferences()..refuse = true;
    SharedPreferencesStorePlatform.instance = backend;
    final c = await briefController();
    addTearDown(c.dispose);
    await tester.pumpWidget(briefApp(c));
    await frames(tester);
    await _menu(tester, 'Mark as reviewed');
    expect(find.text("Couldn't mark it as reviewed. Try again."), findsOne);
    expect(_mark, findsOneWidget);
    backend.refuse = false;
    await _menu(tester, 'Mark as reviewed');
    expect(_mark, findsNothing);
  });

  testWidgets('a project switch during the save never marks the new '
      "project's work", (tester) async {
    SharedPreferences.resetStatic();
    final backend = BriefTestPreferences()..barrier = Completer<void>();
    SharedPreferencesStorePlatform.instance = backend;
    final c = await briefController();
    addTearDown(c.dispose);
    final oldScope = c.returnBriefScope;
    await tester.pumpWidget(briefApp(c));
    await frames(tester);
    await _menu(tester, 'Mark as reviewed');
    c.changeProject();
    c.sessionsById['results'] = briefSession('results');
    c.publish();
    await frames(tester);
    backend.barrier!.complete();
    await frames(tester);
    expect(_mark, findsOneWidget);
    expect(c.returnBriefAcknowledgement.runs, isEmpty);
    expect(c.returnBriefScope, isNot(oldScope));
  });

  testWidgets('Review results opens the result and acknowledges nothing', (
    tester,
  ) async {
    final c = await briefController();
    addTearDown(c.dispose);
    await tester.pumpWidget(briefApp(c));
    await frames(tester);
    await _menu(tester, 'Review results');
    expect(find.byType(RunResultScreen), findsOneWidget);
    await tester.pageBack();
    await frames(tester);
    expect(_mark, findsOneWidget);
    expect(c.returnBriefAcknowledgement.runs, isEmpty);
    expect((c.repository as BriefRepository).views, isEmpty);
  });

  testWidgets('a project change retires the result while it loads', (
    tester,
  ) async {
    final c = await briefController();
    addTearDown(c.dispose);
    final wake = Completer<void>();
    c.wake = wake.future;
    await tester.pumpWidget(briefApp(c));
    await frames(tester);
    await _menu(tester, 'Review results');
    c.changeProject();
    await frames(tester);
    expect(find.byType(RunResultScreen), findsNothing);
    wake.complete();
    await frames(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a server without read state marks nothing', (tester) async {
    final c = await briefController();
    addTearDown(c.dispose);
    c.known = false;
    await tester.pumpWidget(briefApp(c));
    await frames(tester);
    expect(_mark, findsNothing);
    expect(find.text('Review status unknown'), findsNothing);
  });

  testWidgets('a partial list keeps the mark and pages itself', (tester) async {
    final c = await briefController(requests: true);
    addTearDown(c.dispose);
    c.partial = true;
    await tester.pumpWidget(briefApp(c));
    await frames(tester);
    expect(_mark, findsOneWidget);
    final more = find.byKey(const ValueKey('sessions-older-more'));
    await tester.scrollUntilVisible(
      more,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(more, findsOneWidget);
    expect(find.text('Load more conversations'), findsNothing);
    expect(c.returnBriefAcknowledgement.runs, isEmpty);
  });

  testWidgets('an empty failed list does not claim there is nothing', (
    tester,
  ) async {
    final c = await briefController();
    addTearDown(c.dispose);
    c.sessionsById.clear();
    c.sessionsError = 'Could not load this project';
    await tester.pumpWidget(briefApp(c));
    await frames(tester);
    expect(find.text('No recent conversations'), findsNothing);
    expect(find.text('No conversations yet'), findsNothing);
    expect(find.text('Could not load your conversations.'), findsOneWidget);
    expect(find.byKey(const ValueKey('sessions-older-retry')), findsOneWidget);
  });

  for (final cancel in [false, true]) {
    test(
      'form ${cancel ? 'cancel' : 'reply'} rejects project switch during transport wake',
      () async {
        final c = await briefController();
        addTearDown(c.dispose);
        final form = Api2FormInfo(id: 'same', sessionID: 'results');
        c.forms['same'] = form;
        final wake = Completer<void>();
        c.wake = wake.future;
        final send = cancel ? c.cancelForm('same') : c.replyForm('same', {});
        final check = expectLater(send, throwsStateError);
        c.changeProject();
        final replacement = Api2FormInfo(id: 'same', sessionID: 'another');
        c.forms['same'] = replacement;
        wake.complete();
        await check;
        expect((c.api as BriefApi).formReplies, isEmpty);
        expect(c.forms['same'], same(replacement));
      },
    );
  }
}
