import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';

import '../tool/capture/fixtures.dart';
import 'support/setup_capture_preferences.dart';

/// The pictures of a conversation open as one gallery, in transcript order,
/// starting at the one tapped; Send puts the picture in the message field as
/// a photo and focuses it, and is not offered when the agent cannot take
/// pictures.

/// A 1×1 PNG.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

class _Api extends CaptureApi {
  _Api({this.attachments = true});

  final bool attachments;
  final List<String> read = [];

  @override
  ServerCapabilities get capabilities =>
      ServerCapabilities(promptAttachments: attachments, fileBrowsing: true);

  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async => ServerPage(items: cursor == null ? await messages(id) : const []);

  @override
  Future<List<FileNode>> listFiles([String path = '']) async =>
      path == '/tmp/shots'
      ? [FileNode(name: 'home.png', path: '/tmp/shots/home.png', isDir: false)]
      : const [];

  @override
  Future<FileContent> fileContent(String path) async {
    read.add(path);
    return const FileContent(
      _png,
      type: 'binary',
      encoding: 'base64',
      mimeType: 'image/png',
    );
  }
}

List<MessageWithParts> _conversation() {
  final now = DateTime.now().millisecondsSinceEpoch;
  Part photo(String id) => Part(
    id: id,
    messageID: 'msg_user',
    type: 'file',
    mime: 'image/png',
    filename: '$id.png',
    url: 'data:image/png;base64,$_png',
  );
  return [
    MessageWithParts(
      info: messageInfo(
        'msg_user',
        'user',
        created: now - 5000,
        completed: now - 5000,
      ),
      parts: [
        Part(
          id: 'part_ask',
          messageID: 'msg_user',
          type: 'text',
          text: 'What is wrong with these?',
        ),
        photo('one'),
        photo('two'),
      ],
    ),
    MessageWithParts(
      info: messageInfo(
        'msg_assistant',
        'assistant',
        created: now - 4000,
        completed: now - 1000,
      ),
      parts: [
        Part(
          id: 'part_tool',
          messageID: 'msg_assistant',
          type: 'tool',
          callID: 'call_1',
          toolName: 'screenshot',
          toolState: ToolState(
            status: 'completed',
            outputFiles: const [
              ToolOutputFile(
                url: 'data:image/png;base64,$_png',
                filename: 'tool.png',
                mimeType: 'image/png',
              ),
            ],
          ),
        ),
        Part(
          id: 'part_reply',
          messageID: 'msg_assistant',
          type: 'text',
          text:
              'See ![Image](/tmp/shots/home.png) and '
              '![Image](/tmp/shots/missing.png)',
        ),
      ],
    ),
  ];
}

Future<_Api> _pump(WidgetTester tester, {bool attachments = true}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final prefs = await setupCapturePreferences();
  final api = _Api(attachments: attachments)
    ..busy = {}
    ..messagesHandler = (_) async => _conversation();
  final controller = await captureController(prefs: prefs, api: api);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    captureApp(
      home: const ChatScreen(sessionID: checkoutSessionID),
      boundaryKey: GlobalKey(),
      controller: controller,
    ),
  );
  await _settle(tester);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await _settle(tester);
  return api;
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

bool _fieldFocused(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .any((field) => field.focusNode.hasFocus);

void main() {
  testWidgets('a tapped photo opens a gallery of every picture in order', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sent-photo-open-two')));
    await _settle(tester);
    // two sent photos, the tool's picture and the one the server can read. The
    // reply's missing.png is not a page.
    expect(find.text('2 of 4'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('kit-gallery-pager')),
      const Offset(-400, 0),
      1500,
    );
    await _settle(tester);
    expect(find.text('3 of 4'), findsOneWidget);
    await tester.fling(
      find.byKey(const ValueKey('kit-gallery-pager')),
      const Offset(400, 0),
      1500,
    );
    await tester.fling(
      find.byKey(const ValueKey('kit-gallery-pager')),
      const Offset(400, 0),
      1500,
    );
    await _settle(tester);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a tool picture opens the same gallery', (tester) async {
    await _pump(tester);
    final image = find.byKey(const Key('tool-output-image'));
    expect(image, findsOneWidget);
    await tester.tap(image);
    await _settle(tester);
    expect(find.text('3 of 4'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Send puts one photo in the message field and focuses it', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const Key('attachment-thumbnail')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sent-photo-open-one')));
    await _settle(tester);
    await tester.fling(
      find.byKey(const ValueKey('kit-gallery-pager')),
      const Offset(-400, 0),
      1500,
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('kit-gallery-send')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('kit-gallery-pager')), findsNothing);
    // The note names the picture that was sent, not the one tapped.
    expect(find.text('two.png attached. Add your comment.'), findsOneWidget);
    expect(find.byKey(const Key('attachment-thumbnail')), findsOneWidget);
    expect(_fieldFocused(tester), isTrue);
    // Nothing was sent: the conversation holds the same two messages.
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Send is hidden when the agent cannot take pictures', (
    tester,
  ) async {
    await _pump(tester, attachments: false);
    await tester.tap(find.byKey(const ValueKey('sent-photo-open-one')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('kit-gallery-pager')), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-gallery-send')), findsNothing);
    expect(find.byKey(const ValueKey('kit-gallery-edit')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
