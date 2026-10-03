// Before/after captures for the chat's states and banners on the design kit
// (docs/design/design-standard.md §9 step 5): the real ChatScreen at
// 412x915 dp, dark theme, real fonts, with no server or model calls.
//
// This file only drives the public ChatScreen with controller and API
// state, so the same file renders the old code and the new:
//
//   flutter test --concurrency=1 --dart-define=CHAT_STATES_CAPTURE=before \
//     tool/capture/chat_states_test.dart          # on the old commit
//   flutter test --concurrency=1 tool/capture/chat_states_test.dart
//
// Output: docs/qa/design-standard-chat-2026-09-24/<before|after>-<state>.png
//
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/first_run.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

const _prefix = String.fromEnvironment(
  'CHAT_STATES_CAPTURE',
  defaultValue: 'after',
);
const _out = 'docs/qa/design-standard-chat-2026-09-24';
const _size = Size(412, 915);

/// The capture API with a one-page history and a send that can fail.
class _Api extends CaptureApi {
  Object? sendError;

  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async => ServerPage(items: cursor == null ? await messages(id) : const []);

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
    if (sendError case final error?) throw error;
    return super.promptAsync(
      sessionID,
      text: text,
      model: model,
      agent: agent,
      variant: variant,
      attachments: attachments,
      agentMentions: agentMentions,
      delivery: delivery,
    );
  }
}

/// A finished turn: the prompt and a short reply.
List<MessageWithParts> _finishedTurn() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    MessageWithParts(
      info: messageInfo(
        'msg_user',
        'user',
        created: now - 95 * 1000,
        completed: now - 95 * 1000,
      ),
      parts: [
        Part(
          id: 'part_user',
          messageID: 'msg_user',
          type: 'text',
          text: userPrompt,
        ),
      ],
    ),
    MessageWithParts(
      info: messageInfo(
        'msg_assistant',
        'assistant',
        created: now - 80 * 1000,
        completed: now - 4 * 1000,
      ),
      parts: [textPart('part_intro', answerIntro)],
    ),
  ];
}

/// A turn that ended on a model the server does not know.
List<MessageWithParts> _modelErrorTurn() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    _finishedTurn().first,
    MessageWithParts(
      info: MessageInfo(
        id: 'msg_assistant',
        sessionID: checkoutSessionID,
        role: 'assistant',
        providerID: 'openai',
        modelID: 'gpt-5.6',
        time: MsgTime(created: now - 80 * 1000, completed: now - 79 * 1000),
        errorText:
            'ProviderModelNotFoundError: Model not found: openai/gpt-5.6. '
            'Did you mean: gpt-5.6-pro?',
        errorKind: MessageErrorKind.modelNotFound,
      ),
      parts: const [],
    ),
  ];
}

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String state) async {
  expect(tester.takeException(), isNull);
  await writePng(
    '$_out/$_prefix-$state.png',
    await capturePng(tester, key, pixelRatio: 1),
  );
}

/// Pumps the chat for [api] and returns the controller and boundary key.
Future<(CaptureController, GlobalKey)> _chat(
  WidgetTester tester,
  _Api api, {
  Map<String, Object> prefs = const {},
  String sessionID = checkoutSessionID,
  void Function(CaptureController controller)? before,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final controller = await captureController(
    prefs: await SharedPreferences.getInstance(),
    api: api,
  );
  before?.call(controller);
  addTearDown(controller.dispose);
  final key = GlobalKey();
  await tester.pumpWidget(
    captureApp(
      home: ChatScreen(sessionID: sessionID),
      boundaryKey: key,
      controller: controller,
    ),
  );
  await _settle(tester);
  return (controller, key);
}

/// Tells the chat the connection changed, the way the controller does.
void _poke(CaptureController controller) => controller.notifyListeners();

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  testWidgets('1 empty conversation', (tester) async {
    final api = _Api()
      ..busy = {}
      ..messagesHandler = (_) async => [];
    final (_, key) = await _chat(tester, api, sessionID: darkModeSessionID);
    await _settle(tester, 20);
    await _shot(tester, key, '1-empty');
    await _unmount(tester);
  });

  testWidgets('2 loading a conversation', (tester) async {
    final hold = Completer<List<MessageWithParts>>();
    final api = _Api()
      ..busy = {}
      ..messagesHandler = (_) => hold.future;
    final (_, key) = await _chat(tester, api);
    await _shot(tester, key, '2-loading');
    hold.complete(const []);
    await _unmount(tester);
  });

  testWidgets('3 the conversation could not load', (tester) async {
    final api = _Api()
      ..busy = {}
      ..messagesHandler = (_) async => throw ApiException(
        'Cannot reach http://192.168.1.20:4096: Connection refused '
        '(errno = 111)',
      );
    final (_, key) = await _chat(tester, api);
    await _shot(tester, key, '3-load-error');
    await _unmount(tester);
  });

  testWidgets('4 a message was not sent', (tester) async {
    final api = _Api()
      ..busy = {}
      ..sendError = ApiException(
        'Provider is overloaded. Please retry.',
        statusCode: 503,
      )
      ..messagesHandler = (_) async => _finishedTurn();
    final (_, key) = await _chat(tester, api);
    await tester.enterText(
      find.byKey(const Key('chat-composer-field')),
      'Run the full test suite',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await _settle(tester);
    await _shot(tester, key, '4-send-error');
    await _unmount(tester);
  });

  testWidgets('5 the server refused the prompt', (tester) async {
    final api = _Api()
      ..busy = {}
      ..messagesHandler = (_) async => [_finishedTurn().first];
    final (controller, key) = await _chat(tester, api);
    controller.handleEventForTesting(
      captureEvent('session.error', {
        'sessionID': checkoutSessionID,
        'error': {
          'name': 'ProviderModelNotFoundError',
          'data': {
            'message':
                'ProviderModelNotFoundError: Model not found: openai/gpt-5.6. '
                'Did you mean: gpt-5.6-pro?\n'
                '    at <anonymous> (/\$bunfs/root/chunk.js:439:1)',
          },
        },
      }),
    );
    await _settle(tester);
    await _shot(tester, key, '5-prompt-error');
    await _unmount(tester);
  });

  testWidgets('6 a reply ended on a model error', (tester) async {
    final api = _Api()
      ..busy = {}
      ..messagesHandler = (_) async => _modelErrorTurn();
    final (_, key) = await _chat(tester, api);
    await _shot(tester, key, '6-model-error');
    await _unmount(tester);
  });

  testWidgets('7 a permission request, then its sheet', (tester) async {
    final api = _Api()
      ..messagesHandler = (_) async =>
          sampleTranscript(awaitingPermission: true);
    final (_, key) = await _chat(
      tester,
      api,
      before: (controller) =>
          controller.permissions = {samplePermission().id: samplePermission()},
    );
    await _shot(tester, key, '7-permission');
    await tester.tap(find.byKey(const Key('permission-card-review')));
    await _settle(tester);
    await _shot(tester, key, '8-permission-sheet');
    await _unmount(tester);
  });

  testWidgets('9 a question', (tester) async {
    const question = PendingQuestion(
      id: 'q_checkout',
      sessionID: checkoutSessionID,
      prompts: [
        QuestionPrompt(
          title: 'Test scope',
          question: 'Run the whole suite, or only the checkout tests?',
          multiple: false,
          custom: true,
          choices: [
            QuestionChoice(label: 'Whole suite', description: 'About 4 min'),
            QuestionChoice(label: 'Only checkout', description: 'About 20 s'),
          ],
        ),
      ],
    );
    final api = _Api()..messagesHandler = (_) async => _finishedTurn();
    final (_, key) = await _chat(
      tester,
      api,
      before: (controller) => controller.questions = {question.id: question},
    );
    await _shot(tester, key, '9-question');
    await _unmount(tester);
  });

  testWidgets('10-12 disconnected inside a chat', (tester) async {
    final api = _Api()
      ..busy = {}
      ..messagesHandler = (_) async => _finishedTurn();
    final (controller, key) = await _chat(tester, api);
    controller.status = StreamStatus.reconnecting;
    _poke(controller);
    await _settle(tester, 4);
    await _shot(tester, key, '10-reconnecting');
    await tester.pump(const Duration(seconds: 9));
    await _settle(tester, 2);
    await _shot(tester, key, '11-not-answering');
    controller
      ..status = StreamStatus.disconnected
      ..lastError = 'Cannot reach http://192.168.1.20:4096: Connection refused';
    _poke(controller);
    await _settle(tester, 4);
    await _shot(tester, key, '12-lost');
    await _unmount(tester);
  });

  testWidgets('13 notify me when a reply is ready', (tester) async {
    final api = _Api()
      ..busy = {}
      ..messagesHandler = (_) async => _finishedTurn();
    final (_, key) = await _chat(
      tester,
      api,
      prefs: {FirstRun.stateKey: 'done', FirstRun.notifyAskKey: 'pending'},
    );
    await _shot(tester, key, '13-notify');
    await _unmount(tester);
  });
}
