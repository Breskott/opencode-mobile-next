import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/api2/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/offline_queue.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/terminal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/complete_message_history.dart';

// The motion pass's parts, adopted in real screens (docs/qa/motion-adopt-
// 2026-09-25): pull to refresh draws the portal and reloads, a refresh
// failure unfolds and settles, a row added after the first load unfolds (the
// first paint does not), and the chat's send and finished reply use
// KitHaptics. The ready screen's celebration is covered in
// phone_setup_ready_screen_test.dart.

TerminalProcess _terminal(String id) => TerminalProcess(
  id: id,
  title: 'Terminal $id',
  command: 'bash',
  arguments: const [],
  directory: '/work',
  pid: id.hashCode,
  running: true,
);

class _Repository implements ProductRepository {
  final terminals = <TerminalProcess>[_terminal('one')];
  Object? failure;
  var loads = 0;

  @override
  Future<List<TerminalProcess>> listTerminals() async {
    loads++;
    if (failure case final failure?) throw failure;
    return List.of(terminals);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ConnectionController> _terminalController(_Repository repository) async {
  SharedPreferences.setMockInitialValues({});
  return ConnectionController(
      ProfileStore(prefs: await SharedPreferences.getInstance()),
    )
    ..repository = repository
    ..status = StreamStatus.connected;
}

Future<void> _pumpTerminals(
  WidgetTester tester,
  ConnectionController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TerminalScreen(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
}

List<MethodCall> _haptics(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

class _ChatApi extends OpenCodeApi with CompleteMessageHistory {
  _ChatApi() : super(baseUrl: 'http://localhost');

  final prompts = <String>[];

  @override
  ServerCapabilities get capabilities =>
      const ServerCapabilities(forms: true, inbox: true);

  @override
  Future<List<MessageWithParts>> messages(String id) async => [];

  @override
  Future<List<Api2InboxItem>> inboxItems(String sessionID) async => const [];

  @override
  Future<void> promptAsync(
    String sessionID, {
    required String text,
    ModelRef? model,
    String? agent,
    String? variant,
    List<PromptAttachment> attachments = const [],
    List<PromptAgentMention> agentMentions = const [],
    PromptDelivery? delivery,
  }) async {
    prompts.add(text);
  }
}

Future<ConnectionController> _chatController(OpenCodeApi api) async {
  // Seeded through SharedPreferences: upsert would write the password
  // through flutter_secure_storage (mocked in setUp).
  SharedPreferences.setMockInitialValues({
    'oc.profiles': jsonEncode([
      {
        'id': 'profile-1',
        'name': 'Test server',
        'baseUrl': 'http://localhost',
        'username': '',
      },
    ]),
    'oc.activeProfile': 'profile-1',
  });
  final store = ProfileStore(prefs: await SharedPreferences.getInstance());
  await store.load();
  return ConnectionController(store)
    ..api = api
    ..status = StreamStatus.connected;
}

/// Bounded pump: a chat keeps looping indicators alive in some states.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _pumpChat(
  WidgetTester tester,
  ConnectionController controller,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connProvider.overrideWithValue(controller)],
      child: const MaterialApp(home: ChatScreen(sessionID: 'session-1')),
    ),
  );
  await _settle(tester);
}

void _enqueue(ConnectionController controller, String inboxID, String text) {
  controller.handleEventForTesting(
    EventEnvelope(
      type: 'session.inbox.enqueued',
      properties: {
        'sessionID': 'session-1',
        'inboxID': inboxID,
        'item': {
          'type': 'user',
          'payload': {'text': text},
          'delivery': 'queue',
        },
      },
    ),
  );
}

double _height(WidgetTester tester, Finder finder) =>
    tester.getSize(finder).height;

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  group('pull to refresh', () {
    testWidgets('pulling the terminal list draws the portal and reloads', (
      tester,
    ) async {
      final repository = _Repository();
      final controller = await _terminalController(repository);
      addTearDown(controller.dispose);
      await _pumpTerminals(tester, controller);
      expect(repository.loads, 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Terminal one')),
      );
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Mid-pull: the kit's drawn disc, never the stock spinner.
      expect(
        find.byKey(const ValueKey('kit-refresh-indicator')),
        findsOneWidget,
      );
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(repository.loads, 2);
      // Done: the disc has left and nothing keeps running.
      expect(find.byKey(const ValueKey('kit-refresh-indicator')), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('a notice that comes and goes', () {
    testWidgets('a failed refresh unfolds, settles, and folds away', (
      tester,
    ) async {
      final repository = _Repository();
      final controller = await _terminalController(repository);
      addTearDown(controller.dispose);
      await _pumpTerminals(tester, controller);
      final list = find.byKey(const ValueKey('refresh-content'));
      final full = _height(tester, list);

      repository.failure = const ProductException('Refresh unavailable');
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final banner = find.byType(MaterialBanner);
      final reveal = find.ancestor(
        of: banner,
        matching: find.byType(KitReveal),
      );
      final mid = _height(tester, reveal);
      await tester.pumpAndSettle();
      final open = _height(tester, reveal);
      // It unfolded over 250 ms instead of arriving at full height…
      expect(mid, inExclusiveRange(0, open));
      // …and the kept list gave way smoothly, then rests.
      expect(_height(tester, list), full - open);
      expect(tester.binding.hasScheduledFrame, isFalse);

      repository.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_height(tester, reveal), inExclusiveRange(0, open));
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      expect(_height(tester, list), full);
    });
  });

  group('rows that arrive after the first load', () {
    testWidgets('the first paint shows the rows at once; a new one unfolds', (
      tester,
    ) async {
      final repository = _Repository()
        ..terminals.add(_terminal('two'))
        ..terminals.add(_terminal('three'));
      final controller = await _terminalController(repository);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TerminalScreen(controller: controller)),
        ),
      );
      // The load completes in a microtask; one frame later the rows are all
      // there, at full height, with nothing animating.
      await tester.pump();
      await tester.pump();
      final one = find.byKey(const ValueKey('terminal-session-one'));
      final rowHeight = _height(tester, one);
      expect(rowHeight, greaterThan(40));
      expect(
        _height(tester, find.byKey(const ValueKey('terminal-session-three'))),
        rowHeight + 1, // its divider above
      );
      expect(tester.binding.hasScheduledFrame, isFalse);

      // A terminal started elsewhere shows up on the next refresh.
      repository.terminals.add(_terminal('four'));
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final four = find.byKey(const ValueKey('terminal-session-four'));
      final motion = find.ancestor(
        of: four,
        matching: find.byType(SizeTransition),
      );
      expect(_height(tester, motion), inExclusiveRange(0, rowHeight + 1));
      await tester.pumpAndSettle();
      expect(_height(tester, motion), rowHeight + 1);

      // One removed folds away where it was.
      repository.terminals.removeWhere((process) => process.id == 'two');
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final two = find.byKey(const ValueKey('terminal-session-two'));
      expect(two, findsOneWidget);
      expect(
        _height(
          tester,
          find.ancestor(of: two, matching: find.byType(SizeTransition)),
        ),
        inExclusiveRange(0, rowHeight + 1),
      );
      await tester.pumpAndSettle();
      expect(two, findsNothing);
    });

    testWidgets('a queued message unfolds under the transcript', (
      tester,
    ) async {
      final controller = await _chatController(_ChatApi());
      addTearDown(controller.dispose);
      await controller.queuePrompt(
        QueuedPrompt(
          id: 'queued-1',
          profileID: 'profile-1',
          sessionID: 'session-1',
          text: 'offline draft',
          createdAt: 1,
        ),
      );
      await _pumpChat(tester, controller);
      // Present when the chat opened: shown at once, not animated.
      final draft = find.byKey(const ValueKey('queued-row-queued-1'));
      expect(draft, findsOneWidget);
      expect(
        find.ancestor(of: draft, matching: find.byType(SizeTransition)),
        findsOneWidget,
      );
      final draftMotion = tester.widget<SizeTransition>(
        find.ancestor(of: draft, matching: find.byType(SizeTransition)),
      );
      expect(draftMotion.sizeFactor.value, 1);

      _enqueue(controller, 'msg_1', 'sent while it works');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final sent = find.byKey(const ValueKey('pending-row-msg_1'));
      final sentMotion = tester.widget<SizeTransition>(
        find.ancestor(of: sent, matching: find.byType(SizeTransition)),
      );
      expect(sentMotion.sizeFactor.value, inExclusiveRange(0, 1));
      await _settle(tester);
      expect(
        tester
            .widget<SizeTransition>(
              find.ancestor(of: sent, matching: find.byType(SizeTransition)),
            )
            .sizeFactor
            .value,
        1,
      );
    });
  });

  group('chat haptics', () {
    testWidgets('send ticks; a finished reply confirms with KitHaptics.done', (
      tester,
    ) async {
      final api = _ChatApi();
      final controller = await _chatController(api);
      addTearDown(controller.dispose);
      final haptics = _haptics(tester);
      await _pumpChat(tester, controller);

      await tester.enterText(
        find.byKey(const Key('chat-composer-field')),
        'hello',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send-button')));
      await _settle(tester);
      expect(api.prompts, ['hello']);
      expect(haptics.map((call) => call.arguments), [
        'HapticFeedbackType.lightImpact',
      ]);

      // The reply runs, then finishes while the person watches.
      controller.busySessions.add('session-1');
      controller.notifyListeners();
      await _settle(tester);
      controller.busySessions.remove('session-1');
      controller.notifyListeners();
      await _settle(tester);
      expect(haptics.map((call) => call.arguments), [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.successNotification',
      ]);
    });

    testWidgets('no finish haptic under reduced motion', (tester) async {
      final controller = await _chatController(_ChatApi());
      addTearDown(controller.dispose);
      final haptics = _haptics(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connProvider.overrideWithValue(controller)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const ChatScreen(sessionID: 'session-1'),
          ),
        ),
      );
      await _settle(tester);
      controller.busySessions.add('session-1');
      controller.notifyListeners();
      await _settle(tester);
      controller.busySessions.remove('session-1');
      controller.notifyListeners();
      await _settle(tester);
      expect(haptics, isEmpty);
    });
  });
}
