import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/background/live_background.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/first_run.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/widgets/first_reply_notify_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/complete_message_history.dart';

/// "Get told when it's done?" is asked once, after the first reply of a new
/// person's first conversation (UX plan 5.6 step 6).

const _card = ValueKey('first-reply-notify-card');
const _accept = ValueKey('first-reply-notify-accept');
const _decline = ValueKey('first-reply-notify-decline');

/// The native side of "Stay connected in the background": the one place the
/// app raises Android's notification permission.
class _Native {
  final calls = <String>[];
  bool deny = false;

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    calls.add(method);
    if (method == 'enable' && deny) {
      throw PlatformException(
        code: 'notification_denied',
        message: 'Notification access is required.',
      );
    }
    return {
      'enabled': method == 'enable',
      'active': method == 'enable',
      'notificationGranted': method == 'enable',
    };
  }
}

Future<(ConnectionController, _Native)> _controller(
  Map<String, Object> prefs, {
  OpenCodeApi? api,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final native = _Native();
  final controller =
      ConnectionController(
          ProfileStore(prefs: preferences),
          backgroundLive: BackgroundLiveController(
            preferences: preferences,
            invoke: native.call,
          ),
        )
        ..api = api ?? OpenCodeApi(baseUrl: 'http://localhost')
        ..status = StreamStatus.connected;
  return (controller, native);
}

const _pending = <String, Object>{
  FirstRun.stateKey: 'done',
  FirstRun.notifyAskKey: 'pending',
};

Widget _host(
  ConnectionController controller, {
  required bool replyCompleted,
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool compact = false,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: Column(
      children: [
        const Expanded(child: Placeholder()),
        FirstReplyNotifyCard(
          controller: controller,
          replyCompleted: replyCompleted,
          compact: compact,
        ),
        const SizedBox(height: 56, child: Text('composer')),
      ],
    ),
  ),
);

class _TranscriptApi extends OpenCodeApi with CompleteMessageHistory {
  _TranscriptApi(this.transcript) : super(baseUrl: 'http://localhost');

  List<MessageWithParts> transcript;

  @override
  Future<List<MessageWithParts>> messages(String id) async => transcript;

  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}

MessageWithParts _message(String id, String role, String text, int created) =>
    MessageWithParts(
      info: MessageInfo(
        id: id,
        sessionID: 'session-1',
        role: role,
        providerID: 'anthropic',
        modelID: 'claude',
        time: MsgTime(created: created, completed: created + 1),
      ),
      parts: [Part(id: '$id-t', type: 'text', text: text)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugPlatformCapabilities = const PlatformCapabilities.android());
  tearDown(() => debugPlatformCapabilities = null);

  testWidgets('absent before the first reply completes, present after', (
    tester,
  ) async {
    final (controller, native) = await _controller(_pending);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, replyCompleted: false));
    expect(find.byKey(_card), findsNothing);

    await tester.pumpWidget(_host(controller, replyCompleted: true));
    expect(find.byKey(_card), findsOneWidget);
    expect(find.text("Get told when it's done?"), findsOneWidget);
    expect(find.text('Notify me'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    // Showing the question asks Android for nothing.
    expect(native.calls, isEmpty);
    // Above the composer.
    expect(
      tester.getRect(find.byKey(_card)).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('composer')).top),
    );
  });

  testWidgets('"Not now" is permanent', (tester) async {
    final (controller, native) = await _controller(_pending);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, replyCompleted: true));
    await tester.tap(find.byKey(_decline));
    await tester.pump();

    expect(find.byKey(_card), findsNothing);
    expect(native.calls, isEmpty);
    expect(controller.keepLiveInBackground, isFalse);
    expect(FirstRun(controller.store.prefs).notifyAskPending, isFalse);

    // Another conversation, another day: the same preferences, a new card.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(controller, replyCompleted: true));
    await tester.pump();
    expect(find.byKey(_card), findsNothing);
  });

  testWidgets('accepting goes through the existing background request', (
    tester,
  ) async {
    final (controller, native) = await _controller(_pending);
    addTearDown(controller.dispose);
    await controller.setNotifyFinishedRuns(false);
    await tester.pumpWidget(_host(controller, replyCompleted: true));
    await tester.tap(find.byKey(_accept));
    await tester.pumpAndSettle();

    // `enable` is the native call that raises POST_NOTIFICATIONS and starts
    // the service: the same one Settings → Notifications makes.
    expect(native.calls.first, 'enable');
    expect(native.calls.where((call) => call == 'enable'), hasLength(1));
    expect(controller.keepLiveInBackground, isTrue);
    expect(
      controller.store.prefs.getBool(BackgroundLiveController.preferenceKey),
      isTrue,
    );
    expect(controller.notificationPreferences.finishedRuns, isTrue);
    expect(controller.notificationPreferences.requests, isTrue);
    expect(find.byKey(_card), findsNothing);
    expect(FirstRun(controller.store.prefs).notifyAskPending, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(controller, replyCompleted: true));
    await tester.pump();
    expect(find.byKey(_card), findsNothing);
  });

  testWidgets('a refusal at Android\'s prompt is an answer too', (
    tester,
  ) async {
    final (controller, native) = await _controller(_pending);
    addTearDown(controller.dispose);
    native.deny = true;
    await tester.pumpWidget(_host(controller, replyCompleted: true));
    await tester.tap(find.byKey(_accept));
    await tester.pump();
    await tester.pump();

    expect(native.calls, ['enable']);
    expect(controller.keepLiveInBackground, isFalse);
    expect(find.text('Notification access is required.'), findsOneWidget);
    expect(find.byKey(_card), findsNothing);
    expect(FirstRun(controller.store.prefs).notifyAskPending, isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  for (final MapEntry(key: name, value: prefs) in <String, Map<String, Object>>{
    'never came through first run': {},
    'returning, never asked': {FirstRun.stateKey: 'done'},
    'already answered': {
      FirstRun.stateKey: 'done',
      FirstRun.notifyAskKey: 'answered',
    },
    'first run not finished': {FirstRun.stateKey: 'armed'},
  }.entries) {
    testWidgets('absent for a person who is $name', (tester) async {
      final (controller, native) = await _controller(prefs);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, replyCompleted: true));
      await tester.pump();
      expect(find.byKey(_card), findsNothing);
      expect(native.calls, isEmpty);
    });
  }

  testWidgets('not asked when the background connection is already on', (
    tester,
  ) async {
    final (controller, native) = await _controller({
      ..._pending,
      BackgroundLiveController.preferenceKey: true,
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, replyCompleted: true));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(_card), findsNothing);
    expect(native.calls, isEmpty);
    // Turning it on in Settings answered the question.
    expect(FirstRun(controller.store.prefs).notifyAskPending, isFalse);
  });

  testWidgets('absent where the device cannot notify', (tester) async {
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    final (controller, _) = await _controller(_pending);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, replyCompleted: true));
    expect(find.byKey(_card), findsNothing);
    // Still pending: the same person on a phone is asked there.
    expect(FirstRun(controller.store.prefs).notifyAskPending, isTrue);
  });

  testWidgets('waits while the conversation is short on height', (
    tester,
  ) async {
    final (controller, _) = await _controller(_pending);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(controller, replyCompleted: true, compact: true),
    );
    expect(find.byKey(_card), findsNothing);
    await tester.pumpWidget(_host(controller, replyCompleted: true));
    expect(find.byKey(_card), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('fits 320dp at 2.5x text (${locale.languageCode})', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (controller, _) = await _controller(_pending);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(controller, replyCompleted: true, locale: locale, textScale: 2.5),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(_card));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(320));
      // The question never takes the screen from the conversation.
      expect(card.height, lessThanOrEqualTo(640 * .42));
      for (final key in [_accept, _decline]) {
        final button = tester.getRect(find.byKey(key));
        expect(button.height, greaterThanOrEqualTo(48));
        expect(button.left, greaterThanOrEqualTo(card.left));
        expect(button.right, lessThanOrEqualTo(card.right));
        expect(button.bottom, lessThanOrEqualTo(card.bottom));
      }
      expect(find.byKey(_accept).hitTestable(), findsOneWidget);
      expect(find.byKey(_decline).hitTestable(), findsOneWidget);
    });
  }

  group('in the conversation', () {
    Future<(ConnectionController, _TranscriptApi)> open(
      WidgetTester tester,
      Map<String, Object> prefs,
      List<MessageWithParts> transcript, {
      bool busy = false,
    }) async {
      final api = _TranscriptApi(transcript);
      final (controller, _) = await _controller(prefs, api: api);
      addTearDown(controller.dispose);
      if (busy) controller.busySessions.add('session-1');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [connProvider.overrideWithValue(controller)],
          child: const MaterialApp(home: ChatScreen(sessionID: 'session-1')),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return (controller, api);
    }

    final question = _message('u1', 'user', 'Explain this repo', 1);
    final answer = _message('a1', 'assistant', 'It is a phone client.', 2);

    testWidgets('an empty first conversation does not ask', (tester) async {
      await open(tester, _pending, []);
      expect(find.byKey(_card), findsNothing);
    });

    testWidgets('a reply still streaming does not ask; a finished one does', (
      tester,
    ) async {
      final (controller, _) = await open(tester, _pending, [
        question,
        answer,
      ], busy: true);
      expect(find.byKey(_card), findsNothing);

      controller.busySessions.remove('session-1');
      controller.notifyListeners();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final card = find.byKey(_card);
      expect(card, findsOneWidget);
      // Above the composer, below the transcript.
      expect(
        tester.getRect(card).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(TextField).last).top),
      );
    });

    testWidgets('a returning person sees no card after a reply', (
      tester,
    ) async {
      await open(tester, {FirstRun.stateKey: 'done'}, [question, answer]);
      expect(find.byKey(_card), findsNothing);
    });
  });
}
