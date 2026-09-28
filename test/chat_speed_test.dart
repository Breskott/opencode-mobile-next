// The chat feels instant (slice-chat-speed-fixes; speed contract items 2
// and 3 in docs/qa/codex-speed-2026-09-28/README.md).
//
// Opening: while the first history read is on its way, the end of the
// conversation as it read last time stands in for placeholder turns,
// read-only. The live history then replaces it without a duplicate turn,
// and a prefetch fired on the tap that opened the chat shares its one
// history read.
//
// Sending: the person's prompt is on screen on the first frame after Send,
// while the session selection and the prompt request are still pending.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/session_inventory_cache.dart';
import 'package:opencode_mobile/state/session_tail_cache.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart';

const _reply = 'The checkout test is fixed.';

/// History held until the test answers it, counting every read.
class _Api extends CaptureApi {
  _Api() {
    busy = {};
  }

  int reads = 0;
  Completer<List<MessageWithParts>> hold = Completer();
  final sendHold = Completer<void>();

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
    await sendHold.future;
  }

  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async {
    reads += 1;
    return ServerPage(items: cursor == null ? await hold.future : const []);
  }
}

List<MessageWithParts> _turn() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    MessageWithParts(
      info: messageInfo('msg_user', 'user', created: now - 9000),
      parts: [textPart('part_user', userPrompt)],
    ),
    MessageWithParts(
      info: messageInfo(
        'msg_assistant',
        'assistant',
        created: now - 8000,
        completed: now - 1000,
      ),
      parts: [textPart('part_reply', _reply)],
    ),
  ];
}

/// Saves the excerpt the last successful open of [session] left behind.
Future<void> _saveExcerpt(
  SharedPreferences prefs, {
  String session = checkoutSessionID,
}) => SessionTailCache(prefs).save(
  'laptop',
  SessionInventoryCache.scopeFor(
    ServerProfile(
      id: 'laptop',
      name: 'Laptop',
      baseUrl: 'http://192.168.1.20:4096',
    ),
    projectDirectory,
    null,
  ),
  session,
  [
    for (final message in _turn())
      MessageWithParts(
        info: MessageInfo(
          id: message.info.id,
          sessionID: session,
          role: message.info.role,
        ),
        parts: message.parts,
      ),
  ],
  isCurrent: () => true,
);

Future<CaptureController> _open(
  WidgetTester tester,
  _Api api, {
  bool saved = true,
  bool prefetch = false,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (saved) await _saveExcerpt(prefs);
  final controller = await captureController(prefs: prefs, api: api);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    controller.dispose();
  });
  // The tap that opens a chat warms its history (Work, Inbox, Sessions).
  if (prefetch) unawaited(controller.prefetchSessionTail(checkoutSessionID));
  await tester.pumpWidget(
    captureApp(
      home: const ChatScreen(sessionID: checkoutSessionID),
      boundaryKey: GlobalKey(),
      controller: controller,
    ),
  );
  return controller;
}

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

final _excerpt = find.byKey(const ValueKey('chat-opening-excerpt'));
final _skeleton = find.byKey(const ValueKey('chat-loading'));
final _bar = find.byKey(const ValueKey('kit-loading-bar'));

void main() {
  testWidgets('the first frame shows the words saved last time, before any '
      'history has arrived', (tester) async {
    final api = _Api();
    await _open(tester, api);

    // First frame: one read in flight, none answered.
    expect(api.reads, 1);
    expect(api.hold.isCompleted, isFalse);
    expect(_excerpt, findsOneWidget);
    expect(_skeleton, findsNothing);
    expect(find.text(_reply), findsOneWidget);
    expect(find.text(userPrompt), findsOneWidget);
    // Honest: the screen still says the conversation is loading, and the
    // excerpt says how old it is.
    expect(_bar, findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-opening-excerpt-updated')),
      findsOneWidget,
    );
    // The composer is there at once: typing does not wait for history.
    expect(find.byKey(const Key('chat-composer-field')), findsOneWidget);
  });

  testWidgets('the live history replaces the excerpt with no duplicate turn', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api);
    expect(_excerpt, findsOneWidget);

    api.hold.complete(_turn());
    await _frames(tester);

    expect(_excerpt, findsNothing);
    expect(_bar, findsNothing);
    expect(find.text(_reply), findsOneWidget);
    expect(find.text(userPrompt), findsOneWidget);
    expect(find.byType(KitTurn), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a prefetch on the opening tap and the chat share one read', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api, prefetch: true);
    await tester.pump();
    expect(api.reads, 1);

    api.hold.complete(_turn());
    await _frames(tester);
    expect(api.reads, 1);
    expect(find.text(_reply), findsOneWidget);
  });

  testWidgets('without a saved excerpt the chat opens on placeholder turns', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api, saved: false);
    expect(_excerpt, findsNothing);
    expect(_skeleton, findsOneWidget);
    api.hold.complete(_turn());
    await _frames(tester);
    expect(find.text(_reply), findsOneWidget);
  });

  testWidgets('another conversation\'s excerpt never shows here', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = _Api();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await _saveExcerpt(prefs, session: 'ses_other');
    final controller = await captureController(prefs: prefs, api: api);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      controller.dispose();
    });
    await tester.pumpWidget(
      captureApp(
        home: const ChatScreen(sessionID: checkoutSessionID),
        boundaryKey: GlobalKey(),
        controller: controller,
      ),
    );
    expect(_excerpt, findsNothing);
    expect(_skeleton, findsOneWidget);
    api.hold.complete(const []);
    await _frames(tester);
  });

  testWidgets('a failed read replaces the excerpt with the plain load error', (
    tester,
  ) async {
    final api = _Api();
    await _open(tester, api);
    expect(_excerpt, findsOneWidget);

    api.hold.completeError(
      ApiException('Cannot reach http://192.168.1.20:4096: refused'),
    );
    await _frames(tester);
    expect(_excerpt, findsNothing);
    expect(find.text("Couldn't open this conversation"), findsOneWidget);
    expect(find.textContaining('192.168.1.20'), findsNothing);
  });

  testWidgets('a sent prompt shows on the first frame after Send, while the '
      'session selection and the request are still pending', (tester) async {
    final api = _Api();
    api.hold.complete(_turn());
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller =
        _HeldSelection(
            SeededProfileStore(
              prefs: prefs,
              seeded: [
                ServerProfile(
                  id: 'laptop',
                  name: 'Laptop',
                  baseUrl: 'http://192.168.1.20:4096',
                ),
              ],
            ),
          )
          ..api = api
          ..repository = CaptureRepository()
          ..status = StreamStatus.connected
          ..directory = projectDirectory
          ..sessionsById = Map.of(api.sessionsById)
          ..busySessions = <String>{};
    addTearDown(() async {
      if (!controller.selection.isCompleted) controller.selection.complete();
      if (!api.sendHold.isCompleted) api.sendHold.complete();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      controller.dispose();
    });
    await tester.pumpWidget(
      captureApp(
        home: const ChatScreen(sessionID: checkoutSessionID),
        boundaryKey: GlobalKey(),
        controller: controller,
      ),
    );
    await _frames(tester);

    const prompt = 'Run the full test suite';
    await tester.enterText(
      find.byKey(const Key('chat-composer-field')),
      prompt,
    );
    await tester.pump();
    final watch = Stopwatch()..start();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    watch.stop();

    // One frame after the tap: the prompt is in the transcript, the box is
    // empty, and nothing has been answered yet.
    expect(controller.selection.isCompleted, isFalse);
    expect(api.prompts, isEmpty);
    expect(find.text(prompt), findsOneWidget);
    debugPrint(
      'PERF_SEND ${'{'}"tap_to_bubble_frames":1,"tap_to_bubble_us":${watch.elapsedMicroseconds}${'}'}',
    );

    controller.selection.complete();
    await tester.pump();
    expect(api.prompts, [prompt]);
    // Still one bubble while the request is on its way.
    expect(find.text(prompt), findsOneWidget);
    api.sendHold.complete();
    await _frames(tester);
    expect(find.text(prompt), findsOneWidget);
  });
}

/// A controller whose session selection (model/agent choice) settles only
/// when the test says so.
class _HeldSelection extends CaptureController {
  _HeldSelection(super.store);

  final selection = Completer<void>();

  @override
  Future<void> waitForSessionSelection(
    String sessionID, {
    ServerGateway? expectedApi,
  }) => selection.future;
}
