// P6.2 Every automatic act reported: the Inbox's While you were away. What
// the app did by itself (a reconnect, a request allowed, a queued message
// sent, a heat pause) joins the one list with what finished, newest first,
// below everything that waits on the person; each act names what it was
// done to, says what was done in its KitAutoLine, opens that thing's page,
// offers Undo only where the act has a real inverse, and is never Needs
// you. Dismissals (acts and finished work) survive a restart.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/while_away.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/automatic_activity.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/activity_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));

class _Repository implements ProductRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store);

  @override
  bool get isConnected => status == StreamStatus.connected;
  @override
  Future<ServerOperationsGateway?> prepareActionRepository() async =>
      repository;
  @override
  Future<void> refreshSessions() async {}
  @override
  Future<void> refreshPendingPermissions() async {}
  @override
  Future<void> refreshPendingQuestions() async {}
  @override
  Future<void> refreshPendingForms() async {}
}

const _dir = '/work/app';

Future<_Controller> _controller() async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'laptop',
        'name': 'Laptop',
        'baseUrl': 'http://192.168.1.20:4096',
        'username': '',
      },
      {
        'id': 'studio',
        'name': 'Studio',
        'baseUrl': 'http://192.168.1.30:4096',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'laptop',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  final controller = _Controller(store)
    ..repository = _Repository()
    ..status = StreamStatus.connected
    ..directory = _dir;
  controller.sessionsById = {
    'ses_fix': Session(
      id: 'ses_fix',
      title: 'Fix login',
      directory: _dir,
      time: SessionTime(created: 1, updated: 2),
    ),
  };
  return controller;
}

Session _finished(String id, String title, DateTime idle) => Session(
  id: id,
  title: title,
  directory: _dir,
  time: SessionTime(
    created: 1,
    updated: idle.millisecondsSinceEpoch,
    idle: idle.millisecondsSinceEpoch,
  ),
);

Future<void> _serverAct(
  _Controller controller,
  String eventId,
  DateTime at, {
  AutomaticActKind kind = AutomaticActKind.reconnect,
  String profileId = 'laptop',
}) async {
  expect(
    await controller.recordServerAct(
      profileId: profileId,
      kind: kind,
      eventId: eventId,
      at: at,
    ),
    isTrue,
  );
}

Widget _app(Widget home, {List<String>? pushed}) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
  onGenerateRoute: (settings) {
    pushed?.add(settings.name ?? '');
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const Scaffold(body: Text('conversation page')),
    );
  },
);

Finder _words(String text) => find.textContaining(text, findRichText: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AutomaticActivityController.resetShared();
    for (final channel in const [
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      MethodChannel('oc/background'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
    }
  });
  tearDown(AutomaticActivityController.resetShared);

  testWidgets('automatic acts join the one list below what waits, newest '
      'first with finished work, and never read as Needs you', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final now = DateTime.now();
    controller.sessionsById = {
      ...controller.sessionsById,
      'ses_done': _finished(
        'ses_done',
        'Update the docs',
        now.subtract(const Duration(hours: 2)),
      ),
    };
    controller.permissions = {
      'perm-1': PermissionRequest(
        id: 'perm-1',
        sessionID: 'ses_fix',
        permission: 'edit',
        patterns: const ['lib/main.dart'],
      ),
    };
    await _serverAct(
      controller,
      'reconnect-1',
      now.subtract(const Duration(hours: 1)),
    );
    expect(
      await controller.recordAutomaticAct(
        profileId: 'laptop',
        location: controller.automaticActivityProject,
        kind: AutomaticActKind.queuedSend,
        target: 'Fix login',
        eventId: 'queue-1',
        at: now.subtract(const Duration(hours: 3)),
        sessionId: 'ses_fix',
      ),
      isTrue,
    );
    // Another server's act and another project's act stay out of this list.
    await _serverAct(controller, 'studio-1', now, profileId: 'studio');
    expect(
      await controller.recordAutomaticAct(
        profileId: 'laptop',
        location: 'another project',
        kind: AutomaticActKind.permissionApproval,
        target: 'Elsewhere',
        eventId: 'other-1',
        at: now,
      ),
      isTrue,
    );

    await tester.pumpWidget(_app(ActivityScreen(controller: controller)));
    await tester.pump();

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final permission = find.text('Edit a file');
    final reconnect = find.text('Laptop');
    final finished = find.text('Update the docs');
    final sent = find.text('Fix login').last;
    expect(permission, findsOneWidget);
    expect(reconnect, findsOneWidget);
    expect(top(permission), lessThan(top(reconnect)));
    expect(top(reconnect), lessThan(top(finished)));
    expect(top(finished), lessThan(top(sent)));

    // What was done, in one line under the thing it was done to.
    expect(_words(_en.whileAwayActReconnected), findsOneWidget);
    expect(_words(_en.whileAwayActQueuedSent), findsOneWidget);
    expect(find.text('Studio'), findsNothing);
    expect(find.text('Elsewhere'), findsNothing);
    expect(_words(_en.whileAwayActAllowed), findsNothing);

    // Never Needs you: only the one request says it.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('activity-list')),
        matching: _words('Needs you'),
      ),
      findsOneWidget,
    );
    // No section header for it (owner rule R1).
    expect(find.text('While you were away'), findsNothing);
  });

  testWidgets('an act on a conversation opens that conversation', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.recordAutomaticAct(
      profileId: 'laptop',
      location: controller.automaticActivityProject,
      kind: AutomaticActKind.permissionApproval,
      target: 'Fix login',
      eventId: 'perm-auto-1',
      at: DateTime.now(),
      sessionId: 'ses_fix',
    );
    final pushed = <String>[];
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
        pushed: pushed,
      ),
    );
    await tester.pump();

    expect(_words(_en.whileAwayActAllowed), findsOneWidget);
    await tester.tap(find.text('Fix login'));
    await tester.pumpAndSettle();
    expect(pushed, ['/chat/ses_fix']);
  });

  testWidgets('Dismiss hides an act at once with Undo, then saves it so it '
      'stays gone', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await _serverAct(controller, 'reconnect-1', DateTime.now());
    final history = controller.automaticActivity!;
    final id = history.acts.single.id;
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
      ),
    );
    await tester.pump();
    final row = find.byKey(ValueKey('activity-auto-$id'));
    expect(row, findsOneWidget);

    // Dismiss, then Undo: back, and nothing saved.
    await tester.drag(row, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(row, findsNothing);
    expect(find.text(_en.whileAwayDismissed('Laptop')), findsOneWidget);
    await tester.tap(find.text(_en.kitUndoAction));
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
    expect(history.acts.single.acknowledged, isFalse);

    // Dismiss and let the window close: saved as acknowledged.
    await tester.drag(row, const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.pump(KitUndo.window + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(history.acts.single.acknowledged, isTrue);
    expect(row, findsNothing);
    expect(controller.automaticActsHere, isEmpty);
  });

  testWidgets('Undo shows only for an act with a real inverse, and says when '
      'it is undone', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final history = controller.automaticActivity!;
    final location = controller.automaticActivityProject;
    var inverses = 0;
    final at = DateTime.now();
    await history.record(
      eventId: 'with-inverse',
      location: location,
      kind: AutomaticActKind.permissionApproval,
      summary: 'Fix login',
      occurredAt: at,
      sessionId: 'ses_fix',
      undo: () async {
        inverses += 1;
        return true;
      },
    );
    await history.record(
      eventId: 'no-inverse',
      location: location,
      kind: AutomaticActKind.queuedSend,
      summary: 'Fix login',
      occurredAt: at.subtract(const Duration(seconds: 1)),
      sessionId: 'ses_fix',
    );
    final withInverse = history.acts.firstWhere(
      (act) => act.kind == AutomaticActKind.permissionApproval,
    );
    final without = history.acts.firstWhere(
      (act) => act.kind == AutomaticActKind.queuedSend,
    );
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(ValueKey('activity-auto-undo-${without.id}')),
      findsNothing,
    );
    final undo = find.byKey(ValueKey('activity-auto-undo-${withInverse.id}'));
    expect(undo, findsOneWidget);
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(inverses, 1);
    expect(
      _words(_en.whileAwayActUndone(_en.whileAwayActAllowed)),
      findsOneWidget,
    );
    expect(undo, findsNothing);
  });

  testWidgets('a history the device could not read says so', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.store.prefs.setString(
      'oc.automaticActivity.laptop',
      '{broken',
    );
    AutomaticActivityController.resetShared();
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
      ),
    );
    await tester.pump();
    expect(find.text(_en.whileAwayHistoryUnreadable), findsOneWidget);
  });

  testWidgets('a dismissed finished run stays reviewed after the Inbox is '
      'rebuilt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final idle = DateTime.now().subtract(const Duration(minutes: 5));
    controller.sessionsById = {
      'ses_done': _finished('ses_done', 'Update the docs', idle),
    };
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update the docs'));
    await tester.pumpAndSettle();
    final dismiss = find.descendant(
      of: find.byKey(const Key('completion-digest-card')),
      matching: find.text(_en.digestDismiss),
    );
    await tester.ensureVisible(dismiss);
    await tester.pumpAndSettle();
    await tester.tap(dismiss);
    await tester.pumpAndSettle();
    await tester.pump(KitUndo.window + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      controller.returnBriefAcknowledgement.coversRun(
        'ses_done',
        idle.millisecondsSinceEpoch,
      ),
      isTrue,
    );

    // A fresh Inbox (a restart) does not bring it back.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(
        Scaffold(body: ActivityScreen(controller: controller, embedded: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update the docs'), findsNothing);
  });

  testWidgets('deleting a server drains and removes its history', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await _serverAct(
      controller,
      'studio-1',
      DateTime.now(),
      profileId: 'studio',
    );
    expect(
      controller.store.prefs.getString('oc.automaticActivity.studio'),
      isNotNull,
    );

    await controller.deleteProfileAndLocalData('studio');

    expect(
      controller.store.prefs.getString('oc.automaticActivity.studio'),
      isNull,
    );
    // Nothing can file an act for a server that is gone.
    expect(
      await controller.recordServerAct(
        profileId: 'studio',
        kind: AutomaticActKind.reconnect,
        eventId: 'late',
        at: DateTime.now(),
      ),
      isFalse,
    );
    expect(
      controller.store.prefs.getString('oc.automaticActivity.studio'),
      isNull,
    );
  });
}
