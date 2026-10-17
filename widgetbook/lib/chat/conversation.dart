// The conversation screen (ChatScreen) in its main states, rendered from the
// real code over a fake server (fakes/fake_gateway.dart).
//
// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart'
    show PendingQuestion, QuestionChoice, QuestionPrompt, StreamStatus;
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/fake_app.dart';
import '../fakes/fake_gateway.dart';
import 'fake_transcripts.dart';

/// The real chat over [server]. [tweak] changes the connection after it is
/// up (a dropped link, for instance).
Widget _chat(
  FakeServer Function() server, {
  void Function(ConnectionController connection)? tweak,
  String sessionID = chatSessionID,
}) => FakeAppScene<FakeApp>(
  platform: FakePlatform.android,
  create: () async {
    final app = await server().connect();
    tweak?.call(app.connection);
    return app;
  },
  builder: (context, app) => ProviderScope(
    overrides: [
      bootstrapProvider.overrideWithValue(AppBootstrap(app.store)),
      connProvider.overrideWithValue(app.connection),
    ],
    child: ChatScreen(sessionID: sessionID),
  ),
);

const _ask = 'Fix the flaky checkout test';

List<MessageWithParts> _finished() => [
  userTurn('msg_u1', _ask),
  agentTurn(
    'msg_a1',
    (id) => [
      textPart(
        id,
        '${id}_t',
        'The test waited one second and hoped the total had changed. I made '
            'it wait for the new state instead, and the whole file passes now.',
      ),
    ],
    parentID: 'msg_u1',
  ),
];

List<MessageWithParts> _longTurn() => [
  userTurn('msg_u1', _ask, ago: const Duration(minutes: 6)),
  agentTurn(
    'msg_a1',
    (id) => [
      reasoningPart(
        id,
        'The test sleeps for a second. That is a race with the bloc.',
      ),
      textPart(id, '${id}_t0', 'I will look at the test and the bloc first.'),
      readPart(id, 1, 'test/checkout_test.dart'),
      readPart(id, 2, 'lib/checkout/checkout_bloc.dart'),
      readPart(id, 3, 'lib/cart/cart_repository.dart'),
      editPart(id),
      shellPart(id),
      textPart(
        id,
        '${id}_t1',
        'Fixed. The test now waits for the bloc to emit the new total, so it '
            'no longer depends on timing. All 12 tests pass.',
      ),
    ],
    ago: const Duration(minutes: 5),
    took: const Duration(minutes: 1, seconds: 20),
    parentID: 'msg_u1',
  ),
];

PermissionRequest _permission() => PermissionRequest(
  id: 'perm_checkout',
  sessionID: chatSessionID,
  permission: 'bash',
  patterns: const [checkoutCommand],
  metadata: const {'command': checkoutCommand},
  always: const ['flutter test *'],
);

const _question = PendingQuestion(
  id: 'q_checkout',
  sessionID: chatSessionID,
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

CatalogComponent conversationScreen() => catalogComponent(
  area: 'Chats',
  screen: 'ChatScreen',
  name: 'Conversation',
  useCases: [
    WidgetbookUseCase(
      name: 'New chat',
      builder: (_) => _chat(() => serverWith(const [])),
    ),
    WidgetbookUseCase(
      name: 'Loading',
      builder: (_) => _chat(
        () => serverWith(_finished())..holdMessages = Completer<void>(),
      ),
    ),
    WidgetbookUseCase(
      name: 'Short answer',
      builder: (_) => _chat(
        () => serverWith([
          userTurn('msg_u1', 'What is a bloc?'),
          agentTurn(
            'msg_a1',
            (id) => [textPart(id, '${id}_t', shortAnswer)],
            parentID: 'msg_u1',
          ),
        ], title: 'What is a bloc?'),
      ),
    ),
    WidgetbookUseCase(
      name: 'Long turn, tool calls folded',
      builder: (_) => _chat(() => serverWith(_longTurn())),
    ),
    WidgetbookUseCase(
      name: 'Working',
      builder: (_) => _chat(
        () => serverWith([
          userTurn('msg_u1', _ask, ago: const Duration(seconds: 50)),
          agentTurn(
            'msg_a1',
            (id) => [
              textPart(id, '${id}_t0', 'Looking at the test first.'),
              readPart(id, 1, 'test/checkout_test.dart'),
              readPart(id, 2, 'lib/checkout/checkout_bloc.dart'),
              editPart(id),
              shellPart(id, status: 'running'),
            ],
            ago: const Duration(seconds: 40),
            took: null,
            parentID: 'msg_u1',
          ),
        ], busy: true),
      ),
    ),
    WidgetbookUseCase(
      name: 'Task list: chip beside the model',
      builder: (_) => _chat(
        () => serverWith([
          userTurn('msg_u1', _ask, ago: const Duration(minutes: 3)),
          agentTurn(
            'msg_a1',
            (id) => [
              todoPart(id),
              editPart(id),
              textPart(
                id,
                '${id}_t',
                'I removed the legacy cap from the design test. Now running '
                    'the tests.',
              ),
            ],
            parentID: 'msg_u1',
          ),
        ], busy: true),
      ),
    ),
    WidgetbookUseCase(
      name: 'Needs you: permission request',
      builder: (_) => _chat(
        () => serverWith(
          [
            userTurn('msg_u1', _ask, ago: const Duration(seconds: 50)),
            agentTurn(
              'msg_a1',
              (id) => [
                textPart(id, '${id}_t0', 'I will run the test to see it fail.'),
                shellPart(id, status: 'running'),
              ],
              ago: const Duration(seconds: 40),
              took: null,
              parentID: 'msg_u1',
            ),
          ],
          busy: true,
          permissions: [_permission()],
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Needs you: question',
      builder: (_) =>
          _chat(() => serverWith(_finished(), questions: const [_question])),
    ),
    WidgetbookUseCase(
      name: 'Error turn',
      builder: (_) => _chat(
        () => serverWith([
          userTurn('msg_u1', _ask),
          agentTurn(
            'msg_a1',
            (id) => const [],
            took: const Duration(seconds: 1),
            parentID: 'msg_u1',
            errorText:
                'ProviderModelNotFoundError: Model not found: openai/gpt-5.6. '
                'Did you mean: gpt-5.6-pro?',
            errorKind: MessageErrorKind.modelNotFound,
          ),
        ]),
      ),
    ),
    WidgetbookUseCase(
      name: 'Picture attached',
      builder: (_) => _chat(
        () => serverWith([
          userTurn(
            'msg_u1',
            'The total shows 100 here even with the coupon. Why?',
            extra: [picturePart('msg_u1')],
          ),
          agentTurn(
            'msg_a1',
            (id) => [
              textPart(
                id,
                '${id}_t',
                'The screen reads the total before the coupon event is '
                    'handled. I will make it listen to the bloc state.',
              ),
            ],
            parentID: 'msg_u1',
          ),
        ], title: 'Coupon total looks wrong'),
      ),
    ),
    WidgetbookUseCase(
      name: 'Long code block',
      builder: (_) => _chat(
        () => serverWith([
          userTurn('msg_u1', 'Show me the finished test file.'),
          agentTurn(
            'msg_a1',
            (id) => [textPart(id, '${id}_t', longCodeAnswer)],
            parentID: 'msg_u1',
          ),
        ]),
      ),
    ),
    WidgetbookUseCase(
      name: 'Reconnecting',
      builder: (_) => _chat(
        () => serverWith(_finished()),
        tweak: (connection) {
          connection.status = StreamStatus.reconnecting;
          connection.notifyListeners();
        },
      ),
    ),
    WidgetbookUseCase(
      name: 'Offline',
      builder: (_) => _chat(
        () => serverWith(_finished()),
        tweak: (connection) {
          connection
            ..status = StreamStatus.disconnected
            ..lastError =
                'Cannot reach http://192.168.1.20:4096: Connection refused';
          connection.notifyListeners();
        },
      ),
    ),
  ],
);
