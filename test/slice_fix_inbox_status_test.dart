// slice-fix-inbox-status (emulator QA 2026-09-28, F3 F4 F5 F15): a Stop is
// not a failure, an untitled conversation reads as Work shows it, routine
// reconnects are one row, an outage is said once, and every "as of" uses
// the device's own clock.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/domain/session_stop.dart';
import 'package:opencode_mobile/domain/while_away.dart';
import 'package:opencode_mobile/domain/work_row_status.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/attention_feed.dart';
import 'package:opencode_mobile/state/automatic_activity.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/elsewhere_attention.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/activity_screen.dart';
import 'package:opencode_mobile/ui/widgets/attention_feed_rows.dart';
import 'package:opencode_mobile/ui/widgets/older_sessions_pager.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));

class _Repository implements ProductRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends ConnectionController {
  _Controller(super.store);

  bool connected = true;

  @override
  bool get isConnected => connected;
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

Future<_Controller> _controller() async {
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'phone',
        'name': '127.0.0.1',
        'baseUrl': 'http://127.0.0.1:4096',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'phone',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  return _Controller(store)
    ..repository = _Repository()
    ..status = StreamStatus.connected
    ..directory = '/work/app';
}

Widget _app(Widget home, {bool use24h = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(disableAnimations: true, alwaysUse24HourFormat: use24h),
    child: child!,
  ),
  home: Scaffold(body: home),
);

String _plain(String text) =>
    text.replaceAll(RegExp('[\u2066-\u2069\u200e\u200f\u202a-\u202e]'), '');

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

  group('F3 a Stop is not a failure', () {
    test('the session.error of a Stop is recognised, v1 and v2', () {
      expect(sessionErrorIsStop({'name': 'MessageAbortedError'}), isTrue);
      expect(sessionErrorIsStop({'type': 'aborted'}), isTrue);
      expect(
        sessionErrorIsStop({
          'name': 'ProviderAuthError',
          'data': {'message': 'no key'},
        }),
        isFalse,
      );
      expect(sessionErrorIsStop({'name': 'UnknownError'}), isFalse);
      expect(sessionErrorIsStop(null), isFalse);
      expect(sessionErrorIsStop('MessageAbortedError'), isFalse);
    });

    test('another project\'s stopped run is not listed as failed; a real '
        'failure still is', () {
      final tracker = ElsewhereAttention();
      EventEnvelope event(String type, Map<String, dynamic> p) =>
          EventEnvelope(type: type, properties: p, directory: '/work/fin');
      tracker.handle(
        event('session.status', {
          'sessionID': 's1',
          'status': {'type': 'busy'},
        }),
      );
      tracker.handle(
        event('session.error', {
          'sessionID': 's1',
          'error': {
            'name': 'MessageAbortedError',
            'data': {'message': 'Aborted'},
          },
        }),
      );
      expect(
        tracker.observations().where((o) => o.kind == AttentionKind.failedRun),
        isEmpty,
      );
      // The stop still ends the run.
      expect(tracker.activity(), isEmpty);

      tracker.handle(
        event('session.error', {
          'sessionID': 's2',
          'error': {'name': 'ProviderAuthError'},
        }),
      );
      expect(
        tracker
            .observations()
            .where((o) => o.kind == AttentionKind.failedRun)
            .map((o) => o.sessionID),
        ['s2'],
      );
    });

    testWidgets('an untitled conversation reads "New conversation" in the '
        'Inbox, as Work shows it, never the server\'s placeholder', (
      tester,
    ) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final item = AttentionFeedItem(
        identity: 'fail',
        profileID: 'other',
        serverName: 'Home PC',
        kind: AttentionKind.failedRun,
        title: 'New session - 2026-09-28T19:15:50.446Z',
        target: const AttentionTarget(
          profileID: 'other',
          kind: AttentionKind.failedRun,
          sessionID: 's1',
        ),
        status: WorkRowStatus(
          facts: const WorkRowFacts(phase: WorkRowPhase.failed),
          observedAt: DateTime(2026, 9, 28, 23, 19),
          isFresh: true,
        ),
      );
      await tester.pumpWidget(
        _app(
          AttentionFeedRow(
            controller: controller,
            item: item,
            now: DateTime(2026, 9, 28, 23, 21),
            onOpenConversation: (_, _) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_en.workspaceNewSession), findsOneWidget);
      expect(find.textContaining('New session -'), findsNothing);
    });
  });

  group('F15 one clock', () {
    Future<String> line(WidgetTester tester, {required bool use24h}) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final item = AttentionFeedItem(
        identity: 'old',
        profileID: 'other',
        serverName: 'Home PC',
        kind: AttentionKind.failedRun,
        title: 'Fix login',
        target: const AttentionTarget(
          profileID: 'other',
          kind: AttentionKind.failedRun,
          sessionID: 's1',
        ),
        status: WorkRowStatus(
          facts: const WorkRowFacts(phase: WorkRowPhase.failed),
          observedAt: DateTime(2026, 9, 28, 23, 19),
          isFresh: false,
        ),
      );
      await tester.pumpWidget(
        _app(
          AttentionFeedRow(
            key: const ValueKey('row'),
            controller: controller,
            item: item,
            now: DateTime(2026, 9, 28, 23, 40),
            onOpenConversation: (_, _) {},
          ),
          use24h: use24h,
        ),
      );
      await tester.pump();
      final row = tester.widget<KitRow>(
        find.descendant(
          of: find.byKey(const ValueKey('row')),
          matching: find.byType(KitRow),
        ),
      );
      return _plain(row.supporting!.toPlainText());
    }

    testWidgets('an Inbox "as of" follows the device 12/24-hour setting, '
        'the clock alone today (was "9/28/2026 23:19")', (tester) async {
      expect(
        await line(tester, use24h: false),
        'Failed · as of 11:19 PM · on Home PC',
      );
      expect(
        await line(tester, use24h: true),
        'Failed · as of 23:19 · on Home PC',
      );
    });
  });

  group('F4 routine reconnects are one row', () {
    testWidgets('five reconnects read as one current row; dismissing it '
        'dismisses them all', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = await _controller();
      addTearDown(controller.dispose);
      final now = DateTime.now();
      for (final minutes in [39, 23, 19, 16, 1]) {
        expect(
          await controller.recordServerAct(
            profileId: 'phone',
            kind: AutomaticActKind.reconnect,
            eventId: 'reconnect-$minutes',
            at: now.subtract(Duration(minutes: minutes)),
          ),
          isTrue,
        );
      }
      // A different act is its own row still.
      expect(
        await controller.recordServerAct(
          profileId: 'phone',
          kind: AutomaticActKind.restart,
          eventId: 'restart-1',
          at: now.subtract(const Duration(minutes: 30)),
        ),
        isTrue,
      );
      await tester.pumpWidget(
        _app(ActivityScreen(controller: controller, embedded: true)),
      );
      await tester.pump();

      expect(
        find.textContaining(_en.whileAwayActReconnected, findRichText: true),
        findsOneWidget,
      );
      // The one row is the newest.
      expect(
        find.textContaining(_en.e7WorkspaceMinutesAgo(16), findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining(_en.e7WorkspaceMinutesAgo(1), findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(_en.whileAwayActRestarted, findRichText: true),
        findsOneWidget,
      );

      final history = controller.automaticActivity!;
      final newest = history.acts
          .where((act) => act.kind == AutomaticActKind.reconnect)
          .first;
      final row = find.byKey(ValueKey('activity-auto-${newest.id}'));
      expect(row, findsOneWidget);
      await tester.drag(row, const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.pump(KitUndo.window + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // No older reconnect steps up in its place.
      expect(
        find.textContaining(_en.whileAwayActReconnected, findRichText: true),
        findsNothing,
      );
      expect(
        history.acts
            .where((act) => act.kind == AutomaticActKind.reconnect)
            .every((act) => act.acknowledged),
        isTrue,
      );
      expect(
        find.textContaining(_en.whileAwayActRestarted, findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('F5 an outage is said once', () {
    Widget pager(ConnectionController controller) => _app(
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => OlderSessionsPager.showsFor(controller)
            ? OlderSessionsPager(controller: controller)
            : const SizedBox.shrink(),
      ),
    );

    testWidgets('while the server is not answering, no "Could not load your '
        'conversations" panel joins the status line', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller
        ..connected = false
        ..sessionsError = 'SocketException: Connection refused';
      await tester.pumpWidget(pager(controller));
      await tester.pump();
      expect(find.byKey(const ValueKey('sessions-older-error')), findsNothing);
      expect(find.text(_en.sessionsLoadFailed), findsNothing);
      expect(find.textContaining('SocketException'), findsNothing);
    });

    testWidgets('connected, a list that failed to load still says so with '
        'Try again', (tester) async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.sessionsError = 'HTTP 500';
      await tester.pumpWidget(pager(controller));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sessions-older-error')),
        findsOneWidget,
      );
      expect(find.text(_en.sessionsLoadFailed), findsOneWidget);
    });
  });
}
