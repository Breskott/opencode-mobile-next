// Calm chat captures (2026-09-13): real chat widgets with deterministic
// local content; no server or model calls. Companion to quiet_chat_test.dart,
// adding the phone shapes the stabilization targets: 390dp at 1x and 2x
// text, and a 320dp phone at 2.5x with the keyboard open while a run is
// active. Writes PNGs under docs/qa/calm-chat-2026-09-13/.
//
// Run with:
//   flutter test --no-pub --concurrency=1 tool/capture/calm_chat_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import '../../test/support/setup_capture_preferences.dart';

import 'fixtures.dart';

const _outputDir = 'docs/qa/calm-chat-2026-09-13';
const _draft =
    'Keep the basket after reopening.\n'
    'Show a useful empty state.\n'
    'Check keyboard navigation.';

class _StableChatApi extends CaptureApi {
  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) async => ServerPage(items: cursor == null ? await messages(id) : const []);
}

Future<List<MessageWithParts>> _transcript(String _) async => [
  MessageWithParts(
    info: MessageInfo(
      id: 'stable-assistant',
      sessionID: checkoutSessionID,
      role: 'assistant',
    ),
    parts: [
      for (final (id, tool, input) in [
        ('read-basket', 'read', <String, dynamic>{'filePath': 'src/basket.ts'}),
        ('edit-basket', 'edit', <String, dynamic>{'filePath': 'src/basket.ts'}),
        ('test-basket', 'bash', <String, dynamic>{'command': 'npm test'}),
      ])
        Part(
          id: id,
          callID: id,
          type: 'tool',
          toolName: tool,
          toolState: ToolState.fromJson({
            'status': 'completed',
            'input': input,
            'output': 'Completed successfully.',
          }, toolName: tool),
        ),
      Part(
        type: 'text',
        text:
            'The checkout is ready to review.\n\n'
            'The basket restores after reopening, and the payment '
            'form keeps your place if you go back.\n\n'
            'Run locally with:\n\n```bash\nnpm run dev\n```\n\n'
            'Try adding two items, then reopening the app.',
      ),
    ],
  ),
];

/// Pumps a few explicit frames: the busy composer's activity ring never
/// settles, and the idle screens have nothing left to animate by then.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final scale in [1.0, 2.0]) {
      testWidgets('calm chat $mode at ${scale}x', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final prefs = await setupCapturePreferences();
        final api = _StableChatApi()
          ..busy = {}
          ..messagesHandler = _transcript;
        final controller = await captureController(prefs: prefs, api: api);
        addTearDown(controller.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          captureApp(
            home: const ChatScreen(sessionID: checkoutSessionID),
            boundaryKey: key,
            controller: controller,
            light: light,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('chat-title')), findsOneWidget);
        expect(find.text('Tasks'), findsNothing);
        expect(find.byTooltip('Tasks · 0 running'), findsNothing);
        expect(find.byKey(const Key('prompt-editor-button')), findsNothing);
        expect(find.byKey(const Key('embedded-tool-row')), findsNothing);
        final suffix = scale == 1 ? '' : '-${scale.toInt()}x';
        await writePng(
          '$_outputDir/$mode$suffix-idle.png',
          await capturePng(tester, key),
        );
        await tester.enterText(
          find.byKey(const Key('chat-composer-field')),
          _draft,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await writePng(
          '$_outputDir/$mode$suffix-draft.png',
          await capturePng(tester, key),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('calm chat $mode 320dp keyboard busy at 2.5x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final prefs = await setupCapturePreferences();
      final api = _StableChatApi()
        ..busy = {checkoutSessionID}
        ..messagesHandler = _transcript;
      final controller = await captureController(prefs: prefs, api: api);
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        captureApp(
          home: const ChatScreen(sessionID: checkoutSessionID),
          boundaryKey: key,
          controller: controller,
          light: light,
        ),
      );
      await _pumpFrames(tester);
      final field = find.byKey(const Key('chat-composer-field'));
      await tester.tap(field);
      await tester.enterText(field, 'Keep the basket after reopening.');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull);
      // Stop and Send both sit above the keyboard.
      for (final control in const ['chat-stop-button', 'chat-send-button']) {
        expect(
          tester.getRect(find.byKey(Key(control))).bottom,
          lessThanOrEqualTo(640 - 300),
        );
      }
      await writePng(
        '$_outputDir/$mode-320-keyboard-busy-2.5x.png',
        await capturePng(tester, key),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
