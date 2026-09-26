// Gate G10 (docs/ux-system/kit-v2.md §7): a KitSheet with a KitDraft keeps
// typed text across swipe down, back, Esc and a restart, without asking;
// its key is oc.draft.<target>.<profileId>, and ProfileStore's deletion
// sweep finds it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kit_harness.dart';

const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Future<void> _openNote(
  WidgetTester tester,
  BuildContext context,
  KitDraft draft,
) async {
  unawaited(
    showKitSheet<void>(
      context,
      title: 'Session note',
      draft: draft,
      // A guard is present, but the draft wins: nothing is asked.
      dirty: ValueNotifier(true),
      body: (_) => TextField(controller: draft.controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _secure,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, null);
  });

  test('the key is oc.draft.<target>.<profileId>', () {
    expect(KitDraft.keyFor('note.ses_1', 'p1'), 'oc.draft.note.ses_1.p1');
  });

  for (final (how, dismiss) in <(String, Future<void> Function(WidgetTester))>[
    (
      'swipe down',
      (tester) =>
          tester.fling(find.text('Session note'), const Offset(0, 500), 2000),
    ),
    ('back', (tester) async => tester.binding.handlePopRoute()),
    ('Esc', (tester) async => tester.sendKeyEvent(LogicalKeyboardKey.escape)),
    ('close', (tester) => tester.tap(find.byTooltip('Close'))),
  ]) {
    testWidgets('typed text survives $how, silently', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final context = await pumpKitHost(tester);
      final first = TextEditingController();
      addTearDown(first.dispose);
      final draft = KitDraft(
        target: 'note.ses_1',
        profileId: 'p1',
        controller: first,
        prefs: prefs,
      );
      await _openNote(tester, context, draft);
      await tester.enterText(find.byType(TextField), 'half a thought');
      await tester.pump();
      await dismiss(tester);
      await tester.pumpAndSettle();
      expect(find.text('Session note'), findsNothing, reason: 'closed');
      expect(find.text('Discard your changes?'), findsNothing);
      expect(prefs.getString('oc.draft.note.ses_1.p1'), 'half a thought');

      // Reopened with a fresh field (a new screen, or after a restart).
      final second = TextEditingController();
      addTearDown(second.dispose);
      await _openNote(
        tester,
        context,
        KitDraft(
          target: 'note.ses_1',
          profileId: 'p1',
          controller: second,
          prefs: prefs,
        ),
      );
      expect(second.text, 'half a thought');
      expect(find.text('half a thought'), findsOneWidget);
    });
  }

  testWidgets('it survives a restart: the store is read again', (tester) async {
    final context = await pumpKitHost(tester);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _openNote(
      tester,
      context,
      KitDraft(target: 'note.ses_2', profileId: 'p1', controller: controller),
    );
    await tester.enterText(find.byType(TextField), 'before the crash');
    await tester.pumpAndSettle();
    // A cold start re-reads the platform store.
    SharedPreferences.resetStatic();
    final fresh = await SharedPreferences.getInstance();
    expect(fresh.getString('oc.draft.note.ses_2.p1'), 'before the crash');
  });

  testWidgets('clear forgets it once the input is used', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final context = await pumpKitHost(tester);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final draft = KitDraft(
      target: 'note.ses_3',
      profileId: 'p1',
      controller: controller,
      prefs: prefs,
    );
    unawaited(
      showKitSheet<void>(
        context,
        title: 'Session note',
        draft: draft,
        body: (_) => TextField(controller: controller),
        primary: KitAction(
          label: 'Save note',
          onPressed: () async {
            await draft.clear();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'done');
    await tester.pump();
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(prefs.getString('oc.draft.note.ses_3.p1'), isNull);
  });

  testWidgets('profile deletion sweeps the draft', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final context = await pumpKitHost(tester);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _openNote(
      tester,
      context,
      KitDraft(
        target: 'note.ses_1',
        profileId: 'doomed',
        controller: controller,
        prefs: prefs,
      ),
    );
    await tester.enterText(find.byType(TextField), 'secret plan');
    await tester.pumpAndSettle();
    await prefs.setString('oc.draft.note.ses_1.keeper', 'other server');

    final store = ProfileStore(prefs: prefs);
    final scoped = store.profileScopedPreferenceKeys('doomed');
    expect(scoped, contains('oc.draft.note.ses_1.doomed'));
    expect(scoped, isNot(contains('oc.draft.note.ses_1.keeper')));
    expect(await store.removeScopedPreferences('doomed'), isEmpty);
    expect(prefs.getString('oc.draft.note.ses_1.doomed'), isNull);
    expect(prefs.getString('oc.draft.note.ses_1.keeper'), 'other server');
  });
}
