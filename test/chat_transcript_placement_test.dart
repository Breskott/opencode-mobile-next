import 'support/complete_message_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TranscriptApi extends OpenCodeApi with CompleteMessageHistory {
  _TranscriptApi(this.transcript) : super(baseUrl: 'http://localhost');

  final List<MessageWithParts> transcript;

  @override
  Future<List<MessageWithParts>> messages(String id) async => transcript;

  @override
  Future<List<PermissionRequest>> pendingPermissions() async => const [];

  @override
  Future<List<PermissionRequest>> pendingPermissionsV2() =>
      Future.error(ApiException('V2 unavailable', statusCode: 404));
}

MessageWithParts _message(
  String id,
  String role,
  List<Part> parts, {
  required int created,
  Tokens? tokens,
}) => MessageWithParts(
  info: MessageInfo(
    id: id,
    sessionID: 'session-1',
    role: role,
    providerID: 'anthropic',
    modelID: 'claude',
    tokens: tokens,
    time: MsgTime(created: created, completed: created + 1),
  ),
  parts: parts,
);

Part _text(String id, String text) => Part(id: id, type: 'text', text: text);

Future<ConnectionController> _pump(
  WidgetTester tester,
  List<MessageWithParts> transcript, {
  bool busy = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = ConnectionController(ProfileStore(prefs: prefs))
    ..api = _TranscriptApi(transcript)
    ..status = StreamStatus.connected;
  if (busy) controller.busySessions.add('session-1');
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connProvider.overrideWithValue(controller)],
      child: const MaterialApp(home: ChatScreen(sessionID: 'session-1')),
    ),
  );
  // The composer's activity ring animates forever, so a busy chat never
  // settles.
  if (busy) {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  } else {
    await tester.pumpAndSettle();
  }
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a busy session shows working on the composer, not as a '
      'transcript row', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [
      _message('u1', 'user', [_text('u1-t', 'First question')], created: 1),
      _message('a1', 'assistant', [_text('a1-t', 'First answer')], created: 2),
      _message('u2', 'user', [_text('u2-t', 'Second question')], created: 3),
      _message('a2', 'assistant', [_text('a2-t', 'Second answer')], created: 4),
    ], busy: true);

    // The transcript is only the messages: the newest turn is the last row
    // and nothing sits under it.
    expect(find.byKey(const ValueKey('typing-indicator')), findsNothing);
    expect(find.byKey(const ValueKey('message-a2')), findsOneWidget);
    final activity = find.byKey(const ValueKey('composer-activity'));
    expect(activity, findsOneWidget);
    final lastBubbleBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('message-a2')))
        .dy;
    expect(
      tester.getTopLeft(activity).dy,
      greaterThanOrEqualTo(lastBubbleBottom),
    );
    expect(find.bySemanticsLabel('Assistant is working'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an idle session shows no working indicator', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [
      _message('u1', 'user', [_text('u1-t', 'Question')], created: 1),
      _message('a1', 'assistant', [_text('a1-t', 'Answer')], created: 2),
    ]);
    expect(find.byKey(const ValueKey('typing-indicator')), findsNothing);
    expect(find.byKey(const ValueKey('composer-activity')), findsNothing);
    expect(find.bySemanticsLabel('Assistant is working'), findsNothing);
    semantics.dispose();
  });

  testWidgets('step-finish, patch and snapshot parts leave no stray row', (
    tester,
  ) async {
    await _pump(tester, [
      _message('u1', 'user', [_text('u1-t', 'Rename the file')], created: 1),
      _message('a1', 'assistant', [
        Part(id: 'a1-step', type: 'step-start'),
        Part(
          id: 'a1-edit',
          type: 'tool',
          callID: 'call-1',
          toolName: 'edit',
          toolState: ToolState.fromJson(const {
            'status': 'completed',
            'input': {'filePath': '/work/lib/main.dart'},
            'output': 'ok',
            'metadata': {'diff': ''},
          }, toolName: 'edit'),
        ),
      ], created: 2),
      // The bookkeeping tail of the turn: nothing a reader can act on.
      _message(
        'a2',
        'assistant',
        [
          Part(id: 'a2-patch', type: 'patch'),
          Part(id: 'a2-snapshot', type: 'snapshot'),
          Part(id: 'a2-finish', type: 'step-finish'),
        ],
        created: 3,
        tokens: Tokens(input: 10, output: 5),
      ),
    ]);

    expect(find.text('Edit'), findsOneWidget);
    // No "…" placeholder and no orphan actions row for the empty message.
    expect(find.text('…'), findsNothing);
    // The turn keeps exactly one actions affordance, in its footer: the
    // bookkeeping tail adds no second one and takes none away.
    expect(
      find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('message-actions-') &&
            !key.value.startsWith('message-actions-disc-');
      }),
      findsOneWidget,
    );
  });

  Part tool(String id, String name) => Part(
    id: id,
    type: 'tool',
    callID: id,
    toolName: name,
    toolState: ToolState.fromJson(const {
      'status': 'completed',
      'input': {'filePath': '/work/lib/main.dart'},
      'output': 'ok',
    }, toolName: name),
  );

  testWidgets('a turn has one control, and a notice does not end the turn', (
    tester,
  ) async {
    await _pump(tester, [
      _message('u1', 'user', [
        _text('u1-t', 'Tidy the home screen'),
      ], created: 1),
      _message('a1', 'assistant', [
        _text('a1-t', 'Looking first.'),
      ], created: 2),
      // Filed under the user role by the server, but nobody typed it.
      _message('n1', 'user', [
        Part(id: 'v2-0', type: 'v2:notice', toolName: 'synthetic', text: 'x'),
      ], created: 3),
      _message('a2', 'assistant', [_text('a2-t', 'Done.')], created: 4),
      _message('u2', 'user', [_text('u2-t', 'Thanks')], created: 5),
      _message('a3', 'assistant', [_text('a3-t', 'Welcome.')], created: 6),
    ]);

    // No control under a step, under the prompt, or before the notice.
    expect(find.byKey(const ValueKey('message-actions-u1')), findsNothing);
    expect(find.byKey(const ValueKey('message-actions-a1')), findsNothing);
    // One per turn, under the step that ends it.
    expect(find.byKey(const ValueKey('message-actions-a2')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-actions-a3')), findsOneWidget);
  });

  testWidgets('a one-line thought titles the tool run that follows it', (
    tester,
  ) async {
    await _pump(tester, [
      _message('u1', 'user', [_text('u1-t', 'Patch it')], created: 1),
      _message('a1', 'assistant', [
        Part(id: 'a1-r', type: 'reasoning', text: '**Patching home shell**'),
        tool('a1-t1', 'read'),
        tool('a1-t2', 'edit'),
      ], created: 2),
    ]);

    // One line for the step: the agent's own name for it, then what it did.
    expect(find.text('Patching home shell'), findsOneWidget);
    expect(find.byKey(const Key('assistant-reasoning-block')), findsNothing);
    expect(find.byKey(const Key('tool-call-group')), findsOneWidget);
    expect(find.text('Tools'), findsNothing);
  });

  testWidgets('a prompt is a ruled line, not a bubble', (tester) async {
    await _pump(tester, [
      _message('u1', 'user', [_text('u1-t', 'Hello there')], created: 1),
      _message('a1', 'assistant', [_text('a1-t', 'Hi.')], created: 2),
    ]);
    final prompt = tester.widget<Container>(
      find.byKey(const ValueKey('user-prompt-u1')),
    );
    final decoration = prompt.decoration! as BoxDecoration;
    expect(decoration.color, isNull);
    expect(decoration.borderRadius, isNull);
    expect((decoration.border! as BorderDirectional).start.width, 3);
    // Prompt and reply share a left edge.
    expect(
      tester.getTopLeft(find.text('Hello there')).dx,
      lessThan(tester.getTopLeft(find.text('Hi.')).dx + 16),
    );
  });

  testWidgets('what the agent did between two replies folds under one line', (
    tester,
  ) async {
    await _pump(tester, [
      _message('u1', 'user', [_text('u1-t', 'Fix the balance')], created: 1),
      _message('a1', 'assistant', [
        _text('a1-t', 'Looking into it.'),
        tool('t1', 'bash'),
      ], created: 2),
      // Later steps of the same stretch of work, stored as separate messages.
      _message('a2', 'assistant', [
        Part(id: 'r2', type: 'reasoning', text: '**Checking persistence**'),
        tool('t2', 'bash'),
      ], created: 3),
      _message('a3', 'assistant', [
        Part(id: 'r3', type: 'reasoning', text: '**Preparing the patch**'),
        tool('t3', 'read'),
        tool('t4', 'read'),
      ], created: 4),
      _message('a4', 'assistant', [_text('a4-t', 'Fixed.')], created: 5),
    ]);

    // Said: visible. Done: one line, however many steps it took.
    expect(find.text('Looking into it.'), findsOneWidget);
    expect(find.text('Fixed.'), findsOneWidget);
    expect(find.byKey(const Key('work-group')), findsOneWidget);
    expect(find.text('3 steps'), findsOneWidget);
    expect(find.text('Checking persistence'), findsNothing);

    // Discoverable: one tap shows every step, in order, by the agent's name.
    await tester.tap(find.byKey(const Key('work-group-header')));
    await tester.pumpAndSettle();
    expect(find.text('Checking persistence'), findsOneWidget);
    expect(find.text('Preparing the patch'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Checking persistence')).dy,
      lessThan(tester.getTopLeft(find.text('Preparing the patch')).dy),
    );
  });

  testWidgets('a thought titles its step and explains itself inside it', (
    tester,
  ) async {
    await _pump(tester, [
      _message('u1', 'user', [_text('u1-t', 'Go')], created: 1),
      _message('a1', 'assistant', [
        Part(
          id: 'r1',
          type: 'reasoning',
          text:
              '**Rebuilding latest source**\n\nThe bundle is stale, so the '
              'web build has to run before the routes can be checked.',
        ),
        tool('t1', 'bash'),
      ], created: 2),
    ]);

    // No "Reasoning (tap to expand)" row of its own.
    expect(find.byKey(const Key('reasoning-toggle')), findsNothing);
    expect(find.text('Rebuilding latest source'), findsOneWidget);
    expect(find.byKey(const Key('step-note')), findsNothing);

    // Why, then what, once the step is opened.
    await tester.tap(find.text('Rebuilding latest source'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('step-note')), findsOneWidget);
    expect(find.textContaining('The bundle is stale'), findsOneWidget);
  });

  testWidgets('a failure the agent got past does not open or redden the work', (
    tester,
  ) async {
    Part failed(String id) => Part(
      id: id,
      type: 'tool',
      callID: id,
      toolName: 'edit',
      toolState: ToolState.fromJson(const {
        'status': 'error',
        'input': {'filePath': '/work/lib/main.dart'},
        'error': 'patch verification failed',
      }, toolName: 'edit'),
    );
    await _pump(tester, [
      _message('u1', 'user', [_text('u1-t', 'Go')], created: 1),
      _message('a1', 'assistant', [
        failed('t1'),
        Part(id: 'r1', type: 'reasoning', text: '**Retrying the patch**'),
        tool('t2', 'edit'),
        _text('a1-t', 'Patched.'),
      ], created: 2),
    ]);
    expect(find.byKey(const Key('work-group')), findsOneWidget);
    expect(find.byKey(const Key('work-group-steps')), findsNothing);
    expect(find.text('patch verification failed'), findsNothing);
  });

  testWidgets('work that ends on a failure opens itself', (tester) async {
    await _pump(tester, [
      _message('u1', 'user', [_text('u1-t', 'Go')], created: 1),
      _message('a1', 'assistant', [
        tool('t1', 'read'),
        Part(id: 'r1', type: 'reasoning', text: '**Applying the patch**'),
        Part(
          id: 't2',
          type: 'tool',
          callID: 't2',
          toolName: 'edit',
          toolState: ToolState.fromJson(const {
            'status': 'error',
            'input': {'filePath': '/work/lib/main.dart'},
            'error': 'patch verification failed',
          }, toolName: 'edit'),
        ),
      ], created: 2),
    ]);
    expect(find.byKey(const Key('work-group-steps')), findsOneWidget);
  });
}
